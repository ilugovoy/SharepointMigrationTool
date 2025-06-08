param(
    [string]$SiteName,              # Имя сайта
    [string]$siteURL,               # URL сайта
    [hashtable]$LibraryMappings,    # Хэш-таблица маппингов
    [string]$logFolderPath,         # Путь для логов
    [string]$csvFolderPath          # Путь для сохранения CSV
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
    Add-Content -Path $logFilePath -Value $logMessage -Encoding UTF8
    Write-Host $logMessage 
}

function Initialize-CSV {
    param([string]$OutputFilePath)
    Out-File -FilePath $OutputFilePath -Encoding UTF8 -InputObject "siteURL;LibraryName;FilePath;SPFolder;FileName;Size;LastModified"
    Write-Log "CSV file created: $OutputFilePath"
}

function Start-Encode-SharePointUrl {
    param([string]$InputString)
    $InputString = $InputString -replace " ", "%20"
    $InputString = $InputString -replace "[&\-(),;]", ""
    $InputString = [System.Web.HttpUtility]::UrlEncode($InputString)
    return $InputString -replace "%25", "%"
}

function Start-Process-Folder {
    param([string]$LibraryFolder, [string]$OutputFilePath)
    
    if (-not $LibraryMappings.ContainsKey($LibraryFolder)) {
        Write-Log "No library mapping found for: $LibraryFolder" -Level "ERROR"
        return
    }
    
    $LibraryName = $LibraryMappings[$LibraryFolder]
    Write-Log "Processing folder: $LibraryName (Source: $LibraryFolder)"

    $encodedLibraryName = Start-Encode-SharePointUrl -InputString $LibraryName
    $allFiles = Get-ChildItem -Path $LibraryFolder -Recurse -File -ErrorAction SilentlyContinue

    # Счётчики для файлов и папок в текущей библиотеке
    $totalFilesInFolder = $allFiles.Count
    $totalFoldersInFolder = (Get-ChildItem -Path $LibraryFolder -Recurse -Directory).Count

    foreach ($file in $allFiles) {
        $filePath = $file.FullName
        $relativePath = $file.DirectoryName.Replace($LibraryFolder, "").TrimStart("\")
        if ([string]::IsNullOrEmpty($relativePath)) { $relativePath = "." }

        $outputLine = "{0};{1};{2};{3};{4};{5};{6}" -f 
            $siteURL,
            $encodedLibraryName,
            $filePath,
            $relativePath,
            $file.Name,
            $file.Length,
            $file.LastWriteTime.ToString("MM/dd/yyyy HH:mm:ss")

        Add-Content -Path $OutputFilePath -Value $outputLine -Encoding UTF8
    }

    # Логируем количество файлов и папок в текущей библиотеке
    Write-Log "Processed $totalFilesInFolder files and $totalFoldersInFolder folders in $LibraryName"

    # Возвращаем количество файлов и папок для текущей библиотеки
    return @{
        Files = $totalFilesInFolder
        Folders = $totalFoldersInFolder
    }
}

#######################
### Основной код ###
#######################

Add-Type -AssemblyName System.Web
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1
$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFilePath = Join-Path $logFolderPath "${SiteName}_${currentDateTime}.txt"
$outputFileName = Join-Path $csvFolderPath "${SiteName}_${currentDateTime}.csv"

Write-Log "Starting migration processing for: $SiteName"
Initialize-CSV -OutputFilePath $outputFileName

# Общие счётчики для всех файлов и папок
$totalFilesProcessed = 0
$totalFoldersProcessed = 0

foreach ($folder in $LibraryMappings.Keys) {
    if (Test-Path $folder -PathType Container) {
        # Обрабатываем папку и получаем количество файлов и папок
        $folderStats = Start-Process-Folder -LibraryFolder $folder -OutputFilePath $outputFileName

        # Обновляем общие счётчики
        $totalFilesProcessed += $folderStats.Files
        $totalFoldersProcessed += $folderStats.Folders
    } else {
        Write-Log "Folder not found: $folder" -Level "WARNING"
    }
}

# Логируем общее количество файлов и папок
Write-Log "`n=== Total Statistics ==="
Write-Log "Total files processed: $totalFilesProcessed"
Write-Log "Total folders processed: $totalFoldersProcessed"

Write-Log "CSV generation completed: $outputFileName"
Write-Log "`nProcessing complete! Results saved to: $outputFileName`n"