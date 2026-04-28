#Requires -Version 5.1

param(
    [string]$OutputPath = "",
    [switch]$InstallPs2Exe
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceScript = Join-Path $ScriptDir "check-quickstart-deps.ps1"

if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path -Parent $ScriptDir) "commands\check-quickstart-deps.exe"
}

if (-not (Test-Path $SourceScript)) {
    throw "Не найден исходный скрипт: $SourceScript"
}

function Get-Ps2ExeCommand {
    $command = Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command
    }

    $module = Get-Module -ListAvailable -Name ps2exe | Select-Object -First 1
    if ($module) {
        Import-Module ps2exe
        return Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue
    }

    return $null
}

$ps2exe = Get-Ps2ExeCommand

if (-not $ps2exe -and $InstallPs2Exe) {
    Write-Host "PS2EXE не найден. Устанавливаю модуль ps2exe для текущего пользователя..." -ForegroundColor Yellow
    Install-Module ps2exe -Scope CurrentUser -Force
    $ps2exe = Get-Ps2ExeCommand
}

if (-not $ps2exe) {
    Write-Host "Не найден модуль PS2EXE." -ForegroundColor Red
    Write-Host ""
    Write-Host "Установите его один раз:" -ForegroundColor Yellow
    Write-Host "  Install-Module ps2exe -Scope CurrentUser"
    Write-Host ""
    Write-Host "Или запустите сборку с автоматической установкой:" -ForegroundColor Yellow
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\build-check-quickstart-deps-exe.ps1 -InstallPs2Exe"
    exit 1
}

Invoke-ps2exe `
    -inputFile $SourceScript `
    -outputFile $OutputPath `
    -title "ITW MIS Quickstart Dependency Check" `
    -description "Проверка зависимостей быстрого старта проекта ITW MIS" `
    -company "ITWorks" `
    -product "ITW MIS" `
    -version "1.0.0.0" `
    -noConsole:$false `
    -requireAdmin:$false

Write-Host "Готово: $OutputPath" -ForegroundColor Green
