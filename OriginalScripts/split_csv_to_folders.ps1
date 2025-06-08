param(
    [string]$csvPath,
    [string]$outputPath,
    [string]$logFolderPath,
    [string]$SiteName
)

# Установка кодировки консоли на UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFilePath -Value $logMessage -Encoding UTF8
    Write-Host $logMessage
}

# Инициализация логов
$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFilePath = Join-Path $logFolderPath "SplitCSV_${SiteName}_${currentDateTime}.txt"

try {
    Write-Log "Starting CSV splitting process"

    # Проверка существования CSV файла
    if (-not (Test-Path $csvPath)) {
        throw "CSV file not found: $csvPath"
    }

    # Проверка содержимого CSV файла
    $csvContent = Get-Content -Path $csvPath -Encoding UTF8 -ErrorAction Stop
    if (-not $csvContent) {
        throw "CSV file is empty: $csvPath"
    }

    # Создание папки для разбитых CSV
    $splitFolder = Join-Path $outputPath "SplitCSV_$SiteName"
    if (-not (Test-Path -Path $splitFolder)) {
        New-Item -ItemType Directory -Path $splitFolder -Force | Out-Null
        Write-Log "Created folder: $splitFolder"
    }

    # Чтение CSV файла
    $header = $csvContent[0]
    $dataRows = $csvContent | Select-Object -Skip 1

    # Группировка данных по папкам
    $groupedData = $dataRows | Group-Object { 
        $folder = ($_ -split ';')[3] -split '\\' | Select-Object -First 1
        Write-Host "Grouping by folder: $folder" -ForegroundColor Cyan
        $folder
    }

    # Отладочный вывод
    Write-Host "Total groups: $($groupedData.Count)" -ForegroundColor Cyan
    foreach ($group in $groupedData) {
        Write-Host "Group: $($group.Name) | Rows: $($group.Group.Count)" -ForegroundColor Cyan
    }

    # Создание отдельных CSV файлов для каждой группы
    foreach ($group in $groupedData) {
        $newFileName = Join-Path $splitFolder "$($group.Name).csv"
        $header | Set-Content -Path $newFileName -Encoding UTF8
        $group.Group | Add-Content -Path $newFileName -Encoding UTF8
        Write-Log "Created file: $newFileName with $($group.Group.Count) rows"
    }

    Write-Log "CSV splitting completed successfully. Files saved to: $splitFolder"
}
catch {
    Write-Log "Error in CSV splitting: $_" -Level ERROR
    throw
}