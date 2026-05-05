#!/usr/bin/env python3
"""Download a distribution from releases.1c.ru.

The flow mirrors init_workspace/windows/technical/lib/OneCReleases.ps1:
open release page, authenticate on login.1c.ru when redirected, select a
distribution link by title/href regexp, open its page, then download the file.
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import html
import http.cookiejar
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path


USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

try:
    sys.stdout.reconfigure(line_buffering=True)
except AttributeError:
    pass


@dataclass
class Response:
    url: str
    content: bytes

    @property
    def text(self) -> str:
        for encoding in ("utf-8", "cp1251"):
            try:
                return self.content.decode(encoding)
            except UnicodeDecodeError:
                pass
        return self.content.decode("utf-8", errors="replace")


@dataclass
class DistributionLink:
    title: str
    page_url: str
    download_url: str
    file_name: str
    sha512: str


class OneCSession:
    def __init__(self, user: str, password: str) -> None:
        self.user = user
        self.password = password
        self.cookie_jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cookie_jar)
        )

    def request(self, url: str, data: dict[str, str] | None = None) -> Response:
        encoded_data = None
        if data is not None:
            encoded_data = urllib.parse.urlencode(data).encode("utf-8")

        req = urllib.request.Request(
            url,
            data=encoded_data,
            headers={"User-Agent": USER_AGENT},
        )
        with self.opener.open(req, timeout=60) as res:
            content = res.read()
            response = Response(res.geturl(), content)

        if is_login_page(response):
            self.login(response)
            req = urllib.request.Request(url, data=encoded_data, headers={"User-Agent": USER_AGENT})
            with self.opener.open(req, timeout=60) as res:
                response = Response(res.geturl(), res.read())

        if is_login_page(response):
            raise RuntimeError("Авторизация на releases.1c.ru не выполнена. Проверьте логин и пароль.")

        return response

    def login(self, response: Response) -> None:
        match = re.search(r'name="execution"\s+value="([^"]+)"', response.text)
        if not match:
            raise RuntimeError("Не найден hidden-параметр execution на странице авторизации 1С.")

        body = {
            "inviteCode": "",
            "username": self.user,
            "password": self.password,
            "execution": match.group(1),
            "_eventId": "submit",
            "geolocation": "",
            "submit": "Войти",
            "rememberMe": "on",
        }
        self.request(response.url or "https://login.1c.ru/login", body)


def is_login_page(response: Response) -> bool:
    return response.url.startswith("https://login.1c.ru/login")


def absolute_url(base_url: str, href: str) -> str:
    return urllib.parse.urljoin(base_url, href)


def file_name_from_download_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    query = urllib.parse.parse_qs(parsed.query)
    if "path" in query and query["path"]:
        return Path(query["path"][0]).name
    return Path(parsed.path).name


def file_name_from_distribution_html(text: str) -> str:
    match = re.search(
        r"Имя\s+файла:\s*</td>\s*<td>\s*([^<]+?)\s*</td>",
        text,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if match:
        return html.unescape(match.group(1)).strip()
    return ""


def sha512_from_distribution_html(text: str) -> str:
    match = re.search(r"copyToClipboard\('([a-fA-F0-9]{128})'", text, flags=re.IGNORECASE)
    if match:
        return match.group(1).lower()

    match = re.search(
        r"SHA-512:\s*</td>\s*<td[^>]*>.*?([a-fA-F0-9]{128}).*?</td>",
        text,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if match:
        return match.group(1).lower()

    return ""


def anchors(text: str) -> list[tuple[str, str]]:
    pattern = re.compile(r'<a\s+[^>]*href="([^"]+)"[^>]*>\s*([^<]+?)\s*</a>', re.I)
    return [(m.group(1), html.unescape(m.group(2)).strip()) for m in pattern.finditer(text)]


def find_distribution_link(
    session: OneCSession,
    release_page_url: str,
    filters: list[str],
) -> DistributionLink:
    print(f"Открываю страницу релиза: {release_page_url}")
    release_response = session.request(release_page_url)

    for filter_text in filters:
        regex = re.compile(filter_text, re.IGNORECASE)
        for href, title in anchors(release_response.text):
            if not regex.search(title) and not regex.search(href):
                continue

            page_url = absolute_url(release_page_url, href)
            print(f"Найден дистрибутив: {title}")
            print(f"Страница дистрибутива: {page_url}")
            distribution_response = session.request(page_url)
            match = re.search(
                r'<div\s+class="downloadDist">.*?<a\s+href="([^"]+)">\s*Скачать\s+дистрибутив\s*</a>.*?</div>',
                distribution_response.text,
                flags=re.IGNORECASE | re.DOTALL,
            )
            if not match:
                raise RuntimeError("На странице дистрибутива не найдена ссылка 'Скачать дистрибутив'.")

            download_url = absolute_url(page_url, match.group(1))
            file_name = file_name_from_distribution_html(distribution_response.text)
            if not file_name:
                file_name = file_name_from_download_url(page_url)
            if not Path(file_name).suffix:
                file_name = file_name_from_download_url(download_url)
            sha512 = sha512_from_distribution_html(distribution_response.text)
            return DistributionLink(title, page_url, download_url, file_name, sha512)

    raise RuntimeError(f"Не найден дистрибутив по фильтрам: {'; '.join(filters)}")


def sha512_file(path: Path) -> str:
    digest = hashlib.sha512()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().lower()


def verify_sha512(path: Path, expected: str) -> None:
    if not expected:
        print("[WARN] SHA-512 не найден на странице дистрибутива, проверка пропущена.")
        return
    actual = sha512_file(path)
    if actual != expected.lower():
        raise RuntimeError(f"SHA-512 не совпадает. Ожидалось: {expected}. Получено: {actual}")
    print("SHA-512 проверен.")


def download_file(
    session: OneCSession,
    url: str,
    destination: Path,
    force: bool,
    expected_sha512: str = "",
) -> None:
    if destination.exists() and not force:
        print(f"Файл уже существует: {destination}")
        try:
            verify_sha512(destination, expected_sha512)
            print("Повторное скачивание не требуется.")
            return
        except RuntimeError as exc:
            print(f"[WARN] {exc}")
            raise RuntimeError(
                "Существующий файл не удален. Проверьте файл вручную или запустите установку с --force-download "
                "для повторного скачивания."
            ) from exc

    partial = destination.with_suffix(destination.suffix + ".part")
    if partial.exists():
        partial.unlink()

    progress_printed = False
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with session.opener.open(req, timeout=60) as res, partial.open("wb") as out:
        total = int(res.headers.get("Content-Length") or 0)
        downloaded = 0
        started = time.time()
        last_reported = 0.0
        while True:
            chunk = res.read(1024 * 1024)
            if not chunk:
                break
            out.write(chunk)
            downloaded += len(chunk)
            now = time.time()
            if now - last_reported >= 1:
                last_reported = now
                if total:
                    percent = downloaded * 100 / total
                    message = f"Скачано: {downloaded / 1024 / 1024:.1f} МБ из {total / 1024 / 1024:.1f} МБ ({percent:.1f}%)"
                else:
                    speed = downloaded / max(1.0, now - started)
                    message = f"Скачано: {downloaded / 1024 / 1024:.1f} МБ, {speed / 1024 / 1024:.1f} МБ/с"
                print(f"\r{message}", end="", file=sys.stderr, flush=True)
                progress_printed = True
    partial.replace(destination)
    if progress_printed:
        print(file=sys.stderr, flush=True)
    print(f"Скачано: {destination}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-page-url", required=True)
    parser.add_argument("--filter", action="append", required=True, dest="filters")
    parser.add_argument("--destination-dir", required=True)
    parser.add_argument("--user", default=os.environ.get("ONEC_USER", ""))
    parser.add_argument("--password", default=os.environ.get("ONEC_PASSWORD", ""))
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    user = args.user or input("Логин releases.1c.ru: ")
    password = args.password or getpass.getpass("Пароль releases.1c.ru: ")
    if not user or not password:
        raise RuntimeError("Логин и пароль releases.1c.ru обязательны.")

    destination_dir = Path(args.destination_dir)
    destination_dir.mkdir(parents=True, exist_ok=True)

    session = OneCSession(user, password)
    link = find_distribution_link(session, args.release_page_url, args.filters)
    destination = destination_dir / link.file_name
    print(f"Ссылка загрузки: {link.download_url}")
    print(f"Файл: {destination}")
    download_file(session, link.download_url, destination, args.force, link.sha512)
    verify_sha512(destination, link.sha512)
    print(destination)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)
