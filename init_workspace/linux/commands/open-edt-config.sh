#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"

load_init_workspace_vars

ini_path="$(resolve_edt_ini_path)"

if [ -z "$ini_path" ]; then
  print_fail "1cedt.ini" "файл настроек EDT не найден. Укажите EDT_INI_PATH в local.vars.sh."
  exit 1
fi

editor="${EDITOR:-}"
if [ -n "$editor" ]; then
  "$editor" "$ini_path"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$ini_path" >/dev/null 2>&1 &
else
  print_warn "Editor" "EDITOR и xdg-open не найдены. Откройте файл вручную: $ini_path"
fi

print_ok "1cedt.ini" "$ini_path"
