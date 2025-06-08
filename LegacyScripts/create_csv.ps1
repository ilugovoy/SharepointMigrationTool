# Скрипт для формирования csv для загрузки файлов на сайт Sharepoint

#######################
### Изменяемые параметры ###
#######################

# Имя в произвольном формате: испоьзуется для имён файлов лога и csv
$SiteName = "Site1"
# Ссылка на сайт (НЕ ДОЛЖНА СОДЕРЖАТЬ /Pages/Home.aspx!!!)
$siteURL = "https://sharepoint.internal.ru/sites/Site1"

$LibraryMappings = @{
    # Формат: "Локальный путь" = "Имя библиотеки на SharePoint"
    "M:\MigrationMaster\Site1 - Time Keeper" = "Time Keeper"
    "M:\MigrationMaster\Site1 - Test library" = "Test library"
    "M:\MigrationMaster\Site1 - Spend Reports" = "Spend Reports"
    "M:\MigrationMaster\Site1 - Site Assets" = "Site Assets"
    "M:\MigrationMaster\Site1 - Presentations" = "Presentations"
    "M:\MigrationMaster\Site1 - Documents" = "Documents"
    "M:\MigrationMaster\Site1 - Direct Materials files" = "Direct Materials files"
    "M:\MigrationMaster\Site1 - Bidding materials" = "Bidding materials"
}

#######################
### Прочие параметры, в которые, чаще всего, лезть не нужно ###
#######################

$logFolderPath = "M:\CSV_LOGS"
$csvFolderPath = "M:\CSV_FOR_SCRIPT"

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
    $InputString = $InputString -replace "[&\-]", ""
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

    Write-Log "Processed $($allFiles.Count) files in $LibraryName"
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

foreach ($folder in $LibraryMappings.Keys) {
    if (Test-Path $folder -PathType Container) {
        Start-Process-Folder -LibraryFolder $folder -OutputFilePath $outputFileName
    } else {
        Write-Log "Folder not found: $folder" -Level "WARNING"
    }
}

Write-Log "CSV generation completed: $outputFileName"
Write-Host "`nProcessing complete! Results saved to: $outputFileName`n"