#Requires -Version 5.1

param(
    [string]$GitLabHost = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..\..")).Path
. (Join-Path $ScriptDir "lib\InitWorkspaceVars.ps1")

$variables = Get-InitWorkspaceVariables -ScriptDir $ScriptDir
$GitLabHost = Get-InitWorkspaceValue -Variables $variables -Name "GitLabHost" -CurrentValue $GitLabHost -PreferCurrent:$PSBoundParameters.ContainsKey("GitLabHost")

$GitLabHost = $GitLabHost -replace '^https?://', ''

if (-not $GitLabHost) {
    Write-Host "GitLabHost не указан в local.vars.ps1 или параметре." -ForegroundColor Red
    exit 1
}

Write-Host "Проверка SSH-подключения к GitLab: $GitLabHost" -ForegroundColor Cyan

function Get-SshKeyInfo {
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $defaultKeyNames = @("id_ed25519", "id_rsa", "id_ecdsa", "id_dsa")

    foreach ($keyName in $defaultKeyNames) {
        $privateKeyPath = Join-Path $sshDir $keyName
        $publicKeyPath = "$privateKeyPath.pub"

        if ((Test-Path $privateKeyPath) -or (Test-Path $publicKeyPath)) {
            return [pscustomobject]@{
                PrivateKeyPath = $privateKeyPath
                PublicKeyPath = $publicKeyPath
                HasPrivateKey = Test-Path $privateKeyPath
                HasPublicKey = Test-Path $publicKeyPath
            }
        }
    }

    if (Test-Path $sshDir) {
        $publicKey = Get-ChildItem -Path $sshDir -Filter "*.pub" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($publicKey) {
            $privateKeyPath = $publicKey.FullName -replace '\.pub$', ''
            return [pscustomobject]@{
                PrivateKeyPath = $privateKeyPath
                PublicKeyPath = $publicKey.FullName
                HasPrivateKey = Test-Path $privateKeyPath
                HasPublicKey = $true
            }
        }
    }

    return $null
}

function Write-SshKeyInstructions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [string]$PrivateKeyPath = ""
    )

    if (-not $PrivateKeyPath) {
        $PrivateKeyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
    }

    Write-Host "[WARN] SSH-ключ для GitLab не найден." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Создайте SSH-ключ:"
    Write-Host "  ssh-keygen -t ed25519 -C ""you@example.com"" -f ""$PrivateKeyPath"""
    Write-Host ""
    Write-Host "Затем выведите публичный ключ:"
    Write-Host "  type ""$PrivateKeyPath.pub"""
    Write-Host ""
    Write-Host "Добавьте содержимое .pub-файла в GitLab: Preferences > SSH Keys."
    Write-Host "После добавления проверьте подключение:"
    Write-Host "  ssh -T git@$HostName"
}

function Write-PermissionDeniedInstructions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [string]$PublicKeyPath = ""
    )

    Write-Host ""
    Write-Host "[HINT] GitLab отклонил SSH-ключ." -ForegroundColor Yellow
    Write-Host "Проверьте, что публичный ключ добавлен в профиль GitLab:"
    Write-Host "  https://$HostName/-/user_settings/ssh_keys"

    Write-Host ""
    Write-Host "[HINT] Подробная инструкция по настройке SSH для GitLab:" -ForegroundColor Yellow
    Write-Host "  https://archives.docs.gitlab.com/17.7/ee/user/ssh/"

    if ($PublicKeyPath) {
        Write-Host ""
        Write-Host "[HINT] Публичный ключ можно вывести командой:" -ForegroundColor Yellow
        Write-Host "  type ""$PublicKeyPath"""
    }

    Write-Host ""
    Write-Host "[HINT] После проверки ключа повторите команду:" -ForegroundColor Yellow
    Write-Host "  ssh -T git@$HostName"
}

$sshKeyInfo = Get-SshKeyInfo
if (-not $sshKeyInfo) {
    Write-SshKeyInstructions -HostName $GitLabHost
    exit 1
}

if (-not $sshKeyInfo.HasPrivateKey) {
    Write-Host "[WARN] Найден публичный SSH-ключ, но не найден приватный ключ: $($sshKeyInfo.PrivateKeyPath)" -ForegroundColor Yellow
    Write-Host "Без приватного ключа SSH-подключение к GitLab не сработает." -ForegroundColor Yellow
    Write-SshKeyInstructions -HostName $GitLabHost -PrivateKeyPath $sshKeyInfo.PrivateKeyPath
    exit 1
}

if (-not $sshKeyInfo.HasPublicKey) {
    Write-Host "[WARN] Найден приватный SSH-ключ, но не найден публичный ключ: $($sshKeyInfo.PublicKeyPath)" -ForegroundColor Yellow
    Write-Host "Создайте публичный ключ из приватного:" -ForegroundColor Yellow
    Write-Host "  ssh-keygen -y -f ""$($sshKeyInfo.PrivateKeyPath)"" > ""$($sshKeyInfo.PublicKeyPath)"""
    Write-Host "Затем добавьте содержимое .pub-файла в GitLab: Preferences > SSH Keys."
    exit 1
}

Write-Host "SSH-ключ найден: $($sshKeyInfo.PrivateKeyPath)" -ForegroundColor Green

# Добавляем хост-ключ в known_hosts, если его нет
$knownHostsPath = "$env:USERPROFILE\.ssh\known_hosts"
if (-not (Test-Path $knownHostsPath)) {
    New-Item -ItemType File -Path $knownHostsPath -Force | Out-Null
}

$existingKey = Get-Content $knownHostsPath | Where-Object { $_ -match "^$GitLabHost " }
if (-not $existingKey) {
    Write-Host "Добавляю хост-ключ для $GitLabHost в known_hosts..."
    try {
        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $keyScan = & ssh-keyscan -H $GitLabHost 2>$null
            $keyScanExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $oldErrorActionPreference
        }

        if ($keyScanExitCode -eq 0 -and $keyScan) {
            Add-Content -Path $knownHostsPath -Value $keyScan
            Write-Host "Хост-ключ добавлен." -ForegroundColor Green
        }
        else {
            Write-Host "[WARN] Не удалось получить хост-ключ для $GitLabHost. Проверьте подключение к сети." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[WARN] Ошибка при сканировании ключа: $($_.Exception.Message). Проверьте подключение к сети." -ForegroundColor Yellow
    }
}

try {
    $result = & ssh -T -o BatchMode=yes -o ConnectTimeout=10 git@$GitLabHost "echo 'SSH connection successful'" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] SSH-подключение к $GitLabHost успешно." -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "[FAIL] SSH-подключение к $GitLabHost не удалось: $result" -ForegroundColor Red

        if (($result | Out-String) -match "Permission denied") {
            Write-PermissionDeniedInstructions -HostName $GitLabHost -PublicKeyPath $sshKeyInfo.PublicKeyPath
        }

        exit 1
    }
}
catch {
    Write-Host "[FAIL] Ошибка при проверке SSH: $($_.Exception.Message)" -ForegroundColor Red

    if (($($_.Exception.Message) | Out-String) -match "Permission denied") {
            Write-PermissionDeniedInstructions -HostName $GitLabHost -PublicKeyPath $sshKeyInfo.PublicKeyPath
        }

    exit 1
}
