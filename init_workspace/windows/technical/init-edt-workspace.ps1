#Requires -Version 5.1

param(
    [string]$ProjectRepoUrl = "",
    [string]$ProjectCloneDir = "",
    [string]$ProjectRootDir = "",
    [string]$EdtWorkspaceDir = "",
    [string]$EdtCliPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib\InitWorkspaceVars.ps1")

$variables = Get-InitWorkspaceVariables -ScriptDir $ScriptDir
$ProjectRepoUrl = Get-InitWorkspaceValue -Variables $variables -Name "ProjectRepoUrl" -CurrentValue $ProjectRepoUrl -PreferCurrent:$PSBoundParameters.ContainsKey("ProjectRepoUrl")
$ProjectCloneDir = Get-InitWorkspaceValue -Variables $variables -Name "ProjectCloneDir" -CurrentValue $ProjectCloneDir -PreferCurrent:$PSBoundParameters.ContainsKey("ProjectCloneDir")
$ProjectRootDir = Get-InitWorkspaceValue -Variables $variables -Name "ProjectRootDir" -CurrentValue $ProjectRootDir -PreferCurrent:$PSBoundParameters.ContainsKey("ProjectRootDir")
$EdtWorkspaceDir = Get-InitWorkspaceValue -Variables $variables -Name "EdtWorkspaceDir" -CurrentValue $EdtWorkspaceDir -PreferCurrent:$PSBoundParameters.ContainsKey("EdtWorkspaceDir")
$EdtCliPath = Get-InitWorkspaceValue -Variables $variables -Name "EdtCliPath" -CurrentValue $EdtCliPath -PreferCurrent:$PSBoundParameters.ContainsKey("EdtCliPath")

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

function Get-DefaultCloneDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoUrl
    )

    $repoName = $RepoUrl.TrimEnd("/")
    $repoName = ($repoName -split "[/:\\]")[-1]
    $repoName = $repoName -replace "\.git$", ""

    if ([string]::IsNullOrWhiteSpace($repoName)) {
        $repoName = "project"
    }

    return Join-Path (Join-Path $env:USERPROFILE "source") $repoName
}

function Resolve-ProjectPaths {
    if ([string]::IsNullOrWhiteSpace($script:ProjectCloneDir)) {
        if (-not [string]::IsNullOrWhiteSpace($script:ProjectRootDir)) {
            $script:ProjectCloneDir = $script:ProjectRootDir
        }
        elseif (-not [string]::IsNullOrWhiteSpace($script:ProjectRepoUrl)) {
            $script:ProjectCloneDir = Get-DefaultCloneDir -RepoUrl $script:ProjectRepoUrl
        }
    }

    if ([string]::IsNullOrWhiteSpace($script:ProjectRootDir)) {
        $script:ProjectRootDir = $script:ProjectCloneDir
    }

    if ([string]::IsNullOrWhiteSpace($script:EdtWorkspaceDir)) {
        $script:EdtWorkspaceDir = $script:ProjectCloneDir
    }
}

function Test-GitRepository {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Test-Path (Join-Path $Path ".git"))
}

function Get-EdtCliPath {
    param(
        [string]$PreferredPath = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($PreferredPath) -and (Test-Path $PreferredPath)) {
        return (Resolve-Path $PreferredPath).Path
    }

    foreach ($commandName in @("1cedtcli.exe", "1cedtcli.cmd", "1cedtcli.bat", "1cedtcli")) {
        $commandPath = Get-CommandPath $commandName
        if ($commandPath) {
            return $commandPath
        }
    }

    $candidatePaths = @()
    $candidatePaths += @(Get-ChildItem "C:\Program Files\1C\1CE\components\1c-edt-*\1cedtcli.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files\1C\1CE\components\1c-edt-*\eclipse\1cedtcli.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files (x86)\1C\1CE\components\1c-edt-*\1cedtcli.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files (x86)\1C\1CE\components\1c-edt-*\eclipse\1cedtcli.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

    return $candidatePaths | Where-Object { $_ } | Select-Object -First 1
}

function Format-Duration {
    param(
        [Parameter(Mandatory = $true)]
        [TimeSpan]$Duration
    )

    if ($Duration.TotalHours -ge 1) {
        return "{0:00}:{1:00}:{2:00}" -f [int]$Duration.TotalHours, $Duration.Minutes, $Duration.Seconds
    }

    return "{0:00}:{1:00}" -f [int]$Duration.TotalMinutes, $Duration.Seconds
}

Resolve-ProjectPaths

if ([string]::IsNullOrWhiteSpace($ProjectCloneDir)) {
    Write-Host "[FAIL] Не задан каталог проекта." -ForegroundColor Red
    Write-Host "Заполните ProjectCloneDir или ProjectRootDir в local.vars.ps1."
    exit 1
}

if (-not (Test-GitRepository -Path $ProjectCloneDir)) {
    Write-Host "[FAIL] Репозиторий проекта не найден: $ProjectCloneDir" -ForegroundColor Red
    Write-Host "Сначала выполните команду commands\clone-project.cmd."
    exit 1
}

if (-not (Test-Path $ProjectRootDir)) {
    Write-Host "[FAIL] Каталог проекта EDT не найден: $ProjectRootDir" -ForegroundColor Red
    exit 1
}

$resolvedEdtCliPath = Get-EdtCliPath -PreferredPath $EdtCliPath
if (-not $resolvedEdtCliPath) {
    Write-Host "[FAIL] 1cedtcli не найден." -ForegroundColor Red
    Write-Host "Установите 1C:EDT или укажите путь в local.vars.ps1:"
    Write-Host '  EdtCliPath = "C:\Program Files\1C\1CE\components\1c-edt-2026.1.0\1cedtcli.exe"'
    exit 1
}

if (-not (Test-Path $EdtWorkspaceDir)) {
    New-Item -ItemType Directory -Path $EdtWorkspaceDir -Force | Out-Null
}

Write-Host "Инициализация рабочей области 1C:EDT"
Write-Host "1cedtcli: $resolvedEdtCliPath"
Write-Host "Рабочая область EDT: $EdtWorkspaceDir"
Write-Host "Проект EDT: $ProjectRootDir"
Write-Host ""
Write-Host "Команда:"
Write-Host "  1cedtcli -data `"$EdtWorkspaceDir`" -command import --project `"$ProjectRootDir`""
Write-Host ""

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& $resolvedEdtCliPath -data $EdtWorkspaceDir -command import --project $ProjectRootDir
$stopwatch.Stop()

if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Импорт проекта в рабочую область EDT завершился с ошибкой. Код: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Время выполнения: $(Format-Duration -Duration $stopwatch.Elapsed)"
    exit $LASTEXITCODE
}

Write-Host "[OK] Рабочая область EDT инициализирована." -ForegroundColor Green
Write-Host "Время выполнения: $(Format-Duration -Duration $stopwatch.Elapsed)"
