# Укажите путь к вашему CSV файлу
$csvPath = "C:\Users\<your_user>\Desktop\Shared_folders.csv"

# Извлекаем имя файла из пути (без расширения)
$fileNamePart = [System.IO.Path]::GetFileNameWithoutExtension($csvPath)

# Укажите путь для сохранения файлов
$outputPath = Join-Path (Split-Path $csvPath -Parent) "${fileNamePart}_SplitCSV"

# Количество строк для разбивки
$stringNumber = 35000

### ____________________________________________________________________________
# Создаем папку для сохранения файлов, если она не существует
if (-not (Test-Path -Path $outputPath)) {
    try {
        New-Item -ItemType Directory -Path $outputPath | Out-Null
        Write-Host "Folder $outputPath created."
    } catch {
        Write-Host "Failed to create folder $outputPath. Error: $_"
        exit
    }
} else {
    Write-Host "Folder $outputPath already exists."
}

# Читаем весь CSV файл
Write-Host "Reading CSV file from $csvPath..."
try {
    $csvContent = Get-Content -Path $csvPath -ErrorAction Stop
} catch {
    Write-Host "Failed to read CSV file. Error: $_"
    exit
}

# Проверяем, что файл не пустой
if ($csvContent.Count -eq 0) {
    Write-Host "The CSV file is empty. Please check the file path and content."
    exit
}

# Получаем заголовок (первую строку)
$header = $csvContent[0]
Write-Host "Header extracted: $header"

# Разбиваем содержимое на строки, начиная со второй строки (без заголовка)
$dataRows = $csvContent | Select-Object -Skip 1
Write-Host "Data rows extracted: $($dataRows.Count) rows found."

# Проверяем, что есть данные для обработки
if ($dataRows.Count -eq 0) {
    Write-Host "No data rows found in the CSV file. Please check the file content."
    exit
}

# Разбиваем содержимое на N тысяч строк для каждого файла
$linesPerFile = $stringNumber
$totalLines = $dataRows.Count
$fileIndex = 0

for ($i = 0; $i -lt $totalLines; $i += $linesPerFile) {
    # Определяем имя нового файла
    $newFileName = Join-Path $outputPath "${fileNamePart}_${fileIndex}.csv"
    
    # Выбираем строки для текущего файла
    $linesToWrite = $dataRows[$i..[math]::Min($i + $linesPerFile - 1, $totalLines - 1)]
    
    # Добавляем заголовок в начало файла
    try {
        $header | Set-Content -Path $newFileName -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Host "Failed to write header to $newFileName. Error: $_"
        continue
    }

    # Добавляем выбранные строки в новый CSV файл
    try {
        $linesToWrite | Add-Content -Path $newFileName -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Host "Failed to write data to $newFileName. Error: $_"
        continue
    }

    Write-Host "File $newFileName created with $($linesToWrite.Count) rows."
    $fileIndex++
}

Write-Host "Files successfully split and saved to $outputPath!"