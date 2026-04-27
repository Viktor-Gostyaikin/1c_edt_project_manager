# Локальные переменные для скриптов подготовки рабочего места.
# Скопируйте файл в local.vars.ps1 и заполните нужные значения.
# local.vars.ps1 не нужно коммитить: в нем могут быть учетные данные и локальные пути.

$InitWorkspace = @{
    # Учетная запись releases.1c.ru.
    # Безопаснее оставить OneCPassword пустым: тогда скрипт спросит пароль интерактивно.
    OneCUser = "user@example.com"
    OneCPassword = ""

    # Git for Windows.
    GitUserName = "Ваше Имя"
    GitUserEmail = "you@example.com"
    GitLabHost = "gitlab.com"
    GitDownloadDir = ""
    GitInstallerUrl = ""

    # 1C:Enterprise Platform.
    PlatformVersion = "8.5.1.1302"
    PlatformDownloadDir = ""
    PlatformExtractDir = ""
    PlatformReleasePageUrl = ""

    # 1C:EDT.
    EdtVersion = "2026.1.0"
    EdtDownloadDir = ""
    EdtExtractDir = ""
    EdtReleasePageUrl = ""
}
