#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"
# shellcheck source=../technical/lib/os-detect.sh
. "$SCRIPT_DIR/../technical/lib/os-detect.sh"

load_init_workspace_vars

DOWNLOAD_ONLY=0
FORCE_DOWNLOAD=0
FORCE_EXTRACT=0
SKIP_DEPENDENCY_CHECK=0
PLATFORM_INSTALL_COMPONENTS="${PLATFORM_INSTALL_COMPONENTS:-server,client}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --download-only|-DownloadOnly) DOWNLOAD_ONLY=1 ;;
    --force-download|-ForceDownload) FORCE_DOWNLOAD=1 ;;
    --force-extract|-ForceExtract) FORCE_EXTRACT=1 ;;
    --skip-dependency-check|-SkipDependencyCheck) SKIP_DEPENDENCY_CHECK=1 ;;
    *)
      print_fail "Параметр" "неизвестный параметр: $1"
      exit 1
      ;;
  esac
  shift
done

repo_root="$(cd "$SCRIPT_DIR/../../.." && pwd)"
download_dir="${PLATFORM_DOWNLOAD_DIR:-$repo_root/build/downloads/platform/$PLATFORM_VERSION}"
extract_dir="${PLATFORM_EXTRACT_DIR:-$repo_root/build/installers/platform/$PLATFORM_VERSION}"
release_page_url="${PLATFORM_RELEASE_PAGE_URL:-https://releases.1c.ru/version_files?nick=Platform85&ver=$PLATFORM_VERSION}"
pm="$(detect_package_manager)"
sudo_cmd="$(sudo_prefix)"

if [ -z "$sudo_cmd" ] && [ "$(id -u)" -ne 0 ] && [ "$DOWNLOAD_ONLY" -eq 0 ]; then
  print_fail "sudo" "sudo не найден. Запустите скрипт от root или используйте --download-only."
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  print_fail "python3" "python3 не найден. Он нужен для загрузки с releases.1c.ru."
  exit 1
fi

run_privileged() {
  if [ -n "$sudo_cmd" ]; then
    "$sudo_cmd" "$@"
  else
    "$@"
  fi
}

install_platform_dependencies() {
  case "$pm" in
    apt)
      run_privileged apt-get install -y fontconfig libgsf-1-114 unixodbc
      ;;
    dnf|yum)
      run_privileged "$pm" install -y fontconfig libgsf unixODBC
      ;;
    zypper)
      run_privileged zypper --non-interactive install fontconfig libgsf-1-114 unixODBC
      ;;
  esac
}

component_is_requested() {
  local component="$1"

  case ",$PLATFORM_INSTALL_COMPONENTS," in
    *,all,*|*,"$component",*) return 0 ;;
    *) return 1 ;;
  esac
}

platform_package_is_requested() {
  local package_name="$1"

  if [[ ! "$package_name" =~ ^1c-enterprise ]]; then
    return 1
  fi

  if component_is_requested server; then
    if [[ "$package_name" =~ -(common|server|ws)(_|-[0-9]) ]]; then
      return 0
    fi
  fi

  if component_is_requested client; then
    if [[ "$package_name" =~ -(common|client)(_|-[0-9]) ]]; then
      return 0
    fi
  fi

  return 1
}

find_platform_packages() {
  local extension="$1"

  find "$extract_dir" -type f -name "*.$extension" | while IFS= read -r package_path; do
    if platform_package_is_requested "$(basename "$package_path")"; then
      printf '%s\n' "$package_path"
    fi
  done | sort
}

run_installer_components() {
  local components=()

  if component_is_requested server; then
    components+=(server ws)
  fi
  if component_is_requested client; then
    components+=(client_full)
  fi
  components+=(ru)

  local IFS=,
  printf '%s\n' "${components[*]}"
}

create_current_symlink() {
  local platform_path=""
  local expected_path="/opt/1cv8/x86_64/$PLATFORM_VERSION"

  if [ -d "$expected_path" ]; then
    platform_path="$expected_path"
  elif [ -d /opt/1cv8 ]; then
    platform_path="$(
      find /opt/1cv8 -type f \( -name '1cv8c' -o -name '1cv8' -o -name 'ragent' \) -exec dirname {} \; 2>/dev/null \
        | sort -V \
        | tail -n 1
    )"
  fi

  if [ -z "$platform_path" ] || [ ! -d "$platform_path" ]; then
    print_warn "1C:Enterprise Platform" "не удалось определить каталог установленной платформы для ссылки /opt/1cv8/current."
    return 0
  fi

  if [ -e /opt/1cv8/current ] && [ ! -L /opt/1cv8/current ]; then
    print_warn "1C:Enterprise Platform" "/opt/1cv8/current уже существует и не является ссылкой. Обновите путь вручную: $platform_path"
    return 0
  fi

  run_privileged mkdir -p /opt/1cv8
  run_privileged ln -sfn "$platform_path" /opt/1cv8/current
  print_ok "1C:Enterprise Platform" "ссылка /opt/1cv8/current -> $platform_path"
}

filter_args=()
IFS='|' read -r -a filters <<<"$PLATFORM_DISTRIBUTION_FILTERS"
for filter in "${filters[@]}"; do
  [ -n "$filter" ] && filter_args+=(--filter "$filter")
done

downloader_args=(
  "$SCRIPT_DIR/../technical/onec_release_downloader.py"
  --release-page-url "$release_page_url"
  --destination-dir "$download_dir"
)
downloader_args+=("${filter_args[@]}")

if [ "$FORCE_DOWNLOAD" -eq 1 ]; then
  downloader_args+=(--force)
fi

download_log="$(mktemp)"
trap 'rm -f "$download_log"' EXIT
ONEC_USER="$ONEC_USER" ONEC_PASSWORD="$ONEC_PASSWORD" python3 "${downloader_args[@]}" | tee "$download_log"
archive_path="$(tail -n 1 "$download_log")"

if [ -z "$archive_path" ] || [ ! -f "$archive_path" ]; then
  print_fail "Download" "не удалось определить скачанный файл из вывода загрузчика."
  exit 1
fi

if [ "$DOWNLOAD_ONLY" -eq 1 ]; then
  print_ok "1C:Enterprise Platform" "дистрибутив скачан: $archive_path"
  exit 0
fi

mkdir -p "$extract_dir"
if [ "$FORCE_EXTRACT" -eq 1 ]; then
  find "$extract_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi

case "$archive_path" in
  *.zip) unzip -o "$archive_path" -d "$extract_dir" ;;
  *.rar) 7z x -y "-o$extract_dir" "$archive_path" ;;
  *.tar.gz|*.tgz) tar -xzf "$archive_path" -C "$extract_dir" ;;
  *.tar.xz) tar -xJf "$archive_path" -C "$extract_dir" ;;
  *.tar) tar -xf "$archive_path" -C "$extract_dir" ;;
  *.deb|*.rpm) extract_dir="$(dirname "$archive_path")" ;;
  *)
    print_warn "Archive" "неизвестное расширение, установка будет искать пакеты рядом с файлом: $archive_path"
    extract_dir="$(dirname "$archive_path")"
    ;;
esac

print_ok "1C:Enterprise Platform" "компоненты для установки: $PLATFORM_INSTALL_COMPONENTS"
install_platform_dependencies

case "$pm" in
  apt)
    mapfile -t packages < <(find_platform_packages deb)
    if [ "${#packages[@]}" -gt 0 ]; then
      run_privileged apt-get install -y "${packages[@]}"
    elif mapfile -t run_files < <(find "$extract_dir" -type f -name '*.run' | sort) && [ "${#run_files[@]}" -gt 0 ]; then
      run_privileged chmod +x "${run_files[0]}"
      run_privileged "${run_files[0]}" --mode unattended --enable-components "$(run_installer_components)"
    else
      print_fail "1C:Enterprise Platform" "в дистрибутиве не найдены пакеты компонентов server/client: $extract_dir"
      exit 1
    fi
    ;;
  dnf|yum)
    mapfile -t packages < <(find_platform_packages rpm)
    if [ "${#packages[@]}" -gt 0 ]; then
      run_privileged "$pm" install -y "${packages[@]}"
    elif mapfile -t run_files < <(find "$extract_dir" -type f -name '*.run' | sort) && [ "${#run_files[@]}" -gt 0 ]; then
      run_privileged chmod +x "${run_files[0]}"
      run_privileged "${run_files[0]}" --mode unattended --enable-components "$(run_installer_components)"
    else
      print_fail "1C:Enterprise Platform" "в дистрибутиве не найдены пакеты компонентов server/client: $extract_dir"
      exit 1
    fi
    ;;
  zypper)
    mapfile -t packages < <(find_platform_packages rpm)
    if [ "${#packages[@]}" -gt 0 ]; then
      run_privileged zypper --non-interactive install "${packages[@]}"
    elif mapfile -t run_files < <(find "$extract_dir" -type f -name '*.run' | sort) && [ "${#run_files[@]}" -gt 0 ]; then
      run_privileged chmod +x "${run_files[0]}"
      run_privileged "${run_files[0]}" --mode unattended --enable-components "$(run_installer_components)"
    else
      print_fail "1C:Enterprise Platform" "в дистрибутиве не найдены пакеты компонентов server/client: $extract_dir"
      exit 1
    fi
    ;;
  *)
    print_fail "Пакетный менеджер" "не удалось определить apt/dnf/yum/zypper для установки платформы."
    exit 1
    ;;
esac

create_current_symlink
print_ok "1C:Enterprise Platform" "установка платформы $PLATFORM_VERSION завершена."

if [ "$SKIP_DEPENDENCY_CHECK" -eq 0 ]; then
  "$SCRIPT_DIR/check-quickstart-deps.sh"
fi
