[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

try {
    Write-Log "Starting CSV generation process"
    
    # Преобразуем маппинги в хэш-таблицу
    $libraryMappings = @{}
    foreach ($mapping in $global:MigrationContext.mappings) {
        if ($mapping.local -and $mapping.sharepoint) {
            $libraryMappings[$mapping.local] = $mapping.sharepoint
        } else {
            Write-Host "Error: Invalid mapping format: $($mapping | ConvertTo-Json)" -ForegroundColor Red
        }
    }
    
    $params = @{
        SiteName = $global:MigrationContext.site.name
        siteURL = $global:MigrationContext.site.target_url
        LibraryMappings = $libraryMappings
        logFolderPath = $global:MigrationContext.paths.csv_logs
        csvFolderPath = $global:MigrationContext.paths.csv_root
    }
    
    # Вызов оригинального скрипта с параметрами
    & "$PSScriptRoot\..\OriginalScripts\create_csv_v4.ps1" @params
    
    # Ищем файл по шаблону имени
    $csvPattern = "$($global:MigrationContext.site.name)_*.csv"
    $csvFile = Get-ChildItem -Path $global:MigrationContext.paths.csv_root -Filter $csvPattern |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    
    if ($csvFile) {
        $global:MigrationContext.GeneratedCsvPath = $csvFile.FullName
        Write-Log "Generated CSV file: $($csvFile.FullName)"
    } else {
        throw "No CSV file matching pattern '$csvPattern' was found"
    }
    
    Write-Log "CSV generation completed successfully"
}
catch {
    Write-Log "Error in CSV generation process: $_" -Level ERROR
    throw
}