# SIZE 4 GB
# Установка кодировки UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Функция для преобразования маппинга
function Convert-Mappings {
    param (
        [hashtable]$Mappings
    )

    $convertedMappings = @()
    foreach ($key in $Mappings.Keys) {
        $convertedMappings += @{ local = $key; sharepoint = $Mappings[$key] }
    }
    return $convertedMappings
}

# Конфигурация сайта
$SiteConfig = @{
    site = @{
        name = "Site1"
        ### В ссылке не должно быть знака % (%20)!!!!
        target_url = "https://sharepoint.internal.ru/sites/Site1"
    }

    # Маппинг локальных путей и библиотек SharePoint в удобном формате
    ### Библиотеки должны быть заранее созданы
    mappings = @{
        # Формат "M:\MigrationMaster\SiteName - Documents" = "Shared Documents"
        # Сверяйтесь с URL имён библиотек на сайте: не должно быть запрещённых символов (C&B" = "CB", C-B" = "CB")
        "M:\MigrationMaster\Site1 - Documents" = "Shared Documents"
        "M:\MigrationMaster\Site1 - Pages" = "Pages"
        "M:\MigrationMaster\Site1 - Site Assets" = "Site Assets"
        "M:\MigrationMaster\Site1 - Style Library" = "Style Library"
    }

    # Настройки обработки
    processing = @{
        enable_renaming = $true
        enable_csv_generation = $true
        enable_csv_splitting = $false # для сайтов где мало библиотек, но они большие
        enable_upload = $true
    }

    # Пути для логов и файлов
    paths = @{
        logs_root = "M:\MIGRATION_LOGS\"
        csv_root = "M:\CSV_FOR_SCRIPT\"
        split_files = "M:\CSV_FOR_SCRIPT\SplitCSV"
        rename_logs = "M:\RENAME_LOGS\"
        csv_logs = "M:\CSV_LOGS\"
        upload_logs = "M:\UPLOAD_LOGS\"
        split_logs = "M:\SPLIT_LOGS\"
    }
}

# Преобразуем маппинг в нужный формат
$SiteConfig.mappings = Convert-Mappings -Mappings $SiteConfig.mappings

# Загрузка конфигурации в глобальную переменную
if (-not $global:MigrationContext) {
    $global:MigrationContext = $SiteConfig
}

# Проверка, что конфигурация загружена
if (-not $global:MigrationContext) {
    Write-Host "Error: The configuration is not loaded." -ForegroundColor Red
    exit 1
}

# Пример использования маппинга
foreach ($mapping in $SiteConfig.mappings) {
    $localPath = $mapping.local
    $sharepointLibrary = $mapping.sharepoint
    
    # Проверка существования пути
    if (Test-Path $localPath) {
        Write-Host "Local path: $localPath -> SharePoint Document library: $sharepointLibrary"
    } else {
        Write-Host "Error: local path not found: $localPath" -ForegroundColor Red
    }
}

# Создание всех необходимых директорий
$global:MigrationContext.paths.GetEnumerator() | ForEach-Object {
    if (-not (Test-Path $_.Value)) {
        New-Item -ItemType Directory -Path $_.Value -Force | Out-Null
    }
}

Write-Host "The configuration has been uploaded and processed successfully."

# Возвращаем конфигурацию
return $SiteConfig