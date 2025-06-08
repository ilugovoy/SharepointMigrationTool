param(
    [string]$csvFilePath,   # Путь к CSV файлу
    [string]$logFolderPath  # Путь для логов
)

# Установка кодировки консоли на UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Инициализация лог-файла
if ($global:MigrationContext.processing.enable_csv_splitting) {
    # Если включен сплит, используем общий лог-файл
    $logFilePath = Join-Path $logFolderPath "Upload_$($global:MigrationContext.site.name)_combined_log.txt"
} else {
    # Если сплит выключен, используем лог-файл на основе имени CSV
    $logFilePath = Join-Path $logFolderPath "Upload_$($global:MigrationContext.site.name).txt"
}

# Функция для записи в лог
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [$($global:MigrationContext.site.name)] $Message"
    
    # Добавляем запись в лог
    Add-Content -Path $logFilePath -Value $logMessage -Encoding UTF8
    Write-Host $logMessage
}

# Функция для работы с длинными путями
function Get-LongPath {
    param([string]$Path)
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        $Path = [System.IO.Path]::GetFullPath($Path)
    }
    if ($Path.Length -ge 240) {
        return "\\?\" + $Path
    }
    return $Path
}

# Функция для форматирования URL SharePoint
function Format-SharePointUrl {
    param([string]$Url)
    $cleanUrl = $Url.Trim() -replace "/Pages/Home\.aspx$", "" -replace "/$", ""
    return $cleanUrl
}

try {
    Write-Log "Initializing SharePoint upload process"
    Write-Log "CSV file: $csvFilePath"

    # Проверка существования CSV файла
    if (-not [System.IO.File]::Exists($csvFilePath)) {
        throw "CSV file not found: $csvFilePath"
    }

    # Отладочный вывод: проверка содержимого CSV
    Write-Host "Reading CSV file: $csvFilePath" -ForegroundColor Cyan
    $csvContent = [System.IO.File]::ReadAllLines($csvFilePath)
    $data = $csvContent | ConvertFrom-Csv -Delimiter ';'
    Write-Log "Imported $($data.Count) records from CSV"
    Write-Host "CSV data imported successfully. First row: $($data[0] | ConvertTo-Json)" -ForegroundColor Cyan
    
    # Подключение к SharePoint
    Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction Stop
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1

    # Импорт данных
    $siteInfo = $data | Select-Object SiteURL, LibraryName | Sort-Object -Property SiteURL, LibraryName -Unique

    # Локальная статистика для текущего CSV
    $localStats = @{
        TotalFiles = 0
        Uploaded = 0
        Skipped = 0
        Failed = 0
        TotalSizeMB = 0
        TotalFolders = 0
    }

    # Обработка данных
    foreach ($site in $siteInfo) {
        $SiteURL = Format-SharePointUrl -Url $site.SiteURL
        $LibraryName = $site.LibraryName

        Write-Log "Processing site: $SiteURL"
        Write-Log "Library: $LibraryName"

        try {
            $Web = Get-SPWeb -Identity $SiteURL -ErrorAction Stop

            # Загрузка файлов
            $filesToUpload = $data | 
                Where-Object { $_.SiteURL -eq $site.SiteURL -and $_.LibraryName -eq $LibraryName }

            # Создание папок
            $siteFolders = $filesToUpload | Select-Object SPFolder | Sort-Object -Property SPFolder -Unique
            foreach ($folder in $siteFolders) {
                $localStats.TotalFolders++
                $targetFolder = $folder.SPFolder
                
                try {
                    Write-Log "Checking folder: $targetFolder in library"
                    
                    # Разбиваем путь на компоненты
                    $FolderTree = $targetFolder -split '\\'
                    $currentPath = $LibraryName
                    $createdFolders = @()
                    $folderCreationError = $false
            
                    foreach ($folderName in $FolderTree) {
                        try {
                            $newFolderPath = Join-Path -Path $currentPath -ChildPath $folderName
                            $spFolder = $Web.GetFolder($newFolderPath)
                            
                            if (-not $spFolder.Exists) {
                                try {
                                    Write-Log "Attempting to create folder: $folderName in $currentPath"
                                    $parentFolder = $Web.GetFolder($currentPath)
                                    $newFolder = $parentFolder.SubFolders.Add($folderName)
                                    $createdFolders += $newFolder.Url
                                    $currentPath = $newFolder.ServerRelativeUrl
                                }
                                catch {
                                    Write-Log "ERROR creating folder '$folderName': $($_.Exception.Message)" -Level ERROR
                                    $localStats.Failed++
                                    $folderCreationError = $true
                                    continue  # Пропускаем эту подпапку, но продолжаем цикл
                                }
                            }
                            else {
                                $currentPath = $spFolder.ServerRelativeUrl
                            }
                        }
                        catch {
                            Write-Log "ERROR accessing folder '$folderName': $($_.Exception.Message)" -Level ERROR
                            $localStats.Failed++
                            $folderCreationError = $true
                            continue
                        }
                        
                        if ($folderCreationError) {
                            Write-Log "Skipping subsequent subfolders due to error" -Level WARNING
                            break  # Прерываем создание вложенных папок
                        }
                    }
            
                    if (-not $folderCreationError -and $createdFolders.Count -gt 0) {
                        Write-Log "Successfully created folders: $($createdFolders -join ', ')"
                    }
                }
                catch {
                    Write-Log "Critical folder error: $($_.Exception.Message)" -Level ERROR
                    $localStats.Failed++
                }
                finally {
                    # Сбрасываем флаг ошибки для следующей итерации
                    $folderCreationError = $false
                }
            }

            Write-Log "Folder tree creation finished in library: $LibraryName"
            Write-Log "Starting data upload in library: $LibraryName"

            foreach ($file in $filesToUpload) {
                $filePath = Get-LongPath -Path $file.FilePath
                $fileName = $file.FileName
                $spPath = "$LibraryName/$($file.SPFolder)/$fileName"

                # Проверка существования файла
                if (-not [System.IO.File]::Exists($filePath)) {
                    Write-Log "File not found: $filePath" -Level ERROR
                    $localStats.Failed++
                    continue
                }
                $localStats.TotalFiles++

                try {
                    if (-not $Web.GetFile($spPath).Exists) {
                        $fileInfo = [System.IO.FileInfo]::new($filePath)
                        $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                        Write-Log "Starting upload: $($file.FileName) ($fileSizeMB MB) from $filePath"

                        $fileStream = [System.IO.File]::OpenRead($filePath)
                        try {
                            $startTime = Get-Date
                            $Web.Files.Add($spPath, $fileStream, $true) | Out-Null

                            $localStats.Uploaded++
                            $fileSizeMB = [math]::Round($fileStream.Length / 1MB, 2)
                            $localStats.TotalSizeMB += $fileSizeMB
                            $duration = ((Get-Date) - $startTime).TotalSeconds

                            Write-Log "Uploaded: $($file.FileName) ($fileSizeMB MB) in $duration sec"
                        }
                        finally {
                            $fileStream.Close()
                        }
                    }
                    else {
                        Write-Log "Skipped (exists): $($file.FileName)" -Level WARNING
                        $localStats.Skipped++
                    }
                }
                catch {
                    Write-Log "Error uploading $($file.FileName): $($_.Exception.Message)" -Level ERROR
                    $localStats.Failed++
                }
            }


        }
        catch {
            Write-Log "Error accessing site $SiteURL : $($_.Exception.Message)" -Level ERROR
            $localStats.Failed ++
            continue
        }
        finally {
            if ($Web) {
                $Web.Dispose()
            }
        }
    }

    # Вывод статистики для текущего CSV
    Write-Log "`n=== Upload Statistics for $csvFilePath ==="
    Write-Log "Total files processed: $($localStats.TotalFiles)"
    Write-Log "Successfully uploaded: $($localStats.Uploaded)"
    Write-Log "Skipped (already exists): $($localStats.Skipped)"
    Write-Log "Failed uploads: $($localStats.Failed)"
    Write-Log "Total uploaded size: $($localStats.TotalSizeMB) MB"
    Write-Log "Log file saved to: $logFilePath"

    # Обновляем глобальную статистику в контексте миграции
    $global:MigrationContext.stats.TotalFiles += $localStats.TotalFiles
    $global:MigrationContext.stats.Uploaded += $localStats.Uploaded
    $global:MigrationContext.stats.Skipped += $localStats.Skipped
    $global:MigrationContext.stats.Failed += $localStats.Failed
    $global:MigrationContext.stats.TotalSizeMB += $localStats.TotalSizeMB
    $global:MigrationContext.stats.TotalCSVFiles++
    $global:MigrationContext.stats.TotalFilesOnSharePoint += $localStats.TotalFilesOnSharePoint
    $global:MigrationContext.stats.ExistingFilesOnSharePoint += $localStats.ExistingFilesOnSharePoint
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level FATAL
    exit 1
}