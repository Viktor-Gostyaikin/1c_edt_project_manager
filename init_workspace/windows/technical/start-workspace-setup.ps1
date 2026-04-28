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

function Restart-Elevated {
    $argumentList = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-WindowStyle",
        "Hidden",
        "-File",
        "`"$PSCommandPath`""
    )

    foreach ($argument in $args) {
        $escapedArgument = $argument -replace '"', '\"'
        $argumentList += "`"$escapedArgument`""
    }

    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $argumentList -Verb RunAs -WindowStyle Hidden | Out-Null
        return $true
    }
    catch {
        Show-Warning "Не удалось перезапустить мастер с правами администратора:`r`n`r`n$($_.Exception.Message)"
        return $false
    }
}

if (-not (Test-Administrator)) {
    Show-Warning "Для запуска мастера требуются права администратора.`r`n`r`nПосле закрытия этого окна появится запрос контроля учетных записей Windows."

    if (Restart-Elevated @args) {
        exit 0
    }

    exit 1
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

        [System.Windows.Forms.Control]$Parent = $form,
        [int]$Width = 235,
        [int]$Height = 42
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::System
    $button.Add_Click($OnClick)
    $Parent.Controls.Add($button)
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

function New-GroupBox {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$X,

        [Parameter(Mandatory = $true)]
        [int]$Y,

        [Parameter(Mandatory = $true)]
        [int]$Width,

        [Parameter(Mandatory = $true)]
        [int]$Height
    )

    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = $Text
    $group.Location = New-Object System.Drawing.Point($X, $Y)
    $group.Size = New-Object System.Drawing.Size($Width, $Height)
    $group.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $group.BackColor = [System.Drawing.Color]::White
    return $group
}

function New-SectionButton {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Parent,

        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$Y,

        [Parameter(Mandatory = $true)]
        [scriptblock]$OnClick
    )

    return New-Button -Text $Text -X 16 -Y $Y -Width 304 -Height 38 -Parent $Parent -OnClick $OnClick
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Подготовка рабочего места 1С"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 800)
$form.MinimumSize = New-Object System.Drawing.Size(760, 800)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

$header = New-Object System.Windows.Forms.Panel
$header.Location = New-Object System.Drawing.Point(0, 0)
$header.Size = New-Object System.Drawing.Size(744, 88)
$header.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($header)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Подготовка рабочего места разработчика 1С"
$title.Location = New-Object System.Drawing.Point(24, 20)
$title.Size = New-Object System.Drawing.Size(520, 28)
$title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$header.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Выполняйте шаги слева направо: подготовка, установка, настройка EDT и базы."
$subtitle.Location = New-Object System.Drawing.Point(24, 54)
$subtitle.Size = New-Object System.Drawing.Size(560, 22)
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(82, 92, 105)
$header.Controls.Add($subtitle)

$adminStatus = New-Object System.Windows.Forms.Label
$adminStatus.Location = New-Object System.Drawing.Point(590, 24)
$adminStatus.Size = New-Object System.Drawing.Size(130, 30)
$adminStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$adminStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
if (Test-Administrator) {
    $adminStatus.Text = "Администратор"
    $adminStatus.BackColor = [System.Drawing.Color]::FromArgb(226, 246, 229)
    $adminStatus.ForeColor = [System.Drawing.Color]::FromArgb(31, 122, 48)
}
else {
    $adminStatus.Text = "Без повышения"
    $adminStatus.BackColor = [System.Drawing.Color]::FromArgb(255, 242, 214)
    $adminStatus.ForeColor = [System.Drawing.Color]::FromArgb(156, 103, 0)
}
$header.Controls.Add($adminStatus)

$prepGroup = New-GroupBox -Text "1. Подготовка проекта" -X 24 -Y 108 -Width 344 -Height 244
$installGroup = New-GroupBox -Text "2. Установка компонентов" -X 392 -Y 108 -Width 344 -Height 244
$edtGroup = New-GroupBox -Text "3. EDT и информационная база" -X 24 -Y 372 -Width 344 -Height 244
$toolsGroup = New-GroupBox -Text "4. Проверка и справка" -X 392 -Y 372 -Width 344 -Height 244
$form.Controls.Add($prepGroup)
$form.Controls.Add($installGroup)
$form.Controls.Add($edtGroup)
$form.Controls.Add($toolsGroup)

$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(24, 636)
$statusPanel.Size = New-Object System.Drawing.Size(712, 58)
$statusPanel.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($statusPanel)

$statusTitle = New-Object System.Windows.Forms.Label
$statusTitle.Text = "Статус"
$statusTitle.Location = New-Object System.Drawing.Point(16, 10)
$statusTitle.Size = New-Object System.Drawing.Size(80, 18)
$statusTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$statusPanel.Controls.Add($statusTitle)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Последнее действие: не запускалось"
$status.Location = New-Object System.Drawing.Point(16, 30)
$status.Size = New-Object System.Drawing.Size(680, 20)
$status.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$status.ForeColor = [System.Drawing.Color]::FromArgb(82, 92, 105)
$statusPanel.Controls.Add($status)

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

New-SectionButton -Parent $prepGroup -Text "1. Проверить окружение" -Y 30 -OnClick {
    Run-And-SetStatus -CommandName "check-quickstart-deps.cmd" -Caption "проверка окружения"
} | Out-Null

New-SectionButton -Parent $prepGroup -Text "2. Настроить local.vars.ps1" -Y 76 -OnClick {
    Ensure-LocalVars
    $status.Text = "Последнее действие: открыт local.vars.ps1"
} | Out-Null

New-SectionButton -Parent $prepGroup -Text "3. Установить Git" -Y 122 -OnClick {
    Run-And-SetStatus -CommandName "install-git.cmd" -Caption "установка Git" -RequiresAdmin
} | Out-Null

New-SectionButton -Parent $prepGroup -Text "4. Проверить SSH GitLab" -Y 168 -OnClick {
    Run-And-SetStatus -CommandName "check-ssh-gitlab.cmd" -Caption "проверка SSH GitLab"
} | Out-Null

New-SectionButton -Parent $installGroup -Text "5. Развернуть репозиторий" -Y 30 -OnClick {
    Run-And-SetStatus -CommandName "clone-project.cmd" -Caption "развертывание репозитория проекта"
} | Out-Null

New-SectionButton -Parent $installGroup -Text "6. Установить 7-Zip" -Y 76 -OnClick {
    Run-And-SetStatus -CommandName "install-archiver.cmd" -Caption "установка 7-Zip" -RequiresAdmin
} | Out-Null

New-SectionButton -Parent $installGroup -Text "7. Установить платформу 1С + HASP" -Y 122 -OnClick {
    Run-And-SetStatus -CommandName "install-platform.cmd" -Caption "установка платформы 1С" -RequiresAdmin
} | Out-Null

New-SectionButton -Parent $installGroup -Text "8. Установить EDT" -Y 168 -OnClick {
    Run-And-SetStatus -CommandName "install-edt.cmd" -Caption "установка EDT" -RequiresAdmin
} | Out-Null

New-SectionButton -Parent $edtGroup -Text "9. Открыть 1cedt.ini" -Y 30 -OnClick {
    Run-And-SetStatus -CommandName "open-edt-config.cmd" -Caption "открытие 1cedt.ini"
} | Out-Null

New-SectionButton -Parent $edtGroup -Text "10. Инициализировать EDT" -Y 76 -OnClick {
    Run-And-SetStatus -CommandName "init-edt-workspace.cmd" -Caption "инициализация рабочей области EDT"
} | Out-Null

New-SectionButton -Parent $edtGroup -Text "11. Запустить EDT" -Y 122 -OnClick {
    Run-And-SetStatus -CommandName "start-edt.cmd" -Caption "запуск приложения EDT"
} | Out-Null

New-SectionButton -Parent $edtGroup -Text "12. Создать ИБ" -Y 168 -OnClick {
    Run-And-SetStatus -CommandName "create-infobase.cmd" -Caption "создание информационной базы"
} | Out-Null

New-SectionButton -Parent $toolsGroup -Text "Итоговая проверка" -Y 30 -OnClick {
    Run-And-SetStatus -CommandName "check-quickstart-deps.cmd" -Caption "итоговая проверка"
} | Out-Null

New-SectionButton -Parent $toolsGroup -Text "Открыть папку команд" -Y 76 -OnClick {
    Open-Folder -Path $CommandsDir
    $status.Text = "Последнее действие: открыта папка команд"
} | Out-Null

New-SectionButton -Parent $toolsGroup -Text "Открыть README" -Y 122 -OnClick {
    $readmePath = Join-Path $WindowsDir "README.md"
    Start-Process -FilePath "notepad.exe" -ArgumentList "`"$readmePath`""
    $status.Text = "Последнее действие: открыт README"
} | Out-Null

New-Button -Text "Закрыть" -X 616 -Y 704 -Width 120 -Height 32 -OnClick {
    $form.Close()
} | Out-Null

[System.Windows.Forms.Application]::Run($form)
