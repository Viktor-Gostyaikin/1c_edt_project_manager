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

install_packages() {
  case "$pm" in
    apt)
      $sudo_cmd apt-get update
      $sudo_cmd apt-get install -y git git-lfs openssh-client ca-certificates
      ;;
    dnf)
      $sudo_cmd dnf install -y git git-lfs openssh-clients ca-certificates
      ;;
    yum)
      $sudo_cmd yum install -y git git-lfs openssh-clients ca-certificates
      ;;
    zypper)
      $sudo_cmd zypper --non-interactive install git git-lfs openssh ca-certificates
      ;;
    *)
      print_fail "Пакетный менеджер" "не удалось определить apt/dnf/yum/zypper. Установите git и git-lfs вручную."
      exit 1
      ;;
  esac
}

if [ -z "$sudo_cmd" ] && [ "$(id -u)" -ne 0 ]; then
  print_fail "sudo" "sudo не найден. Запустите скрипт от root или установите Git вручную."
  exit 1
fi

install_packages

if [ -n "$GIT_USER_NAME" ]; then
  git_for_workspace_user config --global user.name "$GIT_USER_NAME"
fi

if [ -n "$GIT_USER_EMAIL" ]; then
  git_for_workspace_user config --global user.email "$GIT_USER_EMAIL"
fi

git_for_workspace_user config --global core.autocrlf input
git_for_workspace_user config --global core.safecrlf true
git_for_workspace_user config --global core.quotePath false
git_for_workspace_user config --global pull.rebase false
git_for_workspace_user config --global alias.st status
git_for_workspace_user config --global alias.co checkout
git_for_workspace_user config --global alias.br branch
git_for_workspace_user config --global alias.lg "log --oneline --decorate --graph --all"

git_for_workspace_user lfs install

print_ok "Git" "установлен и настроен для Linux: $(workspace_user_home)/.gitconfig"
