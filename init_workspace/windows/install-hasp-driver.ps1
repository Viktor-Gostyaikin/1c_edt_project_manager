#Requires -Version 5.1

param(
    [string]$Version = "7.63",
    [string]$OneCUser = "",
    [object]$OneCPassword = $null,
    [string]$DownloadDir = "",
    [string]$ExtractDir = "",
    [string]$ReleasePageUrl = "",
    [string[]]$DistributionFilters = @("sentinel_ldk_run_time_gui.zip"),
    [string[]]$InstallerArguments = @("/S"),
    [switch]$DownloadOnly,
    [switch]$ForceDownload,
    [switch]$ForceExtract
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..\..")).Path
. (Join-Path $ScriptDir "lib\InitWorkspaceVars.ps1")
. (Join-Path $ScriptDir "lib\OneCReleases.ps1")

$variables = Get-InitWorkspaceVariables -ScriptDir $ScriptDir
$Version = Get-InitWorkspaceValue -Variables $variables -Name "HaspDriverVersion" -CurrentValue $Version -PreferCurrent:$PSBoundParameters.ContainsKey("Version")
$OneCUser = Get-InitWorkspaceValue -Variables $variables -Name "OneCUser" -CurrentValue $OneCUser -PreferCurrent:$PSBoundParameters.ContainsKey("OneCUser")
$OneCPassword = Get-InitWorkspaceValue -Variables $variables -Name "OneCPassword" -CurrentValue $OneCPassword -PreferCurrent:$PSBoundParameters.ContainsKey("OneCPassword")
$DownloadDir = Get-InitWorkspaceValue -Variables $variables -Name "HaspDriverDownloadDir" -CurrentValue $DownloadDir -PreferCurrent:$PSBoundParameters.ContainsKey("DownloadDir")
$ExtractDir = Get-InitWorkspaceValue -Variables $variables -Name "HaspDriverExtractDir" -CurrentValue $ExtractDir -PreferCurrent:$PSBoundParameters.ContainsKey("ExtractDir")
$ReleasePageUrl = Get-InitWorkspaceValue -Variables $variables -Name "HaspDriverReleasePageUrl" -CurrentValue $ReleasePageUrl -PreferCurrent:$PSBoundParameters.ContainsKey("ReleasePageUrl")

if (-not $DownloadDir) {
    $DownloadDir = Join-Path $RepoRoot "build\downloads\hasp-driver\$Version"
}

if (-not $ExtractDir) {
    $ExtractDir = Join-Path $RepoRoot "build\installers\hasp-driver\$Version"
}

if (-not $ReleasePageUrl) {
    $ReleasePageUrl = "https://releases.1c.ru/version_files?nick=AddCompDriverHASP&ver=$Version"
}

function Find-HaspInstaller {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchDir,

        [Parameter(Mandatory = $true)]
        [string]$DownloadedFile
    )

    if ([System.IO.Path]::GetExtension($DownloadedFile) -ieq ".exe") {
        return $DownloadedFile
    }

    $patterns = @("*.exe", "*.msi")
    foreach ($pattern in $patterns) {
        $file = Get-ChildItem -Path $SearchDir -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($file) {
            return $file.FullName
        }
    }

    Write-Host "Доступные файлы в каталоге распаковки:" -ForegroundColor Yellow
    $files = Get-ChildItem -Path $SearchDir -Recurse -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        Write-Host "  $($file.FullName)" -ForegroundColor Yellow
    }

    throw "Не найден установщик драйвера HASP (*.exe или *.msi) в каталоге: $SearchDir"
}

function Install-HaspDriver {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath,

        [string[]]$Arguments = @()
    )

    Assert-Administrator

    Write-Host "Запускаю установку драйвера HASP: $InstallerPath"
    Write-Host "Аргументы: $($Arguments -join ' ')"

    $process = Start-Process `
        -FilePath $InstallerPath `
        -ArgumentList $Arguments `
        -Wait `
        -PassThru

    if ($process.ExitCode -ne 0) {
        throw "Установщик драйвера HASP завершился с кодом $($process.ExitCode)."
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

$installerPath = Find-HaspInstaller -SearchDir $installerRoot -DownloadedFile $distribution.File
Install-HaspDriver -InstallerPath $installerPath -Arguments $InstallerArguments

Write-Host "Установка драйвера HASP завершена." -ForegroundColor Green