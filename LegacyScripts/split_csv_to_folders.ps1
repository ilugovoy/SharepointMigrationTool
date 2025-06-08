# Укажите путь к вашему CSV файлу
$csvPath = "C:\Users\<your_user>\Desktop\Site1.csv"

# Укажите путь для сохранения файлов
$outputPath = "C:\Users\<your_user>\Desktop\Site1"


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

# Группируем строки по папкам (SPFolder)
Write-Host "Grouping data by 'SPFolder' column..."
try {
    $groupedData = $dataRows | Group-Object { 
        $parts = $_ -split ';'
        $spFolder = $parts[3]  # SPFolder
        # Извлекаем только корневую папку (первый уровень)
        $spFolder -split '\\' | Select-Object -First 1
    } -ErrorAction Stop
} catch {
    Write-Host "Failed to group data. Error: $_"
    exit
}

# Проверяем, что группировка прошла успешно
if ($groupedData.Count -eq 0) {
    Write-Host "No groups found. Please check the 'SPFolder' column in the CSV file."
    exit
}

Write-Host "Found $($groupedData.Count) groups."

# Проходим по каждой группе (папке)
foreach ($group in $groupedData) {
    # Получаем имя папки
    $folderName = $group.Name
    Write-Host "Processing folder: $folderName"

    # Определяем имя нового файла
    $newFileName = "$outputPath\$folderName.csv"
    Write-Host "Creating file: $newFileName"

    # Добавляем заголовок в начало файла
    try {
        $header | Set-Content -Path $newFileName -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Host "Failed to write header to $newFileName. Error: $_"
        continue
    }

    # Добавляем строки, относящиеся к этой папке
    try {
        # Используем Add-Content для добавления строк
        $group.Group | Add-Content -Path $newFileName -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Host "Failed to write data to $newFileName. Error: $_"
        continue
    }

    Write-Host "File $newFileName created with $($group.Group.Count) rows."
}

Write-Host "Files successfully split and saved to $outputPath!"