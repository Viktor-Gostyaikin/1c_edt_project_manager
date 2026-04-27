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

if (-not $GitLabHost) {
    Write-Host "GitLabHost не указан в local.vars.ps1 или параметре." -ForegroundColor Red
    exit 1
}

Write-Host "Проверка SSH-подключения к GitLab: $GitLabHost" -ForegroundColor Cyan

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