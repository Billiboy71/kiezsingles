# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\checks\ks-abuse-admin-validation.psm1
# Purpose: Abuse simulation correlation check against /admin/security/events
# Created: 08-03-2026 03:06 (Europe/Berlin)
# Changed: 23-03-2026 20:46 (Europe/Berlin)
# Version: 3.6
# =============================================================================

Set-StrictMode -Version Latest

function Get-AbuseAdminValidationScenarioOrder {
    return @(
        'abuse_device_reuse',
        'abuse_account_sharing',
        'abuse_bot_pattern',
        'abuse_device_cluster_1',
        'abuse_device_cluster_2',
        'abuse_device_cluster_3',
        'abuse_device_cluster_4',
        'abuse_device_cluster_5'
    )
}

function Get-AbuseAdminValidationScenarioSortIndex {
    param(
        [Parameter(Mandatory=$false)][string]$ScenarioName
    )

    $resolvedScenarioName = ""
    try { $resolvedScenarioName = ("" + $ScenarioName).Trim() } catch { $resolvedScenarioName = "" }

    $scenarioOrder = @(Get-AbuseAdminValidationScenarioOrder)
    for ($i = 0; $i -lt $scenarioOrder.Count; $i++) {
        if ($scenarioOrder[$i] -eq $resolvedScenarioName) {
            return $i
        }
    }

    return ([int]$scenarioOrder.Count + 1000)
}

function Get-AbuseAdminValidationBoolean {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)][bool]$Default = $false
    )

    try {
        $var = Get-Variable -Name $Name -Scope Script -ErrorAction Stop
        if ($null -eq $var -or $null -eq $var.Value) {
            return [bool]$Default
        }

        return [bool]$var.Value
    } catch {
        return [bool]$Default
    }
}

function Get-AbuseAdminValidationString {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)][string]$Default = ""
    )

    try {
        $var = Get-Variable -Name $Name -Scope Script -ErrorAction Stop
        if ($null -eq $var -or $null -eq $var.Value) {
            return $Default
        }

        return ("" + $var.Value)
    } catch {
        return $Default
    }
}

function Get-AbuseAdminValidationRunId {
    $auditRunId = Get-AbuseAdminValidationString -Name "AuditRunId" -Default ""
    if (-not [string]::IsNullOrWhiteSpace($auditRunId)) {
        return $auditRunId.Trim()
    }

    $runId = Get-AbuseAdminValidationString -Name "RunId" -Default ""
    if (-not [string]::IsNullOrWhiteSpace($runId)) {
        return $runId.Trim()
    }

    return ""
}

function Get-AbuseAdminValidationInt {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)][int]$Default = 0
    )

    try {
        $var = Get-Variable -Name $Name -Scope Script -ErrorAction Stop
        if ($null -eq $var -or $null -eq $var.Value) {
            return [int]$Default
        }

        return [int]$var.Value
    } catch {
        return [int]$Default
    }
}

function Get-AbuseAdminValidationHashtable {
    param(
        [Parameter(Mandatory=$true)][string]$Name
    )

    try {
        $var = Get-Variable -Name $Name -Scope Script -ErrorAction Stop
        if ($null -eq $var -or $null -eq $var.Value) {
            return @{}
        }

        if ($var.Value -is [hashtable]) {
            return $var.Value
        }

        return @{}
    } catch {
        return @{}
    }
}

function ConvertTo-AbuseAdminValidationStringArray {
    param(
        [Parameter(Mandatory=$false)]$InputObject
    )

    $items = New-Object System.Collections.ArrayList

    if ($null -eq $InputObject) {
        return @()
    }

    if ($InputObject -is [string]) {
        $value = ("" + $InputObject).Trim()
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            [void]$items.Add($value)
        }

        return @($items.ToArray())
    }

    if ($InputObject -is [System.Collections.IEnumerable]) {
        foreach ($item in $InputObject) {
            if ($null -eq $item) {
                continue
            }

            $value = ("" + $item).Trim()
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                [void]$items.Add($value)
            }
        }

        return @($items.ToArray())
    }

    $single = ("" + $InputObject).Trim()
    if (-not [string]::IsNullOrWhiteSpace($single)) {
        [void]$items.Add($single)
    }

    return @($items.ToArray())
}

function Get-AbuseAdminValidationBaseUrl {
    $baseUrl = Get-AbuseAdminValidationString -Name "BaseUrl" -Default "http://kiezsingles.test"

    try {
        if (Get-Command Normalize-BaseUrl -ErrorAction SilentlyContinue) {
            return (Normalize-BaseUrl -s $baseUrl)
        }
    } catch {
    }

    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        return "http://kiezsingles.test"
    }

    return $baseUrl.TrimEnd('/')
}

function Join-AbuseAdminValidationUrl {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $BaseUrl.TrimEnd('/')
    }

    if ($Path -match '^https?://') {
        return $Path
    }

    if ($Path.StartsWith('/')) {
        return ($BaseUrl.TrimEnd('/') + $Path)
    }

    return ($BaseUrl.TrimEnd('/') + '/' + $Path.TrimStart('/'))
}

function Get-AbuseAdminValidationClientIp {
    $simulateClientIpEnabled = Get-AbuseAdminValidationBoolean -Name "SimulateClientIpEnabled" -Default $false
    if (-not $simulateClientIpEnabled) {
        return ""
    }

    $adminValidationTestIp = Get-AbuseAdminValidationString -Name "AdminValidationTestIp" -Default "198.51.100.210"
    $adminValidationTestIp = $adminValidationTestIp.Trim()

    if ([string]::IsNullOrWhiteSpace($adminValidationTestIp)) {
        return ""
    }

    return $adminValidationTestIp
}

function Get-AbuseAdminValidationClientIpHeaderMode {
    $mode = Get-AbuseAdminValidationString -Name "AdminValidationClientIpHeaderMode" -Default ""
    if ([string]::IsNullOrWhiteSpace($mode)) {
        $mode = Get-AbuseAdminValidationString -Name "ClientIpHeaderMode" -Default "standard"
    }

    if ([string]::IsNullOrWhiteSpace($mode)) {
        return "standard"
    }

    return $mode.Trim().ToLowerInvariant()
}

function Get-AbuseAdminValidationDefaultHeaders {
    $headers = @{
        "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    }

    $runId = Get-AbuseAdminValidationRunId
    if (-not [string]::IsNullOrWhiteSpace($runId)) {
        $headers["X-Audit-Run-Id"] = $runId
    }

    $deviceHeaderName = Get-AbuseAdminValidationString -Name "DeviceHeaderName" -Default ""
    $deviceHeaderValue = Get-AbuseAdminValidationString -Name "DeviceHeaderValue" -Default ""

    if (-not [string]::IsNullOrWhiteSpace($deviceHeaderName) -and -not [string]::IsNullOrWhiteSpace($deviceHeaderValue)) {
        $headers[$deviceHeaderName] = $deviceHeaderValue
    }

    $clientIp = Get-AbuseAdminValidationClientIp
    $clientIpHeaderMode = Get-AbuseAdminValidationClientIpHeaderMode

    if (-not [string]::IsNullOrWhiteSpace($clientIp)) {
        switch ($clientIpHeaderMode) {
            "cf" {
                $headers["CF-Connecting-IP"] = $clientIp
            }

            "x-real-ip" {
                $headers["X-Real-IP"] = $clientIp
            }

            "x-forwarded-for" {
                $headers["X-Forwarded-For"] = $clientIp
            }

            default {
                $headers["CF-Connecting-IP"] = $clientIp
                $headers["X-Real-IP"] = $clientIp
                $headers["X-Forwarded-For"] = $clientIp
            }
        }
    }

    return $headers
}

function Get-AbuseAdminValidationResponseText {
    param(
        [Parameter(Mandatory=$false)]$Response
    )

    if ($null -eq $Response) {
        return ""
    }

    try {
        if ($null -ne $Response.Content) {
            return ("" + $Response.Content)
        }
    } catch {
    }

    try {
        if ($null -ne $Response.RawContent) {
            return ("" + $Response.RawContent)
        }
    } catch {
    }

    return ""
}

function Get-AbuseAdminValidationCsrfToken {
    param(
        [Parameter(Mandatory=$true)][string]$Html
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return ""
    }

    $patterns = @(
        '(?is)<input[^>]*name=["'']_token["''][^>]*value=["'']([^"'']+)["'']',
        '(?is)<meta[^>]*name=["'']csrf-token["''][^>]*content=["'']([^"'']+)["'']'
    )

    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Html, $pattern)
        if ($match.Success -and $match.Groups.Count -gt 1) {
            $value = ("" + $match.Groups[1].Value).Trim()
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value
            }
        }
    }

    return ""
}

function Get-AbuseAdminValidationDeviceCookieName {
    $cookieName = Get-AbuseAdminValidationString -Name "DeviceCookieName" -Default "ks_device_id"

    if ([string]::IsNullOrWhiteSpace($cookieName)) {
        return "ks_device_id"
    }

    return $cookieName.Trim()
}

function Get-AbuseAdminValidationDeviceCookieId {
    $deviceCookieId = Get-AbuseAdminValidationString -Name "AdminValidationDeviceCookieId" -Default ""

    if ([string]::IsNullOrWhiteSpace($deviceCookieId)) {
        return ""
    }

    return $deviceCookieId.Trim()
}

function Set-AbuseAdminValidationDeviceCookie {
    param(
        [Parameter(Mandatory=$true)]$WebSession
    )

    $deviceCookieId = Get-AbuseAdminValidationDeviceCookieId
    if ([string]::IsNullOrWhiteSpace($deviceCookieId)) {
        return
    }

    $cookieName = Get-AbuseAdminValidationDeviceCookieName
    $baseUrl = Get-AbuseAdminValidationBaseUrl

    try {
        $baseUri = [System.Uri]$baseUrl
        $cookie = New-Object System.Net.Cookie($cookieName, $deviceCookieId, '/', $baseUri.Host)
        $WebSession.Cookies.Add($baseUri, $cookie)
    } catch {
    }
}

function Test-AbuseAdminValidationIsConfirmPasswordUrl {
    param(
        [Parameter(Mandatory=$false)][string]$Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }

    return ($Url -match '/confirm-password(?:\?|$)')
}

function Test-AbuseAdminValidationIsLoginUrl {
    param(
        [Parameter(Mandatory=$false)][string]$Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }

    return ($Url -match '/login(?:\?|$)')
}

function Test-AbuseAdminValidationLooksLikeLoginHtml {
    param(
        [Parameter(Mandatory=$false)][string]$Html
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return $false
    }

    return (
        ($Html -match '(?is)<input[^>]*name=["'']email["'']') -and
        ($Html -match '(?is)<input[^>]*name=["'']password["'']')
    )
}

function Test-AbuseAdminValidationLooksLikeConfirmPasswordHtml {
    param(
        [Parameter(Mandatory=$false)][string]$Html
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return $false
    }

    return (
        ($Html -match '(?is)confirm\s+password') -or
        ($Html -match '(?is)passwort\s+best(ä|ae)tigen')
    )
}

function Get-AbuseAdminValidationHtmlSnippet {
    param(
        [Parameter(Mandatory=$false)][string]$Html,
        [Parameter(Mandatory=$false)][int]$MaxLength = 400
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return ""
    }

    $text = $Html

    try { $text = [regex]::Replace($text, '(?is)<script\b[^>]*>.*?</script>', ' ') } catch { }
    try { $text = [regex]::Replace($text, '(?is)<style\b[^>]*>.*?</style>', ' ') } catch { }
    try { $text = [regex]::Replace($text, '(?is)<[^>]+>', ' ') } catch { }
    try { $text = [System.Net.WebUtility]::HtmlDecode($text) } catch { }

    try { $text = [regex]::Replace($text, '\s+', ' ') } catch { }
    $text = $text.Trim()

    if ([string]::IsNullOrWhiteSpace($text)) {
        return ""
    }

    if ($text.Length -gt $MaxLength) {
        return $text.Substring(0, $MaxLength)
    }

    return $text
}

function Get-AbuseAdminValidationSearchableText {
    param(
        [Parameter(Mandatory=$false)][string]$Html
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return ""
    }

    $text = $Html

    try { $text = [regex]::Replace($text, '(?is)<script\b[^>]*>.*?</script>', ' ') } catch { }
    try { $text = [regex]::Replace($text, '(?is)<style\b[^>]*>.*?</style>', ' ') } catch { }
    try { $text = [regex]::Replace($text, '(?is)<form\b[^>]*>.*?</form>', ' ') } catch { }
    try { $text = [regex]::Replace($text, '(?is)<input\b[^>]*type=["'']hidden["''][^>]*>', ' ') } catch { }
    try { $text = [regex]::Replace($text, '(?is)<[^>]+>', ' ') } catch { }
    try { $text = [System.Net.WebUtility]::HtmlDecode($text) } catch { }
    try { $text = [regex]::Replace($text, '\s+', ' ') } catch { }

    return $text.Trim()
}

function Get-AbuseAdminValidationHtmlAnchorText {
    param(
        [Parameter(Mandatory=$false)][string]$Html
    )

    $value = ""
    try { $value = "" + $Html } catch { $value = "" }

    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }

    try { $value = [regex]::Replace($value, '(?is)<[^>]+>', ' ') } catch { }
    try { $value = [System.Net.WebUtility]::HtmlDecode($value) } catch { }
    try { $value = [regex]::Replace($value, '\s+', ' ') } catch { }

    return $value.Trim()
}

function Get-AbuseAdminValidationQueryValueFromUrl {
    param(
        [Parameter(Mandatory=$false)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Key
    )

    $value = ""
    try { $value = "" + $Url } catch { $value = "" }

    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }

    try {
        $value = [System.Net.WebUtility]::HtmlDecode($value)
    } catch {
    }

    $pattern = '(?i)(?:\?|&)' + [regex]::Escape($Key) + '=([^&#]+)'
    $match = [regex]::Match($value, $pattern)

    if (-not $match.Success -or $match.Groups.Count -lt 2) {
        return ""
    }

    $raw = ""
    try { $raw = "" + $match.Groups[1].Value } catch { $raw = "" }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        return ""
    }

    try {
        $raw = $raw.Replace('+', ' ')
        return [System.Uri]::UnescapeDataString($raw).Trim()
    } catch {
        return $raw.Trim()
    }
}

function Get-AbuseAdminValidationLinkedValues {
    param(
        [Parameter(Mandatory=$false)][string]$Html
    )

    $result = [ordered]@{
        Emails       = @()
        Ips          = @()
        DeviceHashes = @()
    }

    $value = ""
    try { $value = "" + $Html } catch { $value = "" }

    if ([string]::IsNullOrWhiteSpace($value)) {
        return [PSCustomObject]$result
    }

    $emails = New-Object System.Collections.ArrayList
    $ips = New-Object System.Collections.ArrayList
    $deviceHashes = New-Object System.Collections.ArrayList

    $matches = [regex]::Matches($value, '(?is)<a\b[^>]*href=["'']([^"'']+)["''][^>]*>(.*?)</a>')

    foreach ($match in $matches) {
        if ($null -eq $match -or -not $match.Success) {
            continue
        }

        $href = ""
$innerHtml = ""

try { $href = ("" + $match.Groups[1].Value).Trim() } catch { $href = "" }
try { $innerHtml = "" + $match.Groups[2].Value } catch { $innerHtml = "" }

# HTML Entities dekodieren (wichtig für &amp;)
try { $href = [System.Net.WebUtility]::HtmlDecode($href) } catch {}

        if ([string]::IsNullOrWhiteSpace($href)) {
            continue
        }

        $anchorText = Get-AbuseAdminValidationHtmlAnchorText -Html $innerHtml

        $emailValue = Get-AbuseAdminValidationQueryValueFromUrl -Url $href -Key 'email'
        if (-not [string]::IsNullOrWhiteSpace($emailValue)) {
            if ([string]::IsNullOrWhiteSpace($anchorText)) {
                $anchorText = $emailValue
            }

            [void]$emails.Add($anchorText)
        }

        $ipValue = Get-AbuseAdminValidationQueryValueFromUrl -Url $href -Key 'ip'
        if (-not [string]::IsNullOrWhiteSpace($ipValue)) {
            if ([string]::IsNullOrWhiteSpace($anchorText)) {
                $anchorText = $ipValue
            }

            [void]$ips.Add($anchorText)
        }

        $deviceHashValue = Get-AbuseAdminValidationQueryValueFromUrl -Url $href -Key 'device_hash'
        if (-not [string]::IsNullOrWhiteSpace($deviceHashValue)) {
            if ([string]::IsNullOrWhiteSpace($anchorText)) {
                $anchorText = $deviceHashValue
            }

            [void]$deviceHashes.Add($anchorText)
        }
    }

    $result['Emails'] = @($emails | Select-Object -Unique)
    $result['Ips'] = @($ips | Select-Object -Unique)
    $result['DeviceHashes'] = @($deviceHashes | Select-Object -Unique)

    return [PSCustomObject]$result
}

function Get-AbuseAdminValidationLoginFailureReason {
    param(
        [Parameter(Mandatory=$false)][string]$FinalUrl,
        [Parameter(Mandatory=$false)][string]$Html
    )

    $snippet = Get-AbuseAdminValidationHtmlSnippet -Html $Html -MaxLength 600

    if (Test-AbuseAdminValidationIsLoginUrl -Url $FinalUrl) {
        if ($snippet -match '(?is)these credentials do not match our records') {
            return "LOGIN_INVALID_CREDENTIALS"
        }

        if ($snippet -match '(?is)zugangsdaten') {
            return "LOGIN_INVALID_CREDENTIALS"
        }

        if ($snippet -match '(?is)ungültig|ungueltig') {
            return "LOGIN_INVALID_CREDENTIALS"
        }

        if ($snippet -match '(?is)wartungsmodus aktiv') {
            return "LOGIN_BLOCKED_MAINTENANCE"
        }

        if ($snippet -match '(?is)login ist aktuell nicht erlaubt') {
            return "LOGIN_BLOCKED_MAINTENANCE"
        }

        if ($snippet -match '(?is)anmeldung aktuell nicht möglich') {
            return "LOGIN_BLOCKED_SECURITY"
        }

        if ($snippet -match '(?is)referenz:\s*SEC-[A-Z0-9]{6,8}') {
            return "LOGIN_BLOCKED_SECURITY"
        }

        if ($snippet -match '(?is)too many|zu viele|lockout|throttle') {
            return "LOGIN_LOCKOUT"
        }

        if ($snippet -match '(?is)email[^ ]* not verified|e-?mail[^ ]* nicht verifiziert') {
            return "LOGIN_EMAIL_NOT_VERIFIED"
        }

        return "LOGIN_FAILED_OR_STAYED_ON_LOGIN"
    }

    if (Test-AbuseAdminValidationLooksLikeLoginHtml -Html $Html) {
        return "LOGIN_RESPONSE_LOOKS_LIKE_LOGIN_PAGE"
    }

    if (Test-AbuseAdminValidationLooksLikeConfirmPasswordHtml -Html $Html) {
        return "LOGIN_REDIRECTED_TO_CONFIRM_PASSWORD"
    }

    return "LOGIN_FAILED_OR_STAYED_ON_LOGIN"
}

function New-AbuseAdminValidationSession {
    try {
        if (Get-Command New-Session -ErrorAction SilentlyContinue) {
            return (New-Session)
        }
    } catch {
    }

    return (New-Object Microsoft.PowerShell.Commands.WebRequestSession)
}

function Invoke-AbuseAdminValidationHttpNoRedirect {
    param(
        [Parameter(Mandatory=$true)][string]$Method,
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][hashtable]$Form = $null
    )

    try {
        if (Get-Command Invoke-HttpNoRedirect -ErrorAction SilentlyContinue) {
            return (Invoke-HttpNoRedirect -Method $Method -Url $Url -Session $Session -Headers $Headers -Form $Form)
        }
    } catch {
        throw $_
    }

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = $Method
    $request.AllowAutoRedirect = $false
    $request.CookieContainer = $Session.Cookies

    foreach ($key in $Headers.Keys) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            continue
        }

        try {
            $request.Headers[$key] = ("" + $Headers[$key])
        } catch {
        }
    }

    if ($null -ne $Form) {
        $pairs = New-Object System.Collections.Generic.List[string]

        foreach ($key in $Form.Keys) {
            $pairs.Add(("{0}={1}" -f [System.Uri]::EscapeDataString("" + $key), [System.Uri]::EscapeDataString("" + $Form[$key])))
        }

        $bodyString = [string]::Join("&", $pairs)
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyString)

        $request.ContentType = "application/x-www-form-urlencoded"
        $request.ContentLength = $bodyBytes.Length

        $stream = $request.GetRequestStream()
        $stream.Write($bodyBytes, 0, $bodyBytes.Length)
        $stream.Dispose()
    }

    try {
        $response = $request.GetResponse()
        $statusCode = 0
        $headersOut = @{}
        $content = ""

        try { $statusCode = [int]([System.Net.HttpWebResponse]$response).StatusCode } catch { $statusCode = 0 }

        try {
            foreach ($headerKey in $response.Headers.AllKeys) {
                $headersOut[$headerKey] = $response.Headers[$headerKey]
            }
        } catch {
        }

        try {
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            $content = $reader.ReadToEnd()
            $reader.Dispose()
        } catch {
            $content = ""
        }

        try { $response.Close() } catch {
        }

        return [PSCustomObject]@{
            StatusCode = $statusCode
            Headers    = $headersOut
            Content    = $content
            RawContent = $content
        }
    } catch {
        $exceptionResponse = $null

        try {
            if ($_.Exception.Response) {
                $exceptionResponse = $_.Exception.Response
            }
        } catch {
            $exceptionResponse = $null
        }

        $statusCode = 0
        $headersOut = @{}
        $content = ""

        if ($null -ne $exceptionResponse) {
            try { $statusCode = [int]([System.Net.HttpWebResponse]$exceptionResponse).StatusCode } catch { $statusCode = 0 }

            try {
                foreach ($headerKey in $exceptionResponse.Headers.AllKeys) {
                    $headersOut[$headerKey] = $exceptionResponse.Headers[$headerKey]
                }
            } catch {
            }

            try {
                $reader = New-Object System.IO.StreamReader($exceptionResponse.GetResponseStream())
                $content = $reader.ReadToEnd()
                $reader.Dispose()
            } catch {
                $content = ""
            }

            try { $exceptionResponse.Close() } catch {
            }
        }

        return [PSCustomObject]@{
            StatusCode = $statusCode
            Headers    = $headersOut
            Content    = $content
            RawContent = $content
        }
    }
}

function Invoke-AbuseAdminValidationFollowGetRedirects {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$StartUrl,
        [Parameter(Mandatory=$true)]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][int]$Max = 5
    )

    try {
        if (Get-Command Invoke-FollowRedirects -ErrorAction SilentlyContinue) {
            return (Invoke-FollowRedirects -BaseUrl $BaseUrl -StartUrl $StartUrl -Session $Session -Headers $Headers -Max $Max)
        }
    } catch {
        throw $_
    }

    $currentUrl = $StartUrl
    $lastResponse = $null

    for ($i = 0; $i -lt $Max; $i++) {
        $lastResponse = Invoke-AbuseAdminValidationHttpNoRedirect -Method 'GET' -Url $currentUrl -Session $Session -Headers $Headers

        $statusCode = 0
        try { $statusCode = [int]$lastResponse.StatusCode } catch { $statusCode = 0 }

        if ($statusCode -ge 300 -and $statusCode -lt 400) {
            $location = ""

            try {
                if ($lastResponse.Headers['Location']) {
                    $location = "" + $lastResponse.Headers['Location']
                } elseif ($lastResponse.Headers['location']) {
                    $location = "" + $lastResponse.Headers['location']
                }
            } catch {
                $location = ""
            }

            if ([string]::IsNullOrWhiteSpace($location)) {
                break
            }

            $currentUrl = Resolve-Url -BaseUrl $BaseUrl -CurrentUrl $currentUrl -Location $location
            if ([string]::IsNullOrWhiteSpace($currentUrl)) {
                break
            }

            continue
        }

        break
    }

    $html = Get-AbuseAdminValidationResponseText -Response $lastResponse

    return [PSCustomObject]@{
        FinalUrl  = $currentUrl
        FinalHtml = $html
        Raw       = $lastResponse
    }
}

function Invoke-AbuseAdminValidationRequest {
    param(
        [Parameter(Mandatory=$true)][string]$Method,
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][hashtable]$Form = $null,
        [Parameter(Mandatory=$false)][int]$MaxRedirects = 5
    )

    $baseUrl = Get-AbuseAdminValidationBaseUrl
    $first = Invoke-AbuseAdminValidationHttpNoRedirect -Method $Method -Url $Url -Session $Session -Headers $Headers -Form $Form

    $statusCode = 0
    try { $statusCode = [int]$first.StatusCode } catch { $statusCode = 0 }

    $location = ""
    try {
        if ($first.Headers['Location']) {
            $location = "" + $first.Headers['Location']
        } elseif ($first.Headers['location']) {
            $location = "" + $first.Headers['location']
        }
    } catch {
        $location = ""
    }

    $finalUrl = $Url
    $finalHtml = Get-AbuseAdminValidationResponseText -Response $first
    $finalRaw = $first
    $followed = $false

    if ($statusCode -ge 300 -and $statusCode -lt 400 -and -not [string]::IsNullOrWhiteSpace($location)) {
        $resolved = Resolve-Url -BaseUrl $baseUrl -CurrentUrl $Url -Location $location

        if (-not [string]::IsNullOrWhiteSpace($resolved)) {
            $follow = Invoke-AbuseAdminValidationFollowGetRedirects -BaseUrl $baseUrl -StartUrl $resolved -Session $Session -Headers $Headers -Max $MaxRedirects
            $finalUrl = $follow.FinalUrl
            $finalHtml = $follow.FinalHtml
            $finalRaw = $follow.Raw
            $followed = $true
        }
    }

    return [PSCustomObject]@{
        InitialStatus = $statusCode
        FinalUrl      = $finalUrl
        FinalHtml     = $finalHtml
        Raw           = $finalRaw
        Followed      = $followed
        Location      = $location
    }
}

function Invoke-AbuseAdminValidationConfirmPassword {
    param(
        [Parameter(Mandatory=$true)]$WebSession,
        [Parameter(Mandatory=$true)][string]$Password
    )

    $baseUrl = Get-AbuseAdminValidationBaseUrl
    $confirmUrl = Join-AbuseAdminValidationUrl -BaseUrl $baseUrl -Path "/confirm-password"
    $headers = Get-AbuseAdminValidationDefaultHeaders

    try {
        $confirmGet = Invoke-AbuseAdminValidationRequest -Method "GET" -Url $confirmUrl -Session $WebSession -Headers $headers
        $confirmHtml = "" + $confirmGet.FinalHtml
        $confirmGetFinalUrl = "" + $confirmGet.FinalUrl

        if (Test-AbuseAdminValidationIsLoginUrl -Url $confirmGetFinalUrl) {
            return [PSCustomObject]@{
                Success      = $false
                HttpStatus   = "" + $confirmGet.InitialStatus
                ConfirmUrl   = $confirmUrl
                FinalUrl     = $confirmGetFinalUrl
                ErrorMessage = "CONFIRM_PASSWORD_REDIRECTED_TO_LOGIN"
                Html         = $confirmHtml
                Response     = $confirmGet.Raw
            }
        }

        $csrfToken = Get-AbuseAdminValidationCsrfToken -Html $confirmHtml

        if ([string]::IsNullOrWhiteSpace($csrfToken)) {
            return [PSCustomObject]@{
                Success      = $false
                HttpStatus   = "" + $confirmGet.InitialStatus
                ConfirmUrl   = $confirmUrl
                FinalUrl     = $confirmGetFinalUrl
                ErrorMessage = "CONFIRM_PASSWORD_CSRF_TOKEN_NOT_FOUND"
                Html         = $confirmHtml
                Response     = $confirmGet.Raw
            }
        }

        $body = @{
            _token   = $csrfToken
            password = $Password
        }

        $confirmPost = Invoke-AbuseAdminValidationRequest -Method "POST" -Url $confirmUrl -Session $WebSession -Headers $headers -Form $body
        $finalUrl = "" + $confirmPost.FinalUrl
        $responseHtml = "" + $confirmPost.FinalHtml
        $httpStatus = "" + $confirmPost.InitialStatus

        $success = $false
        if (Test-AbuseAdminValidationIsLoginUrl -Url $finalUrl) {
            $success = $false
        } elseif (Test-AbuseAdminValidationIsConfirmPasswordUrl -Url $finalUrl) {
            $success = $false
        } elseif (Test-AbuseAdminValidationLooksLikeLoginHtml -Html $responseHtml) {
            $success = $false
        } elseif (Test-AbuseAdminValidationLooksLikeConfirmPasswordHtml -Html $responseHtml) {
            $success = $false
        } else {
            $success = $true
        }

        return [PSCustomObject]@{
            Success      = $success
            HttpStatus   = $httpStatus
            ConfirmUrl   = $confirmUrl
            FinalUrl     = $finalUrl
            ErrorMessage = $(if ($success) { "" } else { "CONFIRM_PASSWORD_FAILED_OR_STAYED_ON_CONFIRM" })
            Html         = $responseHtml
            Response     = $confirmPost.Raw
        }
    } catch {
        return [PSCustomObject]@{
            Success      = $false
            HttpStatus   = ""
            ConfirmUrl   = $confirmUrl
            FinalUrl     = ""
            ErrorMessage = $_.Exception.Message
            Html         = ""
            Response     = $null
        }
    }
}

function Get-AbuseAdminValidationLoginSession {
    $enabled = Get-AbuseAdminValidationBoolean -Name "AdminValidationEnabled" -Default $false
    if (-not $enabled) {
        return [PSCustomObject]@{
            Success             = $false
            HttpStatus          = ""
            LoginUrl            = ""
            FinalUrl            = ""
            ErrorMessage        = "ADMIN_VALIDATION_DISABLED"
            WebSession          = $null
            DashboardHtml       = ""
            DashboardResponse   = $null
            DashboardSnippet    = ""
            DeviceCookieName    = ""
            DeviceCookieId      = ""
            ClientIp            = ""
            ConfirmRequired     = $false
            ConfirmUrl          = ""
            ConfirmFinalUrl     = ""
            ConfirmHttpStatus   = ""
            ConfirmErrorMessage = ""
        }
    }

    $baseUrl = Get-AbuseAdminValidationBaseUrl
    $loginEmail = Get-AbuseAdminValidationString -Name "AdminValidationLoginEmail" -Default ""
    $loginPassword = Get-AbuseAdminValidationString -Name "AdminValidationLoginPassword" -Default ""
    $loginUrl = Join-AbuseAdminValidationUrl -BaseUrl $baseUrl -Path "/login"
    $deviceCookieName = Get-AbuseAdminValidationDeviceCookieName
    $deviceCookieId = Get-AbuseAdminValidationDeviceCookieId
    $clientIp = Get-AbuseAdminValidationClientIp

    if ([string]::IsNullOrWhiteSpace($loginEmail) -or [string]::IsNullOrWhiteSpace($loginPassword)) {
        return [PSCustomObject]@{
            Success             = $false
            HttpStatus          = ""
            LoginUrl            = $loginUrl
            FinalUrl            = ""
            ErrorMessage        = "ADMIN_LOGIN_CREDENTIALS_MISSING"
            WebSession          = $null
            DashboardHtml       = ""
            DashboardResponse   = $null
            DashboardSnippet    = ""
            DeviceCookieName    = $deviceCookieName
            DeviceCookieId      = $deviceCookieId
            ClientIp            = $clientIp
            ConfirmRequired     = $false
            ConfirmUrl          = ""
            ConfirmFinalUrl     = ""
            ConfirmHttpStatus   = ""
            ConfirmErrorMessage = ""
        }
    }

    $headers = Get-AbuseAdminValidationDefaultHeaders
    $webSession = New-AbuseAdminValidationSession
    Set-AbuseAdminValidationDeviceCookie -WebSession $webSession

    try {
        $loginGet = Invoke-AbuseAdminValidationRequest -Method "GET" -Url $loginUrl -Session $webSession -Headers $headers
        $loginHtml = "" + $loginGet.FinalHtml
        $loginGetFinalUrl = "" + $loginGet.FinalUrl
        $csrfToken = Get-AbuseAdminValidationCsrfToken -Html $loginHtml

        if ([string]::IsNullOrWhiteSpace($csrfToken)) {
            return [PSCustomObject]@{
                Success             = $false
                HttpStatus          = "" + $loginGet.InitialStatus
                LoginUrl            = $loginUrl
                FinalUrl            = $loginGetFinalUrl
                ErrorMessage        = "LOGIN_CSRF_TOKEN_NOT_FOUND"
                WebSession          = $webSession
                DashboardHtml       = $loginHtml
                DashboardResponse   = $loginGet.Raw
                DashboardSnippet    = (Get-AbuseAdminValidationHtmlSnippet -Html $loginHtml -MaxLength 600)
                DeviceCookieName    = $deviceCookieName
                DeviceCookieId      = $deviceCookieId
                ClientIp            = $clientIp
                ConfirmRequired     = $false
                ConfirmUrl          = ""
                ConfirmFinalUrl     = ""
                ConfirmHttpStatus   = ""
                ConfirmErrorMessage = ""
            }
        }

        $body = @{
            _token   = $csrfToken
            email    = $loginEmail
            password = $loginPassword
        }

        Write-Host ("LOGIN EMAIL USED: {0}" -f $loginEmail)
        Write-Host ("CONFIG EMAIL: {0}" -f (Get-AbuseAdminValidationString -Name "AdminValidationLoginEmail" -Default ""))

        $loginPost = Invoke-AbuseAdminValidationRequest -Method "POST" -Url $loginUrl -Session $webSession -Headers $headers -Form $body
        $finalUrl = "" + $loginPost.FinalUrl
        $dashboardHtml = "" + $loginPost.FinalHtml
        $dashboardSnippet = Get-AbuseAdminValidationHtmlSnippet -Html $dashboardHtml -MaxLength 600

        $success = $false
        if (Test-AbuseAdminValidationIsLoginUrl -Url $finalUrl) {
            $success = $false
        } elseif (Test-AbuseAdminValidationLooksLikeLoginHtml -Html $dashboardHtml) {
            $success = $false
        } elseif ([string]::IsNullOrWhiteSpace($finalUrl)) {
            $success = $false
        } else {
            $success = $true
        }

        $httpStatus = "" + $loginPost.InitialStatus

        if (-not $success) {
            $failureReason = Get-AbuseAdminValidationLoginFailureReason -FinalUrl $finalUrl -Html $dashboardHtml

            return [PSCustomObject]@{
                Success             = $false
                HttpStatus          = $httpStatus
                LoginUrl            = $loginUrl
                FinalUrl            = $finalUrl
                ErrorMessage        = $failureReason
                WebSession          = $webSession
                DashboardHtml       = $dashboardHtml
                DashboardResponse   = $loginPost.Raw
                DashboardSnippet    = $dashboardSnippet
                DeviceCookieName    = $deviceCookieName
                DeviceCookieId      = $deviceCookieId
                ClientIp            = $clientIp
                ConfirmRequired     = $false
                ConfirmUrl          = ""
                ConfirmFinalUrl     = ""
                ConfirmHttpStatus   = ""
                ConfirmErrorMessage = ""
            }
        }

        $confirmResult = Invoke-AbuseAdminValidationConfirmPassword -WebSession $webSession -Password $loginPassword
        if (-not $confirmResult.Success) {
            return [PSCustomObject]@{
                Success             = $false
                HttpStatus          = $httpStatus
                LoginUrl            = $loginUrl
                FinalUrl            = $finalUrl
                ErrorMessage        = "CONFIRM_PASSWORD_FAILED: $($confirmResult.ErrorMessage)"
                WebSession          = $webSession
                DashboardHtml       = $dashboardHtml
                DashboardResponse   = $loginPost.Raw
                DashboardSnippet    = $dashboardSnippet
                DeviceCookieName    = $deviceCookieName
                DeviceCookieId      = $deviceCookieId
                ClientIp            = $clientIp
                ConfirmRequired     = $true
                ConfirmUrl          = $confirmResult.ConfirmUrl
                ConfirmFinalUrl     = $confirmResult.FinalUrl
                ConfirmHttpStatus   = $confirmResult.HttpStatus
                ConfirmErrorMessage = $confirmResult.ErrorMessage
            }
        }

        return [PSCustomObject]@{
            Success             = $true
            HttpStatus          = $httpStatus
            LoginUrl            = $loginUrl
            FinalUrl            = $finalUrl
            ErrorMessage        = ""
            WebSession          = $webSession
            DashboardHtml       = $dashboardHtml
            DashboardResponse   = $loginPost.Raw
            DashboardSnippet    = $dashboardSnippet
            DeviceCookieName    = $deviceCookieName
            DeviceCookieId      = $deviceCookieId
            ClientIp            = $clientIp
            ConfirmRequired     = $true
            ConfirmUrl          = $confirmResult.ConfirmUrl
            ConfirmFinalUrl     = $confirmResult.FinalUrl
            ConfirmHttpStatus   = $confirmResult.HttpStatus
            ConfirmErrorMessage = ""
        }
    } catch {
        return [PSCustomObject]@{
            Success             = $false
            HttpStatus          = ""
            LoginUrl            = ""
            FinalUrl            = ""
            ErrorMessage        = $_.Exception.Message
            WebSession          = $webSession
            DashboardHtml       = ""
            DashboardResponse   = $null
            DashboardSnippet    = ""
            DeviceCookieName    = $deviceCookieName
            DeviceCookieId      = $deviceCookieId
            ClientIp            = $clientIp
            ConfirmRequired     = $false
            ConfirmUrl          = ""
            ConfirmFinalUrl     = ""
            ConfirmHttpStatus   = ""
            ConfirmErrorMessage = ""
        }
    }
}

function Get-AbuseAdminValidationDeviceHashVariants {
    param(
        [Parameter(Mandatory=$true)][string]$DeviceCookieId
    )

    $variants = New-Object System.Collections.ArrayList

    if ([string]::IsNullOrWhiteSpace($DeviceCookieId)) {
        return @()
    }

    $deviceValue = $DeviceCookieId.Trim()

    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($deviceValue)
            $hashBytes = $sha256.ComputeHash($bytes)

            $hexLower = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
            $hexUpper = $hexLower.ToUpperInvariant()

            if (-not [string]::IsNullOrWhiteSpace($hexLower)) { [void]$variants.Add($hexLower) }
            if (-not [string]::IsNullOrWhiteSpace($hexUpper)) { [void]$variants.Add($hexUpper) }

            # ===== DB FORMAT (ASCII HEX OF HASH STRING) =====
            $asciiBytes = [System.Text.Encoding]::UTF8.GetBytes($hexLower)
            $asciiHex = ([System.BitConverter]::ToString($asciiBytes)).Replace('-', '').ToLowerInvariant()

            if (-not [string]::IsNullOrWhiteSpace($asciiHex)) { [void]$variants.Add($asciiHex) }
        } finally {
            $sha256.Dispose()
        }
    } catch {
    }

    [void]$variants.Add($deviceValue)

    return @(($variants | Select-Object -Unique))
}

function Get-AbuseAdminValidationProjectRoot {
    try {
        $resolved = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')
        if ($null -ne $resolved) {
            return ("" + $resolved.Path)
        }
    } catch {
    }

    return (Get-Location).Path
}

function Get-AbuseAdminValidationEnvValue {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)][string]$Default = ""
    )

    $envPath = Join-Path (Get-AbuseAdminValidationProjectRoot) '.env'
    if (-not (Test-Path -LiteralPath $envPath)) {
        return $Default
    }

    try {
        foreach ($line in [System.IO.File]::ReadAllLines($envPath)) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            if ($line.TrimStart().StartsWith('#')) {
                continue
            }

            $match = [regex]::Match($line, ('^{0}=(.*)$' -f [regex]::Escape($Name)))
            if (-not $match.Success -or $match.Groups.Count -lt 2) {
                continue
            }

            $value = ("" + $match.Groups[1].Value).Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                if ($value.Length -ge 2) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
            }

            return $value
        }
    } catch {
    }

    return $Default
}

function Get-AbuseAdminValidationMySqlExePath {
    $configured = Get-AbuseAdminValidationString -Name "AdminValidationMySqlExe" -Default ""
    if (-not [string]::IsNullOrWhiteSpace($configured) -and (Test-Path -LiteralPath $configured)) {
        return $configured
    }

    try {
        $command = Get-Command mysql -ErrorAction SilentlyContinue
        if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
            return ("" + $command.Source)
        }
    } catch {
    }

    try {
        $candidate = Get-ChildItem -Path 'C:\laragon\bin\mysql' -Recurse -Filter 'mysql.exe' -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1

        if ($null -ne $candidate) {
            return ("" + $candidate.FullName)
        }
    } catch {
    }

    throw "MYSQL_EXE_NOT_FOUND"
}

function Invoke-AbuseAdminValidationMySqlQuery {
    param(
        [Parameter(Mandatory=$true)][string]$Query
    )

    $mysqlExe = Get-AbuseAdminValidationMySqlExePath
    $dbHost = Get-AbuseAdminValidationString -Name "AdminValidationDbHost" -Default (Get-AbuseAdminValidationEnvValue -Name "DB_HOST" -Default "127.0.0.1")
    $dbPort = Get-AbuseAdminValidationString -Name "AdminValidationDbPort" -Default (Get-AbuseAdminValidationEnvValue -Name "DB_PORT" -Default "3306")
    $dbName = Get-AbuseAdminValidationString -Name "AdminValidationDbName" -Default (Get-AbuseAdminValidationEnvValue -Name "DB_DATABASE" -Default "")
    $dbUser = Get-AbuseAdminValidationString -Name "AdminValidationDbUser" -Default (Get-AbuseAdminValidationEnvValue -Name "DB_USERNAME" -Default "root")
    $dbPassword = Get-AbuseAdminValidationString -Name "AdminValidationDbPassword" -Default (Get-AbuseAdminValidationEnvValue -Name "DB_PASSWORD" -Default "")

    if ([string]::IsNullOrWhiteSpace($dbName)) {
        throw "ADMIN_VALIDATION_DB_NAME_MISSING"
    }

    $arguments = New-Object System.Collections.Generic.List[string]
    $arguments.Add('--batch')
    $arguments.Add('--raw')
    $arguments.Add('--skip-column-names')
    $arguments.Add('-h')
    $arguments.Add($dbHost)
    $arguments.Add('-P')
    $arguments.Add(("" + $dbPort))
    $arguments.Add('-u')
    $arguments.Add($dbUser)

    if (-not [string]::IsNullOrEmpty($dbPassword)) {
        $arguments.Add(("-p{0}" -f $dbPassword))
    }

    $arguments.Add($dbName)
    $arguments.Add('-e')
    $arguments.Add($Query)

    $output = & $mysqlExe @arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        $errorText = @($output | ForEach-Object { "" + $_ }) -join [Environment]::NewLine
        throw ("MYSQL_QUERY_FAILED: {0}" -f $errorText.Trim())
    }

    return @($output | ForEach-Object { "" + $_ })
}

function Get-AbuseAdminValidationSecurityEventsColumns {
    $cacheName = "AbuseAdminValidationSecurityEventsColumns"

    try {
        $cached = Get-Variable -Name $cacheName -Scope Script -ErrorAction Stop
        if ($null -ne $cached -and $null -ne $cached.Value) {
            return @($cached.Value)
        }
    } catch {
    }

    $columns = @()

    try {
        $lines = @(Invoke-AbuseAdminValidationMySqlQuery -Query "SHOW COLUMNS FROM security_events;")
        $names = New-Object System.Collections.ArrayList

        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            $parts = @($line -split "`t")
            if ($parts.Count -lt 1) {
                continue
            }

            $name = ("" + $parts[0]).Trim().ToLowerInvariant()
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                [void]$names.Add($name)
            }
        }

        $columns = @($names | Select-Object -Unique)
    } catch {
        $columns = @()
    }

    Set-Variable -Name $cacheName -Scope Script -Value $columns
    return @($columns)
}

function Get-AbuseAdminValidationDbRecords {
    param(
        [Parameter(Mandatory=$true)][string]$FilterType,
        [Parameter(Mandatory=$true)][string]$FilterValue,
        [Parameter(Mandatory=$false)]$FilterValues = $null,
        [Parameter(Mandatory=$false)][string]$RunId = "",
        [Parameter(Mandatory=$false)][string]$ScenarioName = ""
    )

    if ([string]::IsNullOrWhiteSpace($FilterType) -or [string]::IsNullOrWhiteSpace($FilterValue)) {
        return @()
    }

    $column = ""
    switch ($FilterType.Trim().ToLowerInvariant()) {
        'email'       { $column = 'email' }
        'device_hash' { $column = 'HEX(device_hash)' }
        default       { throw ("ADMIN_VALIDATION_UNSUPPORTED_FILTER: {0}" -f $FilterType) }
    }

    $queryCondition = ""

    if ($FilterType -eq 'device_hash') {

        $filterValues = @(ConvertTo-AbuseAdminValidationStringArray -InputObject $FilterValues)

        if ($filterValues.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($FilterValue)) {
            $filterValues = @($FilterValue)
        }

        $escapedValues = @(
            $filterValues |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { "'" + $_.Replace("'", "''").ToUpper() + "'" } |
                Select-Object -Unique
        )

        if ($escapedValues.Count -eq 0) {
            return @()
        }

        $queryCondition = ("HEX(device_hash) IN ({0})" -f ($escapedValues -join ', '))
    }
    else {
        $escapedValue = $FilterValue.Replace("'", "''")
        $queryCondition = ("{0} = '{1}'" -f $column, $escapedValue)
    }

    $queryConditions = New-Object System.Collections.ArrayList
    [void]$queryConditions.Add($queryCondition)

    $securityEventsColumns = @(Get-AbuseAdminValidationSecurityEventsColumns)
    $normalizedRunId = ("" + $RunId).Trim()
    $normalizedScenarioName = ("" + $ScenarioName).Trim()
    $auditWindowStartSql = (Get-AbuseAdminValidationString -Name "AuditWindowStartSql" -Default "").Trim()

    if (-not [string]::IsNullOrWhiteSpace($normalizedRunId) -and -not ($securityEventsColumns -contains 'run_id')) {
        throw "ADMIN_VALIDATION_RUN_ID_COLUMN_MISSING"
    }

    if (-not [string]::IsNullOrWhiteSpace($normalizedRunId) -and ($securityEventsColumns -contains 'run_id')) {
        [void]$queryConditions.Add(("run_id = '{0}'" -f $normalizedRunId.Replace("'", "''")))
    }

    if (-not [string]::IsNullOrWhiteSpace($normalizedScenarioName) -and ($securityEventsColumns -contains 'scenario_name')) {
        [void]$queryConditions.Add(("scenario_name = '{0}'" -f $normalizedScenarioName.Replace("'", "''")))
    }

    if (-not [string]::IsNullOrWhiteSpace($auditWindowStartSql) -and ($securityEventsColumns -contains 'created_at')) {
        [void]$queryConditions.Add(("created_at >= '{0}'" -f $auditWindowStartSql.Replace("'", "''")))
    }

    $query = "SELECT COALESCE(email,''), COALESCE(ip,''), COALESCE(HEX(device_hash),'') FROM security_events WHERE {0} ORDER BY id DESC;" -f (@($queryConditions) -join ' AND ')

    $lines = @(Invoke-AbuseAdminValidationMySqlQuery -Query $query)
    $records = New-Object System.Collections.ArrayList

    foreach ($line in $lines) {

        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = @($line -split "`t", 3)

        while ($parts.Count -lt 3) {
            $parts += ""
        }

        [void]$records.Add([PSCustomObject]@{
            Email      = ("" + $parts[0]).Trim()
            Ip         = ("" + $parts[1]).Trim()
            DeviceHash = ("" + $parts[2]).Trim().ToLower()
        })
    }

    return @($records.ToArray())
}

function Get-AbuseAdminValidationExpectedIncidentType {
    param(
        [Parameter(Mandatory=$false)][string]$ScenarioName = ""
    )

    switch -Regex (($ScenarioName + "").Trim()) {
        '^abuse_device_reuse$' { return 'credential_stuffing' }
        '^abuse_account_sharing$' { return 'account_sharing' }
        '^abuse_bot_pattern$' { return 'bot_pattern' }
        '^abuse_device_cluster_\d+$' { return 'device_cluster' }
        default { return '' }
    }
}

function Get-AbuseAdminValidationDbIncidentStats {
    param(
        [Parameter(Mandatory=$true)][string]$FilterType,
        [Parameter(Mandatory=$true)][string]$FilterValue,
        [Parameter(Mandatory=$false)]$FilterValues = $null,
        [Parameter(Mandatory=$false)][string]$RunId = "",
        [Parameter(Mandatory=$false)][string]$ScenarioName = ""
    )

    if ([string]::IsNullOrWhiteSpace($FilterType) -or [string]::IsNullOrWhiteSpace($FilterValue)) {
        return [PSCustomObject]@{
            MatchedIncidents     = 0
            LinkedIncidentEvents = 0
            IncidentTypes        = @()
        }
    }

    $column = ""
    switch ($FilterType.Trim().ToLowerInvariant()) {
        'email'       { $column = 'se.email' }
        'device_hash' { $column = 'HEX(se.device_hash)' }
        default       { throw ("ADMIN_VALIDATION_UNSUPPORTED_FILTER: {0}" -f $FilterType) }
    }

    $queryCondition = ""

    if ($FilterType -eq 'device_hash') {
        $filterValues = @(ConvertTo-AbuseAdminValidationStringArray -InputObject $FilterValues)

        if ($filterValues.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($FilterValue)) {
            $filterValues = @($FilterValue)
        }

        $escapedValues = @(
            $filterValues |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { "'" + $_.Replace("'", "''").ToUpper() + "'" } |
                Select-Object -Unique
        )

        if ($escapedValues.Count -eq 0) {
            return [PSCustomObject]@{
                MatchedIncidents     = 0
                LinkedIncidentEvents = 0
                IncidentTypes        = @()
            }
        }

        $queryCondition = ("HEX(se.device_hash) IN ({0})" -f ($escapedValues -join ', '))
    }
    else {
        $escapedValue = $FilterValue.Replace("'", "''")
        $queryCondition = ("{0} = '{1}'" -f $column, $escapedValue)
    }

    $queryConditions = New-Object System.Collections.ArrayList
    [void]$queryConditions.Add($queryCondition)

    $securityEventsColumns = @(Get-AbuseAdminValidationSecurityEventsColumns)
    $normalizedRunId = ("" + $RunId).Trim()
    $normalizedScenarioName = ("" + $ScenarioName).Trim()
    $auditWindowStartSql = (Get-AbuseAdminValidationString -Name "AuditWindowStartSql" -Default "").Trim()

    if (-not [string]::IsNullOrWhiteSpace($normalizedRunId) -and -not ($securityEventsColumns -contains 'run_id')) {
        throw "ADMIN_VALIDATION_RUN_ID_COLUMN_MISSING"
    }

    if (-not [string]::IsNullOrWhiteSpace($normalizedRunId) -and ($securityEventsColumns -contains 'run_id')) {
        [void]$queryConditions.Add(("se.run_id = '{0}'" -f $normalizedRunId.Replace("'", "''")))
    }

    if (-not [string]::IsNullOrWhiteSpace($normalizedScenarioName) -and ($securityEventsColumns -contains 'scenario_name')) {
        [void]$queryConditions.Add(("se.scenario_name = '{0}'" -f $normalizedScenarioName.Replace("'", "''")))
    }

    if (-not [string]::IsNullOrWhiteSpace($auditWindowStartSql) -and ($securityEventsColumns -contains 'created_at')) {
        [void]$queryConditions.Add(("se.created_at >= '{0}'" -f $auditWindowStartSql.Replace("'", "''")))
    }

    $query = @"
SELECT
    COALESCE(sie.incident_id, ''),
    COALESCE(si.type, ''),
    COALESCE(sie.security_event_id, '')
FROM security_events se
INNER JOIN security_incident_events sie ON sie.security_event_id = se.id
INNER JOIN security_incidents si ON si.id = sie.incident_id
WHERE $(@($queryConditions) -join ' AND ')
ORDER BY sie.incident_id DESC, sie.security_event_id DESC;
"@

    $lines = @(Invoke-AbuseAdminValidationMySqlQuery -Query $query)
    $incidentIds = New-Object System.Collections.ArrayList
    $incidentTypes = New-Object System.Collections.ArrayList
    $linkedEventIds = New-Object System.Collections.ArrayList

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = @($line -split "`t", 3)
        while ($parts.Count -lt 3) {
            $parts += ""
        }

        $incidentId = ("" + $parts[0]).Trim()
        $incidentType = ("" + $parts[1]).Trim()
        $securityEventId = ("" + $parts[2]).Trim()

        if (-not [string]::IsNullOrWhiteSpace($incidentId)) {
            [void]$incidentIds.Add($incidentId)
        }

        if (-not [string]::IsNullOrWhiteSpace($incidentType)) {
            [void]$incidentTypes.Add($incidentType)
        }

        if (-not [string]::IsNullOrWhiteSpace($securityEventId)) {
            [void]$linkedEventIds.Add($securityEventId)
        }
    }

    return [PSCustomObject]@{
        MatchedIncidents     = @($incidentIds | Select-Object -Unique).Count
        LinkedIncidentEvents = @($linkedEventIds | Select-Object -Unique).Count
        IncidentTypes        = @(ConvertTo-AbuseAdminValidationStringArray -InputObject ($incidentTypes | Select-Object -Unique))
    }
}

function New-AbuseAdminValidationDbCheck {
    param(
        [Parameter(Mandatory=$true)]$ScenarioDefinition
    )

    $runId = Get-AbuseAdminValidationRunId
    $records = @(Get-AbuseAdminValidationDbRecords -FilterType $ScenarioDefinition.FilterType -FilterValue $ScenarioDefinition.FilterValue -FilterValues $ScenarioDefinition.DeviceHashes -RunId $runId -ScenarioName $ScenarioDefinition.ScenarioName)
    $dbEmails = @(ConvertTo-AbuseAdminValidationStringArray -InputObject ($records | Where-Object { $_.Email -ne "" } | Select-Object -ExpandProperty Email -Unique))
    $dbIps = @(ConvertTo-AbuseAdminValidationStringArray -InputObject ($records | Where-Object { $_.Ip -ne "" } | Select-Object -ExpandProperty Ip -Unique))
    $dbDeviceHashes = @(ConvertTo-AbuseAdminValidationStringArray -InputObject ($records | Where-Object { $_.DeviceHash -ne "" } | Select-Object -ExpandProperty DeviceHash -Unique))

    Write-Host ("DEBUG VALIDATION READ: RunId={0} Scenario={1} Records={2}" -f $runId, $ScenarioDefinition.ScenarioName, @($records).Count)

    Write-Host ("[SCENARIO: {0}]" -f $ScenarioDefinition.ScenarioName)
    Write-Host "DEBUG DB READ"
    Write-Host ("Scenario: {0}" -f $ScenarioDefinition.ScenarioName)
    Write-Host ("DBRecords: {0}" -f @($records).Count)
    Write-Host ("DBEmails: {0}" -f ($dbEmails -join ", "))
    Write-Host ("DBIps: {0}" -f ($dbIps -join ", "))
    Write-Host ("DBDeviceHashes: {0}" -f ($dbDeviceHashes -join ", "))
    Write-Host ""

    $emailsFound = New-Object System.Collections.ArrayList
    $ipsFound = New-Object System.Collections.ArrayList
    $hashesFound = New-Object System.Collections.ArrayList

    foreach ($email in @(ConvertTo-AbuseAdminValidationStringArray -InputObject $ScenarioDefinition.Emails)) {
        if ($dbEmails -contains $email) {
            [void]$emailsFound.Add($email)
        }
    }

    foreach ($ip in @(ConvertTo-AbuseAdminValidationStringArray -InputObject $ScenarioDefinition.Ips)) {
        if ($dbIps -contains $ip) {
            [void]$ipsFound.Add($ip)
        }
    }

    foreach ($hash in @(ConvertTo-AbuseAdminValidationStringArray -InputObject $ScenarioDefinition.DeviceHashes)) {
        if ($dbDeviceHashes -contains $hash) {
            [void]$hashesFound.Add($hash)
        }
    }

    $expectedIncidentType = Get-AbuseAdminValidationExpectedIncidentType -ScenarioName $ScenarioDefinition.ScenarioName
    $incidentStats = Get-AbuseAdminValidationDbIncidentStats `
        -FilterType $ScenarioDefinition.FilterType `
        -FilterValue $ScenarioDefinition.FilterValue `
        -FilterValues $ScenarioDefinition.DeviceHashes `
        -RunId $runId `
        -ScenarioName $ScenarioDefinition.ScenarioName

    $matchedIncidents = [int]$incidentStats.MatchedIncidents
    $linkedIncidentEvents = [int]$incidentStats.LinkedIncidentEvents
    $incidentTypes = @(ConvertTo-AbuseAdminValidationStringArray -InputObject $incidentStats.IncidentTypes)
    $scenarioPatternMatched = $false

    if ([string]::IsNullOrWhiteSpace($expectedIncidentType)) {
        $scenarioPatternMatched = ($incidentTypes.Count -gt 0)
    } else {
        $scenarioPatternMatched = ($incidentTypes -contains $expectedIncidentType)
    }

    $incidentFound = ($matchedIncidents -ge 1)
    $eventsLinked = ($linkedIncidentEvents -ge 1)

    Write-Host ("[SCENARIO: {0}]" -f $ScenarioDefinition.ScenarioName)
    Write-Host "DEBUG INCIDENT VALIDATION"
    Write-Host ("ExpectedIncidentType: {0}" -f $expectedIncidentType)
    Write-Host ("MatchedIncidents: {0}" -f $matchedIncidents)
    Write-Host ("LinkedIncidentEvents: {0}" -f $linkedIncidentEvents)
    Write-Host ("IncidentTypes: {0}" -f ($incidentTypes -join ", "))
    Write-Host ("ScenarioPatternMatched: {0}" -f $scenarioPatternMatched)
    Write-Host ""

    $result = "FAIL"
    $errorMessage = "INCIDENT_NOT_FOUND"

    if ($incidentFound -and $eventsLinked -and $scenarioPatternMatched) {
        $result = "PASS"
        $errorMessage = "Incident detection matched scenario events."
    } elseif ($incidentFound -and $eventsLinked) {
        $errorMessage = "INCIDENT_TYPE_MISMATCH"
    } elseif ($incidentFound) {
        $errorMessage = "INCIDENT_EVENTS_NOT_LINKED"
    } else {
        $errorMessage = "NO_INCIDENT_FOUND"
    }

    return [PSCustomObject]@{
        ScenarioName              = $ScenarioDefinition.ScenarioName
        ExpectedPattern           = $ScenarioDefinition.ExpectedPattern
        FilterType                = $ScenarioDefinition.FilterType
        FilterValue               = $ScenarioDefinition.FilterValue
        CheckUrl                  = ("security_events WHERE {0}='{1}'" -f $ScenarioDefinition.FilterType, $ScenarioDefinition.FilterValue)
        HttpStatus                = "DB"
        FinalUrl                  = "security_events"
        ExpectedEmailCount        = @($ScenarioDefinition.Emails).Count
        FoundEmailCount           = @($emailsFound.ToArray()).Count
        ExpectedIpCount           = @($ScenarioDefinition.Ips).Count
        FoundIpCount              = @($ipsFound.ToArray()).Count
        ExpectedDeviceHashes      = @($ScenarioDefinition.DeviceHashes)
        FoundDeviceHashes         = @($hashesFound.ToArray())
        EmailsExpected            = @($ScenarioDefinition.Emails)
        EmailsFound               = @($emailsFound.ToArray())
        IpsExpected               = @($ScenarioDefinition.Ips)
        IpsFound                  = @($ipsFound.ToArray())
        ObservedRequestCount      = @($records).Count
        ObservedDistinctEmailCount = @($dbEmails).Count
        ObservedDistinctIpCount   = @($dbIps).Count
        ObservedDistinctDeviceCount = @($dbDeviceHashes).Count
        ExpectedRequestCount      = [int]$ScenarioDefinition.ExpectedRequestCount
        DbRecordCount             = @($records).Count
        DbEmailCount              = @($dbEmails).Count
        DbIpCount                 = @($dbIps).Count
        DbDeviceHashCount         = @($dbDeviceHashes).Count
        MatchedIncidents          = $matchedIncidents
        LinkedIncidentEvents      = $linkedIncidentEvents
        ExpectedIncidentType      = $expectedIncidentType
        IncidentTypes             = @($incidentTypes)
        ScenarioPatternMatched    = $scenarioPatternMatched
        Result                    = $result
        ErrorMessage              = $errorMessage
    }
}

function New-AbuseAdminValidationCheck {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName,
        [Parameter(Mandatory=$true)][string]$FilterType,
        [Parameter(Mandatory=$true)][string]$FilterValue,
        [Parameter(Mandatory=$true)][string]$ExpectedPattern,
        [Parameter(Mandatory=$false)][string[]]$ExpectedEmails = @(),
        [Parameter(Mandatory=$false)][string[]]$ExpectedIps = @(),
        [Parameter(Mandatory=$false)][string[]]$ExpectedDeviceHashes = @(),
        [Parameter(Mandatory=$true)][string]$CheckUrl,
        [Parameter(Mandatory=$true)][string]$Html,
        [Parameter(Mandatory=$true)][string]$HttpStatus,
        [Parameter(Mandatory=$true)][string]$FinalUrl
    )

    $linkedValues = Get-AbuseAdminValidationLinkedValues -Html $Html
    $linkedEmails = @(ConvertTo-AbuseAdminValidationStringArray -InputObject $linkedValues.Emails)
    $linkedIps = @(ConvertTo-AbuseAdminValidationStringArray -InputObject $linkedValues.Ips)
    $linkedDeviceHashes = @(ConvertTo-AbuseAdminValidationStringArray -InputObject $linkedValues.DeviceHashes)

    $emailsFound = New-Object System.Collections.ArrayList
    $ipsFound = New-Object System.Collections.ArrayList
    $hashesFound = New-Object System.Collections.ArrayList

    foreach ($email in @(ConvertTo-AbuseAdminValidationStringArray -InputObject $ExpectedEmails)) {
        if ([string]::IsNullOrWhiteSpace($email)) {
            continue
        }

        if ($linkedEmails -contains $email) {
            [void]$emailsFound.Add($email)
        }
    }

    foreach ($ip in @(ConvertTo-AbuseAdminValidationStringArray -InputObject $ExpectedIps)) {
        if ([string]::IsNullOrWhiteSpace($ip)) {
            continue
        }

        if ($linkedIps -contains $ip) {
            [void]$ipsFound.Add($ip)
        }
    }

    foreach ($hash in @(ConvertTo-AbuseAdminValidationStringArray -InputObject $ExpectedDeviceHashes)) {
        if ([string]::IsNullOrWhiteSpace($hash)) {
            continue
        }

        if ($linkedDeviceHashes -contains $hash) {
            [void]$hashesFound.Add($hash)
        }
    }

    $expectedEmailCount = @($ExpectedEmails).Count
    $expectedIpCount = @($ExpectedIps).Count
    $expectedHashCount = @($ExpectedDeviceHashes).Count

    $foundEmailCount = $emailsFound.Count
    $foundIpCount = $ipsFound.Count
    $foundHashCount = $hashesFound.Count

    $deviceCount = $foundHashCount
    $expectedDeviceCount = $expectedHashCount
    $emailCount = $foundEmailCount
    $expectedEmailCount = $expectedEmailCount
    $ipCount = $foundIpCount
    $expectedIpCount = $expectedIpCount

    Write-Host ""
    Write-Host ("[SCENARIO: {0}]" -f $ScenarioName)
    Write-Host "DEBUG SCENARIO VALIDATION"
    Write-Host ("Scenario: {0}" -f $ScenarioName)
    Write-Host ("DeviceCount: {0} / Expected: {1}" -f $deviceCount, $expectedDeviceCount)
    Write-Host ("EmailCount:  {0} / Expected: {1}" -f $emailCount, $expectedEmailCount)
    Write-Host ("IpCount:     {0} / Expected: {1}" -f $ipCount, $expectedIpCount)
    Write-Host ""

    if (
        ($deviceCount -eq $expectedDeviceCount) -and
        ($emailCount -ge $expectedEmailCount) -and
        ($ipCount -ge $expectedIpCount)
    ) {
        $result = "PASS"
    } else {
        $result = "WARN"
    }

    return [PSCustomObject]@{
        ScenarioName          = $ScenarioName
        ExpectedPattern       = $ExpectedPattern
        FilterType            = $FilterType
        FilterValue           = $FilterValue
        CheckUrl              = $CheckUrl
        HttpStatus            = $HttpStatus
        FinalUrl              = $FinalUrl
        ExpectedEmailCount    = $expectedEmailCount
        FoundEmailCount       = $foundEmailCount
        ExpectedIpCount       = $expectedIpCount
        FoundIpCount          = $foundIpCount
        ExpectedDeviceHashes  = @($ExpectedDeviceHashes)
        FoundDeviceHashes     = @($hashesFound.ToArray())
        EmailsExpected        = @($ExpectedEmails)
        EmailsFound           = @($emailsFound.ToArray())
        IpsExpected           = @($ExpectedIps)
        IpsFound              = @($ipsFound.ToArray())
        Result                = $result
    }
}

function Get-AbuseAdminValidationScenarioGroups {
    param(
        [Parameter(Mandatory=$true)]$SimulationResult
    )

    $results = @()
    try {
        $results = @($SimulationResult.Results)
    } catch {
        $results = @()
    }

    if ($results.Count -eq 0) {
        return @()
    }

    $groups = @($results | Group-Object ScenarioName)
    $groups = @($groups | Sort-Object @{ Expression = { Get-AbuseAdminValidationScenarioSortIndex -ScenarioName $_.Name } }, @{ Expression = { $_.Name } })

    return $groups
}

function Get-AbuseAdminValidationExpectedPattern {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName
    )

    switch -Regex ($ScenarioName) {
        '^abuse_device_reuse$'       { return "1 Device -> viele Emails -> viele IPs" }
        '^abuse_account_sharing$'    { return "1 Email -> viele Devices -> viele IPs" }
        '^abuse_bot_pattern$'        { return "1 Device -> viele Emails -> sehr viele IPs" }
        '^abuse_device_cluster_\d+$' { return "1 Device pro Cluster -> wenige Emails mehrfach -> begrenzter IP-Bereich" }
        default                      { return "" }
    }
}

function Get-AbuseAdminValidationScenarioCheckDefinition {
    param(
        [Parameter(Mandatory=$true)]$ScenarioGroup,
        [Parameter(Mandatory=$true)][int]$MaxSamplesPerCheck
    )

    $scenarioName = "" + $ScenarioGroup.Name
    $rows = @($ScenarioGroup.Group)
    $sampleRows = @($rows | Select-Object -First $MaxSamplesPerCheck)

    $emails = @(ConvertTo-AbuseAdminValidationStringArray -InputObject ($rows | Select-Object -ExpandProperty Email -Unique))
    $ips = @(ConvertTo-AbuseAdminValidationStringArray -InputObject ($rows | Select-Object -ExpandProperty AttemptIp -Unique))
    $devices = @()

    foreach ($row in $rows) {
        $value = ""

        if ($row.PSObject.Properties['DeviceCookieId']) {
            $value = "" + $row.DeviceCookieId
        }
        elseif ($row.PSObject.Properties['DeviceId']) {
            $value = "" + $row.DeviceId
        }
        elseif ($row.PSObject.Properties['Device']) {
            $value = "" + $row.Device
        }
        elseif ($row.PSObject.Properties['DeviceIdentifier']) {
            $value = "" + $row.DeviceIdentifier
        }

        $value = $value.Trim()

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $devices += $value
        }
    }

    $devices = @(ConvertTo-AbuseAdminValidationStringArray -InputObject ($devices | Select-Object -Unique))

    $filterType = ""
    $filterValue = ""
    $deviceHashes = @()

    switch -Regex ($scenarioName) {
        '^abuse_account_sharing$' {
            $filterType = "email"
            $filterValue = ""
            try { $filterValue = "" + ($rows | Select-Object -First 1 -ExpandProperty Email) } catch { $filterValue = "" }
            $deviceHashes = @()
        }

        default {
            $filterType = "device_hash"
            $primaryDevice = ""
            try { $primaryDevice = "" + ($rows | Select-Object -First 1 -ExpandProperty DeviceCookieId) } catch { $primaryDevice = "" }
            $filterValue = ""
            $deviceHashes = @(Get-AbuseAdminValidationDeviceHashVariants -DeviceCookieId $primaryDevice)
            if (@($deviceHashes).Count -gt 0) {
                $filterValue = "" + $deviceHashes[0]
            }
        }
    }

    Write-Host ("[SCENARIO: {0}]" -f $scenarioName)
    Write-Host "DEBUG SCENARIO DEFINITION"
    Write-Host ("Scenario: {0}" -f $scenarioName)
    Write-Host ("RowsCount: {0}" -f @($rows).Count)
    Write-Host ("SampleRowsCount: {0}" -f @($sampleRows).Count)
    Write-Host ("Emails: {0}" -f ($emails -join ", "))
    Write-Host ("IPs: {0}" -f ($ips -join ", "))
    Write-Host ("DeviceIds: {0}" -f ($devices -join ", "))
    Write-Host ("DeviceHashes: {0}" -f ($deviceHashes -join ", "))
    Write-Host ""

    return [PSCustomObject]@{
        ScenarioName     = $scenarioName
        ExpectedPattern  = (Get-AbuseAdminValidationExpectedPattern -ScenarioName $scenarioName)
        FilterType       = $filterType
        FilterValue      = $filterValue
        Emails           = $emails
        Ips              = $ips
        DeviceIds        = $devices
        DeviceHashes     = $deviceHashes
        ExpectedRequestCount = @($rows).Count
        ExpectedDistinctEmailCount = @($rows | Select-Object -ExpandProperty Email -Unique).Count
        ExpectedDistinctIpCount = @($rows | Select-Object -ExpandProperty AttemptIp -Unique).Count
        ExpectedDistinctDeviceCount = @($rows | Select-Object -ExpandProperty DeviceCookieId -Unique).Count
    }
}

function Invoke-AbuseAdminValidationScenario {
    param(
        [Parameter(Mandatory=$false)]$LoginSession = $null,
        [Parameter(Mandatory=$true)]$ScenarioDefinition
    )

    $checkUrl = ""

    try {
        $useDatabaseValidation = Get-AbuseAdminValidationBoolean -Name "AdminValidationUseDatabase" -Default $true

        if ($useDatabaseValidation) {
            return (New-AbuseAdminValidationDbCheck -ScenarioDefinition $ScenarioDefinition)
        }

        $baseUrl = Get-AbuseAdminValidationBaseUrl
        $eventsPath = Get-AbuseAdminValidationString -Name "AdminValidationEventsPath" -Default "/admin/security/events"
        $eventsUrl = Join-AbuseAdminValidationUrl -BaseUrl $baseUrl -Path $eventsPath
        $queryParts = New-Object System.Collections.Generic.List[string]

        if (-not [string]::IsNullOrWhiteSpace($ScenarioDefinition.FilterType) -and -not [string]::IsNullOrWhiteSpace($ScenarioDefinition.FilterValue)) {
            $queryValue = ""
            try { $queryValue = [System.Uri]::EscapeDataString($ScenarioDefinition.FilterValue) } catch { $queryValue = "" }

            if (-not [string]::IsNullOrWhiteSpace($queryValue)) {
                $queryParts.Add(("{0}={1}" -f $ScenarioDefinition.FilterType, $queryValue))
            }
        }

        $queryParts.Add("per_page=100")

        $checkUrl = $eventsUrl
        if ($queryParts.Count -gt 0) {
            $checkUrl = $eventsUrl + "?" + ([string]::Join("&", $queryParts.ToArray()))
        }

        $headers = Get-AbuseAdminValidationDefaultHeaders
        $response = Invoke-AbuseAdminValidationRequest -Method "GET" -Url $checkUrl -Session $LoginSession.WebSession -Headers $headers
        $html = "" + $response.FinalHtml

        $httpStatus = ""
        $finalUrl = ""
        try { $httpStatus = "" + $response.InitialStatus } catch { $httpStatus = "" }
        try { $finalUrl = "" + $response.FinalUrl } catch { $finalUrl = "" }

        if (Test-AbuseAdminValidationIsLoginUrl -Url $finalUrl) {
            $check = New-AbuseAdminValidationCheck `
                -ScenarioName $ScenarioDefinition.ScenarioName `
                -FilterType $ScenarioDefinition.FilterType `
                -FilterValue $ScenarioDefinition.FilterValue `
                -ExpectedPattern $ScenarioDefinition.ExpectedPattern `
                -ExpectedEmails @($ScenarioDefinition.Emails) `
                -ExpectedIps @($ScenarioDefinition.Ips) `
                -ExpectedDeviceHashes @($ScenarioDefinition.DeviceHashes) `
                -CheckUrl $checkUrl `
                -Html $html `
                -HttpStatus $httpStatus `
                -FinalUrl $finalUrl

            $check | Add-Member -NotePropertyName "ErrorMessage" -NotePropertyValue "EVENTS_REQUEST_REDIRECTED_TO_LOGIN" -Force
            $check.Result = "FAIL"
            return $check
        }

        if (Test-AbuseAdminValidationIsConfirmPasswordUrl -Url $finalUrl) {
            $check = New-AbuseAdminValidationCheck `
                -ScenarioName $ScenarioDefinition.ScenarioName `
                -FilterType $ScenarioDefinition.FilterType `
                -FilterValue $ScenarioDefinition.FilterValue `
                -ExpectedPattern $ScenarioDefinition.ExpectedPattern `
                -ExpectedEmails @($ScenarioDefinition.Emails) `
                -ExpectedIps @($ScenarioDefinition.Ips) `
                -ExpectedDeviceHashes @($ScenarioDefinition.DeviceHashes) `
                -CheckUrl $checkUrl `
                -Html $html `
                -HttpStatus $httpStatus `
                -FinalUrl $finalUrl

            $check | Add-Member -NotePropertyName "ErrorMessage" -NotePropertyValue "EVENTS_REQUEST_REDIRECTED_TO_CONFIRM_PASSWORD" -Force
            $check.Result = "FAIL"
            return $check
        }

        if (Test-AbuseAdminValidationLooksLikeLoginHtml -Html $html) {
            $check = New-AbuseAdminValidationCheck `
                -ScenarioName $ScenarioDefinition.ScenarioName `
                -FilterType $ScenarioDefinition.FilterType `
                -FilterValue $ScenarioDefinition.FilterValue `
                -ExpectedPattern $ScenarioDefinition.ExpectedPattern `
                -ExpectedEmails @($ScenarioDefinition.Emails) `
                -ExpectedIps @($ScenarioDefinition.Ips) `
                -ExpectedDeviceHashes @($ScenarioDefinition.DeviceHashes) `
                -CheckUrl $checkUrl `
                -Html $html `
                -HttpStatus $httpStatus `
                -FinalUrl $finalUrl

            $check | Add-Member -NotePropertyName "ErrorMessage" -NotePropertyValue "EVENTS_RESPONSE_LOOKS_LIKE_LOGIN_PAGE" -Force
            $check.Result = "FAIL"
            return $check
        }

        return (New-AbuseAdminValidationCheck `
            -ScenarioName $ScenarioDefinition.ScenarioName `
            -FilterType $ScenarioDefinition.FilterType `
            -FilterValue $ScenarioDefinition.FilterValue `
            -ExpectedPattern $ScenarioDefinition.ExpectedPattern `
            -ExpectedEmails @($ScenarioDefinition.Emails) `
            -ExpectedIps @($ScenarioDefinition.Ips) `
            -ExpectedDeviceHashes @($ScenarioDefinition.DeviceHashes) `
            -CheckUrl $checkUrl `
            -Html $html `
            -HttpStatus $httpStatus `
            -FinalUrl $finalUrl)
    } catch {
        return [PSCustomObject]@{
            ScenarioName          = $ScenarioDefinition.ScenarioName
            ExpectedPattern       = $ScenarioDefinition.ExpectedPattern
            FilterType            = $ScenarioDefinition.FilterType
            FilterValue           = $ScenarioDefinition.FilterValue
            CheckUrl              = $checkUrl
            HttpStatus            = ""
            FinalUrl              = ""
            ExpectedEmailCount    = @($ScenarioDefinition.Emails).Count
            FoundEmailCount       = 0
            ExpectedIpCount       = @($ScenarioDefinition.Ips).Count
            FoundIpCount          = 0
            ExpectedDeviceHashes  = @($ScenarioDefinition.DeviceHashes)
            FoundDeviceHashes     = @()
            EmailsExpected        = @($ScenarioDefinition.Emails)
            EmailsFound           = @()
            IpsExpected           = @($ScenarioDefinition.Ips)
            IpsFound              = @()
            Result                = "FAIL"
            ErrorMessage          = $_.Exception.Message
        }
    }
}

function Export-AbuseAdminValidationResults {
    param(
        [Parameter(Mandatory=$true)]$ValidationResult
    )

    $runId = Get-AbuseAdminValidationRunId
    if ([string]::IsNullOrWhiteSpace($runId)) {
        $runId = (Get-Date).ToString("ddMMyyyy-HHmmss")
    }
    $exportRunDir = Get-AbuseAdminValidationString -Name "ExportRunDir" -Default ""

    if ([string]::IsNullOrWhiteSpace($exportRunDir)) {
        $exportHtmlDir = Get-AbuseAdminValidationString -Name "ExportHtmlDir" -Default ""
        if (-not [string]::IsNullOrWhiteSpace($exportHtmlDir)) {
            $exportRunDir = Join-Path $exportHtmlDir $runId
        } else {
            $exportRunDir = Join-Path (Get-Location).Path $runId
        }
    }

    if (-not (Test-Path -LiteralPath $exportRunDir)) {
        [void](New-Item -ItemType Directory -Path $exportRunDir -Force)
    }

    $txtPath = Join-Path $exportRunDir ("{0}_abuse_admin_checks.txt" -f $runId)
    $jsonPath = Join-Path $exportRunDir ("{0}_abuse_admin_checks.json" -f $runId)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("ABUSE ADMIN VALIDATION")
    $lines.Add(("RunId: {0}" -f $runId))
    $lines.Add(("GeneratedAt: {0}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")))
    $lines.Add(("LoginSuccess: {0}" -f $ValidationResult.LoginSuccess))
    $lines.Add(("LoginErrorMessage: {0}" -f $ValidationResult.LoginErrorMessage))
    $lines.Add(("LoginHttpStatus: {0}" -f $ValidationResult.LoginHttpStatus))
    $lines.Add(("LoginFinalUrl: {0}" -f $ValidationResult.LoginFinalUrl))
    $lines.Add(("LoginDeviceCookieName: {0}" -f $ValidationResult.LoginDeviceCookieName))
    $lines.Add(("LoginDeviceCookieId: {0}" -f $ValidationResult.LoginDeviceCookieId))
    $lines.Add(("LoginClientIp: {0}" -f $ValidationResult.LoginClientIp))
    $lines.Add(("LoginResponseSnippet: {0}" -f $ValidationResult.LoginResponseSnippet))
    $lines.Add(("ConfirmPasswordRequired: {0}" -f $ValidationResult.ConfirmPasswordRequired))
    $lines.Add(("ConfirmPasswordSuccess: {0}" -f $ValidationResult.ConfirmPasswordSuccess))
    $lines.Add(("ConfirmPasswordErrorMessage: {0}" -f $ValidationResult.ConfirmPasswordErrorMessage))
    $lines.Add("")

    foreach ($check in @($ValidationResult.Checks)) {
        $lines.Add(("{0} -> {1}" -f $check.ScenarioName, $check.Result))
        $lines.Add(("  Filter: {0}={1}" -f $check.FilterType, $check.FilterValue))
        $lines.Add(("  EmailsFound: {0}/{1}" -f $check.FoundEmailCount, $check.ExpectedEmailCount))
        $lines.Add(("  IPsFound: {0}/{1}" -f $check.FoundIpCount, $check.ExpectedIpCount))
        $lines.Add(("  DeviceHashesFound: {0}/{1}" -f @($check.FoundDeviceHashes).Count, @($check.ExpectedDeviceHashes).Count))
        $lines.Add(("  Url: {0}" -f $check.CheckUrl))
        $lines.Add(("  FinalUrl: {0}" -f $check.FinalUrl))
        $lines.Add(("  HttpStatus: {0}" -f $check.HttpStatus))

        if ($null -ne $check.PSObject.Properties['ErrorMessage']) {
            $errorMessage = "" + $check.ErrorMessage
            if (-not [string]::IsNullOrWhiteSpace($errorMessage)) {
                $lines.Add(("  Error: {0}" -f $errorMessage))
            }
        }

        $lines.Add("")
    }

    [System.IO.File]::WriteAllLines($txtPath, $lines, [System.Text.Encoding]::UTF8)

    $jsonObject = [PSCustomObject]@{
        RunId                       = $runId
        GeneratedAt                 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        LoginSuccess                = $ValidationResult.LoginSuccess
        LoginErrorMessage           = $ValidationResult.LoginErrorMessage
        LoginHttpStatus             = $ValidationResult.LoginHttpStatus
        LoginFinalUrl               = $ValidationResult.LoginFinalUrl
        LoginDeviceCookieName       = $ValidationResult.LoginDeviceCookieName
        LoginDeviceCookieId         = $ValidationResult.LoginDeviceCookieId
        LoginClientIp               = $ValidationResult.LoginClientIp
        LoginResponseSnippet        = $ValidationResult.LoginResponseSnippet
        ConfirmPasswordRequired     = $ValidationResult.ConfirmPasswordRequired
        ConfirmPasswordSuccess      = $ValidationResult.ConfirmPasswordSuccess
        ConfirmPasswordErrorMessage = $ValidationResult.ConfirmPasswordErrorMessage
        EventsPath                  = $ValidationResult.EventsPath
        Checks                      = @($ValidationResult.Checks)
        Summary                     = $ValidationResult.Summary
    }

    ($jsonObject | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    return [PSCustomObject]@{
        ChecksTxtPath  = $txtPath
        ChecksJsonPath = $jsonPath
    }
}

function Invoke-AbuseAdminValidation {
    param(
        [Parameter(Mandatory=$true)]$SimulationResult
    )

    $enabled = Get-AbuseAdminValidationBoolean -Name "AdminValidationEnabled" -Default $false
    $useDatabaseValidation = Get-AbuseAdminValidationBoolean -Name "AdminValidationUseDatabase" -Default $true
    $eventsPath = Get-AbuseAdminValidationString -Name "AdminValidationEventsPath" -Default "/admin/security/events"
    $maxSamplesPerCheck = Get-AbuseAdminValidationInt -Name "AdminValidationMaxSamplesPerCheck" -Default 3

    Write-Host ""
    Write-Host ("=" * 70)
    Write-Host "ABUSE ADMIN VALIDATION"
    Write-Host ("=" * 70)

    if (-not $enabled) {
        Write-Host "SKIP: AdminValidationEnabled = false"

        $skipResult = [PSCustomObject]@{
            LoginSuccess                = $false
            LoginErrorMessage           = "ADMIN_VALIDATION_DISABLED"
            LoginHttpStatus             = ""
            LoginFinalUrl               = ""
            LoginDeviceCookieName       = ""
            LoginDeviceCookieId         = ""
            LoginClientIp               = ""
            LoginResponseSnippet        = ""
            ConfirmPasswordRequired     = $false
            ConfirmPasswordSuccess      = $false
            ConfirmPasswordErrorMessage = ""
            EventsPath                  = $eventsPath
            Checks                      = @()
            Summary                     = [PSCustomObject]@{
                Pass = 0
                Warn = 0
                Fail = 0
            }
            ChecksTxtPath               = ""
            ChecksJsonPath              = ""
        }

        return $skipResult
    }

    $loginSession = $null
    if ($useDatabaseValidation) {
        Write-Host ("AdminLogin -> SKIP (DB validation mode)")
        Write-Host ("ConfirmPassword -> SKIP (DB validation mode)")
    } else {
        $loginSession = Get-AbuseAdminValidationLoginSession
        if (-not $loginSession.Success) {
            Write-Host ("AdminLogin -> FAIL ({0})" -f $loginSession.ErrorMessage)

            $failedLoginResult = [PSCustomObject]@{
                LoginSuccess                = $false
                LoginErrorMessage           = $loginSession.ErrorMessage
                LoginHttpStatus             = $loginSession.HttpStatus
                LoginFinalUrl               = $loginSession.FinalUrl
                LoginDeviceCookieName       = $loginSession.DeviceCookieName
                LoginDeviceCookieId         = $loginSession.DeviceCookieId
                LoginClientIp               = $loginSession.ClientIp
                LoginResponseSnippet        = $loginSession.DashboardSnippet
                ConfirmPasswordRequired     = [bool]$loginSession.ConfirmRequired
                ConfirmPasswordSuccess      = $false
                ConfirmPasswordErrorMessage = $loginSession.ConfirmErrorMessage
                EventsPath                  = $eventsPath
                Checks                      = @()
                Summary                     = [PSCustomObject]@{
                    Pass = 0
                    Warn = 0
                    Fail = 0
                }
                ChecksTxtPath               = ""
                ChecksJsonPath              = ""
            }

            $failedExports = Export-AbuseAdminValidationResults -ValidationResult $failedLoginResult
            $failedLoginResult | Add-Member -NotePropertyName "ChecksTxtPath" -NotePropertyValue $failedExports.ChecksTxtPath -Force
            $failedLoginResult | Add-Member -NotePropertyName "ChecksJsonPath" -NotePropertyValue $failedExports.ChecksJsonPath -Force

            return $failedLoginResult
        }

        Write-Host ("AdminLogin -> PASS")
        Write-Host ("ConfirmPassword -> PASS")
    }

    $scenarioGroups = @(Get-AbuseAdminValidationScenarioGroups -SimulationResult $SimulationResult)
    $checks = New-Object System.Collections.ArrayList

    foreach ($group in $scenarioGroups) {
        $definition = Get-AbuseAdminValidationScenarioCheckDefinition -ScenarioGroup $group -MaxSamplesPerCheck $maxSamplesPerCheck
        $check = Invoke-AbuseAdminValidationScenario -LoginSession $loginSession -ScenarioDefinition $definition
        [void]$checks.Add($check)

        Write-Host ("{0} -> {1}" -f $check.ScenarioName, $check.Result)
    }

    $passCount = @($checks | Where-Object { $_.Result -eq "PASS" }).Count
    $warnCount = @($checks | Where-Object { $_.Result -eq "WARN" }).Count
    $failCount = @($checks | Where-Object { $_.Result -eq "FAIL" }).Count

    $result = [PSCustomObject]@{
        LoginSuccess                = $true
        LoginErrorMessage           = ""
        LoginHttpStatus             = $(if ($useDatabaseValidation) { "DB" } else { $loginSession.HttpStatus })
        LoginFinalUrl               = $(if ($useDatabaseValidation) { "security_events" } else { $loginSession.FinalUrl })
        LoginDeviceCookieName       = $(if ($useDatabaseValidation) { "" } else { $loginSession.DeviceCookieName })
        LoginDeviceCookieId         = $(if ($useDatabaseValidation) { "" } else { $loginSession.DeviceCookieId })
        LoginClientIp               = $(if ($useDatabaseValidation) { "" } else { $loginSession.ClientIp })
        LoginResponseSnippet        = $(if ($useDatabaseValidation) { "DB_VALIDATION_MODE" } else { $loginSession.DashboardSnippet })
        ConfirmPasswordRequired     = $(if ($useDatabaseValidation) { $false } else { $true })
        ConfirmPasswordSuccess      = $true
        ConfirmPasswordErrorMessage = ""
        EventsPath                  = $(if ($useDatabaseValidation) { "security_events" } else { $eventsPath })
        Checks                      = @($checks.ToArray())
        Summary                     = [PSCustomObject]@{
            Pass = $passCount
            Warn = $warnCount
            Fail = $failCount
        }
        ChecksTxtPath               = ""
        ChecksJsonPath              = ""
    }

    $exports = Export-AbuseAdminValidationResults -ValidationResult $result
    $result | Add-Member -NotePropertyName "ChecksTxtPath" -NotePropertyValue $exports.ChecksTxtPath -Force
    $result | Add-Member -NotePropertyName "ChecksJsonPath" -NotePropertyValue $exports.ChecksJsonPath -Force

    Write-Host ""
    Write-Host ("PASS: {0}  WARN: {1}  FAIL: {2}" -f $passCount, $warnCount, $failCount)

    return $result
}

Export-ModuleMember -Function *
