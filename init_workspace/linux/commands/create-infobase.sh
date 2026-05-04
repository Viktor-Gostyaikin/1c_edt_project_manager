#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"

load_init_workspace_vars

infobase_path="$(resolve_infobase_path)"
v8="${V8_PATH:-$(command_path 1cv8)}"

if [ -z "$v8" ] || [ ! -x "$v8" ]; then
  print_fail "1C:Enterprise" "не найден 1cv8. Укажите V8_PATH в local.vars.sh."
  exit 1
fi

if [ -f "$infobase_path/1Cv8.1CD" ] || [ -f "$infobase_path/1Cv8.1cd" ]; then
  print_ok "Infobase" "файловая база уже существует: $infobase_path"
  exit 0
fi

mkdir -p "$infobase_path"

"$v8" CREATEINFOBASE "File=$infobase_path;"

print_ok "Infobase" "файловая база создана: $infobase_path"
