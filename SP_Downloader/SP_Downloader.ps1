<#
.SYNOPSIS
    Скрипт для скачивания нескольких библиотек и папок с SharePoint
.DESCRIPTION
    Работает через SharePoint PowerShell Module
.NOTES
    На сайте должен быть выполнен вход от имени пользователя, имеющего доступ к целевым папкам
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

#######################
### ИЗМЕНЯЕМЫЕ НАСТРОЙКИ ###
#######################

# Короткое имя сайта
$SiteName = "StPetersburg"

# URL сайта (без путей к библиотекам и папкам! В ссылке не должно быть знака % (%20)!!!!
$SiteURL = "https://sharepoint.internal.ru/sites/StPetersburg"

# Настройки библиотек и папок
$LibrarySettings = @(
    @{
        # Не использовать %20 вместо пробелов!
        LibraryName = "St.Petersburg plant"
        # Чтобы скачать целиком библиотеку эти поля оставить пустыми в виде ""
        Folders     = @(
            "Security"
        )
    },
    @{
        LibraryName = "Site Assets"
        Folders     = @(
            ""
            # "Templates"
        )
    }
)

# Базовый путь для сохранения
$DownloadRoot = "$env:USERPROFILE\Desktop\SharePointDownload\$SiteName"

#######################
### СИСТЕМНЫЕ НАСТРОЙКИ ###
#######################

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1

#######################
### ЛОГИРОВАНИЕ ###
#######################

$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFilePath = "$env:USERPROFILE\Desktop\SharePointDownload\Download_Log_$($SiteName)_$currentDateTime.txt"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFilePath -Value $logMessage -Encoding UTF8
    Write-Host $logMessage
}

#######################
### ОСНОВНЫЕ ФУНКЦИИ ###
#######################

function Get-SPFolder {
    param(
        [Microsoft.SharePoint.SPFolder]$Folder,
        [string]$LocalPath
    )
    
    try {
        if (-not (Test-Path $LocalPath)) {
            New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
            Write-Log "Создана папка: $LocalPath"
        }

        foreach ($file in $Folder.Files) {
            try {
                $localFilePath = Join-Path $LocalPath $file.Name
                
                if (-not (Test-Path $localFilePath)) {
                    Write-Log "Скачивание файла: $($file.ServerRelativeUrl)"
                    $fileBytes = $file.OpenBinary()
                    [System.IO.File]::WriteAllBytes($localFilePath, $fileBytes)
                    Write-Log "Файл сохранен: $localFilePath"
                }
                else {
                    Write-Log "Файл уже существует: $localFilePath" -Level "WARNING"
                }
            }
            catch {
                Write-Log "Ошибка при скачивании файла $($file.Name): $_" -Level "ERROR"
            }
        }

        foreach ($subFolder in $Folder.SubFolders) {
            if ($subFolder.Name -ne "Forms") {
                $newLocalPath = Join-Path $LocalPath $subFolder.Name
                Get-SPFolder -Folder $subFolder -LocalPath $newLocalPath
            }
        }
    }
    catch {
        Write-Log "Ошибка при обработке папки $($Folder.Url): $_" -Level "ERROR"
    }
}

#######################
### ОСНОВНОЙ КОД ###
#######################

try {
    Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction Stop
    Set-ExecutionPolicy RemoteSigned -Scope Process -Force

    Write-Log "Начало скачивания с сайта: $SiteURL"
    $Web = Get-SPWeb -Identity $SiteURL

    foreach ($Library in $LibrarySettings) {
        try {
            $LibraryName = $Library.LibraryName
            $Folders = $Library.Folders
            $LibraryDownloadRoot = Join-Path $DownloadRoot $LibraryName

            Write-Log "`nОбработка библиотеки: $LibraryName"
            
            $List = $Web.Lists.TryGetList($LibraryName)
            if (-not $List) {
                Write-Log "Библиотека '$LibraryName' не найдена!" -Level "ERROR"
                continue
            }

            # Если папки не указаны - скачиваем всю библиотеку
            if ($Folders.Count -eq 0) {
                $Folders = @("")
            }

            foreach ($FolderPath in $Folders) {
                try {
                    $normalizedPath = $FolderPath.Trim('/').Replace('\', '/')
                    $FullFolderPath = "$($List.RootFolder.ServerRelativeUrl)/$normalizedPath"
                    
                    $Folder = $Web.GetFolder($FullFolderPath)
                    
                    if (-not $Folder.Exists) {
                        Write-Log "Папка '$FolderPath' не найдена!" -Level "ERROR"
                        continue
                    }

                    $LocalDownloadPath = Join-Path $LibraryDownloadRoot $normalizedPath
                    Get-SPFolder -Folder $Folder -LocalPath $LocalDownloadPath
                    
                    Write-Log "Успешно обработана папка: $FolderPath"
                }
                catch {
                    Write-Log "Ошибка при обработке папки '$FolderPath': $_" -Level "ERROR"
                }
            }
        }
        catch {
            Write-Log "Ошибка при обработке библиотеки '$LibraryName': $_" -Level "ERROR"
        }
    }

    Write-Log "Скачивание всех данных завершено!"
}
catch {
    Write-Log "Критическая ошибка: $_" -Level "ERROR"
}
finally {
    if ($null -ne $Web) {
        $Web.Dispose()
    }
}