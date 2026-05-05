# Подготовка рабочего места на Linux

Этот каталог содержит MVP-версию скриптов подготовки рабочего места разработчика 1С под Linux.

## Требования

- Linux x86_64
- Bash
- `sudo` для установки системных пакетов
- Интернет с доступом к GitLab и, при ручной установке 1С, к `releases.1c.ru`
- Учетная запись 1С для скачивания платформы и 1C:EDT

В MVP автоматическая установка платформы 1С и 1C:EDT не реализована. Скрипты помогают подготовить Git, SSH, репозиторий, workspace EDT, файловую ИБ и проверить окружение.

## Локальная конфигурация

Скопируйте шаблон:

```bash
cp init_workspace/linux/local.vars.example.sh init_workspace/linux/local.vars.sh
```

Заполните `local.vars.sh` своими данными:

```bash
ONEC_USER="user@example.com"
ONEC_PASSWORD=""
GIT_USER_NAME="Имя Фамилия"
GIT_USER_EMAIL="you@example.com"
GITLAB_HOST="gitlab.com"
WORKSPACE_USER="v.gostyaikin"
PROJECT_REPO_URL="git@gitlab.com:group/project.git"
PROJECT_CLONE_DIR="$HOME/source"
PROJECT_ROOT_DIR=""
PROJECT_BRANCH="dev"
PLATFORM_VERSION="8.5.1.1302"
EDT_VERSION="2026.1.0"
```

Файл `local.vars.sh` не должен коммититься: он содержит локальные параметры, учетные данные и пути.

`WORKSPACE_USER` указывает основного пользователя рабочего окружения. Это нужно, если утилита запускается через `sudo` от другого пользователя, например:

```bash
su itworks
sudo bash init_workspace/linux/start-workspace-setup.sh
```

В этом случае задайте:

```bash
WORKSPACE_USER="v.gostyaikin"
```

Скрипты будут искать EDT Start, SSH-ключи, дефолтный каталог проекта и другие пользовательские файлы в `/home/v.gostyaikin`, а не в home пользователя `itworks` или `root`.

## Каталоги проекта

В Linux-скриптах используются два разных параметра:

| Параметр | Назначение |
| --- | --- |
| `PROJECT_CLONE_DIR` | Родительский каталог, внутри которого будут размещаться локальные репозитории |
| `PROJECT_ROOT_DIR` | Каталог конкретного репозитория проекта |

Например:

```bash
PROJECT_REPO_URL="git@gitlab.corp.itworks.group:mis/itw_mis.git"
PROJECT_CLONE_DIR="/home/v.gostyaikin/itworks/projects_test"
PROJECT_ROOT_DIR="/home/v.gostyaikin/itworks/projects_test/itw_mis"
```

Если `PROJECT_ROOT_DIR` не задан, его можно вычислять из `PROJECT_CLONE_DIR` и имени репозитория:

```text
PROJECT_ROOT_DIR = PROJECT_CLONE_DIR + "/" + имя репозитория
```

Для примера выше итоговый каталог проекта:

```text
/home/v.gostyaikin/itworks/projects_test/itw_mis
```

Команда клонирования запускает `git clone` от имени `WORKSPACE_USER`, чтобы использовались SSH-ключи, `~/.ssh/config` и Git-настройки основного пользователя рабочего окружения.

## Запуск мастера

```bash
cd init_workspace/linux
./start-workspace-setup.sh
```

Мастер показывает терминальное меню:

```text
[1] Проверить окружение
[2] Настроить local.vars.sh
[3] Установить Git и Git LFS
[4] Создать SSH-ключ GitLab
[5] Проверить SSH GitLab
[6] Развернуть репозиторий проекта
[7] Установить архиваторы
[8] Установить платформу 1С
[9] Установить 1C:EDT
[10] Открыть настройки 1C:EDT
[11] Инициализировать рабочую область EDT
[12] Запустить EDT
[13] Создать файловую информационную базу
[14] Итоговая проверка
[0] Выход
```

## Отдельные команды

Команды можно запускать напрямую:

```bash
./commands/check-quickstart-deps.sh
./commands/install-git.sh
./commands/create-ssh-key-gitlab.sh
./commands/check-ssh-gitlab.sh
./commands/clone-project.sh
./commands/init-edt-workspace.sh
./commands/start-edt.sh
./commands/create-infobase.sh
```

## Что проверяет check-quickstart-deps.sh

- платформу 1С и серверные компоненты `ragent`, `rmngr`, `rphost`
- 1C:EDT и `1cedtcli`
- Git
- настройки Git для Linux: `core.autocrlf=input`, `core.safecrlf=true`
- Git LFS
- Java 17 или выше
- службу или процесс HASP/Sentinel

## Рекомендуемый порядок

1. `./commands/install-git.sh`
2. `./commands/create-ssh-key-gitlab.sh`
3. Добавить публичный ключ в GitLab.
4. `./commands/check-ssh-gitlab.sh`
5. `./commands/clone-project.sh`
6. `./commands/install-archiver.sh`
7. Установить платформу 1С вручную из Linux-дистрибутива.
8. Установить 1C:EDT вручную из Linux-дистрибутива.
9. `./commands/check-quickstart-deps.sh`
10. `./commands/init-edt-workspace.sh`
11. `./commands/start-edt.sh`
12. `./commands/create-infobase.sh`

## SSH-ключ GitLab

Скрипт `create-ssh-key-gitlab.sh` создает ключ по имени хоста GitLab. Для:

```bash
GITLAB_HOST="gitlab.corp.itworks.group"
```

будет создан ключ:

```text
~/.ssh/gitlab.corp.itworks.group_ed25519
```

Скрипт также добавляет managed-блок в `~/.ssh/config`:

```text
Host gitlab.corp.itworks.group
    HostName gitlab.corp.itworks.group
    User git
    IdentityFile ~/.ssh/gitlab.corp.itworks.group_ed25519
    IdentitiesOnly yes
```

Существующий ключ не перезаписывается. Повторный запуск обновляет только блок между маркерами `init-workspace` в SSH config.

Если 1С или EDT установлены в нестандартные каталоги, укажите пути в `local.vars.sh`:

```bash
V8_PATH="/opt/1cv8/x86_64/8.5.1.1302/1cv8"
EDT_PATH="/path/to/1cedt"
EDT_CLI_PATH="/path/to/1cedtcli"
EDT_INI_PATH="/path/to/1cedt.ini"
```

## Автоматическая установка 1С и EDT

Скрипты `install-platform.sh` и `install-edt.sh` скачивают дистрибутивы с `releases.1c.ru`, распаковывают их и запускают установку.

Для платформы используются параметры:

```bash
PLATFORM_VERSION="8.5.1.1302"
PLATFORM_DOWNLOAD_DIR=""
PLATFORM_EXTRACT_DIR=""
PLATFORM_RELEASE_PAGE_URL=""
PLATFORM_DISTRIBUTION_FILTERS="Технологическая платформа 1С:Предприятия \\(64-bit\\) для Linux$"
PLATFORM_INSTALL_COMPONENTS="server,client"
```

Для EDT используются параметры:

```bash
EDT_VERSION="2026.1.0"
EDT_DOWNLOAD_DIR=""
EDT_EXTRACT_DIR=""
EDT_RELEASE_PAGE_URL=""
EDT_DISTRIBUTION_FILTERS="Дистрибутив 1C:EDT для ОС Linux для установки без интернета$"
```

Фильтры разделяются символом `|` и являются регулярными выражениями по названию ссылки на странице релиза. Если 1С изменит название Linux-дистрибутива, уточните соответствующий `*_DISTRIBUTION_FILTERS` в `local.vars.sh`.

Примеры запуска:

```bash
./commands/install-platform.sh --download-only
./commands/install-platform.sh --force-download --force-extract
./commands/install-edt.sh --download-only
./commands/install-edt.sh --force-download --force-extract
```

Поддержанные ключи:

| Ключ | Назначение |
| --- | --- |
| `--download-only` | Только скачать дистрибутив без установки |
| `--force-download` | Перекачать файл, даже если он уже есть |
| `--force-extract` | Очистить каталог распаковки и распаковать заново |
| `--skip-dependency-check` | Не запускать итоговую проверку после установки |

Для платформы Linux установщик ставит компоненты сервера и клиента. Для пакетных дистрибутивов выбираются пакеты `common`, `server`, `ws`, `client`; для `.run` включаются компоненты `server,ws,client_full,ru`. После установки создается ссылка `/opt/1cv8/current` на установленную версию платформы.

Если нужно изменить набор компонентов, задайте `PLATFORM_INSTALL_COMPONENTS` в `local.vars.sh`: `server`, `client` или `server,client`.

Для EDT установщик ищет `1ce-installer-cli`, `1ce-installer` или `.run` и запускает найденный вариант от имени `WORKSPACE_USER`.

Для установки через EDT Start можно указать каталог, где лежит CLI:

```bash
EDT_CLI_PATH="$HOME/.local/share/1C/1cedtstart/installations/1C_EDT 2026.1/1cedt"
```

## Ограничения MVP

- Автоматическая установка зависит от точных названий Linux-дистрибутивов на `releases.1c.ru`; при необходимости настройте `*_DISTRIBUTION_FILTERS`.
- Поддержка пакетных менеджеров есть для `apt`, `dnf`, `yum`, `zypper`, но основной проверенный сценарий рассчитан на Debian/Ubuntu.
- GUI не входит в MVP; точка входа сейчас терминальная.
