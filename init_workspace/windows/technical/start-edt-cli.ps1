#Requires -Version 5.1

param(
    [string]$ProjectRepoUrl = "",
    [string]$ProjectCloneDir = "",
    [string]$ProjectRootDir = "",
    [string]$EdtWorkspaceDir = "",
    [string]$EdtPath = ""
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
$EdtPath = Get-InitWorkspaceValue -Variables $variables -Name "EdtPath" -CurrentValue $EdtPath -PreferCurrent:$PSBoundParameters.ContainsKey("EdtPath")

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

    if ([string]::IsNullOrWhiteSpace($script:EdtWorkspaceDir) -and -not [string]::IsNullOrWhiteSpace($script:ProjectRootDir)) {
        $script:EdtWorkspaceDir = $script:ProjectRootDir
    }
}

function Get-EdtApplicationPath {
    param(
        [string]$PreferredPath = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($PreferredPath)) {
        if (Test-Path $PreferredPath -PathType Leaf) {
            return (Resolve-Path $PreferredPath).Path
        }

        foreach ($fileName in @("1cedtstart.exe", "1cedt.exe")) {
            $candidate = Join-Path $PreferredPath $fileName
            if (Test-Path $candidate -PathType Leaf) {
                return (Resolve-Path $candidate).Path
            }

            $eclipseCandidate = Join-Path (Join-Path $PreferredPath "eclipse") $fileName
            if (Test-Path $eclipseCandidate -PathType Leaf) {
                return (Resolve-Path $eclipseCandidate).Path
            }
        }
    }

    foreach ($commandName in @("1cedtstart.exe", "1cedt.exe")) {
        $commandPath = Get-CommandPath $commandName
        if ($commandPath) {
            return $commandPath
        }
    }

    $candidatePaths = @()
    $candidatePaths += @(Get-ChildItem "C:\Program Files\1C\1CE\components\1c-edt-*\1cedtstart.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files\1C\1CE\components\1c-edt-*\1cedt.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files\1C\1CE\components\1c-edt-*\eclipse\1cedt.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files (x86)\1C\1CE\components\1c-edt-*\1cedtstart.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files (x86)\1C\1CE\components\1c-edt-*\1cedt.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files (x86)\1C\1CE\components\1c-edt-*\eclipse\1cedt.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

    return $candidatePaths | Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1
}

Resolve-ProjectPaths

if ([string]::IsNullOrWhiteSpace($EdtWorkspaceDir)) {
    Write-Host "[FAIL] Не задана рабочая область EDT." -ForegroundColor Red
    Write-Host "Заполните EdtWorkspaceDir, ProjectCloneDir или ProjectRootDir в local.vars.ps1."
    exit 1
}

$resolvedEdtPath = Get-EdtApplicationPath -PreferredPath $EdtPath
if (-not $resolvedEdtPath) {
    Write-Host "[FAIL] Приложение 1C:EDT не найдено." -ForegroundColor Red
    Write-Host "Установите 1C:EDT или укажите путь в local.vars.ps1:"
    Write-Host '  EdtPath = "C:\Program Files\1C\1CE\components\1c-edt-2026.1.0\1cedtstart.exe"'
    exit 1
}

if (-not (Test-Path $EdtWorkspaceDir)) {
    New-Item -ItemType Directory -Path $EdtWorkspaceDir -Force | Out-Null
}

Write-Host "Запуск приложения 1C:EDT"
Write-Host "1C:EDT: $resolvedEdtPath"
Write-Host "Рабочая область EDT: $EdtWorkspaceDir"
Write-Host ""
Write-Host "Команда:"
Write-Host "  `"$resolvedEdtPath`" -data `"$EdtWorkspaceDir`""
Write-Host ""

$process = Start-Process -FilePath $resolvedEdtPath -ArgumentList @("-data", "`"$EdtWorkspaceDir`"") -PassThru
Write-Host "[OK] 1C:EDT запущена. PID: $($process.Id)" -ForegroundColor Green
exit 0
