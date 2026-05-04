#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"

load_init_workspace_vars

workspace_dir="$(resolve_edt_workspace_dir)"
edt="$(resolve_edt_path)"

if [ -z "$edt" ] || [ ! -x "$edt" ]; then
  print_fail "1C:EDT" "не найден 1cedt. Укажите EDT_PATH в local.vars.sh."
  exit 1
fi

mkdir -p "$workspace_dir"

nohup "$edt" -data "$workspace_dir" >/tmp/init-workspace-edt.log 2>&1 &

print_ok "1C:EDT" "запущен с рабочей областью: $workspace_dir"
print_ok "Log" "/tmp/init-workspace-edt.log"
