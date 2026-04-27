# Подготовка рабочего места на Windows

В каталоге находятся скрипты для установки и проверки зависимостей проекта на Windows.

## Локальные переменные

Для повторного запуска скриптов можно хранить локальные значения в файле переменных.

Скопируйте пример:

```cmd
copy tools\init_workspace\windows\local.vars.example.ps1 tools\init_workspace\windows\local.vars.ps1
```

Заполните `local.vars.ps1` под свой компьютер: имя и почту Git, логин 1С, домен GitLab, версии и локальные пути при необходимости.

Файл `local.vars.ps1` не нужно коммитить. Он добавлен в `.gitignore`, потому что может содержать учетные данные и локальные пути.

Пароль `OneCPassword` безопаснее оставить пустым: тогда скрипты установки платформы и EDT спросят его интерактивно.

## Установка платформы и EDT

Скрипты скачивают дистрибутивы с `https://releases.1c.ru` по прямым страницам релизов и запускают установку.

Дистрибутив платформы поставляется в RAR-архиве. Перед установкой платформы можно установить 7-Zip:

```cmd
tools\init_workspace\windows\install-archiver.cmd
```

Требуется учетная запись 1С с доступом к дистрибутивам. Логин и пароль можно передать параметрами:

```cmd
tools\init_workspace\windows\install-platform.cmd -OneCUser user@example.com -OneCPassword password
tools\init_workspace\windows\install-edt.cmd -OneCUser user@example.com -OneCPassword password
```

Или через переменные окружения:

```cmd
set ONEC_USERNAME=user@example.com
set ONEC_PASSWORD=password
tools\init_workspace\windows\install-platform.cmd
tools\init_workspace\windows\install-edt.cmd
```

Платформа по умолчанию:

```text
https://releases.1c.ru/version_files?nick=Platform85&ver=8.5.1.1302
```

EDT по умолчанию:

```text
https://releases.1c.ru/version_files?nick=DevelopmentTools10&ver=2026.1.0
```

Скачанные файлы сохраняются в:

```text
build\downloads\platform\8.5.1.1302
build\downloads\edt\2026.1.0
```

Распакованные установщики сохраняются в:

```text
build\installers\platform\8.5.1.1302
build\installers\edt\2026.1.0
```

Для проверки скачивания без запуска установки:

```cmd
tools\init_workspace\windows\install-platform.cmd -DownloadOnly
tools\init_workspace\windows\install-edt.cmd -DownloadOnly
```

Скрипты установки нужно запускать от имени администратора, если используется режим установки.

Для платформы используется `setup.exe /S USEHWLICENSES=0`. После установки обязательно запускается `check-quickstart-deps.cmd`, который проверит, что установлен серверный компонент 1С.

Для EDT скрипт предпочитает offline-дистрибутив, распаковывает его и запускает:

```text
1ce-installer-cli.exe install
```

Если в дистрибутиве не найден `1ce-installer-cli.exe`, будет запущен доступный `.exe`-установщик в интерактивном режиме.

## Проверка зависимостей

Скрипт `check-quickstart-deps.cmd` проверяет зависимости из первого раздела быстрого старта:

* платформу `1С:Предприятие 8.5.1.1302`;
* компонент сервера 1С;
* `1C:EDT 2026.1.0`;
* Git for Windows;
* настройки Git для окончаний строк;
* Git LFS;
* Java/JDK 17 или выше.

## Проверка SSH-подключения к GitLab

Скрипт `check-ssh-gitlab.cmd` проверяет SSH-подключение к GitLab серверу, указанному в `local.vars.ps1` (переменная `GitLabHost`).

Требуется настроенный SSH-ключ для пользователя `git` на сервере GitLab.

```cmd
tools\init_workspace\windows\check-ssh-gitlab.cmd
```

## Сценарий использования

1. Пользователь клонирует репозиторий или получает папку проекта.
1. Открывает Проводник Windows.
1. Переходит в каталог:

```text
tools\init_workspace\windows
```

1. Запускает файл:

```text
check-quickstart-deps.cmd
```

1. В консоли видит результаты проверки:

```text
[OK]   компонент найден и подходит
[WARN] компонент найден, но требует ручной проверки
[FAIL] обязательный компонент не найден
```

1. Если есть `FAIL`, пользователь устанавливает недостающие компоненты и запускает проверку повторно.
1. Если остались только `OK` и допустимые `WARN`, пользователь продолжает настройку по `doc\Быстрый старт.md`.

Для запуска из командной строки:

```cmd
tools\init_workspace\windows\check-quickstart-deps.cmd
```

Если пауза в конце не нужна, например при автоматическом запуске:

```cmd
set NO_PAUSE=1
tools\init_workspace\windows\check-quickstart-deps.cmd
```

## Более удобный вариант

Для пользователя удобнее один исполняемый файл `check-quickstart-deps.exe`:

* его можно запускать двойным кликом;
* не нужно объяснять политику запуска PowerShell;
* файл проще передать отдельно от репозитория;
* можно положить рядом с инструкцией или на сетевой ресурс.

Собрать `.exe` можно через PS2EXE:

```powershell
cd tools\init_workspace\windows
powershell -ExecutionPolicy Bypass -File .\build-check-quickstart-deps-exe.ps1 -InstallPs2Exe
```

После сборки появится файл:

```text
tools\init_workspace\windows\check-quickstart-deps.exe
```

Повторная сборка без установки модуля:

```powershell
powershell -ExecutionPolicy Bypass -File .\build-check-quickstart-deps-exe.ps1
```
