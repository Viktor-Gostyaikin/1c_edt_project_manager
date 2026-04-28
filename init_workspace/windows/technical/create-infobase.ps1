#Requires -Version 5.1

param(
    [string]$ProjectRepoUrl = "",
    [string]$ProjectCloneDir = "",
    [string]$ProjectRootDir = "",
    [string]$InfoBasePath = "",
    [string]$InfoBaseListName = "",
    [string]$V8Path = "",
    [switch]$AddToList
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib\InitWorkspaceVars.ps1")

$variables = Get-InitWorkspaceVariables -ScriptDir $ScriptDir
$ProjectRepoUrl = Get-InitWorkspaceValue -Variables $variables -Name "ProjectRepoUrl" -CurrentValue $ProjectRepoUrl -PreferCurrent:$PSBoundParameters.ContainsKey("ProjectRepoUrl")
$ProjectCloneDir = Get-InitWorkspaceValue -Variables $variables -Name "ProjectCloneDir" -CurrentValue $ProjectCloneDir -PreferCurrent:$PSBoundParameters.ContainsKey("ProjectCloneDir")
$ProjectRootDir = Get-InitWorkspaceValue -Variables $variables -Name "ProjectRootDir" -CurrentValue $ProjectRootDir -PreferCurrent:$PSBoundParameters.ContainsKey("ProjectRootDir")
$InfoBasePath = Get-InitWorkspaceValue -Variables $variables -Name "InfoBasePath" -CurrentValue $InfoBasePath -PreferCurrent:$PSBoundParameters.ContainsKey("InfoBasePath")
$InfoBaseListName = Get-InitWorkspaceValue -Variables $variables -Name "InfoBaseListName" -CurrentValue $InfoBaseListName -PreferCurrent:$PSBoundParameters.ContainsKey("InfoBaseListName")
$V8Path = Get-InitWorkspaceValue -Variables $variables -Name "V8Path" -CurrentValue $V8Path -PreferCurrent:$PSBoundParameters.ContainsKey("V8Path")

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

    if ([string]::IsNullOrWhiteSpace($script:InfoBasePath) -and -not [string]::IsNullOrWhiteSpace($script:ProjectRootDir)) {
        $script:InfoBasePath = Join-Path $script:ProjectRootDir "build\ib"
    }

    if ([string]::IsNullOrWhiteSpace($script:InfoBaseListName) -and -not [string]::IsNullOrWhiteSpace($script:ProjectRootDir)) {
        $projectName = Split-Path -Path $script:ProjectRootDir -Leaf
        if ([string]::IsNullOrWhiteSpace($projectName)) {
            $projectName = "edt project"
        }

        $script:InfoBaseListName = $projectName
    }
}

function Get-V8ClientPath {
    param(
        [string]$PreferredPath = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($PreferredPath)) {
        if (Test-Path $PreferredPath -PathType Leaf) {
            return (Resolve-Path $PreferredPath).Path
        }

        $candidate = Join-Path $PreferredPath "1cv8.exe"
        if (Test-Path $candidate -PathType Leaf) {
            return (Resolve-Path $candidate).Path
        }
    }

    $commandPath = Get-CommandPath "1cv8.exe"
    if ($commandPath) {
        return $commandPath
    }

    $candidatePaths = @()
    $candidatePaths += @(Get-ChildItem "C:\Program Files\1cv8\*\bin\1cv8.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files (x86)\1cv8\*\bin\1cv8.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

    return $candidatePaths | Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1
}

Resolve-ProjectPaths

if ([string]::IsNullOrWhiteSpace($ProjectRootDir)) {
    Write-Host "[FAIL] Не задан каталог проекта." -ForegroundColor Red
    Write-Host "Заполните ProjectCloneDir или ProjectRootDir в local.vars.ps1."
    exit 1
}

if (-not (Test-Path $ProjectRootDir)) {
    Write-Host "[FAIL] Каталог проекта не найден: $ProjectRootDir" -ForegroundColor Red
    Write-Host "Сначала выполните команду commands\clone-project.cmd."
    exit 1
}

$resolvedV8Path = Get-V8ClientPath -PreferredPath $V8Path
if (-not $resolvedV8Path) {
    Write-Host "[FAIL] 1cv8.exe не найден." -ForegroundColor Red
    Write-Host "Установите платформу 1С или укажите путь в local.vars.ps1:"
    Write-Host '  V8Path = "C:\Program Files\1cv8\8.5.1.1302\bin\1cv8.exe"'
    exit 1
}

$infoBaseFile = Join-Path $InfoBasePath "1Cv8.1CD"
if (Test-Path $infoBaseFile) {
    Write-Host "[OK] Информационная база уже существует: $InfoBasePath" -ForegroundColor Green
    exit 0
}

if (Test-Path $InfoBasePath) {
    $existingItems = Get-ChildItem -Path $InfoBasePath -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existingItems) {
        Write-Host "[FAIL] Каталог ИБ существует, но не содержит файловую базу 1С: $InfoBasePath" -ForegroundColor Red
        Write-Host "Выберите другой InfoBasePath или очистите каталог вручную."
        exit 1
    }
}
else {
    New-Item -ItemType Directory -Path $InfoBasePath -Force | Out-Null
}

$connectionString = "File=`"$InfoBasePath`";"
$createArguments = @("CREATEINFOBASE", $connectionString)
if ($AddToList) {
    $createArguments += @("/AddInList", $InfoBaseListName)
}

Write-Host "Создание файловой информационной базы 1С"
Write-Host "1cv8.exe: $resolvedV8Path"
Write-Host "Каталог проекта: $ProjectRootDir"
Write-Host "Каталог ИБ: $InfoBasePath"
Write-Host ""
Write-Host "Команда:"
if ($AddToList) {
    Write-Host "  1cv8.exe CREATEINFOBASE File=`"$InfoBasePath`"; /AddInList `"$InfoBaseListName`""
}
else {
    Write-Host "  1cv8.exe CREATEINFOBASE File=`"$InfoBasePath`";"
}
Write-Host ""

& $resolvedV8Path @createArguments
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Создание информационной базы завершилось с ошибкой. Код: $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "[OK] Информационная база создана: $InfoBasePath" -ForegroundColor Green
