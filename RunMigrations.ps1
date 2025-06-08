# Список конфигурационных файлов
$configFiles = @(
    # ".\Sites\Site1.ps1"
    # ".\Sites\Site2.ps1"
### HISTORY
    # ".\Sites\start_from_166\Site0.ps1"
) | ForEach-Object { Resolve-Path $_ }

# Максимальное количество одновременных заданий
$maxJobs = 4

# Общее количество задач (на основе количества конфигурационных файлов)
$totalJobs = $configFiles.Count

# Переменная для хранения истории старта и завершения джоб
$jobHistory = @()

# Функция для запуска миграции
function Start-Migration {
    param([string]$configPath)
    # Полный путь к Main.ps1
    $mainScriptPath = Resolve-Path ".\Main.ps1"
    
    # Имя джобы (без расширения .ps1)
    $jobName = [System.IO.Path]::GetFileNameWithoutExtension($configPath)

    # Запуск фонового задания
    Start-Job -Name $jobName -ScriptBlock {
        param($scriptPath, $configPath)
        try {
            # Запуск скрипта миграции
            & $scriptPath -ConfigPath $configPath
        } catch {
            # Обработка ошибок (если нужно)
            Write-Error "Error in migration job: $_"
        }
    } -ArgumentList $mainScriptPath, $configPath

    # Добавляем запись о старте джобы в историю
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $jobHistory += "[$timestamp] Started job for: $jobName"
}

# Функция для вывода статуса джоб
function Show-JobStatus {
    # Очистка консоли
    Clear-Host

    # Вывод истории старта и завершения джоб
    foreach ($entry in $jobHistory) {
        Write-Host $entry
    }

    # Получение текущих джоб
    $jobs = Get-Job

    # Вывод заголовка таблицы
    Write-Host "`nTimestamp           Id Name                     State"
    Write-Host "---------           -- ----                     -----"

    # Вывод информации о каждой джобе
    foreach ($job in $jobs) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "$timestamp $($job.Id.ToString().PadRight(2)) $($job.Name.PadRight(24)) $($job.State)"
    }

    # Вывод общего количества задач и завершенных
    $completedJobs = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
    Write-Host "`nJOBS COMPLETED: $completedJobs/$totalJobs"
}

# Запуск миграции для каждого конфигурационного файла
foreach ($configFile in $configFiles) {
    if (-not (Test-Path $configFile)) {
        # Если конфигурационный файл не найден, просто пропускаем его
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Config file not found: $configFile" -ForegroundColor Red
        $totalJobs--  # Уменьшаем общее количество задач, если файл не найден
        continue
    }
    while ((Get-Job -State Running).Count -ge $maxJobs) {
        # Вывод статуса джоб каждую минуту
        Show-JobStatus
        # Write-Host "`nNext check in 60 seconds."
        Start-Sleep -Seconds 60  # Ожидание, пока не освободится место
    }
    Start-Migration -configPath $configFile
}

# Ожидание завершения всех заданий
while ((Get-Job -State Running).Count -gt 0) {
    # Проверяем завершенные джобы и добавляем их в историю
    $completedJobs = Get-Job -State Completed
    foreach ($job in $completedJobs) {
        if (-not ($jobHistory -like "*Completed job for: $($job.Name)*")) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $jobHistory += "[$timestamp] Completed job for: $($job.Name)"
        }
    }

    # Вывод статуса джоб каждую минуту
    Show-JobStatus
    # Write-Host "`nNext check in 60 seconds."
    Start-Sleep -Seconds 60
}

# Проверяем завершенные джобы и добавляем их в историю перед финальным выводом
$completedJobs = Get-Job -State Completed
foreach ($job in $completedJobs) {
    if (-not ($jobHistory -like "*Completed job for: $($job.Name)*")) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $jobHistory += "[$timestamp] Completed job for: $($job.Name)"
    }
}

# Финальный вывод статуса перед завершением
Show-JobStatus

# Очистка заданий
Get-Job | Remove-Job
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] All jobs completed."