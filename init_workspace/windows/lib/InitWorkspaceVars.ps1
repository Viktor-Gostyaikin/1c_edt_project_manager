#Requires -Version 5.1

function Get-InitWorkspaceVariables {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptDir
    )

    $varsPath = Join-Path $ScriptDir "local.vars.ps1"
    if (-not (Test-Path $varsPath)) {
        return @{}
    }

    $InitWorkspace = @{}
    . $varsPath

    if ($InitWorkspace -isnot [hashtable]) {
        throw "Файл переменных должен задавать hashtable `$InitWorkspace. Файл: $varsPath"
    }

    return $InitWorkspace
}

function Get-InitWorkspaceValue {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Variables,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [object]$CurrentValue = $null,

        [switch]$PreferCurrent
    )

    if ($PreferCurrent -and $null -ne $CurrentValue) {
        return $CurrentValue
    }

    if ($Variables.ContainsKey($Name) -and $null -ne $Variables[$Name]) {
        if ($Variables[$Name] -is [string] -and [string]::IsNullOrWhiteSpace($Variables[$Name])) {
            return $CurrentValue
        }

        return $Variables[$Name]
    }

    return $CurrentValue
}
