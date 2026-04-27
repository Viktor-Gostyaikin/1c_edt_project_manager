#Requires -Version 5.1

param(
    [string]$Version = "8.5.1.1302",
    [string]$OneCUser = "",
    [object]$OneCPassword = $null,
    [string]$DownloadDir = "",
    [string]$ExtractDir = "",
    [string]$ReleasePageUrl = "",
    [string[]]$DistributionFilters = @("Технологическая платформа 1С:Предприятия \(64-bit\) для Windows$"),
    [string[]]$InstallerArguments = @("/S", "USEHWLICENSES=0"),
    [switch]$DownloadOnly,
    [switch]$ForceDownload,
    [switch]$ForceExtract,
    [switch]$SkipDependencyCheck
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..\..")).Path
. (Join-Path $ScriptDir "lib\InitWorkspaceVars.ps1")
. (Join-Path $ScriptDir "lib\OneCReleases.ps1")

$variables = Get-InitWorkspaceVariables -ScriptDir $ScriptDir
$Version = Get-InitWorkspaceValue -Variables $variables -Name "PlatformVersion" -CurrentValue $Version -PreferCurrent:$PSBoundParameters.ContainsKey("Version")
$OneCUser = Get-InitWorkspaceValue -Variables $variables -Name "OneCUser" -CurrentValue $OneCUser -PreferCurrent:$PSBoundParameters.ContainsKey("OneCUser")
$OneCPassword = Get-InitWorkspaceValue -Variables $variables -Name "OneCPassword" -CurrentValue $OneCPassword -PreferCurrent:$PSBoundParameters.ContainsKey("OneCPassword")
$DownloadDir = Get-InitWorkspaceValue -Variables $variables -Name "PlatformDownloadDir" -CurrentValue $DownloadDir -PreferCurrent:$PSBoundParameters.ContainsKey("DownloadDir")
$ExtractDir = Get-InitWorkspaceValue -Variables $variables -Name "PlatformExtractDir" -CurrentValue $ExtractDir -PreferCurrent:$PSBoundParameters.ContainsKey("ExtractDir")
$ReleasePageUrl = Get-InitWorkspaceValue -Variables $variables -Name "PlatformReleasePageUrl" -CurrentValue $ReleasePageUrl -PreferCurrent:$PSBoundParameters.ContainsKey("ReleasePageUrl")

if (-not $DownloadDir) {
    $DownloadDir = Join-Path $RepoRoot "build\downloads\platform\$Version"
}

if (-not $ExtractDir) {
    $ExtractDir = Join-Path $RepoRoot "build\installers\platform\$Version"
}

if (-not $ReleasePageUrl) {
    $ReleasePageUrl = "https://releases.1c.ru/version_files?nick=Platform85&ver=$Version"
}

function Find-PlatformInstaller {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchDir,

        [Parameter(Mandatory = $true)]
        [string]$DownloadedFile
    )

    if ([System.IO.Path]::GetExtension($DownloadedFile) -ieq ".exe") {
        return $DownloadedFile
    }

    $patterns = @("setup.exe", "setup-full-*.exe", "*.msi")
    foreach ($pattern in $patterns) {
        $file = Get-ChildItem -Path $SearchDir -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($file) {
            return $file.FullName
        }
    }

    throw "Не найден установщик платформы в каталоге: $SearchDir"
}

function Install-Platform {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath,

        [string[]]$Arguments = @()
    )

    Assert-Administrator

    Write-Host "Запускаю установку платформы: $InstallerPath"
    Write-Host "Аргументы: $($Arguments -join ' ')"
    Write-Host "Ожидаемый состав проекта: платформа 1С, сервер 1С, русский интерфейс."
    Write-Host "После установки будет выполнена проверка зависимостей."

    $process = Start-Process `
        -FilePath $InstallerPath `
        -ArgumentList $Arguments `
        -Wait `
        -PassThru

    if ($process.ExitCode -ne 0) {
        throw "Установщик платформы завершился с кодом $($process.ExitCode)."
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

$installerPath = Find-PlatformInstaller -SearchDir $installerRoot -DownloadedFile $distribution.File
Install-Platform -InstallerPath $installerPath -Arguments $InstallerArguments

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

Write-Host "Установка платформы завершена." -ForegroundColor Green
