try {
    Write-Log "Starting data upload process"
    
    # Если передан путь к существующему CSV-файлу, используем его
    if ($global:MigrationContext.GeneratedCsvPath) {
        $csvFiles = @($global:MigrationContext.GeneratedCsvPath)
        Write-Log "Using existing CSV file: $($global:MigrationContext.GeneratedCsvPath)"
    }
    # Иначе, если передан путь к папке с разбитыми CSV, используем её
    elseif ($global:MigrationContext.paths.split_files) {
        $splitFolder = $global:MigrationContext.paths.split_files
        if (-not (Test-Path $splitFolder)) {
            throw "Split CSV folder not found: $splitFolder"
        }
        # Получаем все CSV файлы из папки сплита
        $csvFiles = Get-ChildItem -Path $splitFolder -Filter *.csv
        Write-Log "Found $($csvFiles.Count) split CSV files in folder: $splitFolder"
    }
    # Иначе, если включен сплит, используем папку с разбитыми CSV
    elseif ($global:MigrationContext.processing.enable_csv_splitting) {
        $splitFolder = Join-Path $global:MigrationContext.paths.split_files "SplitCSV_$($global:MigrationContext.site.name)"
        if (-not (Test-Path $splitFolder)) {
            throw "Split CSV folder not found: $splitFolder"
        }
        # Получаем все CSV файлы из папки сплита
        $csvFiles = Get-ChildItem -Path $splitFolder -Filter *.csv
        Write-Log "Found $($csvFiles.Count) split CSV files in folder: $splitFolder"
    }
    # Иначе используем созданный CSV файл
    else {
        if (-not $global:MigrationContext.GeneratedCsvPath) {
            throw "No CSV file was generated. Run CsvGenerator first."
        }

        # Используем путь к CSV-файлу напрямую
        $csvFiles = @($global:MigrationContext.GeneratedCsvPath)
        Write-Log "Using single CSV file: $($global:MigrationContext.GeneratedCsvPath)"
    }

    # Обрабатываем каждый CSV файл
    foreach ($csvFile in $csvFiles) {
        # Если $csvFile — это строка (путь к файлу), преобразуем её в объект FileInfo
        if ($csvFile -is [string]) {
            $csvFile = Get-Item -Path $csvFile
        }

        Write-Log "Processing CSV file: $($csvFile.FullName)"
        
        # Проверка, что путь к CSV-файлу не пустой
        if ([string]::IsNullOrEmpty($csvFile.FullName)) {
            Write-Log "CSV file path is empty. Skipping this file." -Level WARNING
            continue
        }

        # Отладочный вывод
        Write-Host "Passing CSV file path to upload script: $($csvFile.FullName)" -ForegroundColor Cyan

        try {
            # Вызов оригинального скрипта с параметрами
            & "$PSScriptRoot\..\OriginalScripts\upload_data_with_skip_exists_v5.ps1" -csvFilePath $csvFile.FullName -logFolderPath $global:MigrationContext.paths.upload_logs
        }
        catch {
            Write-Log "Error processing CSV file $($csvFile.FullName): $_" -Level ERROR
            continue
        }
    }
    
    # Если включен сплит, выводим в конце лога глобальную статистику по всем csv
    if ($global:MigrationContext.processing.enable_csv_splitting) {
        Write-Log "`n=== Global Upload Statistics ==="
        Write-Log "Total CSV files processed: $($global:MigrationContext.stats.TotalCSVFiles)"
        Write-Log "Total processed files: $($global:MigrationContext.stats.TotalFiles)"
        Write-Log "Successfully uploaded: $($global:MigrationContext.stats.Uploaded)"
        Write-Log "Skipped (already exists): $($global:MigrationContext.stats.Skipped)"
        Write-Log "Failed uploads: $($global:MigrationContext.stats.Failed)"
        Write-Log "Total uploaded size: $($global:MigrationContext.stats.TotalSizeMB) MB"
        Write-Log "Data upload completed successfully"
    }
}
catch {
    Write-Log "Error in upload process: $_" -Level ERROR
    throw
}