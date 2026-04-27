#Requires -Version 5.1

Set-StrictMode -Version 2.0

[Net.ServicePointManager]::SecurityProtocol = (
    [Net.ServicePointManager]::SecurityProtocol -bor
    [Net.SecurityProtocolType]::Tls12
)

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

    if (-not $User) {
        $User = $env:ONEC_USERNAME
    }

    if (-not $Password) {
        $Password = $env:ONEC_PASSWORD
    }

    if (-not $User) {
        $User = Read-Host "Логин releases.1c.ru"
    }

    if (-not $Password) {
        $Password = Read-Host "Пароль releases.1c.ru" -AsSecureString
    }

    [pscustomobject]@{
        User = $User
        Password = ConvertTo-PlainText $Password
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
            if ($title -notmatch $filter) {
                continue
            }

            $distributionPageUri = Resolve-OneCUri -BaseUri $ReleasePageUrl -RelativeOrAbsoluteUri $anchor.Groups[1].Value
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
            $fileName = Get-FileNameFromOneCDownloadUri $downloadUri

            return [pscustomobject]@{
                Title = $title
                DistributionPageUri = $distributionPageUri
                DownloadUri = $downloadUri
                FileName = $fileName
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

    if ((Test-Path $destinationFile) -and -not $Force) {
        Write-Host "Файл уже скачан: $destinationFile"
    }
    else {
        Write-Host "Скачиваю: $($link.DownloadUri)"
        Write-Host "В файл: $destinationFile"
        Invoke-OneCRequest `
            -Uri $link.DownloadUri `
            -Session $session `
            -User $User `
            -Password $Password `
            -OutFile $destinationFile | Out-Null
    }

    return [pscustomobject]@{
        Title = $link.Title
        File = $destinationFile
        DownloadUri = $link.DownloadUri
        DistributionPageUri = $link.DistributionPageUri
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

    Write-Host "Файл не является zip-архивом, распаковка пропущена: $ArchivePath"
    return (Split-Path -Parent $ArchivePath)
}

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Скрипт установки нужно запустить от имени администратора."
    }
}
