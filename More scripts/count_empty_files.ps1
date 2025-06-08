# Список путей к директориям
$targetPaths = @(
    "M:\MigrationMaster\Site1 - Folder1"
)

# Функция для работы с длинными путями
function Get-LongPath {
    param(
        [string]$Path
    )
    return "\\?\$Path"
}

# Функция для подсчета пустых файлов и папок
function Start-Count-EmptyItems {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Paths
    )

    # Инициализация счетчиков
    $totalEmptyFiles = 0
    $totalEmptyFolders = 0

    try {
        foreach ($path in $Paths) {
            Write-Host "Processing path: $path" -ForegroundColor Cyan
            
            # Преобразуем путь для работы с длинными путями
            $longPath = Get-LongPath $path

            # Проверяем, существует ли путь
            if (!(Test-Path $longPath)) {
                Write-Host "Path $path does not exist"
                continue
            }

            # Подсчет пустых файлов
            $emptyFiles = @()
            try {
                $files = Get-ChildItem -Path $longPath -Recurse -File -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    try {
                        if ($file.Length -eq 0) {
                            $emptyFiles += $file
                        }
                    }
                    catch {
                        Write-Host "Skipping problematic file: $($file.FullName)" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                Write-Host "Error processing files in ${path}: $_" -ForegroundColor Red
            }

            # Подсчет пустых папок
            $emptyFolders = @()
            try {
                $folders = Get-ChildItem -Path $longPath -Recurse -Directory -ErrorAction SilentlyContinue
                foreach ($folder in $folders) {
                    try {
                        if ((Get-ChildItem $folder.FullName -Recurse -ErrorAction SilentlyContinue).Count -eq 0) {
                            $emptyFolders += $folder
                        }
                    }
                    catch {
                        Write-Host "Skipping problematic folder: $($folder.FullName)" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                Write-Host "Error processing folders in ${path}: $_" -ForegroundColor Red
            }

            # Вывод результатов
            Write-Host "Empty files (size 0 bytes) in ${path}:"
            $emptyFiles | Select-Object Name, FullName
            Write-Host "Number of empty files: $($emptyFiles.Count)"

            Write-Host "Empty folders in ${path}:"
            $emptyFolders | Select-Object Name, FullName
            Write-Host "Number of empty folders: $($emptyFolders.Count)"
            Write-Host ""

            # Обновление общих счетчиков
            $totalEmptyFiles += $emptyFiles.Count
            $totalEmptyFolders += $emptyFolders.Count
        }

        # Вывод общей статистики
        Write-Host "Overall Statistics:" -ForegroundColor Yellow
        $overallStats = [PSCustomObject]@{
            "Path" = "Total"
            "Empty Files" = $totalEmptyFiles
            "Empty Folders" = $totalEmptyFolders
            "Total Empty Items" = $totalEmptyFiles + $totalEmptyFolders
        }
        $overallStats | Format-Table -AutoSize
    }
    catch {
        Write-Host "An error occurred: $_"
    }
}

# Запуск функции с передачей списка путей
Start-Count-EmptyItems -Paths $targetPaths
