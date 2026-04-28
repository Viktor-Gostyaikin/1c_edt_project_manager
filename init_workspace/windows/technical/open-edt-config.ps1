#Requires -Version 5.1

param(
    [string]$EdtIniPath = "",
    [string]$EdtPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib\InitWorkspaceVars.ps1")

$variables = Get-InitWorkspaceVariables -ScriptDir $ScriptDir
$EdtIniPath = Get-InitWorkspaceValue -Variables $variables -Name "EdtIniPath" -CurrentValue $EdtIniPath -PreferCurrent:$PSBoundParameters.ContainsKey("EdtIniPath")
$EdtPath = Get-InitWorkspaceValue -Variables $variables -Name "EdtPath" -CurrentValue $EdtPath -PreferCurrent:$PSBoundParameters.ContainsKey("EdtPath")

function Get-EdtIniPath {
    param(
        [string]$PreferredIniPath = "",
        [string]$PreferredEdtPath = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($PreferredIniPath) -and (Test-Path $PreferredIniPath -PathType Leaf)) {
        return (Resolve-Path $PreferredIniPath).Path
    }

    if (-not [string]::IsNullOrWhiteSpace($PreferredEdtPath)) {
        $edtItem = Get-Item $PreferredEdtPath -ErrorAction SilentlyContinue
        if ($edtItem) {
            $baseDir = if ($edtItem.PSIsContainer) { $edtItem.FullName } else { $edtItem.DirectoryName }
            foreach ($candidate in @(
                (Join-Path $baseDir "1cedt.ini"),
                (Join-Path (Split-Path -Parent $baseDir) "1cedt.ini")
            )) {
                if (Test-Path $candidate -PathType Leaf) {
                    return (Resolve-Path $candidate).Path
                }
            }
        }
    }

    $candidatePaths = @()
    $candidatePaths += @(Get-ChildItem "C:\Program Files\1C\1CE\components\1c-edt-*\1cedt.ini" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files\1C\1CE\components\1c-edt-*\eclipse\1cedt.ini" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files (x86)\1C\1CE\components\1c-edt-*\1cedt.ini" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files (x86)\1C\1CE\components\1c-edt-*\eclipse\1cedt.ini" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

    return $candidatePaths | Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1
}

$resolvedIniPath = Get-EdtIniPath -PreferredIniPath $EdtIniPath -PreferredEdtPath $EdtPath
if (-not $resolvedIniPath) {
    Write-Host "[FAIL] Файл 1cedt.ini не найден." -ForegroundColor Red
    Write-Host "Укажите путь в local.vars.ps1, например:"
    Write-Host '  EdtIniPath = "C:\Program Files\1C\1CE\components\1c-edt-2022.2.5+10-x86_64\1cedt.ini"'
    exit 1
}

Write-Host "Открываю конфигурационный файл 1C:EDT:"
Write-Host "  $resolvedIniPath"
Start-Process -FilePath "notepad.exe" -ArgumentList "`"$resolvedIniPath`""
Write-Host "[OK] Файл 1cedt.ini открыт." -ForegroundColor Green
exit 0
