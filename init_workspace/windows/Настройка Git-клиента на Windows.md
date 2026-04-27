# Настройка Git-клиента на Windows

Инструкция описывает базовую настройку Git for Windows для работы с репозиториями проекта.

Источники:

1. [1C:Enterprise Development Tools / Групповая разработка / Настроить групповую разработку](https://its.1c.ru/db/edtdoc#content:10054:hdoc)

## 1. Установка Git for Windows

1. Скачайте установщик с [официального сайта](https://git-scm.com/downloads) в рекомендуемом варианте: «Git from the command line and also from 3rd-party software».
2. Запустите установщик от имени обычного пользователя.
3. На шагах установки оставьте рекомендуемые параметры, кроме пунктов ниже:
   * `Choosing the default editor used by Git` - выберите удобный редактор, например Visual Studio Code.
   * `Adjusting the name of the initial branch in new repositories` - можно оставить `master`, если в проекте нет другого требования.
   * `Choosing the SSH executable` - оставьте `Use bundled OpenSSH`.
   * `Configuring the line ending conversions` - выберите `Checkout Windows-style, commit Unix-style line endings`.
   * `Configuring the terminal emulator` - оставьте `Use MinTTY`.

После установки откройте `Git Bash` из меню Пуск.

Если Git устанавливается впервые для работы через 1C:EDT, перезапустите 1C:EDT, чтобы обновилась переменная окружения `%PATH%`.

## 2. Настройка доступа по SSH

Если в проекте используется SSH-доступ, создайте ключ:

```bash
ssh-keygen -t ed25519 -C "you@example.com"
```

На вопрос о пути можно нажать `Enter`, чтобы сохранить ключ в стандартное место:

```text
C:\Users\<Пользователь>\.ssh\id_ed25519
```

После выполнения команды будут созданы два файла:

```text
C:\Users\<Пользователь>\.ssh\id_ed25519
C:\Users\<Пользователь>\.ssh\id_ed25519.pub
```

Файл `id_ed25519` - это приватный ключ. Он важен для доступа к репозиториям и должен оставаться только на вашем компьютере. Не отправляйте его в чат, почту, GitLab, GitHub и не коммитьте в репозиторий.

Файл `id_ed25519.pub` - это публичный ключ. Его можно передавать GitLab, GitHub или другому Git-серверу, чтобы сервер разрешил доступ по SSH.

Запустите SSH-агент и добавьте приватный ключ:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Выведите публичный ключ:

```bash
cat ~/.ssh/id_ed25519.pub
```

Скопируйте весь вывод команды, начиная с `ssh-ed25519` и заканчивая комментарием с вашей почтой.

Добавьте ключ в GitLab:

1. Откройте GitLab в браузере.
1. Нажмите на аватар пользователя в правом верхнем углу.
1. Перейдите в `Preferences` > `SSH Keys`.
1. Вставьте содержимое `id_ed25519.pub` в поле `Key`.
1. В поле `Title` укажите понятное имя компьютера, например `Work laptop`.
1. При необходимости задайте срок действия ключа в `Expiration date`.
1. Нажмите `Add key`.

Проверьте подключение:

```bash
ssh -T git@gitlab.com
```

Для корпоративного GitLab замените домен на адрес вашего сервера:

```bash
ssh -T git@gitlab.example.com
```

Если дополнительно используется GitHub, добавьте этот же публичный ключ в профиль GitHub и проверьте подключение:

```bash
ssh -T git@github.com
```

## 3. Настройка имени и почты

Укажите имя и почту, которые будут попадать в коммиты:

```bash
git config --global user.name "Ваше Имя"
git config --global user.email "you@example.com"
```

Проверьте результат:

```bash
git config --global --list
```

## 4. Настройка окончаний строк

В репозитории текстовые файлы должны храниться с окончанием строк `LF`. В рабочей копии разработчика Git может использовать окончания строк, родные для операционной системы.

Для Windows:

```bash
git config --global core.autocrlf true
git config --global core.safecrlf true
```

Для Linux и macOS:

```bash
git config --global core.autocrlf input
git config --global core.safecrlf true
```

Файл `.gitattributes` в репозитории должен задавать текстовую нормализацию без принудительного `eol=crlf` для обычных текстовых файлов. В этом случае Git хранит в репозитории `LF`, а рабочую копию формирует по настройкам клиента.

## 5. Длинные имена файлов

В Windows может действовать ограничение на длину пути. Чтобы снизить риск ошибки `Filename too long`, располагайте локальные репозитории ближе к корню диска, например `C:\work\project`.

Также включите поддержку длинных путей. Командную строку нужно запустить от имени администратора:

```bash
git config --system core.longpaths true
```

## 6. Русские буквы в путях

Чтобы пути с русскими буквами отображались читаемо, отключите экранирование не-ASCII символов:

```bash
git config --global core.quotePath false
```

## 7. Большие файлы и HTTP

При работе с большими файлами по HTTP может потребоваться увеличить буфер отправки:

```bash
git config --global http.postBuffer 1048576000
```

## 8. Настройка редактора

Если установлен Visual Studio Code, назначьте его редактором Git:

```bash
git config --global core.editor "code --wait"
```

Проверьте, что команда `code` доступна в терминале:

```bash
code --version
```

Если команда не найдена, откройте VS Code и выполните команду `Shell Command: Install 'code' command in PATH` через `Ctrl+Shift+P`.

## 9. Настройка доступа по HTTPS

Для работы по HTTPS Git for Windows использует Git Credential Manager. Обычно он включен сразу после установки.

Проверьте настройку:

```bash
git config --global credential.helper
```

Если значение пустое, включите менеджер учетных данных:

```bash
git config --global credential.helper manager
```

При первом `git clone`, `git fetch` или `git push` Git попросит авторизоваться в GitLab, GitHub или другом сервере. Для GitLab вместо пароля обычно используется Personal Access Token.

## 10. Настройка Git LFS

Git for Windows уже включает Git LFS. Если репозиторий использует Git LFS, включите его:

```bash
git lfs install
```

Проверьте версию:

```bash
git lfs version
```

После клонирования репозитория загрузите LFS-файлы:

```bash
git lfs pull
```

Если создается новый репозиторий с поддержкой Git LFS, настройку нужно выполнить после создания репозитория, но до первого коммита:

```bash
git lfs install
git lfs track "*.cf"
git lfs track "*.bin"
git lfs track "*.png"
git lfs track "*.gif"
git lfs track "*.bmp"
git lfs track "*.jpg"
git lfs track "*.zip"
git add .gitattributes
```

Файл `.gitattributes` нужно хранить в репозитории, чтобы все разработчики использовали одинаковые правила Git LFS и текстовой нормализации.

## 11. Клонирование репозитория

Перейдите в папку, где будут храниться проекты:

```bash
cd /c/work
```

Клонирование по HTTPS:

```bash
git clone https://example.com/group/project.git
```

Клонирование по SSH:

```bash
git clone git@example.com:group/project.git
```

Перейдите в папку проекта:

```bash
cd project
```

Проверьте состояние рабочей копии:

```bash
git status
```

## 12. Базовая проверка настройки

Выполните команды:

```bash
git --version
git config --global user.name
git config --global user.email
git config --global core.autocrlf
git config --global core.safecrlf
git config --global core.quotePath
git config --system core.longpaths
git lfs version
git status
```

Если все команды выполнились без ошибок, Git-клиент готов к работе.

## 13. Тайм-аут удаленного подключения в 1C:EDT

Если в 1C:EDT при импорте или работе с удаленным репозиторием появляется ошибка вида `Read timed out after 30 000 ms`, увеличьте тайм-аут в настройках EDT:

```text
Окно > Параметры... > Групповая разработка > Git > Тайм-аут удаленного подключения (сек)
```

## 14. Исправление неправильных окончаний строк в серверной ветке

Если настройки окончаний строк не были выполнены заранее и в серверную ветку попали неправильные разделители, при слиянии могут появиться отличия почти во всех файлах.

Общий порядок исправления:

1. Временно установите:

```bash
git config --global core.autocrlf false
git config --global core.safecrlf false
```

1. Заново склонируйте репозиторий и переключитесь на ветку, которую нужно исправить.
1. Преобразуйте разделители строк в `LF`, зафиксируйте изменения и отправьте их на сервер.
1. Верните правильные настройки:

```bash
git config --global core.autocrlf true
git config --global core.safecrlf true
```

Для Linux и macOS вместо `core.autocrlf true` верните `core.autocrlf input`.

## 15. Частые проблемы

* `Permission denied (publickey)` - SSH-ключ не добавлен в профиль Git-сервера или используется не тот ключ.
* `Authentication failed` - для HTTPS нужен актуальный токен доступа, обычный пароль часто не подходит.
* `LF will be replaced by CRLF` - Git сообщает, что файл в рабочей копии будет приведен к окончаниям строк, заданным настройками клиента или `.gitattributes`.
* `fatal: LF will be replaced by CRLF` - Git прервал команду из-за строгой проверки `core.safecrlf true`. Проверьте `.gitattributes`: для обычных текстовых файлов не должно быть принудительного `eol=crlf`, если политика проекта требует хранить в репозитории `LF`.
* `Filename too long` - репозиторий расположен слишком глубоко в файловой системе или не включен `core.longpaths`.
* Пути с русскими буквами отображаются как `\320\...` - включите `core.quotePath false`.
* `detected dubious ownership in repository` - Git считает папку небезопасной. Добавьте ее в доверенные:

```bash
git config --global --add safe.directory "C:/path/to/project"
```
