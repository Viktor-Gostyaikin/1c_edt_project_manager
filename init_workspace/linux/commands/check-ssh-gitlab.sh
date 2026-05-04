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

user_home="$(workspace_user_home)"
workspace_user="$(workspace_user_name)"
ssh_dir="$user_home/.ssh"
key_basename="$(printf '%s' "$GITLAB_HOST" | sed -E 's/[^A-Za-z0-9._-]+/_/g')_ed25519"
key_path="$ssh_dir/$key_basename"
config_path="$ssh_dir/config"
known_hosts_path="$ssh_dir/known_hosts"

mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir" 2>/dev/null || print_warn "SSH permissions" "не удалось изменить права на $ssh_dir"
touch "$known_hosts_path" 2>/dev/null || print_warn "known_hosts" "не удалось создать или обновить $known_hosts_path"
chmod 600 "$known_hosts_path" 2>/dev/null || true
fix_workspace_file_owner "$ssh_dir" "$known_hosts_path"

if [ -f "$key_path" ]; then
  print_ok "SSH key" "найден ключ: $key_path"
else
  print_fail "SSH key" "ключ для $GITLAB_HOST не найден: $key_path"
  printf 'Создайте ключ через пункт меню "Создать SSH-ключ GitLab" или командой:\n'
  printf './commands/create-ssh-key-gitlab.sh\n'
  exit 1
fi

if [ ! -f "$key_path.pub" ]; then
  print_fail "SSH public key" "публичный ключ не найден: $key_path.pub"
  printf 'Восстановите публичный ключ командой:\n'
  printf 'ssh-keygen -y -f "%s" > "%s.pub"\n' "$key_path" "$key_path"
  exit 1
fi

key_fingerprint="$(ssh-keygen -lf "$key_path.pub" 2>/dev/null || true)"

if ! ssh-keygen -F "$GITLAB_HOST" -f "$known_hosts_path" >/dev/null 2>&1; then
  print_warn "known_hosts" "добавляю ключ хоста $GITLAB_HOST."
  ssh-keyscan -H "$GITLAB_HOST" >>"$known_hosts_path" 2>/dev/null || true
  fix_workspace_file_owner "$known_hosts_path"
fi

run_ssh_as_workspace_user() {
  local ssh_args=("$@")

  if [ -n "$workspace_user" ] && [ "$(id -un 2>/dev/null || true)" != "$workspace_user" ]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo -H -u "$workspace_user" env HOME="$user_home" ssh "${ssh_args[@]}"
      return
    fi

    if [ "$(id -u)" -eq 0 ] && command -v runuser >/dev/null 2>&1; then
      runuser -u "$workspace_user" -- env HOME="$user_home" ssh "${ssh_args[@]}"
      return
    fi
  fi

  HOME="$user_home" ssh "${ssh_args[@]}"
}

build_main_ssh_args() {
  if [ -f "$config_path" ]; then
    printf '%s\0' \
      -F "$config_path" \
      -T \
      -o BatchMode=yes \
      -o ConnectTimeout=10 \
      "git@$GITLAB_HOST"
    return
  fi

  printf '%s\0' \
    -F /dev/null \
    -T \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$known_hosts_path" \
    -i "$key_path" \
    "git@$GITLAB_HOST"
}

main_ssh_args=()
while IFS= read -r -d '' arg; do
  main_ssh_args+=("$arg")
done < <(build_main_ssh_args)

set +e
ssh_output="$(run_ssh_as_workspace_user "${main_ssh_args[@]}" 2>&1)"
code=$?
set -e

if [ -n "$ssh_output" ]; then
  printf '%s\n' "$ssh_output"
fi

case "$code" in
  0|1)
    print_ok "GitLab SSH" "подключение к git@$GITLAB_HOST выполнено. Код SSH: $code"
    ;;
  *)
    print_fail "GitLab SSH" "подключение не выполнено. Проверьте сеть, ключ и доступ в GitLab. Код SSH: $code"
    if printf '%s\n' "$ssh_output" | grep -qi 'Permission denied'; then
      printf '\nGitLab не принял ключ. Добавьте публичный ключ в GitLab:\n'
      printf 'https://%s/-/user_settings/ssh_keys\n\n' "$GITLAB_HOST"
      printf 'Key:\n'
      cat "$key_path.pub"
      printf '\n\n'
      printf 'Title:\n'
      hostname 2>/dev/null || printf '%s\n' "$GITLAB_HOST"
      printf '\nUsage type:\n'
      printf 'Authentication & Signing\n\n'
      printf 'Expiration date:\n'
      printf 'Без срока действия. GitLab позволяет оставить поле пустым, но это не рекомендуется.\n\n'
      printf 'Самостоятельная проверка после добавления ключа:\n'
      if [ -f "$config_path" ] && [ -n "$workspace_user" ]; then
        printf 'sudo -H -u %s ssh -F "%s" -T git@%s\n' "$workspace_user" "$config_path" "$GITLAB_HOST"
      elif [ -f "$config_path" ]; then
        printf 'ssh -F "%s" -T git@%s\n' "$config_path" "$GITLAB_HOST"
      elif [ -n "$workspace_user" ]; then
        printf 'sudo -H -u %s ssh -T git@%s\n' "$workspace_user" "$GITLAB_HOST"
      else
        printf 'ssh -T git@%s\n' "$GITLAB_HOST"
      fi
      printf 'Ожидаемый успешный ответ:\n'
      printf 'Welcome to GitLab, @<ваш-логин>!\n\n'
      printf 'Точная команда, которую использует эта проверка:\n'
      if [ -n "$workspace_user" ]; then
        printf 'sudo -H -u %s env HOME="%s" ssh' "$workspace_user" "$user_home"
      else
        printf 'HOME="%s" ssh' "$user_home"
      fi
      printf ' %q' "${main_ssh_args[@]}"
      printf '\n\n'
      printf 'Команда для подробной диагностики SSH:\n'
      if [ -n "$workspace_user" ]; then
        printf 'sudo -H -u %s env HOME="%s" ssh -vvv' "$workspace_user" "$user_home"
      else
        printf 'HOME="%s" ssh -vvv' "$user_home"
      fi
      printf ' %q' "${main_ssh_args[@]}"
      printf '\n\n'
      if [ -n "$key_fingerprint" ]; then
        printf 'Fingerprint ключа, который должен быть добавлен в GitLab:\n'
        printf '%s\n' "$key_fingerprint"
      fi
    fi
    exit "$code"
    ;;
esac
