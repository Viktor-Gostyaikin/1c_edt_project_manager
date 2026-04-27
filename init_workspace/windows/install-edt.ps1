#Requires -Version 5.1

param(
    [string]$Version = "2026.1.0",
    [string]$OneCUser = "",
    [object]$OneCPassword = $null,
    [string]$DownloadDir = "",
    [string]$ExtractDir = "",
    [string]$ReleasePageUrl = "",
    [string[]]$DistributionFilters = @(
        "Дистрибутив для оффлайн установки 1C:EDT для ОС Windows 64 бит$",
        "Дистрибутив 1C:EDT для ОС Windows для установки без интернета$",
        "Дистрибутив 1C:EDT для ОС Windows 64 бит$"
    ),
    [string[]]$InstallerArguments = @("install"),
    [switch]$DownloadOnly,
    [switch]$ForceDownload,
    [switch]$ForceExtract,
    [switch]$SkipDependencyCheck
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..\..")).Path
. (Join-Path $ScriptDir "lib\OneCReleases.ps1")

if (-not $DownloadDir) {
    $DownloadDir = Join-Path $RepoRoot "build\downloads\edt\$Version"
}

if (-not $ExtractDir) {
    $ExtractDir = Join-Path $RepoRoot "build\installers\edt\$Version"
}

if (-not $ReleasePageUrl) {
    $ReleasePageUrl = "https://releases.1c.ru/version_files?nick=DevelopmentTools10&ver=$Version"
}

function Find-EdtInstaller {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchDir,

        [Parameter(Mandatory = $true)]
        [string]$DownloadedFile
    )

    $cli = Get-ChildItem -Path $SearchDir -Filter "1ce-installer-cli.exe" -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($cli) {
        return [pscustomobject]@{
            Path = $cli.FullName
            Type = "Cli"
        }
    }

    $gui = Get-ChildItem -Path $SearchDir -Filter "1ce-installer.exe" -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($gui) {
        return [pscustomobject]@{
            Path = $gui.FullName
            Type = "Gui"
        }
    }

    if ([System.IO.Path]::GetExtension($DownloadedFile) -ieq ".exe") {
        return [pscustomobject]@{
            Path = $DownloadedFile
            Type = "Exe"
        }
    }

    throw "Не найден установщик EDT в каталоге: $SearchDir"
}

function Install-Edt {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Installer,

        [string[]]$Arguments = @()
    )

    Assert-Administrator

    Write-Host "Запускаю установку EDT: $($Installer.Path)"

    if ($Installer.Type -eq "Cli") {
        Write-Host "Консольный установщик EDT, аргументы: $($Arguments -join ' ')"
        $process = Start-Process `
            -FilePath $Installer.Path `
            -ArgumentList $Arguments `
            -WorkingDirectory (Split-Path -Parent $Installer.Path) `
            -Wait `
            -PassThru
    }
    else {
        Write-Host "Консольный установщик не найден, запускаю доступный установщик в интерактивном режиме."
        $process = Start-Process `
            -FilePath $Installer.Path `
            -WorkingDirectory (Split-Path -Parent $Installer.Path) `
            -Wait `
            -PassThru
    }

    if ($process.ExitCode -ne 0) {
        throw "Установщик EDT завершился с кодом $($process.ExitCode)."
    }
}

$credential = Get-OneCCredential -User $OneCUser -Password $OneCPassword

$distribution = Save-OneCDistribution `
    -ReleasePageUrl $ReleasePageUrl `
    -DistributionFilters $DistributionFilters `
    -DestinationDir $DownloadDir `
    -User $credential.User `
    -Password $credential.Password `
    -Force:$ForceDownload

Write-Host "Скачанный дистрибутив: $($distribution.File)"

if ($DownloadOnly) {
    Write-Host "Режим DownloadOnly: установка не запускается."
    exit 0
}

$installerRoot = Expand-OneCArchive `
    -ArchivePath $distribution.File `
    -DestinationDir $ExtractDir `
    -Force:$ForceExtract

$installer = Find-EdtInstaller -SearchDir $installerRoot -DownloadedFile $distribution.File
Install-Edt -Installer $installer -Arguments $InstallerArguments

if (-not $SkipDependencyCheck) {
    $checkScript = Join-Path $ScriptDir "check-quickstart-deps.cmd"
    if (Test-Path $checkScript) {
        Write-Host "Запускаю проверку зависимостей..."
        $env:NO_PAUSE = "1"
        & $checkScript
        if ($LASTEXITCODE -ne 0) {
            throw "Проверка зависимостей завершилась с ошибкой."
        }
    }
}

Write-Host "Установка EDT завершена." -ForegroundColor Green
