# Локальные переменные для скриптов подготовки рабочего места.
# local.vars.ps1 не нужно коммитить: в нем могут быть учетные данные и локальные пути.

$InitWorkspace = @{
    # Учетная запись releases.1c.ru.
    # Безопаснее оставить OneCPassword пустым: тогда скрипт спросит пароль интерактивно.
    OneCUser = "user@example.com"
    OneCPassword = "password"

    # Git for Windows.
    GitUserName = "Имя Фамилия"
    GitUserEmail = "you@example.com"
    GitLabHost = "gitlab.com"
    GitDownloadDir = ""
    GitInstallerUrl = ""

    # Репозиторий проекта.
    ProjectRepoUrl = "git@gitlab.com:group/project.git"
    # Если ProjectRootDir пустой, используется ProjectCloneDir.
    # Если EdtWorkspaceDir пустой, рабочая область EDT создается внутри проекта: <ProjectRootDir>\.metadata.
    ProjectCloneDir = ""
    ProjectRootDir = ""
    EdtWorkspaceDir = ""
    InfoBasePath = ""
    InfoBaseListName = ""
    ProjectBranch = "dev"

    # 1C:Enterprise Platform.
    PlatformVersion = "8.5.1.1302"
    V8Path = ""
    PlatformDownloadDir = ""
    PlatformExtractDir = ""
    PlatformReleasePageUrl = ""

    # 1C:EDT.
    EdtVersion = "2026.1.0"
    EdtCliPath = ""
    EdtDownloadDir = ""
    EdtExtractDir = ""
    EdtReleasePageUrl = ""
}
