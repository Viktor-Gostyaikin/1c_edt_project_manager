#Requires -Version 5.1

param(
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

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

function Get-ExistingPath {
    param(
        [string[]]$Paths = @()
    )

    foreach ($path in $Paths) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path $path)) {
            return $path
        }
    }

    return ""
}

function Get-SevenZipPath {
    foreach ($commandName in @("7z.exe", "7za.exe")) {
        $commandPath = Get-CommandPath $commandName
        if ($commandPath) {
            return $commandPath
        }
    }

    $programFiles = [Environment]::GetFolderPath("ProgramFiles")
    $programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")

    $candidatePaths = @()
    if (-not [string]::IsNullOrWhiteSpace($programFiles)) {
        $candidatePaths += (Join-Path $programFiles "7-Zip\7z.exe")
    }

    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $candidatePaths += (Join-Path $programFilesX86 "7-Zip\7z.exe")
    }

    return Get-ExistingPath -Paths $candidatePaths
}

function Install-SevenZipWithWinget {
    $wingetPath = Get-CommandPath "winget.exe"
    if (-not $wingetPath) {
        throw "winget.exe не найден. ”становите 7-Zip вручную с https://www.7-zip.org/ или установите App Installer из Microsoft Store."
    }

    Write-Host "”станавливаю 7-Zip через winget..."
    & $wingetPath install `
        --id 7zip.7zip `
        --exact `
        --source winget `
        --accept-source-agreements `
        --accept-package-agreements | Out-Host

    if ($LASTEXITCODE -ne 0) {
        throw "winget не смог установить 7-Zip.  од завершени€: $LASTEXITCODE"
    }
}

$sevenZipPath = Get-SevenZipPath
if ($sevenZipPath) {
    Write-Host "7-Zip уже установлен: $sevenZipPath" -ForegroundColor Green
    exit 0
}

if ($SkipInstall) {
    throw "7-Zip не найден."
}

Install-SevenZipWithWinget

$sevenZipPath = Get-SevenZipPath
if (-not $sevenZipPath) {
    throw "7-Zip установлен, но 7z.exe пока не найден. ѕерезапустите терминал или проверьте каталог C:\Program Files\7-Zip."
}

Write-Host "7-Zip установлен: $sevenZipPath" -ForegroundColor Green
