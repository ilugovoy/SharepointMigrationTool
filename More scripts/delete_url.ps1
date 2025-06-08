### Колонка "Action" (Действие):
# "Check" - Файл был проверен, но не требует удаления Пример: .url файл найден, но соответствующего файла без расширения нет
# "Marked" - Файл помечен для удаления (найден соответствующий файл без .url) Пример: Найден file.url и существует file
# "Delete" - Была попытка удаления файла Пример: Непосредственное действие удаления
# "Process Library" - Начало обработки библиотеки
# "Access Site" - Попытка доступа к сайту
# "Check Library" - Проверка существования библиотеки

### Колонка "Status" (Статус выполнения):
# "Kept" - Файл оставлен (не удален) Причина: Нет соответствующего файла без .url
# "Pending" - Файл помечен для удаления (ожидает удаления) Примечание: Это промежуточный статус перед фактическим удалением
# "Success" - Действие выполнено успешно Пример: Файл успешно удален
# "Failed" - Действие не выполнено Причины: Нет прав, файл заблокирован, ошибка доступа и т.д.

#######################
### Script Parameters ###
#######################

# Список сайтов для обработки
$sitesToProcess = @(
    "https://sharepoint.internal.ru/sites/Site1"
    "https://sharepoint.internal.ru/sites/Site2"
    # Можно добавить другие сайты
)

# Пути для логов
$logFolder = "M:\URL_CLEANUP_LOGS"
$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFilePath = "$logFolder\URL_Cleanup_$currentDateTime.csv"

# Подключение к SharePoint
Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

#######################
### Functions ###
#######################

function Write-Log {
    param (
        [string]$SiteURL,
        [string]$LibraryName,
        [string]$FolderPath,
        [string]$FileName,
        [string]$Action,
        [string]$Status,
        [string]$Notes = ""
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = [PSCustomObject]@{
        Timestamp    = $timestamp
        SiteURL      = $SiteURL
        LibraryName  = $LibraryName
        FolderPath   = $FolderPath
        FileName     = $FileName
        Action       = $Action
        Status       = $Status
        Notes        = $Notes
    }
    
    $logEntry | Export-Csv -Path $logFilePath -Append -NoTypeInformation -Encoding UTF8
    Write-Host "[$timestamp] [$Status] $Action - $FileName $Notes"
}

function Start-Process-Folder {
    param (
        [Microsoft.SharePoint.SPFolder]$Folder,
        [string]$LibraryName,
        [Microsoft.SharePoint.SPWeb]$Web
    )
    
    try {
        Write-Host "Scanning folder: $($Folder.ServerRelativeUrl)"
        
        # 1. Сначала собираем ВСЕ .url файлы для удаления
        $filesToDelete = @()
        $allFiles = @($Folder.Files | ForEach-Object { $_ })
        
        foreach ($file in $allFiles) {
            if ($file.Name -like "*.url") {
                $baseName = $file.Name -replace "\.url$", ""
                $correspondingFile = $allFiles | Where-Object { $_.Name -eq $baseName }
                
                if ($correspondingFile) {
                    $filesToDelete += $file
                    Write-Host "  Marked for deletion: $($file.Name)" -ForegroundColor Green
                    Write-Log -SiteURL $Web.Url -LibraryName $LibraryName -FolderPath $Folder.ServerRelativeUrl `
                        -FileName $file.Name -Action "Marked" -Status "Pending" `
                        -Notes "Corresponding file found: $($correspondingFile.Name)"
                }
                else {
                    Write-Host "  Keeping URL file: $($file.Name)" -ForegroundColor Yellow
                    Write-Log -SiteURL $Web.Url -LibraryName $LibraryName -FolderPath $Folder.ServerRelativeUrl `
                        -FileName $file.Name -Action "Check" -Status "Kept" -Notes "No corresponding file"
                }
            }
        }
        
        # 2. Затем удаляем отмеченные файлы
        foreach ($file in $filesToDelete) {
            try {
                $file.Delete()
                Write-Host "  Successfully deleted: $($file.Name)" -ForegroundColor DarkGreen
                Write-Log -SiteURL $Web.Url -LibraryName $LibraryName -FolderPath $Folder.ServerRelativeUrl `
                    -FileName $file.Name -Action "Delete" -Status "Success" `
                    -Notes "Corresponding file exists"
            }
            catch {
                Write-Host "  Error deleting file: $($_.Exception.Message)" -ForegroundColor Red
                Write-Log -SiteURL $Web.Url -LibraryName $LibraryName -FolderPath $Folder.ServerRelativeUrl `
                    -FileName $file.Name -Action "Delete" -Status "Failed" -Notes $_.Exception.Message
            }
        }
        
        # 3. Обрабатываем подпапки
        $subFolders = @($Folder.SubFolders | Where-Object { $_.Name -notin @("Forms", "_private", "_catalogs") })
        foreach ($subFolder in $subFolders) {
            Start-Process-Folder -Folder $subFolder -LibraryName $LibraryName -Web $Web
        }
    }
    catch {
        Write-Host "Error processing folder $($Folder.ServerRelativeUrl): $($_.Exception.Message)" -ForegroundColor Red
    }
}

#######################
### Main Script ###
#######################

# Создаем папку для логов
if (-not (Test-Path -Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}

# Инициализируем лог-файл с заголовками только если файл не существует
if (-not (Test-Path $logFilePath)) {
    [PSCustomObject]@{
        Timestamp    = "Timestamp"
        SiteURL      = "SiteURL"
        LibraryName  = "LibraryName"
        FolderPath   = "FolderPath"
        FileName     = "FileName"
        Action       = "Action"
        Status       = "Status"
        Notes        = "Notes"
    } | Export-Csv -Path $logFilePath -NoTypeInformation -Encoding UTF8
}

Write-Host "`n### URL File Cleanup Script ###`n" -ForegroundColor Cyan
Write-Host "Log file: $logFilePath`n"
Write-Host "Processing sites: $($sitesToProcess -join ', ')`n" -ForegroundColor Yellow

foreach ($siteUrl in $sitesToProcess) {
    try {
        Write-Host "`nProcessing site: $siteUrl" -ForegroundColor Magenta
        $web = Get-SPWeb -Identity $siteUrl -ErrorAction Stop
        
        # Обрабатываем ВСЕ не скрытые библиотеки документов
        $documentLibraries = $web.Lists | Where-Object { 
            $_.BaseType -eq "DocumentLibrary" -and 
            $_.Hidden -eq $false
        }
        
        Write-Host "Found $($documentLibraries.Count) document libraries" -ForegroundColor Yellow
        
        foreach ($library in $documentLibraries) {
            Write-Host "`nProcessing library: $($library.Title)" -ForegroundColor Blue
            Write-Host "Items: $($library.ItemCount), Root: $($library.RootFolder.ServerRelativeUrl)"
            
            Start-Process-Folder -Folder $library.RootFolder -LibraryName $library.Title -Web $web
        }
        
        $web.Dispose()
        Write-Host "Completed processing site: $siteUrl" -ForegroundColor Green
    }
    catch {
        Write-Host "Error processing site: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nScript execution completed!`n" -ForegroundColor Cyan