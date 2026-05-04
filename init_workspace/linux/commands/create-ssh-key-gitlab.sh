#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"

load_init_workspace_vars

if [ -z "$GITLAB_HOST" ]; then
  print_fail "GitLabHost" "не указан GITLAB_HOST в local.vars.sh."
  exit 1
fi

if ! command -v ssh-keygen >/dev/null 2>&1; then
  print_fail "ssh-keygen" "команда не найдена. Установите openssh-client."
  exit 1
fi

user_home="$(workspace_user_home)"
ssh_dir="$user_home/.ssh"
key_basename="$(printf '%s' "$GITLAB_HOST" | sed -E 's/[^A-Za-z0-9._-]+/_/g')_ed25519"
key_path="$ssh_dir/$key_basename"
config_path="$ssh_dir/config"
comment="${GIT_USER_EMAIL:-$GITLAB_HOST}"
key_title="$(hostname 2>/dev/null || hostnamectl --static 2>/dev/null || printf '%s' "$GITLAB_HOST")"
begin_marker="# >>> init-workspace $GITLAB_HOST"
end_marker="# <<< init-workspace $GITLAB_HOST"

mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"
fix_workspace_file_owner "$ssh_dir"

if [ -f "$key_path" ]; then
  print_ok "SSH key" "ключ уже существует: $key_path"
else
  ssh-keygen -t ed25519 -C "$comment" -f "$key_path" -N ""
  chmod 600 "$key_path"
  chmod 644 "$key_path.pub"
  fix_workspace_file_owner "$key_path" "$key_path.pub"
  print_ok "SSH key" "создан ключ: $key_path"
fi

touch "$config_path"
chmod 600 "$config_path"
fix_workspace_file_owner "$config_path"

tmp_config="$(mktemp)"
awk -v begin="$begin_marker" -v end="$end_marker" '
  $0 == begin { skip = 1; next }
  $0 == end { skip = 0; next }
  !skip { print }
' "$config_path" >"$tmp_config"

{
  printf '%s\n' "$begin_marker"
  printf 'Host %s\n' "$GITLAB_HOST"
  printf '    HostName %s\n' "$GITLAB_HOST"
  printf '    User git\n'
  printf '    IdentityFile %s\n' "$key_path"
  printf '    IdentitiesOnly yes\n'
  printf '%s\n' "$end_marker"
  printf '\n'
  cat "$tmp_config"
} >"$config_path"

rm -f "$tmp_config"
chmod 600 "$config_path"
fix_workspace_file_owner "$config_path"

print_ok "SSH config" "настроен хост $GITLAB_HOST в $config_path"
printf '\nДобавьте публичный ключ в GitLab:\n'
printf 'https://%s/-/user_settings/ssh_keys\n\n' "$GITLAB_HOST"
printf 'Key:\n'
cat "$key_path.pub"
printf '\n\n'
printf 'Title:\n'
printf '%s\n\n' "$key_title"
printf 'Usage type:\n'
printf 'Authentication & Signing\n\n'
printf 'Expiration date:\n'
printf 'Без срока действия. GitLab позволяет оставить поле пустым, но это не рекомендуется.\n\n'
printf 'Файл публичного ключа: %s\n' "$key_path.pub"
printf '\nСамостоятельная проверка после добавления ключа:\n'
printf 'ssh -T git@%s\n' "$GITLAB_HOST"
printf 'Ожидаемый успешный ответ:\n'
printf 'Welcome to GitLab, @<ваш-логин>!\n'
printf '\n'
