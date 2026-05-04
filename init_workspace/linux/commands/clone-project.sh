#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"

load_init_workspace_vars

if [ -z "$PROJECT_REPO_URL" ]; then
  print_fail "ProjectRepoUrl" "укажите PROJECT_REPO_URL в local.vars.sh."
  exit 1
fi

clone_dir="$(resolve_project_root_dir)"
clone_parent_dir="$(dirname "$clone_dir")"

if [ -d "$clone_dir/.git" ]; then
  print_ok "Repository" "локальный Git-репозиторий уже существует: $clone_dir"
  exit 0
fi

if [ -e "$clone_dir" ] && [ -n "$(find "$clone_dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
  print_fail "Repository" "каталог существует и не пустой, но не является Git-репозиторием: $clone_dir"
  exit 1
fi

run_as_workspace_user mkdir -p "$clone_parent_dir"
fix_workspace_file_owner "$clone_parent_dir"

if [ -n "$PROJECT_BRANCH" ]; then
  run_as_workspace_user git clone --branch "$PROJECT_BRANCH" "$PROJECT_REPO_URL" "$clone_dir"
else
  run_as_workspace_user git clone "$PROJECT_REPO_URL" "$clone_dir"
fi

print_ok "Repository" "проект развернут: $clone_dir"
