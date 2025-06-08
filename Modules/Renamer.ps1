# Установка кодировки консоли на UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    Write-Log "Starting file renaming process for $($global:MigrationContext.site.name)"
    
    # Преобразуем маппинги в формат для оригинального скрипта
    $rootFolders = $global:MigrationContext.mappings | ForEach-Object { $_.local }
    
    $params = @{
        rootFolders = $rootFolders
        SiteName = $global:MigrationContext.site.name
        logFolderPath = $global:MigrationContext.paths.rename_logs
    }
    
    # Вызов оригинального скрипта с параметрами
    & "$PSScriptRoot\..\OriginalScripts\files_rename_for_sp_site_v2.ps1" @params
    
    Write-Log "File renaming completed successfully"
}
catch {
    Write-Log "Error in renaming process: $_" -Level ERROR
    throw
}