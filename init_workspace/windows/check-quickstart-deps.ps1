#Requires -Version 5.1

$ErrorActionPreference = "SilentlyContinue"

$RequiredPlatformVersion = [version]"8.5.1.1302"
$RequiredEdtVersion = [version]"2026.1.0"
$RequiredJavaMajorVersion = 17

$script:HasErrors = $false

function Write-CheckResult {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("OK", "WARN", "FAIL")]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = "Не указано сообщение"
    }

    switch ($Status) {
        "OK" { $color = "Green"; $prefix = "[OK]" }
        "WARN" { $color = "Yellow"; $prefix = "[WARN]" }
        "FAIL" { $color = "Red"; $prefix = "[FAIL]"; $script:HasErrors = $true }
    }

    Write-Host "$prefix $Name - $Message" -ForegroundColor $color
}

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

function Get-VersionFromText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $match = [regex]::Match($Text, "\d+\.\d+\.\d+(?:\.\d+)?")
    if ($match.Success) {
        return [version]$match.Value
    }

    return $null
}

function Test-Platform {
    $commandPath = Get-CommandPath "1cv8.exe"
    $candidatePaths = @()

    if ($commandPath) {
        $candidatePaths += $commandPath
    }

    $candidatePaths += @(Get-ChildItem "C:\Program Files\1cv8\*\bin\1cv8.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files (x86)\1cv8\*\bin\1cv8.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

    $candidatePaths = $candidatePaths | Where-Object { $_ } | Select-Object -Unique

    if (-not $candidatePaths) {
        Write-CheckResult "FAIL" "1C:Enterprise Platform" "не найден 1cv8.exe. Установите платформу 1С:Предприятие $RequiredPlatformVersion и компонент Сервер 1С:Предприятия."
        return
    }

    $installations = foreach ($path in $candidatePaths) {
        $versionText = (& "$path" /Version) 2>$null | Out-String
        $version = Get-VersionFromText $versionText

        if (-not $version) {
            $folderMatch = [regex]::Match($path, "\\(\d+\.\d+\.\d+\.\d+)\\bin\\1cv8\.exe$")
            if ($folderMatch.Success) {
                $version = [version]$folderMatch.Groups[1].Value
            }
        }

        [pscustomobject]@{
            Path = $path
            Version = $version
        }
    }

    $matching = $installations | Where-Object { $_.Version -eq $RequiredPlatformVersion } | Select-Object -First 1

    if ($matching) {
        Write-CheckResult "OK" "1C:Enterprise Platform" "найдена версия $($matching.Version): $($matching.Path)"
    }
    else {
        $versions = ($installations | Where-Object { $_.Version } | ForEach-Object { $_.Version.ToString() } | Sort-Object -Unique) -join ", "
        if (-not $versions) {
            $versions = "версия не определена"
        }

        Write-CheckResult "WARN" "1C:Enterprise Platform" "нужна версия $RequiredPlatformVersion, найдено: $versions"
    }

    $serverService = Get-Service | Where-Object { $_.Name -like "1C:Enterprise 8.3 Server Agent*" -or $_.Name -like "1C:Enterprise 8.5 Server Agent*" } | Select-Object -First 1
    if ($serverService) {
        Write-CheckResult "OK" "1C Server component" "найдена служба '$($serverService.Name)' со статусом $($serverService.Status)"
    }
    else {
        Write-CheckResult "WARN" "1C Server component" "служба сервера 1С не найдена. Проверьте, что при установке выбран компонент Сервер 1С:Предприятия."
    }
}

function Test-Edt {
    $candidatePaths = @()

    foreach ($commandName in @("1cedtstart.exe", "1cedt.exe")) {
        $commandPath = Get-CommandPath $commandName
        if ($commandPath) {
            $candidatePaths += $commandPath
        }
    }

    $candidatePaths += @(Get-ChildItem "C:\Program Files\1C\1CE\components\1c-edt-*\1cedtstart.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files\1C\1CE\components\1c-edt-*\1cedt.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidatePaths += @(Get-ChildItem "C:\Program Files\1C\1CE\components\1c-edt-*\eclipse\1cedt.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

    $candidatePaths = $candidatePaths | Where-Object { $_ } | Select-Object -Unique

    if (-not $candidatePaths) {
        Write-CheckResult "FAIL" "1C:EDT" "не найден 1cedtstart.exe или 1cedt.exe. Установите 1C:EDT $RequiredEdtVersion."
        return
    }

    $installations = foreach ($path in $candidatePaths) {
        $version = $null
        $folderMatch = [regex]::Match($path, "1c-edt-(\d+\.\d+\.\d+)")

        if ($folderMatch.Success) {
            $version = [version]$folderMatch.Groups[1].Value
        }
        else {
            $fileVersion = (Get-Item $path).VersionInfo.ProductVersion
            if ($fileVersion) {
                $version = Get-VersionFromText $fileVersion
            }
        }

        [pscustomobject]@{
            Path = $path
            Version = $version
        }
    }

    $matching = $installations | Where-Object { $_.Version -eq $RequiredEdtVersion } | Select-Object -First 1

    if ($matching) {
        Write-CheckResult "OK" "1C:EDT" "найдена версия $($matching.Version): $($matching.Path)"
    }
    else {
        $versions = ($installations | Where-Object { $_.Version } | ForEach-Object { $_.Version.ToString() } | Sort-Object -Unique) -join ", "
        if (-not $versions) {
            $versions = "версия не определена"
        }

        Write-CheckResult "WARN" "1C:EDT" "нужна версия $RequiredEdtVersion, найдено: $versions"
    }
}

function Test-Git {
    $gitPath = Get-CommandPath "git.exe"
    if (-not $gitPath) {
        Write-CheckResult "FAIL" "Git" "git.exe не найден в PATH. Установите Git for Windows."
        return
    }

    $versionText = (& git --version) 2>$null | Out-String
    Write-CheckResult "OK" "Git" "$($versionText.Trim()) ($gitPath)"

    $autocrlf = (& git config --global --get core.autocrlf) 2>$null
    $safecrlf = (& git config --global --get core.safecrlf) 2>$null

    if ($autocrlf -eq "true" -and $safecrlf -eq "true") {
        Write-CheckResult "OK" "Git line endings" "core.autocrlf=true, core.safecrlf=true"
    }
    else {
        Write-CheckResult "WARN" "Git line endings" "для Windows ожидается: git config --global core.autocrlf true; git config --global core.safecrlf true"
    }

    $lfsVersion = (& git lfs version) 2>$null | Out-String
    if ($LASTEXITCODE -eq 0 -and $lfsVersion.Trim()) {
        Write-CheckResult "OK" "Git LFS" $lfsVersion.Trim()
    }
    else {
        Write-CheckResult "WARN" "Git LFS" "git lfs не найден или не настроен. Для Git for Windows обычно помогает команда: git lfs install"
    }
}

function Test-Java {
    $javaPath = Get-CommandPath "java.exe"
    if (-not $javaPath) {
        Write-CheckResult "WARN" "Java" "java.exe не найден в PATH. Если JDK установлен вместе с EDT, это может быть нормально; иначе установите JDK $RequiredJavaMajorVersion или выше."
        return
    }

    $versionOutput = (& java -version) 2>&1 | Out-String
    $match = [regex]::Match($versionOutput, 'version "(\d+)(?:\.\d+)?')

    if (-not $match.Success) {
        Write-CheckResult "WARN" "Java" "java.exe найден, но версия не определена: $javaPath"
        return
    }

    $majorVersion = [int]$match.Groups[1].Value

    if ($majorVersion -ge $RequiredJavaMajorVersion) {
        Write-CheckResult "OK" "Java" "найдена версия $majorVersion или выше: $javaPath"
    }
    else {
        Write-CheckResult "WARN" "Java" "нужна версия $RequiredJavaMajorVersion или выше, найдена ${majorVersion}: $javaPath"
    }
}

function Test-Hasp {
    $haspService = Get-Service | Where-Object { $_.Name -like "*Sentinel*" -or $_.Name -like "*HASP*" } | Select-Object -First 1
    if ($haspService) {
        Write-CheckResult "OK" "HASP Driver" "найдена служба '$($haspService.Name)' со статусом $($haspService.Status)"
    }
    else {
        Write-CheckResult "WARN" "HASP Driver" "служба драйвера HASP не найдена. Установите драйвер HASP для работы с аппаратными ключами."
    }
}

Write-Host "Проверка зависимостей быстрого старта" -ForegroundColor Cyan
Write-Host ""

try { Test-Platform } catch { Write-Host "Error in Test-Platform: $($_.Exception.Message)" -ForegroundColor Red; throw }
try { Test-Edt } catch { Write-Host "Error in Test-Edt: $($_.Exception.Message)" -ForegroundColor Red; throw }
try { Test-Git } catch { Write-Host "Error in Test-Git: $($_.Exception.Message)" -ForegroundColor Red; throw }
try { Test-Java } catch { Write-Host "Error in Test-Java: $($_.Exception.Message)" -ForegroundColor Red; throw }
try { Test-Hasp } catch { Write-Host "Error in Test-Hasp: $($_.Exception.Message)" -ForegroundColor Red; throw }

Write-Host ""
if ($script:HasErrors) {
    Write-Host "Проверка завершена с ошибками. Установите отсутствующие обязательные компоненты." -ForegroundColor Red
    exit 1
}

Write-Host "Проверка завершена. Предупреждения требуют ручной проверки, но не всегда блокируют запуск." -ForegroundColor Green
exit 0
