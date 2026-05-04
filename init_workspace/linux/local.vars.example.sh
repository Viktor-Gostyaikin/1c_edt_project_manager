#!/usr/bin/env bash

# Локальные переменные для скриптов подготовки рабочего места Linux.
# Скопируйте файл в local.vars.sh и заполните нужные значения.
# local.vars.sh не нужно коммитить: в нем могут быть учетные данные и локальные пути.

# Основной пользователь рабочего окружения.
# Заполните, если утилита запускается через sudo от другого пользователя,
# а EDT, SSH-ключи и проект находятся в домашнем каталоге разработчика.
WORKSPACE_USER=""

# Учетная запись releases.1c.ru. Для MVP автоматическая загрузка платформы и EDT
# не реализована; значения оставлены для совместимости с будущими установщиками.
ONEC_USER="user@example.com"
ONEC_PASSWORD=""

# Git.
GIT_USER_NAME="Имя Фамилия"
GIT_USER_EMAIL="you@example.com"
GITLAB_HOST="gitlab.com"

# Репозиторий проекта.
PROJECT_REPO_URL="git@gitlab.com:group/project.git"
# Родительский каталог для локальных репозиториев.
PROJECT_CLONE_DIR=""
# Каталог конкретного репозитория. Если пустой, вычисляется как PROJECT_CLONE_DIR/<имя-репозитория>.
PROJECT_ROOT_DIR=""
PROJECT_BRANCH="dev"

# Рабочая область EDT и файловая информационная база.
EDT_WORKSPACE_DIR=""
INFOBASE_PATH=""
INFOBASE_LIST_NAME=""

# 1C:Enterprise Platform.
PLATFORM_VERSION="8.5.1.1302"
V8_PATH=""

# 1C:EDT.
EDT_VERSION="2026.1.0"
EDT_PATH=""
EDT_CLI_PATH=""
EDT_INI_PATH=""
