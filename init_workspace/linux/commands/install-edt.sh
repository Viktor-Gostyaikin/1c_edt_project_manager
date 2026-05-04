#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"

load_init_workspace_vars

cat <<EOF
[WARN] 1C:EDT - автоматическая установка для Linux пока не входит в MVP.

Установите Linux-дистрибутив 1C:EDT вручную из releases.1c.ru:
- версия: $EDT_VERSION
- offline-дистрибутив или installer-cli для Linux x86_64

После установки повторите:
./commands/check-quickstart-deps.sh

Если EDT установлен в нестандартный каталог, укажите пути в local.vars.sh:
EDT_PATH="/path/to/1cedt"
EDT_CLI_PATH="/path/to/1cedtcli"
EDT_INI_PATH="/path/to/1cedt.ini"
EOF
