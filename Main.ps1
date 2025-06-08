param(
    [string]$ConfigPath = ".\config.ps1",  # Путь к конфигурационному файлу
    [string]$SiteName,                     # Имя сайта
    [bool]$EnableRenaming,                 # Включить/отключить переименование
    [bool]$EnableCsvGeneration,            # Включить/отключить генерацию CSV
    [bool]$EnableCsvSplitting,             # Включить/отключить разделение CSV
    [bool]$EnableUpload,                   # Включить/отключить загрузку
    [string]$LogFolderPath,                # Путь для логов
    [string]$CsvFolderPath,                # Путь для CSV
    [string]$SplitFolderPath,              # Путь для разделённых CSV
    [string]$ExistingCsvPath,              # Путь к существующему CSV-файлу
    [string]$SplitCsvFolderPath            # Путь к существующей папке с разбитыми CSV-файлами
)

# Установка кодировки консоли на UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Проверка существования конфигурационного файла
if (-not (Test-Path $ConfigPath)) {
    Write-Host "Config file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

# Загружаем конфигурацию
try {

    $global:MigrationContext = . $ConfigPath
    
    # Переопределение параметров, если они переданы
    if ($SiteName) {
        $global:MigrationContext.site.name = $SiteName
    }

    if ($PSBoundParameters.ContainsKey('EnableRenaming')) {
        $global:MigrationContext.processing.enable_renaming = $EnableRenaming
    }

    if ($PSBoundParameters.ContainsKey('EnableCsvGeneration')) {
        $global:MigrationContext.processing.enable_csv_generation = $EnableCsvGeneration
    }

    if ($PSBoundParameters.ContainsKey('EnableCsvSplitting')) {
        $global:MigrationContext.processing.enable_csv_splitting = $EnableCsvSplitting
    }

    if ($PSBoundParameters.ContainsKey('EnableUpload')) {
        $global:MigrationContext.processing.enable_upload = $EnableUpload
    }

    if ($LogFolderPath) {
        $global:MigrationContext.paths.logs_root = $LogFolderPath
    }

    if ($CsvFolderPath) {
        $global:MigrationContext.paths.csv_root = $CsvFolderPath
    }

    if ($SplitFolderPath) {
        $global:MigrationContext.paths.split_files = $SplitFolderPath
    }

    if ($ExistingCsvPath) {
        if (-not (Test-Path $ExistingCsvPath)) {
            Write-Host "Existing CSV file not found: $ExistingCsvPath" -ForegroundColor Red
            exit 1
        }
        $global:MigrationContext.GeneratedCsvPath = $ExistingCsvPath
        Write-Host "Using existing CSV file: $ExistingCsvPath" -ForegroundColor Green
    }

    if ($SplitCsvFolderPath) {
        if (-not (Test-Path $SplitCsvFolderPath)) {
            Write-Host "Split CSV folder not found: $SplitCsvFolderPath" -ForegroundColor Red
            exit 1
        }
        $global:MigrationContext.paths.split_files = $SplitCsvFolderPath
        Write-Host "Using split CSV folder: $SplitCsvFolderPath" -ForegroundColor Green
    }

    # Если передан путь к существующему CSV-файлу, отключаем лишние этапы
    if ($ExistingCsvPath -or $SplitCsvFolderPath) {
        $global:MigrationContext.processing.enable_renaming = $false
        $global:MigrationContext.processing.enable_csv_generation = $false
        $global:MigrationContext.processing.enable_csv_splitting = $false
    }

    Write-Host "Config loaded successfully." -ForegroundColor Green
    Write-Host "MigrationContext content: $($global:MigrationContext | ConvertTo-Json -Depth 5)" -ForegroundColor Cyan

    # Проверка наличия ключевых элементов
    if (-not $global:MigrationContext.site -or -not $global:MigrationContext.mappings) {
        Write-Host "Error: Configuration is missing required keys (site or mappings)." -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Failed to load config. Error: $_" -ForegroundColor Red
    exit 1
}

# Проверка, что конфигурация загружена
if (-not $global:MigrationContext) {
    Write-Host "Error: The configuration is not loaded." -ForegroundColor Red
    exit 1
}

# Функция для логирования
function Write-Log {
    param($Message, $Level = "INFO")
    $logEntry = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level.ToUpper(), $Message
    Add-Content -Path (Join-Path $global:MigrationContext.paths.logs_root "migration.log") -Value $logEntry -Encoding UTF8
    Write-Host $logEntry
}

# Создаем все необходимые директории
if ($global:MigrationContext.paths) {
    $global:MigrationContext.paths.GetEnumerator() | ForEach-Object {
        if (-not (Test-Path $_.Value)) {
            New-Item -ItemType Directory -Path $_.Value -Force | Out-Null
            Write-Host "Created directory: $($_.Value)"
        }
    }
} else {
    Write-Host "Error: Paths configuration is missing in the config." -ForegroundColor Red
    exit 1
}

# Проверка и вывод информации о маппинге
Write-Host "Checking local paths and SharePoint mappings..." -ForegroundColor Cyan
foreach ($mapping in $global:MigrationContext.mappings) {
    $localPath = $mapping.local
    $sharepointLibrary = $mapping.sharepoint
    
    # Проверка существования пути
    if (Test-Path $localPath) {
        Write-Host "Local path: $localPath -> SharePoint Document library: $sharepointLibrary" -ForegroundColor Green
    } else {
        Write-Host "Error: local path not found: $localPath" -ForegroundColor Red
    }
}

try {
    # Отладочный вывод
    # Write-Host "MigrationContext initialized: $($global:MigrationContext | ConvertTo-Json -Depth 3)"
    
    # Шаг 1: Переименование файлов
    if ($global:MigrationContext.processing.enable_renaming) {
        Write-Host "Starting file renaming process..."
        & "$PSScriptRoot\Modules\Renamer.ps1"
    }

    if (-not $global:MigrationContext.stats) {
        $global:MigrationContext.stats = @{
            TotalFiles = 0
            Uploaded = 0
            Skipped = 0
            Failed = 0
            TotalSizeMB = 0
            TotalCSVFiles = 0
            ExistingFilesOnSharePoint = 0
            TotalFilesOnSharePoint = 0
            TotalFolders = 0
        }
    }
    
    # Шаг 2: Генерация CSV
    if ($global:MigrationContext.processing.enable_csv_generation) {
        Write-Host "Starting CSV generation process..."
        & "$PSScriptRoot\Modules\CsvGenerator.ps1"
    }
    
    # Шаг 3: Разделение CSV (опционально)
    if ($global:MigrationContext.processing.enable_csv_splitting) {
        Write-Host "Starting CSV splitting process..."
        & "$PSScriptRoot\Modules\CsvSplitter.ps1"
    }
    
    # Шаг 4: Загрузка данных
    if ($global:MigrationContext.processing.enable_upload) {
        Write-Host "Starting data upload process..."
        & "$PSScriptRoot\Modules\Uploader.ps1"
    }
}
catch {
    Write-Host "Critical error: $_" -ForegroundColor Red
    exit 1
}

Write-Host "All processes completed successfully." -ForegroundColor Green