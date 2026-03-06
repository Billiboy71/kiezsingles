# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\ks-security-browserfirst-check.ps1
# Purpose: Browser-first Security Login/Ban evidence check via PowerShell (no audit-tool)
# Created: 05-03-2026 01:19 (Europe/Berlin)
# Changed: 06-03-2026 03:48 (Europe/Berlin)
# Version: 3.0
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# CONFIG (edit here; then run script without any parameters)
# -----------------------------------------------------------------------------
$BaseUrl               = "http://kiezsingles.test"
$RegisteredEmail       = "admin@web.de"
$UnregisteredEmail     = "audit-test1@kiezsingles.local"
$WrongPassword         = "falschespasswort"
$LockoutAttempts       = 7   # NOTE: if backend is configured for max 6 attempts, set this to 6 (or 7 to see first lockout response)

# Ban checks (manual precondition: you must set the ban in Admin UI before running this)
$CheckIpBan            = $true
$CheckIdentityBan      = $false
$CheckDeviceBan        = $false  # PS-only device-ban needs custom header/cookie; default SKIP

# If IP ban PASS in this run, the lockout scenarios become invalid (ban UI masks wrong-creds/lockout flow).
# This will SKIP scenarios to avoid misleading output.
$SkipLockoutScenariosIfIpBanPass = $true

# IMPORTANT: If you set an IP ban in Admin UI, this script MUST test the SAME client IP.
# Set this to the banned IP (example: "203.0.113.12"). Empty = use rotation pool.
$PinnedIpBanTestIp     = "203.0.113.13"

# IMPORTANT: Lockout should be tested with ONE constant client IP across all attempts,
# otherwise you may never hit the per-IP rate limit / lockout threshold.
# Set this to a stable test IP (example: "203.0.113.20"). Empty = auto-select or use rotation pool.
$PinnedLockoutTestIp   = ""

# If PinnedLockoutTestIp is empty, the script can auto-pick a lockout test IP from the pool.
# It prefers the pool tail and excludes the pinned IP-ban test IP.
$AutoSelectFreeLockoutTestIp = $true

# When checking bans, we expect: neutral ban message + SEC-XXXXXX visible in final HTML.
# Adjust these patterns to your actual UI texts.
# NOTE: Current UI text for bans (per evidence): "Anmeldung aktuell nicht möglich."
$IpBanPattern          = '(?is)(anmeldung\s+aktuell\s+nicht\s+m(ö|oe)glich|zugriff\s+ist\s+aktuell\s+eingeschr(ä|ae)nkt|der\s+zugriff\s+ist\s+aktuell\s+eingeschr(ä|ae)nkt|access\s+is\s+currently\s+restricted)'
$IdentityBanPattern    = '(?is)(anmeldung\s+derzeit\s+nicht\s+m(ö|oe)glich|login\s+currently\s+not\s+possible|sign\s+in\s+is\s+currently\s+not\s+possible)'
$DeviceBanPattern      = '(?is)(ger(ä|ae)t\s+ist\s+gesperrt|device\s+is\s+blocked|device\s+blocked)'

# Optional: inject a device marker if your backend expects it (ONLY if you know what you’re doing)
# Example: $DeviceHeaderName="X-KS-Device" $DeviceHeaderValue="abcdef..."
$DeviceHeaderName      = ""
$DeviceHeaderValue     = ""

# -----------------------------------------------------------------------------
# CLIENT-IP SIMULATION (to avoid local lockout interference across repeated test runs)
# IMPORTANT: Works ONLY if Laravel trusts proxy headers (TrustProxies) for your environment.
# -----------------------------------------------------------------------------
$SimulateClientIpEnabled = $true

# Which headers to send
# - standard: X-Forwarded-For + X-Real-IP + CF-Connecting-IP
# - xff_only: only X-Forwarded-For
$ClientIpHeaderMode      = "standard"

# If empty: auto-generate RFC5737 test IPs (safe, non-routable in docs/examples).
# You can also set explicit values, e.g. @('127.0.0.2','127.0.0.3') if you really have them.
$TestIpPool              = @()

# Rotation strategy
# - per_request: every HTTP request gets the next test IP (NOTE: will still keep GET/POST consistent per attempt)
# - per_step: one test IP per "step" (GET /login + POST /login (+ redirect follow) share same IP)
$IpRotationMode          = "per_step"

# HTML export (evidence)
$ExportHtmlEnabled     = $true
$ExportHtmlDir         = (Join-Path $PSScriptRoot "output")

# Evidence patterns
$SecPattern            = 'SEC-[A-Z0-9]{6,8}'
$SnippetRadiusChars    = 80

# Wrong-credentials evidence
$WrongCredsPattern     = '(?is)(zugangsdaten\s+sind\s+ung(ü|ue)ltig|passwort\s+ist\s+falsch|benutzername\/e-?mail\s+oder\s+passwort\s+ist\s+falsch|these\s+credentials\s+do\s+not\s+match|invalid\s+credentials|ung(ü|ue)ltig)'

# Lockout evidence: keyword + seconds/minutes (German + English, Laravel phrasing)
# NOTE: non-greedy match to capture full seconds number (avoid capturing only last digit)
$LockoutPattern        = '(?is)(zu viele|zu\s+viele|too many|throttle|lockout|locked|versuche).{0,220}?(\d{1,5})\s*(sek|sekunden|second|seconds|min|minute|minuten)\b'

# Redirect follow settings (final HTML is usually behind a redirect back to /login)
$FollowRedirectsEnabled = $true
$MaxRedirects           = 5

# PS 5.1: avoid Invoke-WebRequest prompt + DOM script execution warning
$IwrSupportsUseBasicParsing = $false
try {
    $cmd = Get-Command Invoke-WebRequest -ErrorAction Stop
    if ($null -ne $cmd -and $null -ne $cmd.Parameters -and $cmd.Parameters.ContainsKey('UseBasicParsing')) {
        $IwrSupportsUseBasicParsing = $true
    }
} catch {
    $IwrSupportsUseBasicParsing = $false
}

# -----------------------------------------------------------------------------
# RUN IDENT / EXPORT SEQUENCE (keeps all files grouped per run, avoids "duplicate" names)
# -----------------------------------------------------------------------------
$script:RunId = (Get-Date).ToString("yyyyMMdd-HHmmss")
$script:ExportSeq = 0
$script:ExportRunDir = ""

# -----------------------------------------------------------------------------
# IP ROTATION STATE
# -----------------------------------------------------------------------------
$script:ClientIpPool = @()
$script:ClientIpIndex = -1
$script:ClientIpStepIp = ""

# Forced client IP (when you want one stable IP for a whole test segment)
$script:ForcedClientIp = ""

# Resolved lockout IP (either pinned or auto-selected)
$script:ResolvedLockoutTestIp = ""

function Normalize-BaseUrl([string]$s) {
    $t = ""
    if ($null -ne $s) {
        try { $t = ("" + $s).Trim() } catch { $t = "" }
    }
    if ($t -eq "") { throw "BaseUrl is empty." }
    if ($t.EndsWith("/")) { $t = $t.Substring(0, $t.Length - 1) }
    return $t
}

function Resolve-Url([string]$BaseUrl, [string]$CurrentUrl, [string]$Location) {
    $loc = ""
    try { $loc = ("" + $Location).Trim() } catch { $loc = "" }
    if ($loc -eq "") { return "" }

    if ($loc -match '^(?i)https?://') { return $loc }

    if ($loc.StartsWith("//")) {
        $u = [Uri]$BaseUrl
        return ("{0}:{1}" -f $u.Scheme, $loc)
    }

    if ($loc.StartsWith("/")) {
        return ($BaseUrl + $loc)
    }

    try {
        $cur = [Uri]$CurrentUrl
        $abs = New-Object Uri($cur, $loc)
        return $abs.AbsoluteUri
    } catch {
        return ($BaseUrl + "/" + $loc)
    }
}

function New-Session() {
    return New-Object Microsoft.PowerShell.Commands.WebRequestSession
}

function Try-GetExceptionResponse($ex) {
    if ($null -eq $ex) { return $null }

    if ($ex -is [System.Net.WebException]) {
        if ($null -ne $ex.Response) { return $ex.Response }
        return $null
    }

    $p = $ex.PSObject.Properties['Response']
    if ($null -ne $p) {
        try {
            $r = $ex.Response
            if ($null -ne $r) { return $r }
        } catch {
            return $null
        }
    }

    $inner = $null
    try { $inner = $ex.InnerException } catch { $inner = $null }
    if ($null -ne $inner -and $inner -is [System.Net.WebException]) {
        if ($null -ne $inner.Response) { return $inner.Response }
    }

    return $null
}

function Read-ResponseBody([System.Net.WebResponse]$resp) {
    if ($null -eq $resp) { return "" }
    try {
        $stream = $resp.GetResponseStream()
        if ($null -eq $stream) { return "" }
        $sr = New-Object System.IO.StreamReader($stream)
        $body = $sr.ReadToEnd()
        $sr.Dispose()
        return $body
    } catch {
        return ""
    }
}

function Invoke-HttpWebRequestNoRedirect {
    param(
        [Parameter(Mandatory=$true)][string]$Method,
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][hashtable]$Form = $null
    )

    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = $Method
    $req.AllowAutoRedirect = $false
    $req.CookieContainer = $Session.Cookies

    foreach ($k in $Headers.Keys) {
        $v = "" + $Headers[$k]
        if ([string]::IsNullOrWhiteSpace($k)) { continue }
        try { $req.Headers[$k] = $v } catch { }
    }

    if ($null -ne $Form) {
        $pairs = New-Object System.Collections.Generic.List[string]
        foreach ($k in $Form.Keys) {
            $key = [System.Uri]::EscapeDataString("" + $k)
            $val = [System.Uri]::EscapeDataString("" + $Form[$k])
            $pairs.Add(("{0}={1}" -f $key, $val))
        }
        $bodyStr = [string]::Join("&", $pairs)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyStr)

        $req.ContentType = "application/x-www-form-urlencoded"
        $req.ContentLength = $bytes.Length
        try {
            $rs = $req.GetRequestStream()
            $rs.Write($bytes, 0, $bytes.Length)
            $rs.Dispose()
        } catch {
            # ignore here; will surface on GetResponse
        }
    }

    try {
        $resp = $req.GetResponse()
        $statusCode = 0
        try { $statusCode = [int]([System.Net.HttpWebResponse]$resp).StatusCode } catch { $statusCode = 0 }

        $headersOut = @{}
        try {
            foreach ($hk in $resp.Headers.AllKeys) { $headersOut[$hk] = $resp.Headers[$hk] }
        } catch { }

        $body = Read-ResponseBody $resp
        try { $resp.Close() } catch { }

        return [PSCustomObject]@{
            StatusCode = $statusCode
            Headers    = $headersOut
            Content    = $body
            RawContent = $body
        }
    } catch {
        $we = $_.Exception
        $resp = Try-GetExceptionResponse $we

        $statusCode = 0
        $headersOut = @{}
        $body = ""

        if ($null -ne $resp) {
            try { $statusCode = [int]([System.Net.HttpWebResponse]$resp).StatusCode } catch { $statusCode = 0 }
            try {
                foreach ($hk in $resp.Headers.AllKeys) { $headersOut[$hk] = $resp.Headers[$hk] }
            } catch { }
            $body = Read-ResponseBody $resp
            try { $resp.Close() } catch { }
        }

        return [PSCustomObject]@{
            StatusCode = $statusCode
            Headers    = $headersOut
            Content    = $body
            RawContent = $body
        }
    }
}

function Invoke-HttpNoRedirect {
    param(
        [Parameter(Mandatory=$true)][string]$Method,
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][hashtable]$Form = $null
    )

    # Use HttpWebRequest to reliably avoid redirect loops without MaximumRedirectExceeded noise.
    return Invoke-HttpWebRequestNoRedirect -Method $Method -Url $Url -Session $Session -Headers $Headers -Form $Form
}

function Try-GetLocationHeader($resp) {
    $loc = ""
    try {
        if ($null -ne $resp -and $null -ne $resp.Headers) {
            if ($resp.Headers['Location']) { $loc = "" + $resp.Headers['Location'] }
            elseif ($resp.Headers['location']) { $loc = "" + $resp.Headers['location'] }
        }
    } catch { $loc = "" }
    return $loc
}

function Invoke-FollowRedirects {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$StartUrl,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][int]$Max = 5
    )

    $curUrl = $StartUrl
    $last = $null

    for ($i=0; $i -lt $Max; $i++) {
        $last = Invoke-HttpNoRedirect -Method 'GET' -Url $curUrl -Session $Session -Headers $Headers
        $sc = 0
        try { $sc = [int]$last.StatusCode } catch { $sc = 0 }

        if ($sc -ge 300 -and $sc -lt 400) {
            $loc = Try-GetLocationHeader $last
            if ([string]::IsNullOrWhiteSpace($loc)) { break }
            $curUrl = Resolve-Url -BaseUrl $BaseUrl -CurrentUrl $curUrl -Location $loc
            if ([string]::IsNullOrWhiteSpace($curUrl)) { break }
            continue
        }

        break
    }

    $html = ""
    try {
        if ($null -ne $last.Content) { $html = "" + $last.Content }
        elseif ($null -ne $last.RawContent) { $html = "" + $last.RawContent }
        else { $html = "" }
    } catch { $html = "" }

    return [PSCustomObject]@{
        FinalUrl  = $curUrl
        FinalHtml = $html
        Raw       = $last
    }
}

function Extract-CsrfTokenFromHtml([string]$html) {
    if ([string]::IsNullOrWhiteSpace($html)) { return "" }

    $m = [regex]::Match($html, 'name="_token"\s+value="([^"]+)"', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }

    $m2 = [regex]::Match($html, 'name="csrf-token"\s+content="([^"]+)"', 'IgnoreCase')
    if ($m2.Success) { return $m2.Groups[1].Value }

    return ""
}

function Get-Snippet([string]$text, [int]$index, [int]$radius) {
    if ($null -eq $text) { return "" }
    if ($index -lt 0) { return "" }
    $start = [Math]::Max(0, $index - $radius)
    $len = [Math]::Min($text.Length - $start, $radius * 2)
    if ($len -le 0) { return "" }
    return $text.Substring($start, $len)
}

function Convert-ToSearchText([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }

    $t = "" + $text

    try { $t = [System.Net.WebUtility]::HtmlDecode($t) } catch { }

    $t = ($t -replace '(?is)<script\b[^>]*>.*?</script>', ' ')
    $t = ($t -replace '(?is)<style\b[^>]*>.*?</style>', ' ')
    $t = ($t -replace '(?is)<[^>]+>', ' ')
    $t = ($t -replace '(?is)&nbsp;', ' ')
    $t = ($t -replace '(?is)\s+', ' ').Trim()

    return $t
}

function Ensure-ExportDir() {
    if (-not $script:ExportHtmlEnabled) { return }
    if ([string]::IsNullOrWhiteSpace($script:ExportHtmlDir)) { return }

    if (-not (Test-Path -LiteralPath $script:ExportHtmlDir)) {
        New-Item -ItemType Directory -Path $script:ExportHtmlDir | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($script:ExportRunDir)) {
        $script:ExportRunDir = Join-Path $script:ExportHtmlDir $script:RunId
    }

    if (-not (Test-Path -LiteralPath $script:ExportRunDir)) {
        New-Item -ItemType Directory -Path $script:ExportRunDir | Out-Null
    }
}

function Export-LoginHtml([string]$label, [string]$html) {
    if (-not $script:ExportHtmlEnabled) { return "" }
    Ensure-ExportDir

    $script:ExportSeq = $script:ExportSeq + 1
    $seq = "{0:D4}" -f [int]$script:ExportSeq

    $safeLabel = ($label -replace '[^a-zA-Z0-9_\-]+','_')
    $file = Join-Path $script:ExportRunDir ("{0}_{1}_{2}.html" -f $script:RunId, $seq, $safeLabel)

    $content = ""
    if ($null -ne $html) { $content = $html }

    [System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)
    return $file
}

function Analyze-TextPattern([string]$html, [string]$pattern) {
    $snippet = ""
    $value = ""
    $found = $false

    $m = [regex]::Match($html, $pattern, 'IgnoreCase')
    if ($m.Success) {
        $found = $true
        $value = $m.Value
        $snippet = Get-Snippet -text $html -index $m.Index -radius $SnippetRadiusChars
    } else {
        $searchText = Convert-ToSearchText $html
        if (-not [string]::IsNullOrWhiteSpace($searchText)) {
            $m2 = [regex]::Match($searchText, $pattern, 'IgnoreCase')
            if ($m2.Success) {
                $found = $true
                $value = $m2.Value
                $snippet = Get-Snippet -text $searchText -index $m2.Index -radius $SnippetRadiusChars
            }
        }
    }

    return [PSCustomObject]@{
        Found   = $found
        Snippet = $snippet
        Value   = $value
    }
}

function Analyze-Html([string]$html) {
    $sec = [regex]::Match($html, $SecPattern, 'IgnoreCase')
    $secSnippet = ""
    if ($sec.Success) { $secSnippet = Get-Snippet -text $html -index $sec.Index -radius $SnippetRadiusChars }

    $wrong = [regex]::Match($html, $WrongCredsPattern, 'IgnoreCase')
    $wrongSnippet = ""
    if ($wrong.Success) { $wrongSnippet = Get-Snippet -text $html -index $wrong.Index -radius $SnippetRadiusChars }

    $lock = [regex]::Match($html, $LockoutPattern, 'IgnoreCase')
    $lockSeconds = ""
    $lockSnippet = ""
    if ($lock.Success) {
        $lockSeconds = $lock.Groups[2].Value
        $lockSnippet = Get-Snippet -text $html -index $lock.Index -radius $SnippetRadiusChars
    }

    return [PSCustomObject]@{
        SecFound          = $sec.Success
        SecValue          = $sec.Value
        SecSnippet        = $secSnippet

        WrongCredsFound   = $wrong.Success
        WrongCredsSnippet = $wrongSnippet

        LockoutFound      = $lock.Success
        LockoutSeconds    = $lockSeconds
        LockoutSnippet    = $lockSnippet
    }
}

function Write-Section([string]$t){
    Write-Host ""
    Write-Host ("="*70)
    Write-Host $t
    Write-Host ("="*70)
}

function Get-DeviceHeaders() {
    $h = @{}
    if (-not [string]::IsNullOrWhiteSpace($script:DeviceHeaderName) -and -not [string]::IsNullOrWhiteSpace($script:DeviceHeaderValue)) {
        $h[$script:DeviceHeaderName] = $script:DeviceHeaderValue
    }
    return $h
}

function Get-LocalClientIPs() {
    $ips = New-Object System.Collections.Generic.List[string]

    # Modern (Windows): Get-NetIPAddress
    try {
        $rows = Get-NetIPAddress -ErrorAction Stop | Where-Object {
            $_.IPAddress -and ($_.AddressFamily -eq "IPv4" -or $_.AddressFamily -eq "IPv6")
        }
        foreach ($r in $rows) {
            $ip = "" + $r.IPAddress
            if (-not [string]::IsNullOrWhiteSpace($ip)) { $ips.Add($ip) }
        }
    } catch {
        # fallback below
    }

    # Fallback: .NET DNS
    try {
        $dnsEntry = [System.Net.Dns]::GetHostEntry([System.Net.Dns]::GetHostName())
        foreach ($a in $dnsEntry.AddressList) {
            $ip = "" + $a.IPAddressToString
            if (-not [string]::IsNullOrWhiteSpace($ip)) { $ips.Add($ip) }
        }
    } catch { }

    # Always add loopbacks (often used for local laravel)
    $ips.Add("::1")
    $ips.Add("127.0.0.1")

    # unique + stable-ish order
    $uniq = @()
    foreach ($ip in $ips) {
        if ($uniq -notcontains $ip) { $uniq += $ip }
    }

    return $uniq
}

function Build-DefaultTestIpPool() {
    # RFC5737 example ranges (safe, non-routable in docs/examples)
    $pool = @()
    for ($i=10; $i -le 29; $i++) { $pool += ("203.0.113.{0}" -f $i) }
    for ($i=10; $i -le 29; $i++) { $pool += ("198.51.100.{0}" -f $i) }
    for ($i=10; $i -le 29; $i++) { $pool += ("192.0.2.{0}" -f $i) }
    return $pool
}

function Reset-ClientIpRotation([string[]]$Pool) {
    $script:ClientIpPool = @()
    if ($null -ne $Pool -and $Pool.Count -gt 0) {
        $script:ClientIpPool = $Pool
    }
    $script:ClientIpIndex = -1
    $script:ClientIpStepIp = ""
}

function Next-TestIp() {
    if (-not $script:SimulateClientIpEnabled) { return "" }
    if ($null -eq $script:ClientIpPool -or $script:ClientIpPool.Count -eq 0) { return "" }

    $script:ClientIpIndex = $script:ClientIpIndex + 1
    if ($script:ClientIpIndex -ge $script:ClientIpPool.Count) { $script:ClientIpIndex = 0 }

    return ("" + $script:ClientIpPool[$script:ClientIpIndex])
}

function Get-StepIp() {
    if (-not $script:SimulateClientIpEnabled) { return "" }

    if (-not [string]::IsNullOrWhiteSpace($script:ForcedClientIp)) {
        return ("" + $script:ForcedClientIp)
    }

    if ($script:IpRotationMode -eq "per_step") {
        if ([string]::IsNullOrWhiteSpace($script:ClientIpStepIp)) {
            $script:ClientIpStepIp = Next-TestIp
        }
        return $script:ClientIpStepIp
    }

    return Next-TestIp
}

function Begin-StepIp() {
    if (-not $script:SimulateClientIpEnabled) { return }
    if (-not [string]::IsNullOrWhiteSpace($script:ForcedClientIp)) { return }
    if ($script:IpRotationMode -eq "per_step") {
        $script:ClientIpStepIp = Next-TestIp
    }
}

function End-StepIp() {
    if (-not $script:SimulateClientIpEnabled) { return }
    if (-not [string]::IsNullOrWhiteSpace($script:ForcedClientIp)) { return }
    if ($script:IpRotationMode -eq "per_step") {
        $script:ClientIpStepIp = ""
    }
}

function Enter-ForcedClientIp([string]$ip) {
    if (-not $script:SimulateClientIpEnabled) { $script:ForcedClientIp = ""; return }
    if ([string]::IsNullOrWhiteSpace($ip)) { $script:ForcedClientIp = ""; return }
    $script:ForcedClientIp = ("" + $ip)
}

function Exit-ForcedClientIp() {
    $script:ForcedClientIp = ""
}

function Test-LockoutHasSeparatePinnedIp {
    $banIp = ""
    $lockoutIp = ""

    try { $banIp = ("" + $script:PinnedIpBanTestIp).Trim() } catch { $banIp = "" }
    try { $lockoutIp = ("" + $script:ResolvedLockoutTestIp).Trim() } catch { $lockoutIp = "" }

    if ([string]::IsNullOrWhiteSpace($lockoutIp)) { return $false }
    if ([string]::IsNullOrWhiteSpace($banIp)) { return $true }
    if ($lockoutIp -ne $banIp) { return $true }

    return $false
}

function Test-LockoutCandidateLooksClean {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$CandidateIp
    )

    if ([string]::IsNullOrWhiteSpace($CandidateIp)) { return $false }

    $session = New-Session
    $headers = Get-ClientIpHeaders $CandidateIp
    $resp = Get-LoginPage -BaseUrl $BaseUrl -Session $session -Headers $headers
    $html = ""
    try { $html = "" + $resp.Content } catch { $html = "" }

    $an = Analyze-Html $html

    if ($an.LockoutFound) { return $false }
    if ($an.SecFound) { return $false }

    return $true
}

function Resolve-LockoutTestIp {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl
    )

    if (-not $script:SimulateClientIpEnabled) { return "" }

    $pinned = ""
    $banIp = ""

    try { $pinned = ("" + $script:PinnedLockoutTestIp).Trim() } catch { $pinned = "" }
    try { $banIp = ("" + $script:PinnedIpBanTestIp).Trim() } catch { $banIp = "" }

    if (-not [string]::IsNullOrWhiteSpace($pinned)) {
        return $pinned
    }

    if (-not $script:AutoSelectFreeLockoutTestIp) {
        return ""
    }

    if ($null -eq $script:ClientIpPool -or $script:ClientIpPool.Count -eq 0) {
        return ""
    }

    $candidates = @()
    for ($i = $script:ClientIpPool.Count - 1; $i -ge 0; $i--) {
        $ip = "" + $script:ClientIpPool[$i]
        if ([string]::IsNullOrWhiteSpace($ip)) { continue }
        if (-not [string]::IsNullOrWhiteSpace($banIp) -and $ip -eq $banIp) { continue }
        $candidates += $ip
    }

    foreach ($candidate in $candidates) {
        if (Test-LockoutCandidateLooksClean -BaseUrl $BaseUrl -CandidateIp $candidate) {
            return $candidate
        }
    }

    if ($candidates.Count -gt 0) {
        return ("" + $candidates[0])
    }

    return ""
}

function Get-ClientIpHeaders([string]$ip) {
    $h = @{}
    if (-not $script:SimulateClientIpEnabled) { return $h }
    if ([string]::IsNullOrWhiteSpace($ip)) { return $h }

    if ($script:ClientIpHeaderMode -eq "xff_only") {
        $h["X-Forwarded-For"] = $ip
        return $h
    }

    # standard
    $h["X-Forwarded-For"] = $ip
    $h["X-Real-IP"] = $ip
    $h["CF-Connecting-IP"] = $ip
    return $h
}

function Merge-Headers([hashtable]$A, [hashtable]$B) {
    $h = @{}
    if ($null -ne $A) {
        foreach ($k in $A.Keys) { $h[$k] = $A[$k] }
    }
    if ($null -ne $B) {
        foreach ($k in $B.Keys) { $h[$k] = $B[$k] }
    }
    return $h
}

function Get-RequestHeaders([hashtable]$ExtraHeaders) {
    $ip = Get-StepIp
    $ipHeaders = Get-ClientIpHeaders $ip
    $h = Merge-Headers -A $ExtraHeaders -B $ipHeaders
    return [PSCustomObject]@{
        Headers = $h
        Ip      = $ip
    }
}

function Get-LoginPage {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{}
    )
    $url = "$BaseUrl/login"
    return Invoke-HttpNoRedirect -Method 'GET' -Url $url -Session $Session -Headers $Headers
}

function Post-LoginAttempt {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$Password,
        [Parameter(Mandatory=$false)][hashtable]$ExtraHeaders = @{}
    )

    # Keep IP consistent within one attempt (GET /login + POST /login + follow-redirects),
    # even if $IpRotationMode is "per_request".
    $attemptIp = ""
    if ($script:SimulateClientIpEnabled) {
        if (-not [string]::IsNullOrWhiteSpace($script:ForcedClientIp)) {
            $attemptIp = "" + $script:ForcedClientIp
        } elseif ($script:IpRotationMode -eq "per_request") {
            $attemptIp = Next-TestIp
        } else {
            $attemptIp = Get-StepIp
        }
    }

    $attemptHeaders = Merge-Headers -A $ExtraHeaders -B (Get-ClientIpHeaders $attemptIp)

    $login = Get-LoginPage -BaseUrl $BaseUrl -Session $Session -Headers $attemptHeaders
    $csrf = Extract-CsrfTokenFromHtml $login.Content

    $postUrl = "$BaseUrl/login"
    $post = Invoke-HttpNoRedirect -Method 'POST' -Url $postUrl -Session $Session -Headers $attemptHeaders -Form @{
        '_token'   = $csrf
        'email'    = $Email
        'password' = $Password
    }

    $loc = Try-GetLocationHeader $post

    $finalUrl = $postUrl
    $finalHtml = ""
    $usedFollow = $false

    $sc = 0
    try { $sc = [int]$post.StatusCode } catch { $sc = 0 }

    if ($script:FollowRedirectsEnabled -and ($sc -ge 300 -and $sc -lt 400) -and (-not [string]::IsNullOrWhiteSpace($loc))) {
        $target = Resolve-Url -BaseUrl $BaseUrl -CurrentUrl $postUrl -Location $loc
        if (-not [string]::IsNullOrWhiteSpace($target)) {
            $follow = Invoke-FollowRedirects -BaseUrl $BaseUrl -StartUrl $target -Session $Session -Headers $attemptHeaders -Max $script:MaxRedirects
            $finalUrl = $follow.FinalUrl
            $finalHtml = $follow.FinalHtml
            $usedFollow = $true
        }
    }

    if (-not $usedFollow) {
        try {
            if ($null -ne $post.Content) { $finalHtml = "" + $post.Content }
            elseif ($null -ne $post.RawContent) { $finalHtml = "" + $post.RawContent }
            else { $finalHtml = "" }
        } catch {
            $finalHtml = ""
        }
    }

    return [PSCustomObject]@{
        AttemptIp     = $attemptIp
        PostStatus    = $post.StatusCode
        PostLocation  = $loc
        FinalUrl      = $finalUrl
        FinalHtml     = $finalHtml
        Followed      = $usedFollow
        Raw           = $post
    }
}

function Run-Scenario {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$WrongPassword,
        [Parameter(Mandatory=$true)][int]$Attempts
    )

    Write-Section ("SCENARIO: {0}" -f $ScenarioName)
    Write-Host "Email:" $Email
    Write-Host "Attempts:" $Attempts

    Reset-ClientIpRotation -Pool $script:ClientIpPool
    $session = New-Session

    if (-not [string]::IsNullOrWhiteSpace($script:ResolvedLockoutTestIp)) {
        Enter-ForcedClientIp $script:ResolvedLockoutTestIp
    }

    Begin-StepIp
    $hGet = Get-RequestHeaders -ExtraHeaders @{}
    $r = Get-LoginPage $BaseUrl $session $hGet.Headers
    End-StepIp

    $csrf = Extract-CsrfTokenFromHtml $r.Content
    Write-Host "GET /login Status:" $r.StatusCode "CSRF present:" (![string]::IsNullOrWhiteSpace($csrf)) "ClientIp:" $hGet.Ip
    $exportGet = Export-LoginHtml -label ("scenario_{0}_get_login" -f $ScenarioName) -html ("" + $r.Content)
    if ($exportGet -ne "") { Write-Host "Exported HTML:" $exportGet }

    Begin-StepIp
    $a1 = Post-LoginAttempt $BaseUrl $session $Email $WrongPassword @{}
    End-StepIp

    $html1 = $a1.FinalHtml
    $an1 = Analyze-Html $html1
    Write-Host "Attempt 1 Status:" $a1.PostStatus "Followed:" $a1.Followed "FinalUrl:" $a1.FinalUrl "ClientIp:" $a1.AttemptIp
    Write-Host "Attempt 1 -> WrongCredsFound:" $an1.WrongCredsFound "LockoutFound:" $an1.LockoutFound "Seconds:" $an1.LockoutSeconds "SEC:" $an1.SecFound
    $export1 = Export-LoginHtml -label ("scenario_{0}_attempt_1_final_html" -f $ScenarioName) -html $html1
    if ($export1 -ne "") { Write-Host "Exported HTML:" $export1 }

    $lockHit = $false
    $last = $an1
    $lastHtml = $html1
    $exportLock = ""

    for($i=2;$i -le $Attempts;$i++){
        Begin-StepIp
        $a = Post-LoginAttempt $BaseUrl $session $Email $WrongPassword @{}
        End-StepIp

        $html = $a.FinalHtml
        $an = Analyze-Html $html
        $last = $an
        $lastHtml = $html

        Write-Host ("Attempt {0} Status:" -f $i) $a.PostStatus "Followed:" $a.Followed "FinalUrl:" $a.FinalUrl "ClientIp:" $a.AttemptIp
        Write-Host ("Attempt {0} -> WrongCredsFound:" -f $i) $an.WrongCredsFound "LockoutFound:" $an.LockoutFound "Seconds:" $an.LockoutSeconds "SEC:" $an.SecFound

        if($a.PostStatus -eq 429 -or $an.LockoutFound){
            $lockHit = $true
            $exportLock = Export-LoginHtml -label ("scenario_{0}_lockout_attempt_{1}_final_html" -f $ScenarioName, $i) -html $html
            break
        }
    }

    if($lockHit){
        Write-Host "Lockout detected"
        if ($last.LockoutFound) {
            Write-Host "Lockout seconds:" $last.LockoutSeconds
            Write-Host "Lockout snippet:"
            Write-Host $last.LockoutSnippet
        }
        if ($exportLock -ne "") { Write-Host "Exported HTML:" $exportLock }
    } else {
        Write-Host "Lockout NOT detected"
        $exportNo = Export-LoginHtml -label ("scenario_{0}_lockout_not_detected_final_html_after_{1}_attempts" -f $ScenarioName, $Attempts) -html $lastHtml
        if ($exportNo -ne "") { Write-Host "Exported HTML:" $exportNo }
    }

    if (-not [string]::IsNullOrWhiteSpace($script:ResolvedLockoutTestIp)) {
        Exit-ForcedClientIp
    }

    return [PSCustomObject]@{
        ScenarioName        = $ScenarioName
        Email               = $Email
        WrongCredsDetected  = $an1.WrongCredsFound
        LockoutDetected     = $last.LockoutFound
        LockoutSeconds      = $last.LockoutSeconds
        SupportCodeDetected = $last.SecFound
        SkipReason          = ""
    }
}

function Test-UrlLooksLikeLogin([string]$u) {
    if ([string]::IsNullOrWhiteSpace($u)) { return $false }
    return ($u -match '(?is)(/login)(\?|$)')
}

function Run-BanCheck {
    param(
        [Parameter(Mandatory=$true)][string]$BanName,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$WrongPassword,
        [Parameter(Mandatory=$true)][string]$BanPattern,
        [Parameter(Mandatory=$false)][hashtable]$ExtraHeaders = @{}
    )

    Write-Section ("BAN CHECK: {0}" -f $BanName)
    Write-Host "Email:" $Email

    Reset-ClientIpRotation -Pool $script:ClientIpPool
    $session = New-Session

    if ($BanName -eq "ip" -and -not [string]::IsNullOrWhiteSpace($script:PinnedIpBanTestIp)) {
        Enter-ForcedClientIp $script:PinnedIpBanTestIp
    }

    # Keep SAME step IP for GET + POST within this ban check (so Admin UI ban matches what the tool actually uses).
    Begin-StepIp
    $hGet = Get-RequestHeaders -ExtraHeaders $ExtraHeaders
    Write-Host "ClientIp:" $hGet.Ip

    $get = Get-LoginPage -BaseUrl $BaseUrl -Session $session -Headers $hGet.Headers

    $getHtml = "" + $get.Content
    $getAn = Analyze-Html $getHtml
    $getBan = Analyze-TextPattern -html $getHtml -pattern $BanPattern
    Write-Host "GET /login Status:" $get.StatusCode "BanTextFound:" $getBan.Found "SEC:" $getAn.SecFound "Lockout:" $getAn.LockoutFound

    if ($getAn.LockoutFound) {
        Write-Host "Lockout snippet:"
        Write-Host $getAn.LockoutSnippet
    }
    if ($getBan.Found) {
        Write-Host "Ban snippet:"
        Write-Host $getBan.Snippet
    }

    $exportGet = Export-LoginHtml -label ("ban_{0}_get_login" -f $BanName) -html $getHtml
    if ($exportGet -ne "") { Write-Host "Exported HTML:" $exportGet }

    # If lockout is already active, the ban-check becomes meaningless (it will never reach ban UI).
    if ($getAn.LockoutFound) {
        End-StepIp
        if ($BanName -eq "ip" -and -not [string]::IsNullOrWhiteSpace($script:PinnedIpBanTestIp)) { Exit-ForcedClientIp }
        Write-Host ("SKIP ban_{0} -> lockout_active_interference" -f $BanName)
        return [PSCustomObject]@{
            BanName             = $BanName
            BanResult           = "SKIP_LOCKOUT_ACTIVE"
            PostStatus          = ""
            PostLocation        = ""
            FinalUrl            = ""
            RedirectedToLogin   = $false
            BanTextFound        = $false
            SecFound            = $false
            SecValue            = ""
            TestIp              = $hGet.Ip
        }
    }

    $post = Post-LoginAttempt -BaseUrl $BaseUrl -Session $session -Email $Email -Password $WrongPassword -ExtraHeaders $ExtraHeaders
    End-StepIp

    if ($BanName -eq "ip" -and -not [string]::IsNullOrWhiteSpace($script:PinnedIpBanTestIp)) { Exit-ForcedClientIp }

    $postHtml = $post.FinalHtml
    $an = Analyze-Html $postHtml
    $ban = Analyze-TextPattern -html $postHtml -pattern $BanPattern

    $postStatusInt = 0
    try { $postStatusInt = [int]$post.PostStatus } catch { $postStatusInt = 0 }

    $redirectedToLogin = $false
    if ($postStatusInt -ge 300 -and $postStatusInt -lt 400) {
        if (Test-UrlLooksLikeLogin $post.PostLocation) { $redirectedToLogin = $true }
        elseif (Test-UrlLooksLikeLogin $post.FinalUrl) { $redirectedToLogin = $true }
    }

    $banTextAny = ($getBan.Found -or $ban.Found)
    $secAny = ($getAn.SecFound -or $an.SecFound)

    $evidence = @()
    if ($banTextAny) { $evidence += "BanText" }
    if ($secAny) { $evidence += "SupportRef" }
    if ($redirectedToLogin) { $evidence += "RedirectToLogin" }

    Write-Host "POST /login Status:" $post.PostStatus "Followed:" $post.Followed "FinalUrl:" $post.FinalUrl
    Write-Host "POST /login -> BanTextFound:" $ban.Found "SEC:" $an.SecFound "Lockout:" $an.LockoutFound "RedirectToLogin:" $redirectedToLogin
    Write-Host "Evidence:" (($evidence | Where-Object { $_ -ne "" }) -join ", ")

    if ($secAny) {
        $secPrint = ""
        if ($an.SecFound) { $secPrint = $an.SecValue }
        elseif ($getAn.SecFound) { $secPrint = $getAn.SecValue }
        if (-not [string]::IsNullOrWhiteSpace($secPrint)) {
            Write-Host "SupportRef:" $secPrint
        }
    }

    if ($an.LockoutFound) {
        Write-Host "Lockout snippet:"
        Write-Host $an.LockoutSnippet
    }
    if ($ban.Found) {
        Write-Host "Ban snippet:"
        Write-Host $ban.Snippet
    }
    if ($an.SecFound) {
        Write-Host "SEC snippet:"
        Write-Host $an.SecSnippet
    }

    $exportPost = Export-LoginHtml -label ("ban_{0}_post_login_final_html" -f $BanName) -html $postHtml
    if ($exportPost -ne "") { Write-Host "Exported HTML:" $exportPost }

    # If lockout triggers during ban-check, we must not report a ban FAIL.
    if ($an.LockoutFound) {
        Write-Host ("SKIP ban_{0} -> lockout_active_interference" -f $BanName)
        return [PSCustomObject]@{
            BanName             = $BanName
            BanResult           = "SKIP_LOCKOUT_ACTIVE"
            PostStatus          = $post.PostStatus
            PostLocation        = $post.PostLocation
            FinalUrl            = $post.FinalUrl
            RedirectedToLogin   = $redirectedToLogin
            BanTextFound        = $false
            SecFound            = $false
            SecValue            = ""
            TestIp              = $post.AttemptIp
        }
    }

    # PASS if any of:
    # - Ban UI text detected (GET or POST final HTML)
    # - Support reference SEC-XXXXXX detected (GET or POST final HTML)
    $status = "FAIL_NO_EVIDENCE"
    if ($banTextAny -or $secAny) {
        $status = "PASS"
    } elseif ($redirectedToLogin) {
        $status = "FAIL_REDIRECT_NO_BAN_UI"
    }

    if ($status -eq "PASS") {
        $secValue = ""
        if ($an.SecFound) { $secValue = $an.SecValue }
        elseif ($getAn.SecFound) { $secValue = $getAn.SecValue }
        Write-Host ("PASS ban_{0} (SEC:{1})" -f $BanName, $secValue)
    } else {
        Write-Host ("FAIL ban_{0} -> {1}" -f $BanName, $status)
    }

    $secValueOut = ""
    if ($an.SecFound) { $secValueOut = $an.SecValue }
    elseif ($getAn.SecFound) { $secValueOut = $getAn.SecValue }

    return [PSCustomObject]@{
        BanName             = $BanName
        BanResult           = $status
        PostStatus          = $post.PostStatus
        PostLocation        = $post.PostLocation
        FinalUrl            = $post.FinalUrl
        RedirectedToLogin   = $redirectedToLogin
        BanTextFound        = $banTextAny
        SecFound            = $secAny
        SecValue            = $secValueOut
        TestIp              = $post.AttemptIp
    }
}

# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------
$BaseUrl = Normalize-BaseUrl $BaseUrl

$localIps = Get-LocalClientIPs

if ($TestIpPool -and $TestIpPool.Count -gt 0) {
    $script:ClientIpPool = $TestIpPool
} else {
    $script:ClientIpPool = Build-DefaultTestIpPool
}

# make pinned settings available to functions via script scope
$script:PinnedIpBanTestIp           = $PinnedIpBanTestIp
$script:PinnedLockoutTestIp         = $PinnedLockoutTestIp
$script:AutoSelectFreeLockoutTestIp = $AutoSelectFreeLockoutTestIp
$script:ResolvedLockoutTestIp       = Resolve-LockoutTestIp -BaseUrl $BaseUrl

Write-Section "CONFIG"
Write-Host "BaseUrl:" $BaseUrl
Write-Host "RegisteredEmail:" $RegisteredEmail
Write-Host "UnregisteredEmail:" $UnregisteredEmail
Write-Host "LockoutAttempts:" $LockoutAttempts
Write-Host "Invoke-WebRequest UseBasicParsing supported:" $IwrSupportsUseBasicParsing
Write-Host "ExportHtmlEnabled:" $ExportHtmlEnabled
Write-Host "ExportHtmlDir:" $ExportHtmlDir
Write-Host "ExportRunDir:" (Join-Path $ExportHtmlDir $script:RunId)
Write-Host "FollowRedirectsEnabled:" $FollowRedirectsEnabled
Write-Host "MaxRedirects:" $MaxRedirects
Write-Host "CheckIpBan:" $CheckIpBan
Write-Host "CheckIdentityBan:" $CheckIdentityBan
Write-Host "CheckDeviceBan:" $CheckDeviceBan
Write-Host "SkipLockoutScenariosIfIpBanPass:" $SkipLockoutScenariosIfIpBanPass
Write-Host "PinnedIpBanTestIp:" $PinnedIpBanTestIp
Write-Host "PinnedLockoutTestIp:" $PinnedLockoutTestIp
Write-Host "AutoSelectFreeLockoutTestIp:" $AutoSelectFreeLockoutTestIp
Write-Host "ResolvedLockoutTestIp:" $script:ResolvedLockoutTestIp
Write-Host "LocalClientIPs:" ($localIps -join ", ")
Write-Host "SimulateClientIpEnabled:" $SimulateClientIpEnabled
Write-Host "ClientIpHeaderMode:" $ClientIpHeaderMode
Write-Host "IpRotationMode:" $IpRotationMode
Write-Host "TestIpPoolCount:" $script:ClientIpPool.Count
Write-Host "TestIpPoolPreview:" (($script:ClientIpPool | Select-Object -First 8) -join ", ")

# -----------------------------------------------------------------------------
# Run ban checks FIRST (avoid lockout interfering with ban checks)
# -----------------------------------------------------------------------------
$banResults = @()

if ($CheckIpBan) {
    $banResults += Run-BanCheck -BanName "ip" -Email $UnregisteredEmail -WrongPassword $WrongPassword -BanPattern $IpBanPattern
}

if ($CheckIdentityBan) {
    $banResults += Run-BanCheck -BanName "identity" -Email $RegisteredEmail -WrongPassword $WrongPassword -BanPattern $IdentityBanPattern
}

if ($CheckDeviceBan) {
    $deviceHeaders = Get-DeviceHeaders
    if ($deviceHeaders.Keys.Count -eq 0) {
        Write-Section "BAN CHECK: device"
        Write-Host "SKIP: Device ban check enabled, but no DeviceHeaderName/DeviceHeaderValue configured."
        $banResults += [PSCustomObject]@{ BanName="device"; BanResult="SKIP_NO_DEVICE_HEADER"; PostStatus=""; PostLocation=""; FinalUrl=""; RedirectedToLogin=$false; BanTextFound=$false; SecFound=$false; SecValue=""; TestIp="" }
    } else {
        $banResults += Run-BanCheck -BanName "device" -Email $RegisteredEmail -WrongPassword $WrongPassword -BanPattern $DeviceBanPattern -ExtraHeaders $deviceHeaders
    }
}

# -----------------------------------------------------------------------------
# Run both lockout scenarios in isolation (fresh session per scenario)
# -----------------------------------------------------------------------------
$ipBanPass = $false
$lockoutHasSeparatePinnedIp = $false

try {
    foreach ($b in $banResults) {
        if ($null -ne $b -and ("" + $b.BanName) -eq "ip" -and ("" + $b.BanResult) -eq "PASS") {
            $ipBanPass = $true
            break
        }
    }
} catch { $ipBanPass = $false }

try {
    $lockoutHasSeparatePinnedIp = Test-LockoutHasSeparatePinnedIp
} catch { $lockoutHasSeparatePinnedIp = $false }

$res1 = $null
$res2 = $null

if ($ipBanPass -and $SkipLockoutScenariosIfIpBanPass -and (-not $lockoutHasSeparatePinnedIp)) {
    Write-Section "SCENARIO: unregistered_email"
    Write-Host "SKIP: ip_ban_pass_interference (run lockout test without active IP ban)."
    $res1 = [PSCustomObject]@{
        ScenarioName        = "unregistered_email"
        Email               = $UnregisteredEmail
        WrongCredsDetected  = $false
        LockoutDetected     = $false
        LockoutSeconds      = ""
        SupportCodeDetected = $false
        SkipReason          = "ip_ban_pass_interference"
    }

    Write-Section "SCENARIO: registered_email"
    Write-Host "SKIP: ip_ban_pass_interference (run lockout test without active IP ban)."
    $res2 = [PSCustomObject]@{
        ScenarioName        = "registered_email"
        Email               = $RegisteredEmail
        WrongCredsDetected  = $false
        LockoutDetected     = $false
        LockoutSeconds      = ""
        SupportCodeDetected = $false
        SkipReason          = "ip_ban_pass_interference"
    }
} else {
    $res1 = Run-Scenario -ScenarioName "unregistered_email" -Email $UnregisteredEmail -WrongPassword $WrongPassword -Attempts $LockoutAttempts
    $res2 = Run-Scenario -ScenarioName "registered_email" -Email $RegisteredEmail -WrongPassword $WrongPassword -Attempts $LockoutAttempts
}

Write-Section "RESULT SUMMARY"
Write-Host "UnregisteredEmail -> WrongCredsDetected:" $res1.WrongCredsDetected "LockoutDetected:" $res1.LockoutDetected "Seconds:" $res1.LockoutSeconds "SupportCodeDetected:" $res1.SupportCodeDetected "SkipReason:" $res1.SkipReason
Write-Host "RegisteredEmail   -> WrongCredsDetected:" $res2.WrongCredsDetected "LockoutDetected:" $res2.LockoutDetected "Seconds:" $res2.LockoutSeconds "SupportCodeDetected:" $res2.SupportCodeDetected "SkipReason:" $res2.SkipReason

if ($banResults.Count -gt 0) {
    Write-Section "BAN SUMMARY"
    foreach ($b in $banResults) {
        $tip = ""
        try { $tip = "" + $b.TestIp } catch { $tip = "" }
        Write-Host ("{0} -> {1} (TestIp:{2} SEC:{3} BanText:{4} RedirectToLogin:{5} HTTP:{6})" -f $b.BanName, $b.BanResult, $tip, $b.SecFound, $b.BanTextFound, $b.RedirectedToLogin, $b.PostStatus)
    }
}