#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"

load_init_workspace_vars

cat <<EOF
[WARN] 1C:Enterprise Platform - автоматическая установка для Linux пока не входит в MVP.

Установите Linux-дистрибутив платформы 1С вручную из releases.1c.ru:
- версия: $PLATFORM_VERSION
- пакеты клиента и серверных компонентов для вашего дистрибутива (.deb или .rpm)
- при необходимости драйвер HASP/Sentinel

После установки повторите:
./commands/check-quickstart-deps.sh

Если 1cv8 установлен в нестандартный каталог, укажите путь в local.vars.sh:
V8_PATH="/opt/1cv8/x86_64/$PLATFORM_VERSION/1cv8"
EOF
