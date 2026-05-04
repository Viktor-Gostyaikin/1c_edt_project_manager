#!/usr/bin/env bash

set -o pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done

INIT_WORKSPACE_LIB_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
INIT_WORKSPACE_LINUX_DIR="$(cd "$INIT_WORKSPACE_LIB_DIR/../.." && pwd)"

load_init_workspace_vars() {
  local vars_path="$INIT_WORKSPACE_LINUX_DIR/local.vars.sh"

  if [ -f "$vars_path" ]; then
    # shellcheck source=/dev/null
    . "$vars_path"
  fi

  : "${ONEC_USER:=}"
  : "${ONEC_PASSWORD:=}"
  : "${GIT_USER_NAME:=}"
  : "${GIT_USER_EMAIL:=}"
  : "${GITLAB_HOST:=}"
  : "${WORKSPACE_USER:=}"
  : "${PROJECT_REPO_URL:=}"
  : "${PROJECT_CLONE_DIR:=}"
  : "${PROJECT_ROOT_DIR:=}"
  : "${PROJECT_BRANCH:=}"
  : "${EDT_WORKSPACE_DIR:=}"
  : "${INFOBASE_PATH:=}"
  : "${INFOBASE_LIST_NAME:=}"
  : "${PLATFORM_VERSION:=8.5.1.1302}"
  : "${V8_PATH:=}"
  : "${EDT_VERSION:=2026.1.0}"
  : "${EDT_PATH:=}"
  : "${EDT_CLI_PATH:=}"
  : "${EDT_INI_PATH:=}"
}

user_home_by_name() {
  local user_name="$1"
  local user_home fallback_home

  if [ -z "$user_name" ]; then
    return 1
  fi

  user_home="$(getent passwd "$user_name" 2>/dev/null | cut -d: -f6)"
  if [ -n "$user_home" ] && [ -d "$user_home" ]; then
    printf '%s\n' "$user_home"
    return 0
  fi

  fallback_home="/home/$user_name"
  if [ -d "$fallback_home" ]; then
    printf '%s\n' "$fallback_home"
    return 0
  fi

  return 1
}

workspace_user_home() {
  if [ -n "$WORKSPACE_USER" ]; then
    user_home_by_name "$WORKSPACE_USER" && return
  fi

  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    user_home_by_name "$SUDO_USER" && return
  fi

  printf '%s\n' "$HOME"
}

workspace_user_name() {
  if [ -n "$WORKSPACE_USER" ]; then
    printf '%s\n' "$WORKSPACE_USER"
    return
  fi

  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    printf '%s\n' "$SUDO_USER"
    return
  fi

  id -un 2>/dev/null || true
}

workspace_user_owner() {
  local user_home
  user_home="$(workspace_user_home)"

  stat -c '%u:%g' "$user_home" 2>/dev/null || true
}

fix_workspace_file_owner() {
  if [ "$(id -u)" -ne 0 ]; then
    return
  fi

  local owner
  owner="$(workspace_user_owner)"
  if [ -n "$owner" ]; then
    chown "$owner" "$@" 2>/dev/null || true
  fi
}

repo_name_from_url() {
  local url="$1"
  local name="${url##*/}"
  name="${name%.git}"
  printf '%s\n' "$name"
}

default_project_clone_dir() {
  local user_home
  user_home="$(workspace_user_home)"

  if [ -n "$PROJECT_CLONE_DIR" ]; then
    printf '%s\n' "$PROJECT_CLONE_DIR"
    return
  fi

  printf '%s/source\n' "$user_home"
}

resolve_project_root_dir() {
  if [ -n "$PROJECT_ROOT_DIR" ]; then
    printf '%s\n' "$PROJECT_ROOT_DIR"
    return
  fi

  if [ -n "$PROJECT_REPO_URL" ]; then
    printf '%s/%s\n' "$(default_project_clone_dir)" "$(repo_name_from_url "$PROJECT_REPO_URL")"
    return
  fi

  printf '%s/project\n' "$(default_project_clone_dir)"
}

resolve_edt_workspace_dir() {
  if [ -n "$EDT_WORKSPACE_DIR" ]; then
    printf '%s\n' "$EDT_WORKSPACE_DIR"
  else
    printf '%s/.edt-workspace\n' "$(resolve_project_root_dir)"
  fi
}

resolve_infobase_path() {
  if [ -n "$INFOBASE_PATH" ]; then
    printf '%s\n' "$INFOBASE_PATH"
  else
    printf '%s/build/ib\n' "$(resolve_project_root_dir)"
  fi
}

command_path() {
  command -v "$1" 2>/dev/null || true
}

git_for_workspace_user() {
  HOME="$(workspace_user_home)" git "$@"
}

run_as_workspace_user() {
  local user_home workspace_user current_user
  user_home="$(workspace_user_home)"
  workspace_user="$(workspace_user_name)"
  current_user="$(id -un 2>/dev/null || true)"

  if [ -n "$workspace_user" ] && [ "$current_user" != "$workspace_user" ]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo -H -u "$workspace_user" env HOME="$user_home" "$@"
      return
    fi

    if [ "$(id -u)" -eq 0 ] && command -v runuser >/dev/null 2>&1; then
      runuser -u "$workspace_user" -- env HOME="$user_home" "$@"
      return
    fi
  fi

  HOME="$user_home" "$@"
}

resolve_edt_cli_path() {
  if [ -n "$EDT_CLI_PATH" ]; then
    if [ -x "$EDT_CLI_PATH" ] && [ ! -d "$EDT_CLI_PATH" ]; then
      printf '%s\n' "$EDT_CLI_PATH"
      return
    fi

    if [ -x "$EDT_CLI_PATH/1cedtcli" ]; then
      printf '%s\n' "$EDT_CLI_PATH/1cedtcli"
      return
    fi
  fi

  local path opt_edt_dir edt_start_dir user_home
  user_home="$(workspace_user_home)"

  opt_edt_dir="/opt/1C/1CE/components/1c-edt-${EDT_VERSION}+10-x86_64"
  if [ -x "$opt_edt_dir/1cedtcli" ]; then
    printf '%s\n' "$opt_edt_dir/1cedtcli"
    return
  fi

  edt_start_dir="$user_home/.local/share/1C/1cedtstart/installations"
  if [ -d "$edt_start_dir" ]; then
    path="$(find "$edt_start_dir" -type f -name 1cedtcli -perm /111 2>/dev/null | sort -V | tail -n 1)"
    if [ -n "$path" ]; then
      printf '%s\n' "$path"
      return
    fi
  fi

  path="$(command_path 1cedtcli)"
  if [ -n "$path" ]; then
    printf '%s\n' "$path"
    return
  fi

  find /opt "$user_home/.local/share" -type f -name 1cedtcli -perm /111 2>/dev/null | sort -V | tail -n 1
}

resolve_edt_path() {
  if [ -n "$EDT_PATH" ]; then
    if [ -x "$EDT_PATH" ] && [ ! -d "$EDT_PATH" ]; then
      printf '%s\n' "$EDT_PATH"
      return
    fi

    if [ -x "$EDT_PATH/1cedt" ]; then
      printf '%s\n' "$EDT_PATH/1cedt"
      return
    fi
  fi

  local path opt_edt_dir edt_start_dir user_home
  user_home="$(workspace_user_home)"

  opt_edt_dir="/opt/1C/1CE/components/1c-edt-${EDT_VERSION}+10-x86_64"
  if [ -x "$opt_edt_dir/1cedt" ]; then
    printf '%s\n' "$opt_edt_dir/1cedt"
    return
  fi

  edt_start_dir="$user_home/.local/share/1C/1cedtstart/installations"
  if [ -d "$edt_start_dir" ]; then
    path="$(find "$edt_start_dir" -type f -name 1cedt -perm /111 2>/dev/null | sort -V | tail -n 1)"
    if [ -n "$path" ]; then
      printf '%s\n' "$path"
      return
    fi
  fi

  path="$(command_path 1cedt)"
  if [ -n "$path" ]; then
    printf '%s\n' "$path"
    return
  fi

  find /opt "$user_home/.local/share" -type f -name 1cedt -perm /111 2>/dev/null | sort -V | tail -n 1
}

resolve_edt_ini_path() {
  if [ -n "$EDT_INI_PATH" ] && [ -f "$EDT_INI_PATH" ]; then
    printf '%s\n' "$EDT_INI_PATH"
    return
  fi

  local edt_path edt_dir user_home
  edt_path="$(resolve_edt_path)"
  if [ -n "$edt_path" ]; then
    edt_dir="$(dirname "$edt_path")"
    if [ -f "$edt_dir/1cedt.ini" ]; then
      printf '%s\n' "$edt_dir/1cedt.ini"
      return
    fi
  fi

  user_home="$(workspace_user_home)"
  find /opt "$user_home/.local/share" -type f -name 1cedt.ini 2>/dev/null | sort -V | tail -n 1
}

print_ok() {
  printf '\033[32m[OK]\033[0m %s - %s\n' "$1" "$2"
}

print_warn() {
  printf '\033[33m[WARN]\033[0m %s - %s\n' "$1" "$2"
}

print_fail() {
  printf '\033[31m[FAIL]\033[0m %s - %s\n' "$1" "$2"
}

require_local_vars() {
  local vars_path="$INIT_WORKSPACE_LINUX_DIR/local.vars.sh"
  if [ ! -f "$vars_path" ]; then
    print_fail "local.vars.sh" "файл не найден. Скопируйте local.vars.example.sh в local.vars.sh и заполните параметры."
    return 1
  fi
}
