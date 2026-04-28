#Requires -Version 5.1

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WindowsDir = Split-Path -Parent $ScriptDir
$CommandsDir = Join-Path $WindowsDir "commands"
$VarsPath = Join-Path $WindowsDir "local.vars.ps1"
$VarsExamplePath = Join-Path $WindowsDir "local.vars.example.ps1"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-Warning {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Title = "Подготовка рабочего места"
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
}

function Invoke-WorkspaceCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,

        [switch]$RequiresAdmin
    )

    $commandPath = Join-Path $CommandsDir $CommandName
    if (-not (Test-Path $commandPath)) {
        Show-Warning "Команда не найдена:`r`n$commandPath"
        return $null
    }

    $startInfo = @{
        FilePath = "cmd.exe"
        ArgumentList = @("/c", "`"$commandPath`"")
        Wait = $true
        PassThru = $true
    }

    if ($RequiresAdmin -and -not (Test-Administrator)) {
        $startInfo.Verb = "RunAs"
    }

    try {
        return Start-Process @startInfo
    }
    catch {
        Show-Warning "Не удалось запустить команду:`r`n$CommandName`r`n`r`n$($_.Exception.Message)"
        return $null
    }
}

function Ensure-LocalVars {
    if (-not (Test-Path $VarsPath)) {
        if (-not (Test-Path $VarsExamplePath)) {
            Show-Warning "Не найден шаблон настроек:`r`n$VarsExamplePath"
            return
        }

        Copy-Item -Path $VarsExamplePath -Destination $VarsPath
    }

    Start-Process -FilePath "notepad.exe" -ArgumentList "`"$VarsPath`""
}

function Open-Folder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path $Path) {
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$Path`""
    }
    else {
        Show-Warning "Каталог не найден:`r`n$Path"
    }
}

function New-Button {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$X,

        [Parameter(Mandatory = $true)]
        [int]$Y,

        [Parameter(Mandatory = $true)]
        [scriptblock]$OnClick,

        [int]$Width = 235,
        [int]$Height = 42
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $button.Add_Click($OnClick)
    return $button
}

function New-StatusLabel {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$Y
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point(24, $Y)
    $label.Size = New-Object System.Drawing.Size(500, 22)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    return $label
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Подготовка рабочего места 1С"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(560, 560)
$form.MinimumSize = New-Object System.Drawing.Size(560, 560)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "Подготовка рабочего места разработчика 1С"
$title.Location = New-Object System.Drawing.Point(24, 20)
$title.Size = New-Object System.Drawing.Size(500, 30)
$title.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Запускайте команды сверху вниз. Окно консоли покажет подробный результат."
$subtitle.Location = New-Object System.Drawing.Point(24, 54)
$subtitle.Size = New-Object System.Drawing.Size(500, 24)
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($subtitle)

$status = New-StatusLabel -Text "Последнее действие: не запускалось" -Y 470
$form.Controls.Add($status)

$adminStatus = New-StatusLabel -Text "" -Y 492
if (Test-Administrator) {
    $adminStatus.Text = "Права администратора: да"
    $adminStatus.ForeColor = [System.Drawing.Color]::DarkGreen
}
else {
    $adminStatus.Text = "Права администратора: нет. Установки будут запрошены с повышением прав."
    $adminStatus.ForeColor = [System.Drawing.Color]::DarkOrange
}
$form.Controls.Add($adminStatus)

function Run-And-SetStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,

        [Parameter(Mandatory = $true)]
        [string]$Caption,

        [switch]$RequiresAdmin
    )

    $status.Text = "Последнее действие: выполняется - $Caption"
    $form.Refresh()

    $process = Invoke-WorkspaceCommand -CommandName $CommandName -RequiresAdmin:$RequiresAdmin
    if ($null -eq $process) {
        $status.Text = "Последнее действие: не удалось запустить - $Caption"
        return
    }

    if ($null -ne $process.ExitCode -and $process.ExitCode -eq 0) {
        $status.Text = "Последнее действие: успешно - $Caption"
    }
    elseif ($null -ne $process.ExitCode) {
        $status.Text = "Последнее действие: ошибка $($process.ExitCode) - $Caption"
    }
    else {
        $status.Text = "Последнее действие: завершено - $Caption"
    }
}

$form.Controls.Add((New-Button -Text "1. Проверить окружение" -X 24 -Y 96 -OnClick {
    Run-And-SetStatus -CommandName "check-quickstart-deps.cmd" -Caption "проверка окружения"
}))

$form.Controls.Add((New-Button -Text "2. Настроить local.vars.ps1" -X 286 -Y 96 -OnClick {
    Ensure-LocalVars
    $status.Text = "Последнее действие: открыт local.vars.ps1"
}))

$form.Controls.Add((New-Button -Text "3. Установить Git" -X 24 -Y 152 -OnClick {
    Run-And-SetStatus -CommandName "install-git.cmd" -Caption "установка Git" -RequiresAdmin
}))

$form.Controls.Add((New-Button -Text "4. Проверить SSH GitLab" -X 286 -Y 152 -OnClick {
    Run-And-SetStatus -CommandName "check-ssh-gitlab.cmd" -Caption "проверка SSH GitLab"
}))

$form.Controls.Add((New-Button -Text "5. Установить 7-Zip" -X 24 -Y 208 -OnClick {
    Run-And-SetStatus -CommandName "install-archiver.cmd" -Caption "установка 7-Zip" -RequiresAdmin
}))

$form.Controls.Add((New-Button -Text "6. Установить платформу 1С" -X 286 -Y 208 -OnClick {
    Run-And-SetStatus -CommandName "install-platform.cmd" -Caption "установка платформы 1С" -RequiresAdmin
}))

$form.Controls.Add((New-Button -Text "7. Установить EDT" -X 24 -Y 264 -OnClick {
    Run-And-SetStatus -CommandName "install-edt.cmd" -Caption "установка EDT" -RequiresAdmin
}))

$form.Controls.Add((New-Button -Text "8. Установить HASP" -X 286 -Y 264 -OnClick {
    Run-And-SetStatus -CommandName "install-hasp-driver.cmd" -Caption "установка HASP" -RequiresAdmin
}))

$form.Controls.Add((New-Button -Text "Итоговая проверка" -X 24 -Y 330 -OnClick {
    Run-And-SetStatus -CommandName "check-quickstart-deps.cmd" -Caption "итоговая проверка"
}))

$form.Controls.Add((New-Button -Text "Открыть папку команд" -X 286 -Y 330 -OnClick {
    Open-Folder -Path $CommandsDir
    $status.Text = "Последнее действие: открыта папка команд"
}))

$form.Controls.Add((New-Button -Text "Открыть README" -X 24 -Y 386 -OnClick {
    $readmePath = Join-Path $WindowsDir "README.md"
    Start-Process -FilePath "notepad.exe" -ArgumentList "`"$readmePath`""
    $status.Text = "Последнее действие: открыт README"
}))

$form.Controls.Add((New-Button -Text "Закрыть" -X 286 -Y 386 -OnClick {
    $form.Close()
}))

[System.Windows.Forms.Application]::Run($form)
