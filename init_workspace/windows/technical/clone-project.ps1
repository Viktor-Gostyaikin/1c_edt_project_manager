#Requires -Version 5.1

param(
    [string]$ProjectRepoUrl = "",
    [string]$ProjectCloneDir = "",
    [string]$ProjectRootDir = "",
    [string]$EdtWorkspaceDir = "",
    [string]$ProjectBranch = "",
    [switch]$OpenAfterClone
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
$ProjectBranch = Get-InitWorkspaceValue -Variables $variables -Name "ProjectBranch" -CurrentValue $ProjectBranch -PreferCurrent:$PSBoundParameters.ContainsKey("ProjectBranch")

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

function Test-GitRepository {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    $gitDir = Join-Path $Path ".git"
    return Test-Path $gitDir
}

if ([string]::IsNullOrWhiteSpace($ProjectRepoUrl)) {
    Write-Host "[FAIL] ProjectRepoUrl не задан." -ForegroundColor Red
    Write-Host ""
    Write-Host "Укажите URL репозитория в local.vars.ps1, например:"
    Write-Host '  ProjectRepoUrl = "git@gitlab.corp.itworks.group:group/project.git"'
    Write-Host '  ProjectCloneDir = "C:\src\project"'
    exit 1
}

if ([string]::IsNullOrWhiteSpace($ProjectCloneDir)) {
    if (-not [string]::IsNullOrWhiteSpace($ProjectRootDir)) {
        $ProjectCloneDir = $ProjectRootDir
    }
    else {
        $ProjectCloneDir = Get-DefaultCloneDir -RepoUrl $ProjectRepoUrl
    }
}

if ([string]::IsNullOrWhiteSpace($ProjectRootDir)) {
    $ProjectRootDir = $ProjectCloneDir
}

if ([string]::IsNullOrWhiteSpace($EdtWorkspaceDir)) {
    $EdtWorkspaceDir = Join-Path $ProjectRootDir ".metadata"
}

$gitPath = Get-CommandPath "git.exe"
if (-not $gitPath) {
    Write-Host "[FAIL] git.exe не найден в PATH. Сначала установите Git for Windows." -ForegroundColor Red
    exit 1
}

Write-Host "Проверка репозитория проекта"
Write-Host "URL: $ProjectRepoUrl"
Write-Host "Каталог репозитория: $ProjectCloneDir"
Write-Host "Каталог проекта: $ProjectRootDir"
Write-Host "Рабочая область EDT: $EdtWorkspaceDir"

if (Test-GitRepository -Path $ProjectCloneDir) {
    Write-Host "[OK] Репозиторий уже найден: $ProjectCloneDir" -ForegroundColor Green

    $origin = (& $gitPath -C $ProjectCloneDir remote get-url origin) 2>$null
    if ($LASTEXITCODE -eq 0 -and $origin) {
        Write-Host "origin: $origin"
    }

    if ($OpenAfterClone) {
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$ProjectCloneDir`""
    }

    if (-not (Test-Path $EdtWorkspaceDir)) {
        New-Item -ItemType Directory -Path $EdtWorkspaceDir -Force | Out-Null
        Write-Host "[OK] Рабочая область EDT создана: $EdtWorkspaceDir" -ForegroundColor Green
    }
    else {
        Write-Host "[OK] Рабочая область EDT найдена: $EdtWorkspaceDir" -ForegroundColor Green
    }

    exit 0
}

if (Test-Path $ProjectCloneDir) {
    $existingItems = Get-ChildItem -Path $ProjectCloneDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existingItems) {
        Write-Host "[FAIL] Каталог существует, но это не Git-репозиторий: $ProjectCloneDir" -ForegroundColor Red
        Write-Host "Выберите другой ProjectCloneDir или очистите каталог вручную."
        exit 1
    }
}

$parentDir = Split-Path -Parent $ProjectCloneDir
if (-not (Test-Path $parentDir)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

$cloneArguments = @("clone")
if (-not [string]::IsNullOrWhiteSpace($ProjectBranch)) {
    $cloneArguments += @("--branch", $ProjectBranch)
}
$cloneArguments += @($ProjectRepoUrl, $ProjectCloneDir)

Write-Host "Репозиторий не найден. Выполняю клонирование..."
& $gitPath @cloneArguments
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Клонирование завершилось с ошибкой. Код: $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "[OK] Репозиторий склонирован: $ProjectCloneDir" -ForegroundColor Green

if (-not (Test-Path $EdtWorkspaceDir)) {
    New-Item -ItemType Directory -Path $EdtWorkspaceDir -Force | Out-Null
    Write-Host "[OK] Рабочая область EDT создана: $EdtWorkspaceDir" -ForegroundColor Green
}
else {
    Write-Host "[OK] Рабочая область EDT найдена: $EdtWorkspaceDir" -ForegroundColor Green
}

if ($OpenAfterClone) {
    Start-Process -FilePath "explorer.exe" -ArgumentList "`"$ProjectCloneDir`""
}
