#######################
### Изменяемые параметры ###
#######################

# Путь к CSV-файлу
$csvFilePath = "M:\CSV_FOR_SCRIPT\Site1.csv"

#######################
### Прочие параметры ###
#######################

# Логирование
$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$fileNamePart = ($csvFilePath -split '\\')[-1] -replace '[_\-].*', '' -replace ' ', '_'
$logFilePath = "M:\UPLOAD_LOGS\Upload_${fileNamePart}_${currentDateTime}.txt"

#######################
### Функции ###
#######################

# Функция для записи в лог
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO" 
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFilePath -Value $logMessage -Encoding UTF8
    Write-Host $logMessage 
}

# Функция для работы с длинными путями
function Get-LongPath {
    param([string]$Path)
    if ($Path.Length -gt 240) {
        return "\\?\" + $Path
    }
    return $Path
}

#######################
### Основной код ###
#######################

# Начало работы
Add-PSSnapin Microsoft.SharePoint.PowerShell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1
Write-Log "Log file created: $logFilePath"
Write-Log "Starting upload..."

# Импорт данных из CSV
$data = Import-Csv -Path $csvFilePath -Delimiter ';'
$siteInfo = $data | Select-Object SiteURL, LibraryName | Sort-Object -Property SiteURL, LibraryName -Unique

# Переменные для статистики
$totalFilesProcessed = 0
$totalFilesUploaded = 0
$totalFilesFailed = 0
$totalSizeUploaded = 0

# Обрабатываем каждый сайт и библиотеку
foreach ($site in $siteInfo) {
    $SiteURL = $site.SiteURL
    $LibraryName = $site.LibraryName
    Write-Log "Uploading to site: $SiteURL, folder: $LibraryName"

    # Получаем данные для текущего сайта и библиотеки
    $siteData = $data | Where-Object { $_.SiteURL -eq $SiteURL -and $_.LibraryName -eq $LibraryName }
    $Web = Get-SPWeb $SiteURL
    
    # Создаем структуру папок
    Write-Log "Creating folder tree in library: $LibraryName"
    $siteFolders = $siteData | Select-Object SPFolder | Sort-Object -Property SPFolder -Unique
    foreach ($folder in $siteFolders) {
        $targetFolder = $folder.SPFolder
        Write-Log "Checking folder: $targetFolder in library"

        $FolderTree = $targetFolder -split '\\'
        $SourcePath = $LibraryName
        $PrevPath = $LibraryName

        for ($i = 0; $i -lt $FolderTree.Length; $i++) {
            $FolderName = $FolderTree[$i]
            $SourcePath = Join-Path -Path $SourcePath -ChildPath $FolderTree[$i]
            $folder = $Web.GetFolder($SourcePath)
            $Exist = $folder.Exists

            if ($Exist -like '*False*') {
                Write-Log "Creating folder: $targetFolder"
                $folder = $Web.GetFolder($PrevPath)
                $folder.SubFolders.Add($FolderName)
            }
            $PrevPath = Join-Path -Path $PrevPath -ChildPath $FolderTree[$i]
        }
    }

    Write-Log "Folder tree creation finished in library: $LibraryName"
    Write-Log "Starting data upload in library: $LibraryName"

    # Загружаем файлы
    foreach ($folder in $siteFolders) {
        $SPTargetFolder = $folder.SPFolder 
        Write-Log "Starting upload to folder: $SPTargetFolder"
    
        $fileData = $siteData | Where-Object { $_.SPFolder -eq $SPTargetFolder }
        $SPFolderPath = Join-Path -Path $LibraryName -ChildPath $SPTargetFolder
        $SPPath = $Web.GetFolder($SPFolderPath)
    
        foreach ($file in $fileData) {
            $FilePath = Get-LongPath -Path $file.FilePath
            $FileName = $file.FileName
            $SPFilePath = Join-Path -Path $SPFolderPath -ChildPath $FileName
            $file = $Web.GetFile($SPFilePath)
            $exist = $file.Exists
        
            # Увеличиваем счетчик обработанных файлов
            $totalFilesProcessed++
        
            if ($exist -like '*False*') {
                try {
                    # Получаем размер файла через .NET метод
                    $fileSize = ([System.IO.File]::OpenRead($FilePath)).Length
                    Write-Log "Starting upload: $FilePath (Size: $([math]::Round($fileSize / 1MB, 2))) MB"
                    
                    # Загружаем файл и проверяем результат
                    $SourceFile = [System.IO.File]::OpenRead($FilePath)
                    try {
                        $uploadResult = $SPPath.Files.Add($FileName, $SourceFile)
                        if ($uploadResult) {
                            Write-Log "Finished upload: $FilePath (Size: $([math]::Round($fileSize / 1MB, 2))) MB"
                            $totalFilesUploaded++
                            $totalSizeUploaded += $fileSize
                        } else {
                            throw "Upload failed without exception"
                        }
                    } catch {
                        $errorMessage = $_.Exception.Message
                        Write-Log "Failed to upload: $FilePath. Error: $errorMessage" -Level "ERROR"
                        $totalFilesFailed++
                    }
                } catch {
                    $errorMessage = $_.Exception.Message
                    Write-Log "Failed to get file size or upload: $FilePath. Error: $errorMessage" -Level "ERROR"
                    $totalFilesFailed++
                } finally {
                    if ($SourceFile) {
                        $SourceFile.Close()
                    }
                }
            } else {
                Write-Log "File $FileName already exists in $SPTargetFolder, skipping upload."
            }
        }
    
        Write-Log "Finished upload to folder: $SPTargetFolder"
    }

    Write-Log "Finished data upload in library: $LibraryName"
}

Write-Log "Uploading to site: $SiteURL completed."
Write-Log "Statistics:"
Write-Log "  - Total files processed: $totalFilesProcessed"
Write-Log "  - Total files uploaded: $totalFilesUploaded"
Write-Log "  - Total files failed: $totalFilesFailed"
Write-Log "  - Total size uploaded: $([math]::Round($totalSizeUploaded / 1MB, 2)) MB"