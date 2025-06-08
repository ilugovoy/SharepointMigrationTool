# Установка кодировки консоли на UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    Write-Log "Starting CSV splitting process"
    
    # Используем путь к созданному CSV файлу из контекста
    if (-not $global:MigrationContext.GeneratedCsvPath) {
        throw "No CSV file was generated. Run CsvGenerator first."
    }

    # Проверяем, что путь к CSV-файлу не пустой
    if ([string]::IsNullOrEmpty($global:MigrationContext.GeneratedCsvPath)) {
        throw "CSV file path is empty. Check the CSV generation process."
    }

    # Отладочный вывод
    Write-Host "Using CSV file: $($global:MigrationContext.GeneratedCsvPath)" -ForegroundColor Cyan
    Write-Host "Output path: $($global:MigrationContext.paths.split_files)" -ForegroundColor Cyan
    Write-Host "Log folder path: $($global:MigrationContext.paths.split_logs)" -ForegroundColor Cyan
    Write-Host "Site name: $($global:MigrationContext.site.name)" -ForegroundColor Cyan

    # Обрабатываем CSV файл
    Write-Log "Processing CSV file: $($global:MigrationContext.GeneratedCsvPath)"
    
    $params = @{
        csvPath = $global:MigrationContext.GeneratedCsvPath
        outputPath = $global:MigrationContext.paths.split_files
        logFolderPath = $global:MigrationContext.paths.split_logs
        SiteName = $global:MigrationContext.site.name
    }
    
    # Вызов оригинального скрипта с параметрами
    & "$PSScriptRoot\..\OriginalScripts\split_csv_to_folders.ps1" @params
    
    # Сохраняем путь к папке с разбитыми CSV в контексте
    $splitFolder = Join-Path $global:MigrationContext.paths.split_files "$($global:MigrationContext.site.name)"
    $global:MigrationContext.SplitCsvFolder = $splitFolder
    
    Write-Log "CSV splitting completed successfully. Split files are in: $splitFolder"
}
catch {
    Write-Log "Error in CSV splitting process: $_" -Level ERROR
    throw
}