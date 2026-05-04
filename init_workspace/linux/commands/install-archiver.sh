#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"
# shellcheck source=../technical/lib/os-detect.sh
. "$SCRIPT_DIR/../technical/lib/os-detect.sh"

load_init_workspace_vars

pm="$(detect_package_manager)"
sudo_cmd="$(sudo_prefix)"

if [ -z "$sudo_cmd" ] && [ "$(id -u)" -ne 0 ]; then
  print_fail "sudo" "sudo не найден. Запустите скрипт от root или установите архиваторы вручную."
  exit 1
fi

case "$pm" in
  apt)
    $sudo_cmd apt-get update
    $sudo_cmd apt-get install -y curl ca-certificates unzip p7zip-full unrar-free || \
      $sudo_cmd apt-get install -y curl ca-certificates unzip p7zip-full
    ;;
  dnf)
    $sudo_cmd dnf install -y curl ca-certificates unzip p7zip p7zip-plugins unrar || $sudo_cmd dnf install -y curl ca-certificates unzip p7zip p7zip-plugins
    ;;
  yum)
    $sudo_cmd yum install -y curl ca-certificates unzip p7zip p7zip-plugins unrar || $sudo_cmd yum install -y curl ca-certificates unzip p7zip p7zip-plugins
    ;;
  zypper)
    $sudo_cmd zypper --non-interactive install curl ca-certificates unzip p7zip unrar || $sudo_cmd zypper --non-interactive install curl ca-certificates unzip p7zip
    ;;
  *)
    print_fail "Пакетный менеджер" "не удалось определить apt/dnf/yum/zypper. Установите curl, unzip, 7z/unrar вручную."
    exit 1
    ;;
esac

print_ok "Archiver" "архиваторы и curl установлены."
