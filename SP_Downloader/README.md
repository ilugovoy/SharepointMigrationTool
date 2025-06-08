# SharePoint Files Downloader

## Требования
- PowerShell 5.1 или новее
- SharePoint Management Shell
- Права доступа к целевым библиотекам/папкам

## Установка

### Зависимости
Проверьте наличие Snap-In:
```powershell
Get-PSSnapin -Registered -Name "Microsoft.SharePoint.PowerShell"
```
Если Snap-In есть, скрипт заработает. Если нет — установите SDK.

### SDK
Скачайте нужный SDK
- 2022 (Subscription Edition)	SharePoint Server Subscription Edition SDK
- Запустите скачанный файл (например, sharepointserver2019sdk.exe) от имени администратора:
- ПКМ по файлу → Запуск от имени администратора.
- Примите лицензионное соглашение.
- Дождитесь завершения установки (5-10 минут).
- Перезагрузите компьютер.

Проверка установки
1. Откройте PowerShell от имени администратора.
2. Выполните команду:
```powershell
Get-PSSnapin -Registered -Name "Microsoft.SharePoint.PowerShell"
```
Если в выводе есть `Microsoft.SharePoint.PowerShell` — установка прошла успешно.

### SharePoint Management Shell
1. Установите SharePoint Management Shell:
```powershell
Install-Module -Name Microsoft.Online.SharePoint.PowerShell
```

## Как использовать
1. Скачайте скрипт или скопируйте содержимое в файл `SP_Downloader`.ps1
2. Откройте скрипт и настройте параметры:
```ps1
# Короткое имя сайта
$SiteName = "StPetersburg"

# URL сайта (без путей к библиотекам и папкам! В ссылке не должно быть знака % (%20)!!!!
$SiteURL = "https://sharepoint.internal.jdecoffee.ru/sites/eQCMS/StPetersburg"

# Настройки библиотек и папок
$LibrarySettings = @(
    @{
        # Не использовать %20 вместо пробелов!
        LibraryName = "St.Petersburg plant"
        # Чтобы скачать целиком библиотеку эти поля оставить пустыми в виде ""
        Folders     = @(
            "Safety/Охрана труда"
            "Security"
        )
    },
    @{
        LibraryName = "Site Assets"
        Folders     = @(
            ""
            # "Templates"
        )
    }
)

# Базовый путь для сохранения
$DownloadRoot = "$env:USERPROFILE\Desktop\SharePointDownload\$SiteName"
```

2. Скопируйте файл с заполненным скриптом на машину, с которой будете скачивать данные
3. Запустите PowerShell от имени администратора и перейдите в папку, в которой находится скрипт, например `cd .\Desktop\` 
4. Запустите скрипт `.\SP_Downloader.ps1`

5. Файлы сохраняются по пути:
```
Desktop/
└── SharePointDownload/
    └── StPetersburg/
        ├── St.Petersburg plant/
        │   ├── Safety/
        │   │   └── Охрана труда/
        │   └── Security/
        └── Documents/
            └── (вся содержимое библиотеки)
```

6. Логи сохраняются в общей папке загрузки

## Особенности работы
- Если для библиотеки не указаны папки (пустой массив Folders) - скачивается вся библиотека
- Ошибки в одной библиотеке не останавливают обработку остальных
- Поддерживаются кириллические названия и вложенные папки
- Автоматически создаются недостающие папки в пути сохранения
- Поддержка кириллических имен

Обработка ошибок на уровне:
- Отдельных файлов
- Папок
- Целых библиотек

## Примечания
- Используйте точные имена библиотек/папок как на сайте SharePoint, не как в ссылке
- Требуется подключение к корпоративной сети
- Пользователь должен авторизоваться на сайте с УЗ имеющей доступ к целевым папкам 

## Устранение проблем
1. Ошибка доступа:
- Проверьте права учетной записи
- Убедитесь в правильности URL сайта

2. Библиотека не найдена:
- Проверьте точность имени библиотеки
- Убедитесь в наличии пробелов и регистре символов

3. Ошибка: `Add-PSSnapin: ... not installed`  
- Причина: Не установлен SharePoint Management Shell.
- Решение: Скачайте и установите SDK для вашей версии SharePoint.


