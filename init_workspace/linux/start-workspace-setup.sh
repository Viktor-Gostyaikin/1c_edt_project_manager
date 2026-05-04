#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/technical/lib/init-workspace-vars.sh"
# shellcheck source=technical/lib/os-detect.sh
. "$SCRIPT_DIR/technical/lib/os-detect.sh"

load_init_workspace_vars

ensure_vars_file() {
  if [ ! -f "$SCRIPT_DIR/local.vars.sh" ]; then
    cp "$SCRIPT_DIR/local.vars.example.sh" "$SCRIPT_DIR/local.vars.sh"
    print_warn "local.vars.sh" "создан из local.vars.example.sh. Заполните локальные параметры."
  fi
}

run_command() {
  local command_name="$1"
  printf '\n$ %s\n\n' "$SCRIPT_DIR/commands/$command_name"
  "$SCRIPT_DIR/commands/$command_name"
}

edit_vars() {
  ensure_vars_file
  if [ -n "${EDITOR:-}" ]; then
    "$EDITOR" "$SCRIPT_DIR/local.vars.sh"
  elif command -v nano >/dev/null 2>&1; then
    nano "$SCRIPT_DIR/local.vars.sh"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$SCRIPT_DIR/local.vars.sh" >/dev/null 2>&1 &
  else
    print_warn "Editor" "EDITOR, nano и xdg-open не найдены. Откройте файл вручную: $SCRIPT_DIR/local.vars.sh"
  fi
}

pause_menu() {
  printf '\nНажмите Enter, чтобы вернуться в меню...'
  read -r _
}

sudo_status() {
  if [ "$(id -u)" -eq 0 ]; then
    printf 'текущий пользователь root\n'
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    printf 'sudo не найден\n'
    return
  fi

  if sudo -n -v >/dev/null 2>&1; then
    printf 'sudo доступен\n'
    return
  fi

  if id -nG 2>/dev/null | grep -Eq '(^| )(sudo|wheel|admin)( |$)'; then
    printf 'sudo установлен, может потребоваться пароль\n'
    return
  fi

  printf 'sudo установлен, права не подтверждены\n'
}

cpu_info() {
  local model cores

  if [ -r /proc/cpuinfo ]; then
    model="$(awk -F': ' '/model name/ { print $2; exit }' /proc/cpuinfo)"
  else
    model="$(uname -m)"
  fi

  cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || printf '?')"

  if [ -n "$model" ]; then
    printf '%s, ядер: %s\n' "$model" "$cores"
  else
    printf 'не определен, ядер: %s\n' "$cores"
  fi
}

memory_info() {
  local mem_kb mem_gb

  if [ -r /proc/meminfo ]; then
    mem_kb="$(awk '/MemTotal/ { print $2; exit }' /proc/meminfo)"
    mem_gb="$(awk -v kb="$mem_kb" 'BEGIN { printf "%.1f", kb / 1024 / 1024 }')"
    printf '%s ГБ\n' "$mem_gb"
  else
    printf 'не определен\n'
  fi
}

show_header() {
  clear 2>/dev/null || true
  printf 'Подготовка рабочего места разработчика 1С для Linux\n\n'
  printf 'Каталог: %s\n' "$SCRIPT_DIR"
  printf 'Локальная конфигурация: %s\n' "$SCRIPT_DIR/local.vars.sh"
  printf 'ОС: %s\n' "$(detect_os_name)"
  printf 'Процессор: %s\n' "$(cpu_info)"
  printf 'Оперативная память: %s\n' "$(memory_info)"
  printf 'Пакетный менеджер: %s\n' "$(detect_package_manager)"
  printf 'Root-доступ: %s' "$(sudo_status)"
  printf '\n'
}

ensure_vars_file

while true; do
  show_header
  cat <<'MENU'

Шаги подготовки рабочего места:
[1] Проверить окружение
[2] Настроить local.vars.sh
[3] Установить Git и Git LFS
[4] Создать SSH-ключ GitLab
[5] Проверить SSH GitLab
[6] Развернуть репозиторий проекта
[7] Установить архиваторы (если отсутствуют)
[8] Установить платформу 1С
[9] Установить 1C:EDT
[10] Открыть настройки 1C:EDT
[11] Инициализировать рабочую область EDT
[12] Запустить EDT
[13] Создать файловую информационную базу
[14] Итоговая проверка
[0] Выход (Сtrl+C для принудительного завершения)

MENU
  printf 'Выберите действие: '
  read -r choice

  case "$choice" in
    1) run_command check-quickstart-deps.sh; pause_menu ;;
    2) edit_vars; load_init_workspace_vars ;;
    3) run_command install-git.sh; pause_menu ;;
    4) run_command create-ssh-key-gitlab.sh; pause_menu ;;
    5) run_command check-ssh-gitlab.sh; pause_menu ;;
    6) run_command clone-project.sh; pause_menu ;;
    7) run_command install-archiver.sh; pause_menu ;;
    8) run_command install-platform.sh; pause_menu ;;
    9) run_command install-edt.sh; pause_menu ;;
    10) run_command open-edt-config.sh; pause_menu ;;
    11) run_command init-edt-workspace.sh; pause_menu ;;
    12) run_command start-edt.sh; pause_menu ;;
    13) run_command create-infobase.sh; pause_menu ;;
    14) run_command check-quickstart-deps.sh; pause_menu ;;
    0) exit 0 ;;
    *) print_warn "Меню" "неизвестный пункт: $choice"; pause_menu ;;
  esac
done
