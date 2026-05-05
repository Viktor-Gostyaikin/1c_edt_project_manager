#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../technical/lib/init-workspace-vars.sh
. "$SCRIPT_DIR/../technical/lib/init-workspace-vars.sh"

load_init_workspace_vars

DOWNLOAD_ONLY=0
FORCE_DOWNLOAD=0
FORCE_EXTRACT=0
SKIP_DEPENDENCY_CHECK=0

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
download_dir="${EDT_DOWNLOAD_DIR:-$repo_root/build/downloads/edt/$EDT_VERSION}"
extract_dir="${EDT_EXTRACT_DIR:-$repo_root/build/installers/edt/$EDT_VERSION}"
release_page_url="${EDT_RELEASE_PAGE_URL:-https://releases.1c.ru/version_files?nick=DevelopmentTools10&ver=$EDT_VERSION}"

if ! command -v python3 >/dev/null 2>&1; then
  print_fail "python3" "python3 не найден. Он нужен для загрузки с releases.1c.ru."
  exit 1
fi

filter_args=()
IFS='|' read -r -a filters <<<"$EDT_DISTRIBUTION_FILTERS"
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
  print_ok "1C:EDT" "дистрибутив скачан: $archive_path"
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
  *.run|*.sh) extract_dir="$(dirname "$archive_path")" ;;
  *)
    print_warn "Archive" "неизвестное расширение, установка будет искать installer рядом с файлом: $archive_path"
    extract_dir="$(dirname "$archive_path")"
    ;;
esac

installer_cli="$(find "$extract_dir" -type f \( -name '1ce-installer-cli' -o -name '1ce-installer-cli.sh' \) | sort | head -n 1)"
installer_gui="$(find "$extract_dir" -type f \( -name '1ce-installer' -o -name '1ce-installer.sh' -o -name '*.run' \) | sort | head -n 1)"

if [ -n "$installer_cli" ]; then
  chmod +x "$installer_cli"
  run_as_workspace_user "$installer_cli" install
elif [ -n "$installer_gui" ]; then
  chmod +x "$installer_gui"
  print_warn "1C:EDT" "консольный установщик не найден, запускаю доступный установщик: $installer_gui"
  run_as_workspace_user "$installer_gui"
else
  print_fail "1C:EDT" "не найден установщик 1ce-installer-cli/1ce-installer в $extract_dir"
  exit 1
fi

print_ok "1C:EDT" "установка EDT $EDT_VERSION завершена."

if [ "$SKIP_DEPENDENCY_CHECK" -eq 0 ]; then
  "$SCRIPT_DIR/check-quickstart-deps.sh"
fi
