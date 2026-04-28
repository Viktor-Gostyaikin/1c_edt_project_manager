# Утилиты инициализации рабочего пространства разработчика 1С

Каталог `init_workspace` содержит вспомогательные скрипты для подготовки рабочего места разработчика 1С под Windows. Скрипты помогают проверить окружение, установить типовые зависимости и задать локальные параметры, которые зависят от конкретного компьютера.

## Что есть в этом каталоге

| Задача | Скрипт |
| --- | --- |
| Открыть мастер подготовки с кнопками | `windows\start-workspace-setup.cmd` |
| Проверить платформу 1С, серверный компонент, EDT, Git, Git LFS и Java | `windows\commands\check-quickstart-deps.cmd` |
| Установить Git for Windows и настроить Git | `windows\commands\install-git.cmd` |
| Установить 7-Zip | `windows\commands\install-archiver.cmd` |
| Скачать и установить платформу 1С | `windows\commands\install-platform.cmd` |
| Скачать и установить 1C:EDT | `windows\commands\install-edt.cmd` |
| Установить драйвер HASP | `windows\commands\install-hasp-driver.cmd` |
| Проверить SSH-доступ к GitLab | `windows\commands\check-ssh-gitlab.cmd` |
| Проверить и склонировать репозиторий проекта | `windows\commands\clone-project.cmd` |
| Импортировать проект в рабочую область EDT | `windows\commands\init-edt-workspace.cmd` |
| Запустить 1C:EDT CLI в интерактивном режиме | `windows\commands\start-edt-cli.cmd` |
| Создать файловую информационную базу 1С | `windows\commands\create-infobase.cmd` |

Пользовательские команды лежат в `windows\commands`. Техническая реализация на PowerShell лежит в `windows\technical`.

## Быстрый старт

1. Перейдите в каталог:

```cmd
cd init_workspace\windows
```

2. Скопируйте пример локальных настроек:

```cmd
copy local.vars.example.ps1 local.vars.ps1
```

3. Заполните `local.vars.ps1` своими значениями:

```powershell
$InitWorkspace = @{
    OneCUser = "user@example.com"
    OneCPassword = ""

    GitUserName = "Ваше Имя"
    GitUserEmail = "you@example.com"
    GitLabHost = "gitlab.corp.your.group"
    ProjectRepoUrl = "git@gitlab.corp.your.group:group/project.git"
    ProjectCloneDir = "C:\src\project"
    EdtWorkspaceDir = ""
    InfoBasePath = ""
    EdtCliPath = ""

    PlatformVersion = "8.5.1.1302"
    EdtVersion = "2026.1.0"
}
```

4. Запустите мастер подготовки:

```cmd
start-workspace-setup.cmd
```

5. В мастере нажимайте кнопки сверху вниз. Если проверка показывает `FAIL`, установите недостающие компоненты и повторите проверку.

## Рекомендуемый порядок подготовки

1. `commands\install-git.cmd`
2. `commands\check-ssh-gitlab.cmd`
3. `commands\clone-project.cmd`
4. `commands\install-archiver.cmd`
5. `commands\install-platform.cmd`
6. `commands\install-edt.cmd`
7. `commands\init-edt-workspace.cmd`
8. `commands\start-edt-cli.cmd`
9. `commands\create-infobase.cmd`
10. `commands\check-quickstart-deps.cmd`

> Мастер `start-workspace-setup.cmd` требует права администратора и при обычном запуске сам покажет UAC-запрос.

## Локальные настройки

Файл `windows\local.vars.ps1` хранит параметры, которые не должны попадать в репозиторий.

| Параметр | Назначение |
| --- | --- |
| `OneCUser`, `OneCPassword` | учетная запись для `releases.1c.ru` |
| `GitUserName`, `GitUserEmail` | глобальные настройки Git |
| `GitLabHost` | домен GitLab для проверки SSH |
| `ProjectRepoUrl`, `ProjectCloneDir`, `ProjectRootDir`, `EdtWorkspaceDir`, `InfoBasePath`, `InfoBaseListName`, `ProjectBranch` | URL репозитория, каталоги проекта, EDT workspace и файловой ИБ, ветка проекта |
| `PlatformVersion`, `V8Path`, `EdtVersion`, `EdtCliPath` | версии платформы/EDT и пути к `1cv8.exe`/`1cedtcli`, если они не найдены автоматически |
| `PlatformDownloadDir`, `EdtDownloadDir` | каталоги скачивания дистрибутивов |
| `PlatformExtractDir`, `EdtExtractDir` | каталоги распаковки установщиков |
| `PlatformReleasePageUrl`, `EdtReleasePageUrl` | прямые страницы релизов на `releases.1c.ru` |

Если параметр не задан, используется значение по умолчанию из соответствующего скрипта.

## Что дальше

Подробная документация для Windows-скриптов находится в `windows/README.md`.

Если нужно только просмотреть пример переменных, откройте `windows/local.vars.example.ps1`.
