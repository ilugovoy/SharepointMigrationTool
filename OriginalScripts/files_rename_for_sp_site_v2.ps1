param(
    [string[]]$rootFolders,                     # Массив путей к папкам
    [string]$SiteName,                          # Имя сайта
    [string]$logFolderPath,                     # Путь для логов
    [string]$replaceChars = '[;#%*:<>!?/\\|"]'  # Символы для замены
)

# Установка кодировки консоли на UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

#######################
### Функции ###
#######################

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logPath -Value $logMessage -Encoding UTF8
    Write-Host $logMessage 
}

function Format-Name {
    param([string]$Name)
    # Убираем запрещённые символы
    $newName = $Name -replace $replaceChars, ''
    # Удаляем пробелы в начале и конце имени
    $newName = $newName.Trim()
    # Заменяем множественные пробелы на один
    $newName = $newName -replace '\s+', ' '
    return $newName
}

#######################
### Основной скрипт ###
#######################

# Инициализация логов
$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logPath = Join-Path $logFolderPath "Renaming_${SiteName}_${currentDateTime}.txt"

# Включаем поддержку длинных путей
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1

# Настройка обработки ошибок
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO

# Статистика
$stats = @{
    TotalFiles = 0
    TotalFolders = 0
    RenamedFiles = 0
    RenamedFolders = 0
    Errors = 0
}

# Создаем лог-файл
New-Item -Path $logPath -ItemType File -Force | Out-Null

# Обрабатываем каждую папку
foreach ($folder in $rootFolders) {
    if (-not (Test-Path $folder)) {
        Write-Log "Folder not found: $folder" -Level WARNING
        continue
    }
    
    Write-Log "Processing folder: $folder"
    
    # Обрабатываем файлы
    $files = [System.IO.Directory]::EnumerateFiles($folder, "*", [System.IO.SearchOption]::AllDirectories)
    foreach ($file in $files) {
        $stats.TotalFiles++
        $originalFullName = $file
        
        try {
            $fileInfo = New-Object System.IO.FileInfo($originalFullName)
            $newName = Format-Name -Name $fileInfo.Name
            $newFullName = Join-Path $fileInfo.DirectoryName $newName

            # Добавляем префикс для длинных путей
            if ($newFullName.Length -gt 240 -and -not $newFullName.StartsWith("\\?\")) {
                $newFullName = "\\?\" + $newFullName
            }

            if ($newName -ne $fileInfo.Name) {
                if ([System.IO.File]::Exists($newFullName)) {
                    Write-Log "Skipped: $originalFullName (file with new name already exists)" -Level WARNING
                    $stats.Errors++
                    continue
                }

                # Переименовываем файл
                $fileInfo.MoveTo($newFullName)
                Write-Log "Renamed file: `nOLD: $originalFullName `nNEW: $newFullName"
                $stats.RenamedFiles++
            }
        }
        catch {
            $stats.Errors++
            Write-Log "Error renaming file $originalFullName : $($_.Exception.Message)" -Level ERROR
            Write-Log "Full path length: $($originalFullName.Length)" -Level DEBUG
        }
    }

    # Обрабатываем папки
    $folders = [System.IO.Directory]::EnumerateDirectories($folder, "*", [System.IO.SearchOption]::AllDirectories)
    foreach ($folderPath in $folders) {
        $stats.TotalFolders++
        $originalFullName = $folderPath
        
        try {
            $directoryInfo = New-Object System.IO.DirectoryInfo($originalFullName)
            $newName = Format-Name -Name $directoryInfo.Name
            $newFullName = Join-Path $directoryInfo.Parent.FullName $newName

            # Добавляем префикс для длинных путей
            if ($newFullName.Length -gt 240) {
                $newFullName = "\\?\" + $newFullName
            }

            if ($newName -ne $directoryInfo.Name) {
                if ([System.IO.Directory]::Exists($newFullName)) {
                    Write-Log "Skipped: $originalFullName (folder with new name already exists)" -Level WARNING
                    $stats.Errors++
                    continue
                }

                # Переименовываем папку
                $directoryInfo.MoveTo($newFullName)
                Write-Log "Renamed folder: `nOLD: $originalFullName `nNEW: $newFullName"
                $stats.RenamedFolders++
            }
        }
        catch {
            $stats.Errors++
            Write-Log "Error renaming folder $originalFullName : $($_.Exception.Message)" -Level ERROR
            Write-Log "Full path length: $($originalFullName.Length)" -Level DEBUG
        }
    }
}

# Вывод статистики
Write-Log "`n=== Statistics ==="
Write-Log "Total files: $($stats.TotalFiles) | Renamed files: $($stats.RenamedFiles)"
Write-Log "Total folders: $($stats.TotalFolders) | Renamed folders: $($stats.RenamedFolders)"
Write-Log "Errors: $($stats.Errors)"
Write-Log "Log: $logPath"