# Подготовка рабочего места на Windows

Этот файл описывает скрипты и сценарий настройки окружения Windows для проекта 1С.

## Требования

- Windows 10/11
- PowerShell 5.1 или новее
- Администратор для установки платформы, EDT, Git, 7-Zip и HASP
- Интернет с доступом к `releases.1c.ru`, GitLab и `winget`/GitHub при необходимости
- Учетная запись 1С для доступа к дистрибутивам

## Локальная конфигурация

Скопируйте шаблон:

```cmd
copy init_workspace\windows\local.vars.example.ps1 init_workspace\windows\local.vars.ps1
```

Заполните `local.vars.ps1` своими данными. Пример:

```powershell
$InitWorkspace = @{
    OneCUser = "user@example.com"
    OneCPassword = ""
    GitUserName = "Ваше Имя"
    GitUserEmail = "you@example.com"
    GitLabHost = "gitlab.corp.your.group"
    PlatformVersion = "8.5.1.1302"
    EdtVersion = "2026.1.0"
}
```

Файл `local.vars.ps1` не должен коммититься: он содержит локальные параметры, учетные данные и пути.

## Структура каталогов

| Каталог | Назначение |
| --- | --- |
| `commands` | пользовательские `.cmd`-команды для запуска двойным кликом или из консоли |
| `technical` | технические PowerShell-скрипты, которые вызываются из `.cmd`-команд |
| `technical\lib` | общие библиотеки PowerShell |

Обычно пользователю нужно заходить только в `commands`. Файлы из `technical` лучше не запускать напрямую.

## Описание скриптов

| Скрипт | Что делает |
| --- | --- |
| `commands\install-git.cmd` | Устанавливает Git for Windows и настраивает глобальные параметры Git |
| `commands\install-archiver.cmd` | Устанавливает 7-Zip для распаковки RAR-архивов |
| `commands\install-platform.cmd` | Скачивает и устанавливает платформу 1С вместе с серверным компонентом |
| `commands\install-edt.cmd` | Скачивает и устанавливает 1C:EDT |
| `commands\install-hasp-driver.cmd` | Устанавливает драйвер HASP из поставки платформы |
| `commands\check-quickstart-deps.cmd` | Проверяет базовое окружение: платформа, сервер, EDT, Git, Git LFS, Git CRLF и Java |
| `commands\check-ssh-gitlab.cmd` | Проверяет SSH-подключение к GitLab и добавляет ключ хоста в `known_hosts` |

## Рекомендуемый workflow

1. `commands\install-git.cmd`
2. `commands\install-archiver.cmd`
3. `commands\install-platform.cmd`
4. `commands\install-edt.cmd`
5. `commands\check-ssh-gitlab.cmd`
6. `commands\check-quickstart-deps.cmd`

## Параметры запуска

- `-DownloadOnly` — скачать дистрибутив без запуска установки
- `-ForceDownload` — перекачать файл, даже если он уже есть
- `-ForceExtract` — распаковать заново, даже если каталог уже существует
- `-SkipDependencyCheck` — пропустить финальную проверку после установки
- `NO_PAUSE=1` — отключает паузу в `.cmd`-обертках

## Как работают установки

- `commands\install-platform.cmd` скачивает RAR-архив платформы, распаковывает его и запускает `setup.exe /S USEHWLICENSES=0`.
- `commands\install-edt.cmd` работает через offline-дистрибутив и предпочитает `1ce-installer-cli.exe install`. Если CLI не найден, запускается доступный установщик `.exe`.
- `commands\install-git.cmd` настраивает `core.autocrlf=true`, `core.safecrlf=true`, `core.quotePath=false`, `credential.helper=manager` и несколько удобных алиасов.

## Проверка зависимостей

`commands\check-quickstart-deps.cmd` проверяет:

- платформу `1С:Предприятие 8.5.1.1302`
- компонент сервера 1С
- `1C:EDT 2026.1.0`
- Git for Windows
- настройки Git CRLF
- Git LFS
- Java/JDK 17 или выше

## Проверка SSH к GitLab

Скрипт `commands\check-ssh-gitlab.cmd` использует `GitLabHost` из `local.vars.ps1`.
Он проверяет наличие локального SSH-ключа, добавляет хост-ключ в `%USERPROFILE%\.ssh\known_hosts` и затем выполняет подключение к `git@<GitLabHost>`.

Если SSH-ключ не найден, скрипт выведет предупреждение и команды для создания ключа:

```cmd
ssh-keygen -t ed25519 -C "you@example.com" -f "%USERPROFILE%\.ssh\id_ed25519"
type "%USERPROFILE%\.ssh\id_ed25519.pub"
```

Содержимое `.pub`-файла нужно добавить в GitLab: `Preferences > SSH Keys`.

### Распространенные ошибки

- `Host key verification failed` — обычно означает, что ключ хоста ещё не в `known_hosts`
- `Permission denied (publickey)` — SSH-ключ не настроен или не привязан в GitLab
- `Connection timed out` — блокировка сети или недоступность порта 22

### Ручная проверка

```cmd
ssh -T git@gitlab.corp.itworks.group
```

## Устранение проблем

- Если `Git line endings` в `commands\check-quickstart-deps.cmd` показывает `WARN`, запустите `commands\install-git.cmd` или проверьте `git config --global core.autocrlf true` и `git config --global core.safecrlf true`.
- Если `Java` показывает `WARN`, это означает, что JDK не обнаружен или версия ниже требуемой.
- Если `HASP Driver` не найден, установите драйвер через `commands\install-hasp-driver.cmd`.

## Дополнительно

Можно собрать исполняемый файл `commands\check-quickstart-deps.exe` через `technical\build-check-quickstart-deps-exe.ps1`.

```powershell
cd init_workspace\windows
powershell -ExecutionPolicy Bypass -File .\technical\build-check-quickstart-deps-exe.ps1 -InstallPs2Exe
```

После сборки появится `init_workspace\windows\commands\check-quickstart-deps.exe`.
