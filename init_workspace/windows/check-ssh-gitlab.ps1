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

# Добавляем хост-ключ в known_hosts, если его нет
$knownHostsPath = "$env:USERPROFILE\.ssh\known_hosts"
if (-not (Test-Path $knownHostsPath)) {
    New-Item -ItemType File -Path $knownHostsPath -Force | Out-Null
}

$existingKey = Get-Content $knownHostsPath | Where-Object { $_ -match "^$GitLabHost " }
if (-not $existingKey) {
    Write-Host "Добавляю хост-ключ для $GitLabHost в known_hosts..."
    try {
        $keyScan = & ssh-keyscan -H $GitLabHost
        if ($LASTEXITCODE -eq 0 -and $keyScan) {
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
        exit 1
    }
}
catch {
    Write-Host "[FAIL] Ошибка при проверке SSH: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}