#Requires -Version 5.1

param(
    [string]$UserName = "",
    [string]$UserEmail = "",
    [string]$DownloadDir = "",
    [string]$InstallerUrl = "",
    [string]$GitLabHost = "gitlab.com",
    [switch]$SkipInstall,
    [switch]$ForceDownload,
    [switch]$ConfigureSystem,
    [switch]$CreateSshKey
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

[Net.ServicePointManager]::SecurityProtocol = (
    [Net.ServicePointManager]::SecurityProtocol -bor
    [Net.SecurityProtocolType]::Tls12
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..\..")).Path
. (Join-Path $ScriptDir "lib\InitWorkspaceVars.ps1")

$variables = Get-InitWorkspaceVariables -ScriptDir $ScriptDir
$UserName = Get-InitWorkspaceValue -Variables $variables -Name "GitUserName" -CurrentValue $UserName -PreferCurrent:$PSBoundParameters.ContainsKey("UserName")
$UserEmail = Get-InitWorkspaceValue -Variables $variables -Name "GitUserEmail" -CurrentValue $UserEmail -PreferCurrent:$PSBoundParameters.ContainsKey("UserEmail")
$DownloadDir = Get-InitWorkspaceValue -Variables $variables -Name "GitDownloadDir" -CurrentValue $DownloadDir -PreferCurrent:$PSBoundParameters.ContainsKey("DownloadDir")
$InstallerUrl = Get-InitWorkspaceValue -Variables $variables -Name "GitInstallerUrl" -CurrentValue $InstallerUrl -PreferCurrent:$PSBoundParameters.ContainsKey("InstallerUrl")
$GitLabHost = Get-InitWorkspaceValue -Variables $variables -Name "GitLabHost" -CurrentValue $GitLabHost -PreferCurrent:$PSBoundParameters.ContainsKey("GitLabHost")

if (-not $DownloadDir) {
    $DownloadDir = Join-Path $RepoRoot "build\downloads\git"
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-CommandPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    return $null
}

function Get-GitPath {
    $gitPath = Get-CommandPath "git.exe"
    if ($gitPath) {
        return $gitPath
    }

    $candidatePaths = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )

    foreach ($path in $candidatePaths) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }

    return $null
}

function Get-SshKeygenPath {
    $sshKeygenPath = Get-CommandPath "ssh-keygen.exe"
    if ($sshKeygenPath) {
        return $sshKeygenPath
    }

    $gitPath = Get-GitPath
    if ($gitPath) {
        $gitRoot = Resolve-Path (Join-Path (Split-Path -Parent $gitPath) "..")
        $candidatePath = Join-Path $gitRoot "usr\bin\ssh-keygen.exe"
        if (Test-Path $candidatePath) {
            return $candidatePath
        }
    }

    return $null
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $gitPath = Get-GitPath
    if (-not $gitPath) {
        throw "git.exe не найден. Установите Git for Windows и перезапустите терминал."
    }

    & $gitPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Команда git завершилась с кодом ${LASTEXITCODE}: git $($Arguments -join ' ')"
    }
}

function Install-GitWithWinget {
    $wingetPath = Get-CommandPath "winget.exe"
    if (-not $wingetPath) {
        return $false
    }

    Write-Host "Устанавливаю Git for Windows через winget..."
    & $wingetPath install `
        --id Git.Git `
        --exact `
        --source winget `
        --accept-source-agreements `
        --accept-package-agreements | Out-Host

    if ($LASTEXITCODE -ne 0) {
        throw "winget не смог установить Git for Windows. Код завершения: $LASTEXITCODE"
    }

    return $true
}

function Get-LatestGitInstallerUrl {
    Write-Host "Получаю ссылку на актуальный Git for Windows..."
    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest" `
        -Headers @{ "User-Agent" = "itw-mis-init-workspace" } `
        -UseBasicParsing

    $asset = $release.assets |
        Where-Object { $_.name -match "^Git-.*-64-bit\.exe$" } |
        Select-Object -First 1

    if (-not $asset) {
        throw "В последнем релизе Git for Windows не найден 64-bit .exe установщик."
    }

    return $asset.browser_download_url
}

function Save-GitInstaller {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
    $fileName = [System.IO.Path]::GetFileName(([uri]$Url).AbsolutePath)
    $installerPath = Join-Path $DownloadDir $fileName

    if ((Test-Path $installerPath) -and -not $ForceDownload) {
        Write-Host "Установщик уже скачан: $installerPath"
        return $installerPath
    }

    Write-Host "Скачиваю Git for Windows: $Url"
    Write-Host "В файл: $installerPath"
    Invoke-WebRequest -Uri $Url -OutFile $installerPath -UseBasicParsing

    return $installerPath
}

function Assert-ValidInstallerSignature {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath
    )

    $signature = Get-AuthenticodeSignature -FilePath $InstallerPath
    if ($signature.Status -ne "Valid") {
        throw "Подпись установщика Git for Windows не прошла проверку: $($signature.Status). Файл: $InstallerPath"
    }

    Write-Host "Подпись установщика проверена: $($signature.SignerCertificate.Subject)"
}

function Install-GitWithInstaller {
    if (-not $InstallerUrl) {
        $InstallerUrl = Get-LatestGitInstallerUrl
    }

    $installerPath = Save-GitInstaller -Url $InstallerUrl
    Assert-ValidInstallerSignature -InstallerPath $installerPath

    Write-Host "Запускаю установщик Git for Windows..."
    $arguments = @(
        "/VERYSILENT",
        "/NORESTART",
        "/NOCANCEL",
        "/SP-",
        "/CLOSEAPPLICATIONS",
        "/RESTARTAPPLICATIONS"
    )

    $process = Start-Process `
        -FilePath $installerPath `
        -ArgumentList $arguments `
        -Wait `
        -PassThru

    if ($process.ExitCode -ne 0) {
        throw "Установщик Git for Windows завершился с кодом $($process.ExitCode)."
    }
}

function Read-GitIdentity {
    if ([string]::IsNullOrWhiteSpace($UserName)) {
        $script:UserName = Read-Host "Имя для git user.name"
    }

    if ([string]::IsNullOrWhiteSpace($UserEmail)) {
        $script:UserEmail = Read-Host "Почта для git user.email"
    }

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        throw "Имя пользователя Git не указано."
    }

    if ([string]::IsNullOrWhiteSpace($UserEmail)) {
        throw "Почта пользователя Git не указана."
    }
}

function Set-GitConfig {
    Read-GitIdentity

    Write-Host "Настраиваю Git для групповой разработки..."
    Invoke-Git -Arguments @("config", "--global", "user.name", $UserName)
    Invoke-Git -Arguments @("config", "--global", "user.email", $UserEmail)
    Invoke-Git -Arguments @("config", "--global", "core.autocrlf", "true")
    Invoke-Git -Arguments @("config", "--global", "core.safecrlf", "true")
    Invoke-Git -Arguments @("config", "--global", "core.quotePath", "false")
    Invoke-Git -Arguments @("config", "--global", "credential.helper", "manager")
    Invoke-Git -Arguments @("config", "--global", "http.postBuffer", "1048576000")
    Invoke-Git -Arguments @("config", "--global", "alias.co", "checkout")
    Invoke-Git -Arguments @("config", "--global", "alias.br", "branch")
    Invoke-Git -Arguments @("config", "--global", "alias.ci", "commit")
    Invoke-Git -Arguments @("config", "--global", "alias.st", "status")
    Invoke-Git -Arguments @("config", "--global", "alias.unstage", "reset HEAD --")
    Invoke-Git -Arguments @("config", "--global", "alias.last", "log -1 HEAD")

    try {
        Invoke-Git -Arguments @("lfs", "install")
    }
    catch {
        Write-Host "[WARN] Git LFS не найден в PATH. Обычно он устанавливается вместе с Git for Windows." -ForegroundColor Yellow
    }

    if ($ConfigureSystem) {
        if (-not (Test-Administrator)) {
            throw "Для настройки --system запустите PowerShell от имени администратора."
        }

        Invoke-Git -Arguments @("config", "--system", "core.longpaths", "true")
        setx LC_ALL C.UTF-8 /M | Out-Null
    }
}

function Ensure-SshKey {
    if (-not $CreateSshKey) {
        return
    }

    $sshKeyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
    $sshPublicKeyPath = "$sshKeyPath.pub"
    $sshDir = Split-Path -Parent $sshKeyPath

    if (Test-Path $sshKeyPath) {
        Write-Host "SSH-ключ уже существует: $sshKeyPath"
    }
    else {
        $sshKeygenPath = Get-SshKeygenPath
        if (-not $sshKeygenPath) {
            throw "ssh-keygen.exe не найден. Проверьте установку Git for Windows."
        }

        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        Write-Host "Создаю SSH-ключ для Git..."
        & $sshKeygenPath -t ed25519 -C $UserEmail -f $sshKeyPath
        if ($LASTEXITCODE -ne 0) {
            throw "ssh-keygen завершился с кодом $LASTEXITCODE."
        }
    }

    Write-Host ""
    Write-Host "Приватный ключ: $sshKeyPath"
    Write-Host "Публичный ключ: $sshPublicKeyPath"
    Write-Host "Приватный ключ никому не передавайте и не коммитьте в репозиторий." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Добавьте публичный ключ в GitLab: профиль > Preferences > SSH Keys."
    Write-Host "Содержимое публичного ключа:"
    Write-Host ""
    Get-Content $sshPublicKeyPath
    Write-Host ""
    Write-Host "После добавления проверьте подключение:"
    Write-Host "  ssh -T git@$GitLabHost"
}

if (-not $SkipInstall) {
    $installed = Install-GitWithWinget
    if (-not $installed) {
        Install-GitWithInstaller
    }
}
else {
    Write-Host "Режим SkipInstall: установка Git пропущена."
}

Set-GitConfig
Ensure-SshKey

Write-Host ""
Write-Host "Git for Windows настроен для групповой разработки." -ForegroundColor Green
Invoke-Git -Arguments @("--version")
