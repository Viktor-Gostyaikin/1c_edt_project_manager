#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"

load_init_workspace_vars

project_root="$(resolve_project_root_dir)"
workspace_dir="$(resolve_edt_workspace_dir)"

if [ ! -d "$project_root" ]; then
  print_fail "ProjectRoot" "каталог проекта не найден: $project_root"
  exit 1
fi

edt_cli="$(resolve_edt_cli_path)"
if [ -z "$edt_cli" ] || [ ! -x "$edt_cli" ]; then
  print_fail "1C:EDT CLI" "не найден 1cedtcli. Укажите EDT_CLI_PATH в local.vars.sh: путь к файлу 1cedtcli или к каталогу, где он лежит."
  exit 1
fi

mkdir -p "$workspace_dir"

"$edt_cli" -data "$workspace_dir" -command import --project "$project_root"

print_ok "EDT workspace" "проект импортирован в рабочую область: $workspace_dir"
