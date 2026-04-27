#Requires -Version 5.1

Set-StrictMode -Version 2.0

[Net.ServicePointManager]::SecurityProtocol = (
    [Net.ServicePointManager]::SecurityProtocol -bor
    [Net.SecurityProtocolType]::Tls12
)

$script:OneCReleasesWindowsDir = Split-Path -Parent $PSScriptRoot

function ConvertTo-PlainText {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    if ($Value -is [securestring]) {
        $credential = New-Object System.Management.Automation.PSCredential("user", $Value)
        return $credential.GetNetworkCredential().Password
    }

    return [string]$Value
}

function Get-OneCCredential {
    param(
        [string]$User = "",
        [object]$Password = $null
    )

    if ([string]::IsNullOrWhiteSpace($User)) {
        $User = $env:ONEC_USERNAME
    }

    if (-not $Password) {
        $Password = $env:ONEC_PASSWORD
    }

    if ([string]::IsNullOrWhiteSpace($User)) {
        $User = Read-Host "Логин releases.1c.ru"
    }

    if ([string]::IsNullOrWhiteSpace($User)) {
        throw "Логин releases.1c.ru не указан."
    }

    if (-not $Password) {
        $Password = Read-Host "Пароль releases.1c.ru" -AsSecureString
    }

    $plainPassword = ConvertTo-PlainText $Password
    if ([string]::IsNullOrWhiteSpace($plainPassword)) {
        throw "Пароль releases.1c.ru не указан."
    }

    [pscustomobject]@{
        User = $User
        Password = $plainPassword
    }
}

function New-OneCReleaseSession {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    return $session
}

function Get-ResponseUri {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Response
    )

    if ($Response.BaseResponse -and $Response.BaseResponse.ResponseUri) {
        return $Response.BaseResponse.ResponseUri.AbsoluteUri
    }

    return ""
}

function Test-LoginPage {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Response
    )

    $responseUri = Get-ResponseUri $Response
    return ($responseUri -like "https://login.1c.ru/login*")
}

function Invoke-OneCLogin {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

        [Parameter(Mandatory = $true)]
        [object]$LoginResponse,

        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    $executionMatch = [regex]::Match($LoginResponse.Content, 'name="execution"\s+value="([^"]+)"')
    if (-not $executionMatch.Success) {
        throw "Не удалось найти hidden-поле execution на странице авторизации 1С."
    }

    $loginUri = Get-ResponseUri $LoginResponse
    if (-not $loginUri) {
        $loginUri = "https://login.1c.ru/login"
    }

    $body = @{
        inviteCode = ""
        username = $User
        password = $Password
        execution = $executionMatch.Groups[1].Value
        "_eventId" = "submit"
        geolocation = ""
        submit = "Войти"
        rememberMe = "on"
    }

    Invoke-WebRequest `
        -Uri $loginUri `
        -Method Post `
        -Body $body `
        -WebSession $Session `
        -UseBasicParsing | Out-Null
}

function Invoke-OneCRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [string]$OutFile = ""
    )

    $requestParams = @{
        Uri = $Uri
        WebSession = $Session
        UseBasicParsing = $true
    }

    if ($OutFile) {
        $requestParams.OutFile = $OutFile
    }

    $response = Invoke-WebRequest @requestParams

    if ($response -and (Test-LoginPage $response)) {
        Invoke-OneCLogin -Session $Session -LoginResponse $response -User $User -Password $Password
        $response = Invoke-WebRequest @requestParams
    }

    if ($response -and (Test-LoginPage $response)) {
        throw "Авторизация на releases.1c.ru не выполнена. Проверьте логин и пароль."
    }

    return $response
}

function Resolve-OneCUri {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUri,

        [Parameter(Mandatory = $true)]
        [string]$RelativeOrAbsoluteUri
    )

    if ($RelativeOrAbsoluteUri -match "^https?://") {
        return $RelativeOrAbsoluteUri
    }

    $base = [uri]$BaseUri
    return (New-Object -TypeName System.Uri -ArgumentList $base, $RelativeOrAbsoluteUri).AbsoluteUri
}

function Get-FileNameFromOneCDownloadUri {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    $match = [regex]::Match($Uri, "[?&]path=([^&]+)")
    if ($match.Success) {
        $path = [System.Net.WebUtility]::UrlDecode($match.Groups[1].Value)
        $path = $path -replace "/", "\"
        return ($path -split "\\")[-1]
    }

    return [System.IO.Path]::GetFileName(([uri]$Uri).AbsolutePath)
}

function Get-OneCFileNameFromDistributionHtml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Html
    )

    $fileNameMatch = [regex]::Match(
        $Html,
        'Имя\s+файла:\s*</td>\s*<td>\s*([^<]+?)\s*</td>',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    if ($fileNameMatch.Success) {
        return [System.Net.WebUtility]::HtmlDecode($fileNameMatch.Groups[1].Value).Trim()
    }

    return ""
}

function Get-OneCSha512FromDistributionHtml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Html
    )

    $copyMatch = [regex]::Match(
        $Html,
        "copyToClipboard\('([a-fA-F0-9]{128})'",
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    if ($copyMatch.Success) {
        return $copyMatch.Groups[1].Value.ToLowerInvariant()
    }

    $rowMatch = [regex]::Match(
        $Html,
        'Контрольная\s+сумма\s+SHA-512:\s*</td>\s*<td[^>]*>.*?([a-fA-F0-9]{128}).*?</td>',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    if ($rowMatch.Success) {
        return $rowMatch.Groups[1].Value.ToLowerInvariant()
    }

    return ""
}

function Assert-FileSha512 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string]$ExpectedSha512 = ""
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedSha512)) {
        Write-Host "Контрольная сумма SHA-512 на странице дистрибутива не найдена, проверка пропущена." -ForegroundColor Yellow
        return
    }

    if ($ExpectedSha512 -notmatch '^[a-fA-F0-9]{128}$') {
        throw "Некорректная контрольная сумма SHA-512 на странице дистрибутива: $ExpectedSha512"
    }

    Write-Host "Проверяю контрольную сумму SHA-512..."
    $actualSha512 = (Get-FileHash -Path $FilePath -Algorithm SHA512).Hash.ToLowerInvariant()
    $expected = $ExpectedSha512.ToLowerInvariant()

    if ($actualSha512 -ne $expected) {
        throw "Контрольная сумма SHA-512 не совпадает. Файл: $FilePath. Ожидалось: $expected. Получено: $actualSha512"
    }

    Write-Host "Контрольная сумма SHA-512 совпадает." -ForegroundColor Green
}

function Test-FileSha512 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string]$ExpectedSha512 = ""
    )

    try {
        Assert-FileSha512 -FilePath $FilePath -ExpectedSha512 $ExpectedSha512
        return $true
    }
    catch {
        Write-Host "[WARN] $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Assert-ArchiveExtractorAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $extension = [System.IO.Path]::GetExtension($FileName)
    if ($extension -ine ".rar") {
        return
    }

    $extractor = Get-ArchiveExtractor
    if (-not $extractor) {
        $extractor = Install-ArchiveExtractorAfterPrompt
    }

    Write-Host "Найден распаковщик RAR: $($extractor.Type) ($($extractor.Path))"
}

function Install-ArchiveExtractorAfterPrompt {
    $installScript = Join-Path $script:OneCReleasesWindowsDir "install-archiver.ps1"
    if (-not (Test-Path $installScript)) {
        throw "Для RAR-дистрибутива нужен 7-Zip, WinRAR или UnRAR. Скрипт установки архиватора не найден: $installScript"
    }

    Write-Host "Для RAR-дистрибутива нужен 7-Zip, WinRAR или UnRAR." -ForegroundColor Yellow
    $answer = Read-Host "Установить 7-Zip сейчас через winget? [Y/n]"
    if ($answer -and $answer -notmatch "^(y|yes|д|да)$") {
        throw "Архиватор не установлен. Установите 7-Zip, WinRAR или UnRAR и повторите запуск."
    }

    $repoRoot = (Resolve-Path (Join-Path $script:OneCReleasesWindowsDir "..\..\..")).Path
    $logDir = Join-Path $repoRoot "build\logs"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null

    $stdoutLog = Join-Path $logDir "install-archiver.out.log"
    $stderrLog = Join-Path $logDir "install-archiver.err.log"
    Remove-Item $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

    Write-Host "Устанавливаю 7-Zip. Это может занять несколько минут..."
    Write-Host "Подробный вывод установки будет сохранен в: $logDir"
    $process = Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$installScript`"") `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog `
        -Wait `
        -PassThru

    if ($process.ExitCode -ne 0) {
        throw "Установка 7-Zip завершилась с кодом $($process.ExitCode). Проверьте лог: $stderrLog. Установите архиватор вручную и повторите запуск."
    }

    $extractor = Get-ArchiveExtractor
    if (-not $extractor) {
        throw "7-Zip установлен, но архиватор пока не найден. Перезапустите терминал или проверьте каталог C:\Program Files\7-Zip."
    }

    return $extractor
}

function Format-FileSize {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Bytes
    )

    if ($Bytes -ge 1GB) {
        return "{0:N2} ГБ" -f ($Bytes / 1GB)
    }

    if ($Bytes -ge 1MB) {
        return "{0:N2} МБ" -f ($Bytes / 1MB)
    }

    if ($Bytes -ge 1KB) {
        return "{0:N2} КБ" -f ($Bytes / 1KB)
    }

    return "{0:N0} Б" -f $Bytes
}

function Format-Duration {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Seconds
    )

    if ($Seconds -lt 0 -or [double]::IsNaN($Seconds) -or [double]::IsInfinity($Seconds)) {
        return "--:--"
    }

    $timeSpan = [TimeSpan]::FromSeconds([Math]::Round($Seconds))
    if ($timeSpan.TotalHours -ge 1) {
        return "{0:00}:{1:00}:{2:00}" -f [Math]::Floor($timeSpan.TotalHours), $timeSpan.Minutes, $timeSpan.Seconds
    }

    return "{0:00}:{1:00}" -f $timeSpan.Minutes, $timeSpan.Seconds
}

function Write-DownloadProgressLine {
    param(
        [Parameter(Mandatory = $true)]
        [double]$DownloadedBytes,

        [double]$TotalBytes = -1,

        [double]$SpeedBytesPerSecond = 0,

        [string]$FileName = ""
    )

    $barWidth = 28
    $percentText = " --.-%"
    $bar = ("#" * 8).PadRight($barWidth, ".")
    $etaText = "--:--"

    if ($TotalBytes -gt 0) {
        $percent = [Math]::Min(100, [Math]::Max(0, ($DownloadedBytes / $TotalBytes) * 100))
        $filledWidth = [Math]::Min($barWidth, [Math]::Floor(($percent / 100) * $barWidth))
        $bar = ("#" * $filledWidth).PadRight($barWidth, ".")
        $percentText = "{0,5:N1}%" -f $percent

        if ($SpeedBytesPerSecond -gt 0) {
            $etaText = Format-Duration (($TotalBytes - $DownloadedBytes) / $SpeedBytesPerSecond)
        }
    }

    $downloaded = Format-FileSize $DownloadedBytes
    $total = "неизвестно"
    if ($TotalBytes -gt 0) {
        $total = Format-FileSize $TotalBytes
    }

    $speed = Format-FileSize $SpeedBytesPerSecond
    $message = "`r[$bar] $percentText  $downloaded / $total  $speed/с  осталось $etaText"
    if (-not [string]::IsNullOrWhiteSpace($FileName)) {
        $message = "$message  $FileName"
    }

    Write-Host $message -NoNewline
}

function Save-OneCFileWithProgress {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

        [Parameter(Mandatory = $true)]
        [string]$DestinationFile,

        [int]$MaxAttempts = 3,
        [int]$RetryDelaySeconds = 10
    )

    $partialFile = "$DestinationFile.part"
    $buffer = New-Object byte[] (1024 * 1024)
    $attempt = 1
    $activity = "Скачивание дистрибутива"
    $fileName = [System.IO.Path]::GetFileName($DestinationFile)

    while ($attempt -le $MaxAttempts) {
        $response = $null
        $stream = $null
        $fileStream = $null

        try {
            $existingBytes = 0
            if (Test-Path $partialFile) {
                $existingBytes = (Get-Item $partialFile).Length
            }

            if ($existingBytes -gt 0) {
                Write-Host "Продолжаю скачивание с позиции $(Format-FileSize $existingBytes). Попытка $attempt из $MaxAttempts."
            }
            else {
                Write-Host "Начинаю скачивание. Попытка $attempt из $MaxAttempts."
            }

            $request = [System.Net.HttpWebRequest]::Create($Uri)
            $request.Method = "GET"
            $request.CookieContainer = $Session.Cookies
            $request.UserAgent = $Session.UserAgent
            $request.AllowAutoRedirect = $true
            $request.Timeout = 30000
            $request.ReadWriteTimeout = 30000

            if ($existingBytes -gt 0) {
                $request.AddRange($existingBytes)
            }

            $response = $request.GetResponse()

            if ($existingBytes -gt 0 -and $response.StatusCode -ne [System.Net.HttpStatusCode]::PartialContent) {
                Write-Host "Сервер не поддержал продолжение скачивания, начинаю файл заново." -ForegroundColor Yellow
                Remove-Item $partialFile -Force -ErrorAction SilentlyContinue
                $existingBytes = 0
            }

            $totalBytes = -1
            if ($response.ContentLength -gt 0) {
                $totalBytes = $existingBytes + $response.ContentLength
            }

            $fileMode = [System.IO.FileMode]::Append
            if ($existingBytes -eq 0) {
                $fileMode = [System.IO.FileMode]::Create
            }

            $stream = $response.GetResponseStream()
            $fileStream = New-Object System.IO.FileStream($partialFile, $fileMode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

            $downloadedBytes = $existingBytes
            $startedAt = Get-Date
            $lastProgressAt = Get-Date

            while ($true) {
                $read = $stream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) {
                    break
                }

                $fileStream.Write($buffer, 0, $read)
                $downloadedBytes += $read

                $now = Get-Date
                if (($now - $lastProgressAt).TotalMilliseconds -ge 700) {
                    $elapsedSeconds = [Math]::Max(1, ($now - $startedAt).TotalSeconds)
                    $speed = ($downloadedBytes - $existingBytes) / $elapsedSeconds
                    $status = "$(Format-FileSize $downloadedBytes)"

                    if ($totalBytes -gt 0) {
                        $percent = [Math]::Min(100, [Math]::Round(($downloadedBytes / $totalBytes) * 100, 1))
                        $status = "$status из $(Format-FileSize $totalBytes), $(Format-FileSize $speed)/с"
                        Write-Progress -Activity $activity -Status $status -PercentComplete $percent
                    }
                    else {
                        $status = "$status, $(Format-FileSize $speed)/с"
                        Write-Progress -Activity $activity -Status $status
                    }

                    Write-DownloadProgressLine `
                        -DownloadedBytes $downloadedBytes `
                        -TotalBytes $totalBytes `
                        -SpeedBytesPerSecond $speed `
                        -FileName $fileName

                    $lastProgressAt = $now
                }
            }

            $fileStream.Close()
            $stream.Close()
            $response.Close()

            if ($totalBytes -gt 0) {
                $actualBytes = (Get-Item $partialFile).Length
                if ($actualBytes -lt $totalBytes) {
                    throw "Скачивание завершилось не полностью: получено $(Format-FileSize $actualBytes) из $(Format-FileSize $totalBytes)."
                }
            }

            Move-Item -Path $partialFile -Destination $DestinationFile -Force
            Write-Progress -Activity $activity -Completed
            Write-Host ""
            Write-Host "Скачивание завершено: $DestinationFile" -ForegroundColor Green
            return
        }
        catch {
            if ($fileStream) {
                $fileStream.Close()
            }

            if ($stream) {
                $stream.Close()
            }

            if ($response) {
                $response.Close()
            }

            Write-Progress -Activity $activity -Completed

            if ($attempt -ge $MaxAttempts) {
                throw "Не удалось скачать файл после $MaxAttempts попыток. Проверьте подключение к сети и повторите запуск. Частично скачанный файл сохранен как: $partialFile. Последняя ошибка: $($_.Exception.Message)"
            }

            Write-Host "[WARN] Скачивание прервано: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "Повтор через $RetryDelaySeconds сек. Частично скачанный файл сохранен: $partialFile" -ForegroundColor Yellow
            Start-Sleep -Seconds $RetryDelaySeconds
            $attempt++
        }
    }
}

function Get-OneCDistributionLink {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReleasePageUrl,

        [Parameter(Mandatory = $true)]
        [string[]]$DistributionFilters,

        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    Write-Host "Открываю страницу релиза: $ReleasePageUrl"
    $releaseResponse = Invoke-OneCRequest -Uri $ReleasePageUrl -Session $Session -User $User -Password $Password
    $releaseHtml = $releaseResponse.Content

    $anchorRegex = '<a\s+[^>]*href="([^"]+)"[^>]*>\s*([^<]+?)\s*</a>'
    $anchors = [regex]::Matches($releaseHtml, $anchorRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    foreach ($filter in $DistributionFilters) {
        foreach ($anchor in $anchors) {
            $title = [System.Net.WebUtility]::HtmlDecode($anchor.Groups[2].Value).Trim()
            $href = $anchor.Groups[1].Value
            if ($title -notmatch $filter -and $href -notmatch $filter) {
                continue
            }

            $distributionPageUri = Resolve-OneCUri -BaseUri $ReleasePageUrl -RelativeOrAbsoluteUri $href
            Write-Host "Найден дистрибутив: $title"
            Write-Host "Открываю страницу скачивания: $distributionPageUri"

            $distributionResponse = Invoke-OneCRequest -Uri $distributionPageUri -Session $Session -User $User -Password $Password
            $distributionHtml = $distributionResponse.Content
            $downloadRegexOptions = (
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                [System.Text.RegularExpressions.RegexOptions]::Singleline
            )
            $downloadMatch = [regex]::Match(
                $distributionHtml,
                '<div\s+class="downloadDist">.*?<a\s+href="([^"]+)">\s*Скачать дистрибутив\s*</a>.*?</div>',
                $downloadRegexOptions
            )

            if (-not $downloadMatch.Success) {
                throw "На странице дистрибутива не найдена ссылка 'Скачать дистрибутив'."
            }

            $downloadUri = Resolve-OneCUri -BaseUri $distributionPageUri -RelativeOrAbsoluteUri $downloadMatch.Groups[1].Value
            $fileName = Get-OneCFileNameFromDistributionHtml $distributionHtml
            if ([string]::IsNullOrWhiteSpace($fileName)) {
                $fileName = Get-FileNameFromOneCDownloadUri $distributionPageUri
            }

            if ([string]::IsNullOrWhiteSpace($fileName) -or -not [System.IO.Path]::GetExtension($fileName)) {
                $fileName = Get-FileNameFromOneCDownloadUri $downloadUri
            }

            $sha512 = Get-OneCSha512FromDistributionHtml $distributionHtml

            return [pscustomobject]@{
                Title = $title
                DistributionPageUri = $distributionPageUri
                DownloadUri = $downloadUri
                FileName = $fileName
                Sha512 = $sha512
            }
        }
    }

    throw "Не найден дистрибутив по фильтрам: $($DistributionFilters -join '; ')"
}

function Save-OneCDistribution {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReleasePageUrl,

        [Parameter(Mandatory = $true)]
        [string[]]$DistributionFilters,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDir,

        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [switch]$Force
    )

    $session = New-OneCReleaseSession
    $link = Get-OneCDistributionLink `
        -ReleasePageUrl $ReleasePageUrl `
        -DistributionFilters $DistributionFilters `
        -Session $session `
        -User $User `
        -Password $Password

    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    $destinationFile = Join-Path $DestinationDir $link.FileName
    Assert-ArchiveExtractorAvailable -FileName $link.FileName

    $shouldDownload = $true
    if ((Test-Path $destinationFile) -and -not $Force) {
        Write-Host "Найден ранее скачанный файл: $destinationFile"
        if (Test-FileSha512 -FilePath $destinationFile -ExpectedSha512 $link.Sha512) {
            Write-Host "Использую уже скачанный дистрибутив." -ForegroundColor Green
            $shouldDownload = $false
        }
        else {
            Write-Host "Ранее скачанный файл поврежден или не соответствует странице релиза, скачиваю заново." -ForegroundColor Yellow
            Remove-Item $destinationFile -Force -ErrorAction SilentlyContinue
        }
    }

    if ($shouldDownload) {
        Write-Host "Скачиваю: $($link.DownloadUri)"
        Write-Host "В файл: $destinationFile"
        Save-OneCFileWithProgress `
            -Uri $link.DownloadUri `
            -Session $session `
            -DestinationFile $destinationFile
        Assert-FileSha512 -FilePath $destinationFile -ExpectedSha512 $link.Sha512
    }

    return [pscustomobject]@{
        Title = $link.Title
        File = $destinationFile
        DownloadUri = $link.DownloadUri
        DistributionPageUri = $link.DistributionPageUri
        Sha512 = $link.Sha512
    }
}

function Expand-OneCArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDir,

        [switch]$Force
    )

    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null

    $extension = [System.IO.Path]::GetExtension($ArchivePath)
    if ($extension -ieq ".zip") {
        Write-Host "Распаковываю архив: $ArchivePath"
        Expand-Archive -Path $ArchivePath -DestinationPath $DestinationDir -Force:$Force
        return $DestinationDir
    }

    if ($extension -ieq ".rar") {
        Write-Host "Распаковываю RAR-архив: $ArchivePath"

        $extractor = Get-ArchiveExtractor
        if (-not $extractor) {
            $extractor = Install-ArchiveExtractorAfterPrompt
        }

        Invoke-ArchiveExtractor `
            -Extractor $extractor `
            -ArchivePath $ArchivePath `
            -DestinationDir $DestinationDir

        return $DestinationDir
    }

    Write-Host "Файл не является архивом zip/rar, распаковка пропущена: $ArchivePath"
    return (Split-Path -Parent $ArchivePath)
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

function Get-ArchiveExtractor {
    $sevenZipCommand = Get-Command "7z.exe" -ErrorAction SilentlyContinue
    if ($sevenZipCommand) {
        return [pscustomobject]@{
            Type = "7Zip"
            Path = $sevenZipCommand.Source
        }
    }

    $sevenZipStandaloneCommand = Get-Command "7za.exe" -ErrorAction SilentlyContinue
    if ($sevenZipStandaloneCommand) {
        return [pscustomobject]@{
            Type = "7Zip"
            Path = $sevenZipStandaloneCommand.Source
        }
    }

    $programFiles = [Environment]::GetFolderPath("ProgramFiles")
    $programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")

    $sevenZipPaths = @()
    if (-not [string]::IsNullOrWhiteSpace($programFiles)) {
        $sevenZipPaths += (Join-Path $programFiles "7-Zip\7z.exe")
    }

    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $sevenZipPaths += (Join-Path $programFilesX86 "7-Zip\7z.exe")
    }

    $sevenZipPath = Get-ExistingPath -Paths $sevenZipPaths
    if ($sevenZipPath) {
        return [pscustomobject]@{
            Type = "7Zip"
            Path = $sevenZipPath
        }
    }

    $winRarCommand = Get-Command "WinRAR.exe" -ErrorAction SilentlyContinue
    if ($winRarCommand) {
        return [pscustomobject]@{
            Type = "WinRAR"
            Path = $winRarCommand.Source
        }
    }

    $unRarCommand = Get-Command "UnRAR.exe" -ErrorAction SilentlyContinue
    if ($unRarCommand) {
        return [pscustomobject]@{
            Type = "UnRAR"
            Path = $unRarCommand.Source
        }
    }

    $winRarPaths = @()
    if (-not [string]::IsNullOrWhiteSpace($programFiles)) {
        $winRarPaths += (Join-Path $programFiles "WinRAR\WinRAR.exe")
    }

    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $winRarPaths += (Join-Path $programFilesX86 "WinRAR\WinRAR.exe")
    }

    $winRarPath = Get-ExistingPath -Paths $winRarPaths
    if ($winRarPath) {
        return [pscustomobject]@{
            Type = "WinRAR"
            Path = $winRarPath
        }
    }

    return $null
}

function Invoke-ArchiveExtractor {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Extractor,

        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDir
    )

    switch ($Extractor.Type) {
        "7Zip" {
            & $Extractor.Path x $ArchivePath "-o$DestinationDir" -y | Out-Host
        }
        "WinRAR" {
            & $Extractor.Path x -ibck -y $ArchivePath "$DestinationDir\" | Out-Host
        }
        "UnRAR" {
            & $Extractor.Path x -y $ArchivePath "$DestinationDir\" | Out-Host
        }
        default {
            throw "Неизвестный распаковщик архива: $($Extractor.Type)"
        }
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Распаковщик $($Extractor.Type) завершился с кодом $LASTEXITCODE."
    }
}

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Скрипт установки нужно запустить от имени администратора."
    }
}
