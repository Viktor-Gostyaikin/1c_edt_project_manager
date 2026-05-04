#!/usr/bin/env bash

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"
# shellcheck source=../technical/lib/os-detect.sh
. "$SCRIPT_DIR/../technical/lib/os-detect.sh"

load_init_workspace_vars

HAS_ERRORS=0
REQUIRED_JAVA_MAJOR_VERSION=17
EXPECTED_EDT_JVM_PATH="/usr/lib/jvm/axiomjdk-java17-pro-full-amd64/bin"

mark_fail() {
  HAS_ERRORS=1
  print_fail "$1" "$2"
}

version_from_path() {
  local version dots
  version="$(printf '%s\n' "$1" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?(\.[0-9]+)?' | head -n 1)"
  if [ -z "$version" ]; then
    return
  fi

  dots="${version//[^.]}"
  if [ "${#dots}" -eq 1 ]; then
    version="$version.0"
  fi

  printf '%s\n' "$version"
}

find_v8() {
  if [ -n "$V8_PATH" ] && [ -x "$V8_PATH" ]; then
    printf '%s\n' "$V8_PATH"
    return
  fi

  local path
  path="$(command_path 1cv8)"
  if [ -n "$path" ]; then
    printf '%s\n' "$path"
    return
  fi

  find /opt/1cv8 -type f -name 1cv8 2>/dev/null | sort -V | tail -n 1
}

find_edt_cli() {
  resolve_edt_cli_path
}

find_edt() {
  resolve_edt_path
}

test_platform() {
  local v8_path version bin_dir missing
  v8_path="$(find_v8)"

  if [ -z "$v8_path" ]; then
    mark_fail "1C:Enterprise Platform" "не найден исполняемый файл 1cv8. Установите платформу 1С $PLATFORM_VERSION или укажите V8_PATH."
    return
  fi

  version="$(version_from_path "$v8_path")"
  if [ "$version" = "$PLATFORM_VERSION" ]; then
    print_ok "1C:Enterprise Platform" "найдена версия $version: $v8_path"
  elif [ -n "$version" ]; then
    print_warn "1C:Enterprise Platform" "ожидалась версия $PLATFORM_VERSION, найдена $version: $v8_path"
  else
    print_warn "1C:Enterprise Platform" "1cv8 найден, но версия не определена: $v8_path"
  fi

  bin_dir="$(dirname "$v8_path")"
  missing=0
  for binary in ragent rmngr rphost; do
    if [ ! -x "$bin_dir/$binary" ]; then
      missing=1
    fi
  done

  if [ "$missing" -eq 0 ]; then
    print_ok "1C Server component" "найдены ragent, rmngr, rphost в $bin_dir"
  else
    print_warn "1C Server component" "не найдены все серверные компоненты ragent/rmngr/rphost в $bin_dir"
  fi
}

test_edt() {
  local edt_path edt_cli_path version
  edt_path="$(find_edt)"
  edt_cli_path="$(find_edt_cli)"

  if [ -z "$edt_path" ]; then
    mark_fail "1C:EDT" "не найден 1cedt. Установите 1C:EDT $EDT_VERSION или укажите EDT_PATH."
  else
    version="$(version_from_path "$edt_cli_path")"
    if [ -z "$version" ]; then
      version="$(version_from_path "$edt_path")"
    fi

    if [ "$version" = "$EDT_VERSION" ]; then
      print_ok "1C:EDT" "найдена версия $version: $edt_path"
    elif [ -n "$version" ]; then
      print_warn "1C:EDT" "ожидалась версия $EDT_VERSION, найдена $version: $edt_path"
    else
      print_ok "1C:EDT" "приложение найдено: $edt_path"
    fi
  fi

  if [ -z "$edt_cli_path" ]; then
    mark_fail "1C:EDT CLI" "не найден 1cedtcli. Укажите EDT_CLI_PATH или добавьте CLI в PATH."
  else
    print_ok "1C:EDT CLI" "найден: $edt_cli_path"
  fi
}

test_edt_settings() {
  local ini_path xmx vm_path normalized_vm_path
  ini_path="$(resolve_edt_ini_path)"

  if [ -z "$ini_path" ]; then
    print_warn "1C:EDT settings" "не найден 1cedt.ini. Укажите EDT_INI_PATH в local.vars.sh."
    return
  fi

  print_ok "1C:EDT settings" "файл настроек: $ini_path"

  xmx="$(grep -E '^-Xmx[0-9]+[mMgG]$' "$ini_path" | tail -n 1 | sed 's/^-Xmx//')"
  if [ -z "$xmx" ]; then
    print_warn "1C:EDT Xmx" "параметр -Xmx не найден. Рекомендуется добавить -Xmx8192m."
  elif [ "$xmx" = "4096m" ] || [ "$xmx" = "4096M" ]; then
    print_warn "1C:EDT Xmx" "-Xmx$xmx. Рекомендуется изменить на -Xmx8192m."
  else
    print_ok "1C:EDT Xmx" "-Xmx$xmx"
  fi

  vm_path="$(awk '
    $0 == "-vm" { getline; print; exit }
    $0 ~ /^-vm=/ { sub(/^-vm=/, ""); print; exit }
  ' "$ini_path")"

  if [ -z "$vm_path" ]; then
    print_warn "1C:EDT JVM" "путь к JVM не задан. Ожидаемый путь: $EXPECTED_EDT_JVM_PATH"
    return
  fi

  normalized_vm_path="$vm_path"
  if [ "$(basename "$normalized_vm_path")" = "java" ]; then
    normalized_vm_path="$(dirname "$normalized_vm_path")"
  fi

  if [ "$normalized_vm_path" = "$EXPECTED_EDT_JVM_PATH" ]; then
    print_ok "1C:EDT JVM" "$vm_path"
  else
    print_warn "1C:EDT JVM" "текущий путь: $vm_path. Ожидаемый путь: $EXPECTED_EDT_JVM_PATH"
  fi
}

test_git() {
  local git_path version autocrlf safecrlf lfs_version user_home
  git_path="$(command_path git)"
  if [ -z "$git_path" ]; then
    mark_fail "Git" "git не найден в PATH. Запустите commands/install-git.sh."
    return
  fi

  user_home="$(workspace_user_home)"
  version="$(git --version 2>/dev/null)"
  print_ok "Git" "$version ($git_path)"

  autocrlf="$(git_for_workspace_user config --global --get core.autocrlf 2>/dev/null || true)"
  safecrlf="$(git_for_workspace_user config --global --get core.safecrlf 2>/dev/null || true)"
  if [ "$autocrlf" = "input" ] && [ "$safecrlf" = "true" ]; then
    print_ok "Git line endings" "core.autocrlf=input, core.safecrlf=true ($user_home/.gitconfig)"
  else
    print_warn "Git line endings" "для $user_home/.gitconfig рекомендуется: git config --global core.autocrlf input; git config --global core.safecrlf true"
  fi

  if git lfs version >/tmp/init-workspace-git-lfs-version.$$ 2>/dev/null; then
    lfs_version="$(cat /tmp/init-workspace-git-lfs-version.$$)"
    rm -f /tmp/init-workspace-git-lfs-version.$$
    print_ok "Git LFS" "$lfs_version"
  else
    rm -f /tmp/init-workspace-git-lfs-version.$$
    print_warn "Git LFS" "git lfs не найден или не настроен. Запустите commands/install-git.sh."
  fi
}

test_java() {
  local java_path version_output major
  java_path="$(command_path java)"
  if [ -z "$java_path" ]; then
    print_warn "Java" "java не найден в PATH. Рекомендуется JDK $REQUIRED_JAVA_MAJOR_VERSION или выше."
    return
  fi

  version_output="$(java -version 2>&1)"
  major="$(printf '%s\n' "$version_output" | sed -nE 's/.*version "([0-9]+).*/\1/p' | head -n 1)"
  if [ -z "$major" ]; then
    print_warn "Java" "java найден, но версия не определена: $java_path"
  elif [ "$major" -ge "$REQUIRED_JAVA_MAJOR_VERSION" ]; then
    print_ok "Java" "найдена версия $major или выше: $java_path"
  else
    print_warn "Java" "нужна версия $REQUIRED_JAVA_MAJOR_VERSION или выше, найдена $major: $java_path"
  fi
}

test_hasp() {
  if systemctl list-units --type=service --all 2>/dev/null | grep -Eiq 'hasp|aksusbd|sentinel'; then
    print_ok "HASP Driver" "найдена служба HASP/Sentinel"
  elif pgrep -f 'aksusbd|hasplmd' >/dev/null 2>&1; then
    print_ok "HASP Driver" "найден процесс HASP/Sentinel"
  else
    print_warn "HASP Driver" "служба HASP/Sentinel не найдена. Это критично только при работе с аппаратным ключом."
  fi
}

printf 'Проверка окружения рабочего места Linux\n\n'
printf 'ОС: %s\n' "$(detect_os_name)"
printf 'Пакетный менеджер: %s\n\n' "$(detect_package_manager)"

test_platform
test_edt
test_edt_settings
test_git
test_java
test_hasp

printf '\n'
if [ "$HAS_ERRORS" -ne 0 ]; then
  print_fail "Проверка" "найдены критичные проблемы."
  exit 1
fi

print_ok "Проверка" "критичных проблем не найдено. Предупреждения можно обработать отдельно."
