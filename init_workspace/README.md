# Утилиты инициализации рабочего пространства разработчика 1С

Каталог `init_workspace` содержит вспомогательные скрипты для подготовки рабочего места разработчика 1С под Windows. Скрипты помогают проверить окружение, установить типовые зависимости и задать локальные параметры, которые зависят от конкретного компьютера.

## Что есть в этом каталоге

| Задача | Скрипт |
| --- | --- |
| Открыть мастер подготовки с кнопками | `windows\commands\start-workspace-setup.cmd` |
| Проверить платформу 1С, серверный компонент, EDT, Git, Git LFS и Java | `windows\commands\check-quickstart-deps.cmd` |
| Установить Git for Windows и настроить Git | `windows\commands\install-git.cmd` |
| Установить 7-Zip | `windows\commands\install-archiver.cmd` |
| Скачать и установить платформу 1С | `windows\commands\install-platform.cmd` |
| Скачать и установить 1C:EDT | `windows\commands\install-edt.cmd` |
| Установить драйвер HASP | `windows\commands\install-hasp-driver.cmd` |
| Проверить SSH-доступ к GitLab | `windows\commands\check-ssh-gitlab.cmd` |

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

    PlatformVersion = "8.5.1.1302"
    EdtVersion = "2026.1.0"
}
```

4. Запустите мастер подготовки:

```cmd
commands\start-workspace-setup.cmd
```

5. В мастере нажимайте кнопки сверху вниз. Если проверка показывает `FAIL`, установите недостающие компоненты и повторите проверку.

## Рекомендуемый порядок подготовки

1. `commands\install-git.cmd`
2. `commands\install-archiver.cmd`
3. `commands\install-platform.cmd`
4. `commands\install-edt.cmd`
5. `commands\check-ssh-gitlab.cmd`
6. `commands\check-quickstart-deps.cmd`

> Скрипты установки платформы, EDT и HASP должны запускаться от имени администратора. Проверочные скрипты обычно запускаются без повышения прав.

## Локальные настройки

Файл `windows\local.vars.ps1` хранит параметры, которые не должны попадать в репозиторий.

| Параметр | Назначение |
| --- | --- |
| `OneCUser`, `OneCPassword` | учетная запись для `releases.1c.ru` |
| `GitUserName`, `GitUserEmail` | глобальные настройки Git |
| `GitLabHost` | домен GitLab для проверки SSH |
| `PlatformVersion`, `EdtVersion` | версии платформы 1С и EDT |
| `PlatformDownloadDir`, `EdtDownloadDir` | каталоги скачивания дистрибутивов |
| `PlatformExtractDir`, `EdtExtractDir` | каталоги распаковки установщиков |
| `PlatformReleasePageUrl`, `EdtReleasePageUrl` | прямые страницы релизов на `releases.1c.ru` |

Если параметр не задан, используется значение по умолчанию из соответствующего скрипта.

## Что дальше

Подробная документация для Windows-скриптов находится в `windows/README.md`.

Если нужно только просмотреть пример переменных, откройте `windows/local.vars.example.ps1`.
