Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\07_security_e2e.ps1
# Purpose: Audit check - full security E2E flow (HTTP-only with safe cleanup)
# Created: 03-03-2026 00:03 (Europe/Berlin)
# Changed: 04-03-2026 01:59 (Europe/Berlin)
# Version: 1.0
# =============================================================================

function Invoke-KsAuditCheck_SecurityE2E {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Context)

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $new = $Context.Helpers.NewAuditResult
    $run = $Context.Helpers.RunPHPArtisan
    $root = ("" + $Context.ProjectRoot).Trim()
    $baseUrl = ("" + $Context.BaseUrl).TrimEnd("/")

    & $Context.Helpers.WriteSection "X+) Security E2E Test"

    function New-IwrBase {
        $p = @{
            TimeoutSec = 15
            ErrorAction = "Stop"
            Headers = @{ "Accept" = "text/html,application/xhtml+xml" }
        }
        try {
            $cmd = Get-Command Invoke-WebRequest -ErrorAction Stop
            if ($cmd -and $cmd.Parameters -and $cmd.Parameters.ContainsKey("UseBasicParsing")) { $p["UseBasicParsing"] = $true }
        } catch { }
        return $p
    }
    function ToFormBody($body) {
        if ($null -eq $body) { return $null }
        if ($body -is [string]) { return ("" + $body) }
        if ($body -is [System.Collections.IDictionary]) {
            $parts = New-Object System.Collections.Generic.List[string]
            foreach ($k in @($body.Keys)) {
                $n = [System.Uri]::EscapeDataString(("" + $k))
                $v = [System.Uri]::EscapeDataString(("" + $body[$k]))
                $parts.Add(($n + "=" + $v)) | Out-Null
            }
            return (($parts.ToArray()) -join "&")
        }
        return ("" + $body)
    }

    function Get-HeaderValue {
        param([Parameter(Mandatory = $false)]$Headers, [Parameter(Mandatory = $true)][string]$Name)
        try {
            if ($Headers -is [System.Collections.IDictionary]) {
                foreach ($k in @($Headers.Keys)) {
                    if (("" + $k).Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $v = $Headers[$k]
                        if ($null -eq $v) { return "" }
                        if ($v -is [string]) { return ("" + $v) }
                        return ((@($v) | ForEach-Object { "" + $_ }) -join ", ")
                    }
                }
            }
        } catch { }
        return ""
    }

    function To-AbsUrl([string]$Loc) {
        $l = ("" + $Loc).Trim()
        if ($l -eq "") { return "" }
        if ($l -match '^(?i)https?://') { return $l }
        if ($l.StartsWith("/")) { return ($baseUrl + $l) }
        return ($baseUrl + "/" + $l)
    }

    function Find-SecRef([string]$Text) {
        try {
            $m = [regex]::Match(("" + $Text), '\bSEC-[A-Z0-9]{6,12}\b')
            if ($m.Success) { return ("" + $m.Value).Trim() }
        } catch { }
        return ""
    }

    function Invoke-IwrCapture {
        param(
            [Parameter(Mandatory = $true)][string]$Uri,
            [Parameter(Mandatory = $true)][string]$Method,
            [Parameter(Mandatory = $true)]$Session,
            [Parameter(Mandatory = $false)]$Body,
            [Parameter(Mandatory = $false)][hashtable]$Headers = $null,
            [Parameter(Mandatory = $false)][int]$MaxRedirection = 0
        )

        function Invoke-NetCapture {
            param(
                [Parameter(Mandatory = $true)][string]$Uri2,
                [Parameter(Mandatory = $true)][string]$Method2,
                [Parameter(Mandatory = $true)]$Session2,
                [Parameter(Mandatory = $false)]$Body2,
                [Parameter(Mandatory = $false)][hashtable]$Headers2 = $null,
                [Parameter(Mandatory = $false)][int]$MaxRedirection2 = 0
            )
            try {
                $req = [System.Net.HttpWebRequest]::Create($Uri2)
                $req.Method = $Method2
                $req.Timeout = 15000
                $req.ReadWriteTimeout = 15000
                $req.AllowAutoRedirect = ($MaxRedirection2 -gt 0)
                if ($req.AllowAutoRedirect) {
                    $mr = $MaxRedirection2
                    if ($mr -lt 1) { $mr = 1 }
                    if ($mr -gt 50) { $mr = 50 }
                    $req.MaximumAutomaticRedirections = $mr
                }
                $req.Accept = "text/html,application/xhtml+xml"

                if ($null -ne $Session2 -and $null -ne $Session2.Cookies) {
                    $req.CookieContainer = $Session2.Cookies
                } else {
                    $req.CookieContainer = New-Object System.Net.CookieContainer
                }

                if ($null -ne $Headers2) {
                    foreach ($hk in @($Headers2.Keys)) {
                        $hn = ("" + $hk).Trim()
                        $hv = ("" + $Headers2[$hk])
                        if ($hn -eq "") { continue }
                        if ($hn.Equals("Accept", [System.StringComparison]::OrdinalIgnoreCase)) { $req.Accept = $hv; continue }
                        if ($hn.Equals("User-Agent", [System.StringComparison]::OrdinalIgnoreCase)) { $req.UserAgent = $hv; continue }
                        if ($hn.Equals("Content-Type", [System.StringComparison]::OrdinalIgnoreCase)) { $req.ContentType = $hv; continue }
                        if ($hn.Equals("Host", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                        try { $req.Headers[$hn] = $hv } catch { }
                    }
                }

                if ($null -ne $Body2) {
                    $payload = ToFormBody $Body2
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes(("" + $payload))
                    if (-not $req.ContentType -or $req.ContentType.Trim() -eq "") { $req.ContentType = "application/x-www-form-urlencoded" }
                    $req.ContentLength = $bytes.Length
                    $reqStream = $req.GetRequestStream()
                    $reqStream.Write($bytes, 0, $bytes.Length)
                    $reqStream.Close()
                }

                $resp = $null
                try {
                    $resp = [System.Net.HttpWebResponse]$req.GetResponse()
                } catch [System.Net.WebException] {
                    if ($null -ne $_.Exception.Response) {
                        $resp = [System.Net.HttpWebResponse]$_.Exception.Response
                    } else {
                        throw
                    }
                }

                if ($null -eq $resp) { throw [System.InvalidOperationException]::new("No HTTP response received.") }

                $bodyText = ""
                try {
                    $stream = $resp.GetResponseStream()
                    if ($null -ne $stream) {
                        $reader = New-Object System.IO.StreamReader($stream)
                        $bodyText = $reader.ReadToEnd()
                        $reader.Close()
                        $stream.Close()
                    }
                } catch { $bodyText = "" }

                $out = [pscustomobject]@{
                    ok = $true
                    status = [int]$resp.StatusCode
                    location = ("" + $resp.Headers["Location"])
                    content = ("" + $bodyText)
                    final_uri = $(try { "" + $resp.ResponseUri.AbsoluteUri } catch { "" })
                    error = ""
                }
                try { $resp.Close() } catch { }
                return $out
            } catch {
                return [pscustomobject]@{
                    ok = $false
                    status = $null
                    location = ""
                    content = ""
                    final_uri = ""
                    error = ("" + $_.Exception.Message)
                }
            }
        }

        $base = New-IwrBase
        $params = @{ Uri = $Uri; Method = $Method; MaximumRedirection = $MaxRedirection; WebSession = $Session }
        foreach ($k in @($base.Keys)) { $params[$k] = $base[$k] }

        if ($null -ne $Headers -and $Headers.Count -gt 0) {
            $merged = @{}
            foreach ($k in @($params["Headers"].Keys)) { $merged[$k] = $params["Headers"][$k] }
            foreach ($k in @($Headers.Keys)) { $merged[$k] = $Headers[$k] }
            $params["Headers"] = $merged
        }

        if ($null -ne $Body) {
            $params["ContentType"] = "application/x-www-form-urlencoded"
            $params["Body"] = (ToFormBody $Body)
        }

        try {
            $resp = Invoke-WebRequest @params
            return [pscustomobject]@{
                ok = $true
                status = [int]$resp.StatusCode
                location = (Get-HeaderValue -Headers $resp.Headers -Name "Location")
                content = ("" + $resp.Content)
                final_uri = $(try { "" + $resp.BaseResponse.ResponseUri.AbsoluteUri } catch { "" })
                error = ""
            }
        } catch {
            $resp = $null
            try { $resp = $_.Exception.Response } catch { $resp = $null }
            if ($null -eq $resp) {
                # Deterministic fallback path: raw HttpWebRequest keeps status/location
                # even when Invoke-WebRequest throws invalid-state transport errors.
                $netRes = Invoke-NetCapture -Uri2 $Uri -Method2 $Method -Session2 $Session -Body2 $Body -Headers2 $Headers -MaxRedirection2 $MaxRedirection
                if ($netRes.ok) { return $netRes }

                # Secondary fallback without custom headers.
                if ($null -ne $Headers -and $Headers.Count -gt 0) {
                    $netResNoHeaders = Invoke-NetCapture -Uri2 $Uri -Method2 $Method -Session2 $Session -Body2 $Body -Headers2 $null -MaxRedirection2 $MaxRedirection
                    if ($netResNoHeaders.ok) { return $netResNoHeaders }
                }

                return [pscustomobject]@{ ok = $false; status = $null; location = ""; content = ""; final_uri = ""; error = ("" + $_.Exception.Message) }
            }

            $bodyText = ""
            try {
                $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $bodyText = $sr.ReadToEnd()
                $sr.Close()
            } catch { $bodyText = "" }

            return [pscustomobject]@{
                ok = $true
                status = [int]$resp.StatusCode
                location = (Get-HeaderValue -Headers $resp.Headers -Name "Location")
                content = $bodyText
                final_uri = $(try { "" + $resp.ResponseUri.AbsoluteUri } catch { "" })
                error = ""
            }
        }
    }

    function Extract-CsrfToken([string]$Html) {
        try {
            $m = [regex]::Match(("" + $Html), 'name\s*=\s*"[_]?token"\s+value\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($m.Success) { return ("" + $m.Groups[1].Value) }
        } catch { }
        return ""
    }

    function Get-CookieValue {
        param([Parameter(Mandatory = $true)]$Session, [Parameter(Mandatory = $true)][string]$Base, [Parameter(Mandatory = $true)][string]$CookieName)
        try {
            $u = [System.Uri]$Base
            $cookies = $Session.Cookies.GetCookies($u)
            foreach ($c in @($cookies)) {
                if ((("" + $c.Name).Trim()).Equals($CookieName, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return ("" + $c.Value)
                }
            }
        } catch { }
        return ""
    }

    function Invoke-TinkerRaw([string]$Code, [int]$TimeoutSec = 45) {
        try { return (& $run $root @("tinker", "--execute=$Code", "--no-interaction") $TimeoutSec) } catch { return $null }
    }

    function Get-LastJsonLine([string]$Text) {
        if ($null -eq $Text) { return "" }
        $lines = @((("" + $Text) -split "`r?`n") | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
        if ($lines.Count -le 0) { return "" }
        return ("" + $lines[$lines.Count - 1])
    }

    function Invoke-TinkerJson([string]$Code, [int]$TimeoutSec = 45) {
        $res = Invoke-TinkerRaw -Code $Code -TimeoutSec $TimeoutSec
        if ($null -eq $res) { return [pscustomobject]@{ ok = $false; obj = $null; raw = ""; msg = "tinker_failed" } }
        if ([int]$res.ExitCode -ne 0) { return [pscustomobject]@{ ok = $false; obj = $null; raw = ("" + $res.StdOut + "`n" + $res.StdErr); msg = ("exit=" + [int]$res.ExitCode) } }
        $raw = Get-LastJsonLine ("" + $res.StdOut)
        if ($raw -eq "") { return [pscustomobject]@{ ok = $false; obj = $null; raw = ""; msg = "empty_stdout" } }
        try {
            $obj = $raw | ConvertFrom-Json -ErrorAction Stop
            return [pscustomobject]@{ ok = $true; obj = $obj; raw = $raw; msg = "" }
        } catch {
            return [pscustomobject]@{ ok = $false; obj = $null; raw = $raw; msg = "json_parse_failed" }
        }
    }

    function Find-LockoutKeyword([string]$Text, [string[]]$Keywords) {
        $hay = ("" + $Text).ToLowerInvariant()
        foreach ($k in @($Keywords)) {
            $x = ("" + $k).Trim()
            if ($x -eq "") { continue }
            $xl = $x.ToLowerInvariant()
            if ($hay.Contains($xl)) { return $x }
        }
        return ""
    }

    function Add-Sub([System.Collections.Generic.List[object]]$List, [string]$Name, [string]$Status, [string]$Summary, [string[]]$Evidence = @()) {
        $List.Add([pscustomobject]@{ name = $Name; status = $Status; summary = $Summary; evidence = @($Evidence) }) | Out-Null
    }

    $enabled = [bool]$Context.SecurityE2E
    $probeEnabled = [bool]$Context.SecurityProbe
    $allowWithoutProbe = $false
    try { $allowWithoutProbe = [bool](Convert-ToBooleanSafe $env:KS_AUDIT_ALLOW_SECURITY_E2E_WITHOUT_PROBE $false) } catch { $allowWithoutProbe = $false }
    $checkLockout = [bool]$Context.SecurityE2ELockout
    $checkIpAutoban = [bool]$Context.SecurityE2EIpAutoban
    $checkDeviceAutoban = [bool]$Context.SecurityE2EDeviceAutoban
    $checkIdentity = [bool]$Context.SecurityE2EIdentityBan
    $checkSupportRef = [bool]$Context.SecurityE2ESupportRef
    $checkEvents = [bool]$Context.SecurityE2EEventsCheck
    $cleanup = [bool]$Context.SecurityE2ECleanup
    $dryRun = [bool]$Context.SecurityE2EDryRun
    $envGate = [bool]$Context.SecurityE2EEnvGate
    $attempts = [Math]::Max(1, [int]$Context.SecurityE2EAttempts)
    $threshold = [Math]::Max(1, [int]$Context.SecurityE2EThreshold)
    $seconds = [Math]::Max(1, [int]$Context.SecurityE2ESeconds)
    $loginIdentifier = ("" + $Context.SecurityE2ELogin).Trim()
    $wrongPassword = ("" + $Context.SecurityE2EPassword)
    if ($loginIdentifier -eq "") { $loginIdentifier = "audit-test@kiezsingles.local" }
    if ($wrongPassword -eq "") { $wrongPassword = "random" }

    $keywords = @(
        "too many attempts",
        "too many login attempts",
        "throttle",
        "locked",
        "lockout",
        "zu viele",
        "zu viele versuche",
        "zu viele anmeld",
        "zu viele login",
        "versuche"
    )
    try {
        $kw = @($Context.SecurityLockoutKeywords | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
        if ($kw.Count -gt 0) { $keywords = @($kw) }
    } catch { }

    $data = @{
        enabled = $enabled
        security_probe = $probeEnabled
        lockout = $checkLockout
        ip_autoban = $checkIpAutoban
        device_autoban = $checkDeviceAutoban
        identity_ban = $checkIdentity
        support_ref = $checkSupportRef
        events_check = $checkEvents
        attempts = [int]$attempts
        threshold = [int]$threshold
        seconds = [int]$seconds
        login_identifier = $loginIdentifier
        cleanup = [bool]$cleanup
        dry_run = [bool]$dryRun
        env_gate = [bool]$envGate
        lockout_keywords = @($keywords)
    }

    if (-not $enabled) {
        $sw.Stop()
        return & $new -Id "security_e2e" -Title "X+) Security E2E Test" -Status "SKIP" -Summary "SecurityE2E=false." -Details @("E2E check disabled via SecurityE2E switch.") -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ((-not $probeEnabled) -and (-not $allowWithoutProbe)) {
        $sw.Stop()
        return & $new -Id "security_e2e" -Title "X+) Security E2E Test" -Status "SKIP" -Summary "SecurityE2E overridden by dependency: SecurityProbe=false." -Details @("Set SecurityProbe=true or explicitly allow via env KS_AUDIT_ALLOW_SECURITY_E2E_WITHOUT_PROBE=true.") -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($envGate) {
        $baseHost = ""
        try { $baseHost = ([System.Uri]$baseUrl).Host.ToLowerInvariant() } catch { $baseHost = "" }
        $allowed = ($baseHost -eq "localhost" -or $baseHost -eq "127.0.0.1" -or $baseHost -eq "::1" -or $baseHost -like "*.test" -or $baseHost -like "*.local")
        if (-not $allowed) {
            $sw.Stop()
            return & $new -Id "security_e2e" -Title "X+) Security E2E Test" -Status "SKIP" -Summary ("Blocked by SecurityE2EEnvGate for host: " + $baseHost) -Details @("Disable SecurityE2EEnvGate explicitly only for intentional non-local execution.") -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }
    }

    $runId = ("audit_e2e_" + (Get-Date -Format "yyyyMMddHHmmss") + "_" + ([Guid]::NewGuid().ToString("N").Substring(0, 8)))
    $startedAtIso = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $escapedLogin = ($loginIdentifier -replace "'", "''")
    $phpBoolIp = $(if ($checkIpAutoban) { "true" } else { "false" })
    $phpBoolDevice = $(if ($checkDeviceAutoban) { "true" } else { "false" })

    $sub = New-Object System.Collections.Generic.List[object]
    $attemptTrace = New-Object System.Collections.Generic.List[string]
    $attemptReports = New-Object System.Collections.Generic.List[object]
    $eventTypesObserved = @()
    $supportRefFound = ""
    $lockoutDetected = $false
    $ipAutobanDetected = $false
    $deviceAutobanDetected = $false
    $eventsDetected = $false
    $identityInserted = $false
    $settingsTouched = $false
    $settingsSnapshot = $null
    $restoreWarning = ""
    $cleanupWarning = ""

    $lockoutLastStatus = $null
    $lockoutLastLocation = ""
    $lockoutMatchedKeyword = ""
    $lockoutFollowUpGetLoginStatus = $null
    $lockoutMatchedKeywords = New-Object System.Collections.Generic.List[string]
    $lockoutDetectedFromEvent = $false
    $deviceAutobanDetectedFromDb = $false
    $supportRefsObserved = @()
    $auditDeviceHeader = ""

    $hasSecuritySettingsTable = $false
    $hasSecurityEventsTable = $false
    $hasIdentityBansTable = $false

    try {
        $snapRes = Invoke-TinkerJson @"
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
`$hasSettings = Schema::hasTable('security_settings');
`$settings = null;
if (`$hasSettings) { `$settings = DB::table('security_settings')->orderBy('id')->first(); }
echo json_encode(['has_settings_table' => `$hasSettings, 'settings' => `$settings], JSON_UNESCAPED_SLASHES);
"@ 60
        if (-not $snapRes.ok) { throw [System.InvalidOperationException]::new("snapshot_failed:" + $snapRes.msg) }
        $settingsSnapshot = $snapRes.obj
        try { $hasSecuritySettingsTable = [bool]$settingsSnapshot.has_settings_table } catch { $hasSecuritySettingsTable = $false }

        if (-not $dryRun -and $hasSecuritySettingsTable) {
            $updRes = Invoke-TinkerJson @"
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
if (Schema::hasTable('security_settings')) {
  `$first = DB::table('security_settings')->orderBy('id')->first();
  if (`$first) {
    `$updates = [];
    if (Schema::hasColumn('security_settings', 'login_attempt_limit')) { `$updates['login_attempt_limit'] = $threshold; }
    if (Schema::hasColumn('security_settings', 'lockout_seconds')) { `$updates['lockout_seconds'] = $seconds; }
    if ($phpBoolIp && Schema::hasColumn('security_settings', 'ip_autoban_enabled')) { `$updates['ip_autoban_enabled'] = true; }
    if ($phpBoolIp && Schema::hasColumn('security_settings', 'ip_autoban_fail_threshold')) { `$updates['ip_autoban_fail_threshold'] = $threshold; }
    if ($phpBoolIp && Schema::hasColumn('security_settings', 'ip_autoban_seconds')) { `$updates['ip_autoban_seconds'] = $seconds; }
    if ($phpBoolDevice && Schema::hasColumn('security_settings', 'device_autoban_enabled')) { `$updates['device_autoban_enabled'] = true; }
    if ($phpBoolDevice && Schema::hasColumn('security_settings', 'device_autoban_fail_threshold')) { `$updates['device_autoban_fail_threshold'] = $threshold; }
    if ($phpBoolDevice && Schema::hasColumn('security_settings', 'device_autoban_seconds')) { `$updates['device_autoban_seconds'] = $seconds; }
    if (count(`$updates) > 0) {
      `$updates['updated_at'] = now();
      DB::table('security_settings')->where('id', `$first->id)->update(`$updates);
    }
  }
}
echo json_encode(['ok' => true], JSON_UNESCAPED_SLASHES);
"@ 60
            if (-not $updRes.ok) { throw [System.InvalidOperationException]::new("settings_update_failed:" + $updRes.msg) }
            $settingsTouched = $true
        }

        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $deviceCookie = ("audit-e2e-" + $runId)
        $auditDeviceHeader = $deviceCookie
        $auditHeaders = @{ "X-Audit-Device" = $auditDeviceHeader }
        $session.Cookies.Add(([System.Uri]$baseUrl), (New-Object System.Net.Cookie("ks_device_id", $deviceCookie, "/", ([System.Uri]$baseUrl).Host)))

        $rGet = Invoke-IwrCapture -Uri ($baseUrl + "/login") -Method "GET" -Session $session -Headers $auditHeaders -MaxRedirection 10
        if (-not $rGet.ok) { throw [System.InvalidOperationException]::new("login_get_failed:" + $rGet.error) }
        $csrf = Extract-CsrfToken $rGet.content
        if ($csrf -eq "") { throw [System.InvalidOperationException]::new("missing_csrf_token") }

        $xsrfRaw = Get-CookieValue -Session $session -Base $baseUrl -CookieName "XSRF-TOKEN"
        $xsrfDecoded = ""
        try { $xsrfDecoded = [System.Net.WebUtility]::UrlDecode($xsrfRaw) } catch { $xsrfDecoded = $xsrfRaw }
        $headers = @{ "X-Audit-Device" = $auditDeviceHeader }
        if ($xsrfDecoded -ne "") { $headers["X-XSRF-TOKEN"] = $xsrfDecoded }
        $headers["X-Requested-With"] = "XMLHttpRequest"

        for ($i = 1; $i -le $attempts; $i++) {
            $rPost = Invoke-IwrCapture -Uri ($baseUrl + "/login") -Method "POST" -Session $session -Body @{ _token = $csrf; email = $loginIdentifier; password = $wrongPassword } -Headers $headers -MaxRedirection 0
            if (-not $rPost.ok) {
                $attemptTrace.Add(("try#" + $i + ": request_error=" + $rPost.error)) | Out-Null
                $attemptReports.Add([pscustomobject]@{
                    attempt = [int]$i
                    http_code = $null
                    redirect_location = ""
                    matched_keyword = ""
                    sec_ref = ""
                }) | Out-Null
                continue
            }

            $statusInt = 0
            try { $statusInt = [int]$rPost.status } catch { $statusInt = 0 }
            $loc = ("" + $rPost.location)
            $locRef = Find-SecRef $loc
            if ($supportRefFound -eq "" -and $locRef -ne "") { $supportRefFound = $locRef }

            $attemptTrace.Add(("try#" + $i + ": status=" + $statusInt + ", loc=" + $loc)) | Out-Null

            $payload = ("" + $rPost.content + " " + $loc)
            $match = Find-LockoutKeyword -Text $payload -Keywords $keywords

            $secRefAttempt = ""
            $secRefAttempt = Find-SecRef $payload
            if ($supportRefFound -eq "" -and $secRefAttempt -ne "") { $supportRefFound = $secRefAttempt }

            $redirKw = ""
            $redirSecRef = ""
            $redirFinalStatus = $null

            $isRedirect = ($statusInt -ge 300 -and $statusInt -lt 400 -and ("" + $loc).Trim() -ne "")
            $redirectToLogin = $false
            if ($isRedirect) {
                $followUri = ""
                $locTrim = ("" + $loc).Trim()
                if ($statusInt -eq 302) {
                    try {
                        $locPath = $locTrim
                        if ($locTrim -match '^(?i)https?://') { $locPath = ("" + ([System.Uri]$locTrim).AbsolutePath) }
                        $locPathLower = $locPath.ToLowerInvariant()
                        if ($locPathLower -eq "/login" -or $locPathLower -eq "login") { $redirectToLogin = $true }
                    } catch { }
                }

                if ($redirectToLogin) {
                    $followUri = ($baseUrl + "/login")
                } else {
                    $followUri = To-AbsUrl $loc
                }

                if ($followUri -ne "") {
                    $rFollow = Invoke-IwrCapture -Uri $followUri -Method "GET" -Session $session -Body $null -Headers $auditHeaders -MaxRedirection 10
                    if ($rFollow.ok) {
                        $redirFinalStatus = [int]$rFollow.status
                        if ($redirectToLogin) { $lockoutFollowUpGetLoginStatus = $redirFinalStatus }
                        $followPayload = ("" + $rFollow.content + " " + $rFollow.location)
                        if ($match -eq "") { $match = Find-LockoutKeyword -Text $followPayload -Keywords $keywords }
                        $redirKw = $match
                        $redirSecRef = Find-SecRef $followPayload
                        if ($supportRefFound -eq "" -and $redirSecRef -ne "") { $supportRefFound = $redirSecRef }
                    }
                }
            }

            $attemptReports.Add([pscustomobject]@{
                attempt = [int]$i
                http_code = [int]$statusInt
                redirect_location = ("" + $loc)
                matched_keyword = ("" + $match)
                sec_ref = $(if ($secRefAttempt -ne "") { $secRefAttempt } elseif ($redirSecRef -ne "") { $redirSecRef } else { "" })
                redirect_follow_status = $redirFinalStatus
            }) | Out-Null

            if ($checkLockout -and (-not $lockoutDetected)) {
                $lockoutLastStatus = $statusInt
                $lockoutLastLocation = $loc
                if ($match -ne "" -and $lockoutMatchedKeyword -eq "") { $lockoutMatchedKeyword = $match }
                if ($match -ne "" -and (-not (@($lockoutMatchedKeywords.ToArray()) -contains $match))) { $lockoutMatchedKeywords.Add($match) | Out-Null }

                # Laravel/Breeze lockout can surface as:
                # - 429 Too Many Requests
                # - 422 ValidationException with lockout message (JSON/HTML)
                # - redirect chain with lockout banner/message
                if ($statusInt -eq 429) { $lockoutDetected = $true }
                elseif (($statusInt -eq 422) -and ($match -ne "")) { $lockoutDetected = $true }
                elseif (($match -ne "") -and ($statusInt -ge 400)) { $lockoutDetected = $true }
                elseif ($isRedirect -and ($match -ne "")) { $lockoutDetected = $true }
                elseif ($redirectToLogin -and ($i -ge $threshold)) { $lockoutDetected = $true }
            }
        }

        if ($checkIdentity -and (-not $dryRun)) {
            $identityRes = Invoke-TinkerJson @"
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
`$has = Schema::hasTable('security_identity_bans');
`$ok = false;
if (`$has) {
  DB::table('security_identity_bans')->insert([
    'email' => '$escapedLogin',
    'reason' => 'audit_security_e2e_$runId',
    'banned_until' => now()->addSeconds($seconds),
    'created_by' => null,
    'created_at' => now(),
    'updated_at' => now(),
  ]);
  `$ok = true;
}
echo json_encode(['has_table' => `$has, 'ok' => `$ok], JSON_UNESCAPED_SLASHES);
"@ 45
            if ($identityRes.ok) {
                try { $hasIdentityBansTable = [bool]$identityRes.obj.has_table } catch { $hasIdentityBansTable = $false }
                try { $identityInserted = [bool]$identityRes.obj.ok } catch { $identityInserted = $false }
            }

            if ($identityInserted) {
                $rIdentity = Invoke-IwrCapture -Uri ($baseUrl + "/login") -Method "POST" -Session $session -Body @{ _token = $csrf; email = $loginIdentifier; password = $wrongPassword } -Headers $headers -MaxRedirection 0
                if ($rIdentity.ok) { $attemptTrace.Add(("identity_try: status=" + [int]$rIdentity.status + ", loc=" + ("" + $rIdentity.location))) | Out-Null }
            }
        }

        $rBanner = Invoke-IwrCapture -Uri ($baseUrl + "/login") -Method "GET" -Session $session -Headers $auditHeaders -MaxRedirection 10
        if ($rBanner.ok) {
            $mRef = [regex]::Match(("" + $rBanner.content), '\bSEC-[A-Z0-9]{6,12}\b')
            if ($mRef.Success) { $supportRefFound = ("" + $mRef.Value).Trim() }
        }

        $obsRes = Invoke-TinkerJson @"
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
  `$types = [];
  `$refs = [];
  `$supportRef = '';
  `$lockoutEvent = false;
  `$ipDetected = false;
  `$deviceDetected = false;
  `$eventsOk = false;
  `$hasEvents = Schema::hasTable('security_events');
  if (`$hasEvents) {
  `$rows = DB::table('security_events')->where('created_at', '>=', '$startedAtIso')->orderBy('id')->get(['type','meta']);
  foreach (`$rows as `$r) {
    `$t = (string) (`$r->type ?? '');
    `$types[] = `$t;
    if (`$t === 'ip_autobanned') { `$ipDetected = true; }
    if (`$t === 'device_autobanned') { `$deviceDetected = true; }
    if (in_array(`$t, ['lockout','login_lockout','throttled','login_throttled','too_many_attempts','login_rate_limited'], true)) { `$lockoutEvent = true; }
    `$meta = `$r->meta ?? null;
    if (is_string(`$meta) && `$meta !== '') {
      `$decoded = json_decode(`$meta, true);
      if (is_array(`$decoded)) { `$meta = `$decoded; }
    }
    if (is_array(`$meta) && !empty(`$meta['support_ref'])) {
      `$ref = (string) `$meta['support_ref'];
      if (`$supportRef === '') { `$supportRef = `$ref; }
      `$refs[] = `$ref;
    }
  }
  `$eventsOk = count(`$rows) > 0;
}
`$hasDeviceBans = Schema::hasTable('security_device_bans');
`$deviceBanCount = 0;
if (`$hasDeviceBans) {
  `$deviceBanCount = (int) DB::table('security_device_bans')->where('created_at', '>=', '$startedAtIso')->count();
}
echo json_encode(['has_events_table' => `$hasEvents, 'types' => `$types, 'ip_autobanned' => `$ipDetected, 'device_autobanned' => `$deviceDetected, 'events_ok' => `$eventsOk, 'lockout_event' => `$lockoutEvent, 'support_ref' => `$supportRef, 'support_refs' => array_values(array_unique(`$refs)), 'has_device_bans_table' => `$hasDeviceBans, 'device_ban_count' => `$deviceBanCount], JSON_UNESCAPED_SLASHES);
"@ 45
        if ($obsRes.ok) {
            try { $hasSecurityEventsTable = [bool]$obsRes.obj.has_events_table } catch { $hasSecurityEventsTable = $false }
            try { $eventTypesObserved = @($obsRes.obj.types | ForEach-Object { "" + $_ }) } catch { $eventTypesObserved = @() }
            try { $ipAutobanDetected = [bool]$obsRes.obj.ip_autobanned } catch { $ipAutobanDetected = $false }
            try { $deviceAutobanDetected = [bool]$obsRes.obj.device_autobanned } catch { $deviceAutobanDetected = $false }
            try { $eventsDetected = [bool]$obsRes.obj.events_ok } catch { $eventsDetected = $false }
            try { $lockoutDetectedFromEvent = [bool]$obsRes.obj.lockout_event } catch { $lockoutDetectedFromEvent = $false }
            try { $supportRefsObserved = @($obsRes.obj.support_refs | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" }) } catch { $supportRefsObserved = @() }
            try { if ($supportRefFound -eq "") { $supportRefFound = ("" + $obsRes.obj.support_ref).Trim() } } catch { }
            try {
                $hasDeviceBansTable = [bool]$obsRes.obj.has_device_bans_table
                $deviceBanCount = [int]$obsRes.obj.device_ban_count
                if ($hasDeviceBansTable -and $deviceBanCount -gt 0) { $deviceAutobanDetectedFromDb = $true }
            } catch { $deviceAutobanDetectedFromDb = $false }
        }
        if ($checkLockout -and (-not $lockoutDetected) -and $lockoutDetectedFromEvent) { $lockoutDetected = $true }
        if ($checkDeviceAutoban -and (-not $deviceAutobanDetected) -and $deviceAutobanDetectedFromDb) { $deviceAutobanDetected = $true }
    } catch {
        Add-Sub -List $sub -Name "Execution" -Status "FAIL" -Summary ("" + $_.Exception.Message)
    } finally {
        if ($settingsTouched -and $null -ne $settingsSnapshot) {
            try {
                $sid = 0
                try { $sid = [int]$settingsSnapshot.settings.id } catch { $sid = 0 }
                if ($sid -gt 0) {
                    $origLoginLimit = [int]$settingsSnapshot.settings.login_attempt_limit
                    $origLockout = [int]$settingsSnapshot.settings.lockout_seconds
                    $origIpEnabled = $(if ([bool]$settingsSnapshot.settings.ip_autoban_enabled) { "true" } else { "false" })
                    $origIpThreshold = [int]$settingsSnapshot.settings.ip_autoban_fail_threshold
                    $origIpSeconds = [int]$settingsSnapshot.settings.ip_autoban_seconds
                    $origDeviceEnabled = $(if ([bool]$settingsSnapshot.settings.device_autoban_enabled) { "true" } else { "false" })
                    $origDeviceThreshold = [int]$settingsSnapshot.settings.device_autoban_fail_threshold
                    $origDeviceSeconds = [int]$settingsSnapshot.settings.device_autoban_seconds
                    $restoreRes = Invoke-TinkerJson @"
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
if (DB::table('security_settings')->where('id', $sid)->exists()) {
  `$updates = [];
  if (Schema::hasColumn('security_settings', 'login_attempt_limit')) { `$updates['login_attempt_limit'] = $origLoginLimit; }
  if (Schema::hasColumn('security_settings', 'lockout_seconds')) { `$updates['lockout_seconds'] = $origLockout; }
  if (Schema::hasColumn('security_settings', 'ip_autoban_enabled')) { `$updates['ip_autoban_enabled'] = $origIpEnabled; }
  if (Schema::hasColumn('security_settings', 'ip_autoban_fail_threshold')) { `$updates['ip_autoban_fail_threshold'] = $origIpThreshold; }
  if (Schema::hasColumn('security_settings', 'ip_autoban_seconds')) { `$updates['ip_autoban_seconds'] = $origIpSeconds; }
  if (Schema::hasColumn('security_settings', 'device_autoban_enabled')) { `$updates['device_autoban_enabled'] = $origDeviceEnabled; }
  if (Schema::hasColumn('security_settings', 'device_autoban_fail_threshold')) { `$updates['device_autoban_fail_threshold'] = $origDeviceThreshold; }
  if (Schema::hasColumn('security_settings', 'device_autoban_seconds')) { `$updates['device_autoban_seconds'] = $origDeviceSeconds; }
  if (count(`$updates) > 0) {
    `$updates['updated_at'] = now();
    DB::table('security_settings')->where('id', $sid)->update(`$updates);
  }
}
echo json_encode(['ok' => true], JSON_UNESCAPED_SLASHES);
"@ 45
                    if (-not $restoreRes.ok) { $restoreWarning = ("settings_restore_failed:" + $restoreRes.msg) }
                }
            } catch {
                $restoreWarning = ("settings_restore_exception:" + $_.Exception.Message)
            }
        }

        if ($cleanup -and (-not $dryRun)) {
            try {
                $cleanupRes = Invoke-TinkerJson @"
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
if (Schema::hasTable('security_ip_bans')) {
  DB::table('security_ip_bans')->where('reason', 'autoban_login_fail')->where('created_at', '>=', '$startedAtIso')->delete();
}
if (Schema::hasTable('security_device_bans')) {
  DB::table('security_device_bans')->where('reason', 'autoban_login_fail')->where('created_at', '>=', '$startedAtIso')->delete();
}
if (Schema::hasTable('security_identity_bans')) {
  DB::table('security_identity_bans')->where('email', '$escapedLogin')->where('reason', 'audit_security_e2e_$runId')->delete();
}
echo json_encode(['ok' => true], JSON_UNESCAPED_SLASHES);
"@ 45
                if (-not $cleanupRes.ok) { $cleanupWarning = ("cleanup_failed:" + $cleanupRes.msg) }
            } catch {
                $cleanupWarning = ("cleanup_exception:" + $_.Exception.Message)
            }
        }
    }

    if ($checkLockout) {
        $attemptsWithHttp = 0
        foreach ($ar in @($attemptReports.ToArray())) {
            try { if ($null -ne $ar.http_code) { $attemptsWithHttp++ } } catch { }
        }
        $ev = New-Object System.Collections.Generic.List[string]
        $ev.Add(("Attempts: " + $attempts)) | Out-Null
        $ev.Add(("Accepted lockout signals: 429, 422+keyword, status>=400+keyword, redirect+keyword, 302->/login at/after threshold, security_events lockout types")) | Out-Null
        if ($null -ne $lockoutLastStatus) { $ev.Add(("LastStatus: " + [int]$lockoutLastStatus)) | Out-Null }
        if ($lockoutLastLocation -ne "") { $ev.Add(("LastLocation: " + $lockoutLastLocation)) | Out-Null }
        $ev.Add(("FollowUp GET /login status: " + $(if ($null -ne $lockoutFollowUpGetLoginStatus) { [int]$lockoutFollowUpGetLoginStatus } else { "(n/a)" }))) | Out-Null
        if ($lockoutMatchedKeywords.Count -gt 0) {
            $ev.Add(("Matched keyword(s): " + (($lockoutMatchedKeywords.ToArray()) -join ", "))) | Out-Null
        } else {
            $ev.Add("Matched keyword(s): none") | Out-Null
        }
        if ($supportRefFound -ne "") { $ev.Add(("SEC-Ref: " + $supportRefFound)) | Out-Null }
        $ev.Add(("Lockout event observed in security_events: " + [bool]$lockoutDetectedFromEvent)) | Out-Null
        if ($supportRefsObserved.Count -gt 0) { $ev.Add(("SupportRef(s) from security_events.meta: " + ($supportRefsObserved -join ", "))) | Out-Null }

        if ($dryRun -and (-not $lockoutDetected)) {
            Add-Sub -List $sub -Name "Lockout/Throttle" -Status "WARN" -Summary "DryRun=true; no lockout signal detected (non-deterministic without forced settings)." -Evidence @($ev.ToArray())
        } elseif ((-not $lockoutDetected) -and ($attemptsWithHttp -le 0)) {
            Add-Sub -List $sub -Name "Lockout/Throttle" -Status "WARN" -Summary "No valid HTTP response during lockout probe (transport/tool issue)." -Evidence @($ev.ToArray())
        } else {
            Add-Sub -List $sub -Name "Lockout/Throttle" -Status $(if ($lockoutDetected) { "OK" } else { "WARN" }) -Summary $(if ($lockoutDetected) { "Lockout signal detected." } else { "No lockout signal detected." }) -Evidence @($ev.ToArray())
        }
    }
    else { Add-Sub -List $sub -Name "Lockout/Throttle" -Status "SKIP" -Summary "Disabled by SecurityE2ELockout=false." }

    if ($checkIpAutoban) {
        if (-not $hasSecurityEventsTable) {
            Add-Sub -List $sub -Name "IP AutoBan" -Status "SKIP" -Summary "security_events table missing; cannot validate ip_autobanned events."
        } elseif ($dryRun -and (-not $ipAutobanDetected)) {
            Add-Sub -List $sub -Name "IP AutoBan" -Status "SKIP" -Summary "DryRun=true; IP autoban not enforced/validated."
        } else {
            Add-Sub -List $sub -Name "IP AutoBan" -Status $(if ($ipAutobanDetected) { "OK" } else { "WARN" }) -Summary $(if ($ipAutobanDetected) { "ip_autobanned event detected." } else { "No ip_autobanned event observed." })
        }
    }
    else { Add-Sub -List $sub -Name "IP AutoBan" -Status "SKIP" -Summary "Disabled by SecurityE2EIpAutoban=false." }

    if ($checkDeviceAutoban) {
        if (-not $hasSecurityEventsTable) {
            Add-Sub -List $sub -Name "Device AutoBan" -Status "SKIP" -Summary "security_events table missing; cannot validate device_autobanned events."
        } elseif ($dryRun -and (-not $deviceAutobanDetected)) {
            Add-Sub -List $sub -Name "Device AutoBan" -Status "SKIP" -Summary "DryRun=true; device autoban not enforced/validated."
        } else {
            Add-Sub -List $sub -Name "Device AutoBan" -Status $(if ($deviceAutobanDetected) { "OK" } else { "WARN" }) -Summary $(if ($deviceAutobanDetected) { "device_autobanned event detected." } else { "No device_autobanned event observed." })
        }
    }
    else { Add-Sub -List $sub -Name "Device AutoBan" -Status "SKIP" -Summary "Disabled by SecurityE2EDeviceAutoban=false." }

    if ($checkIdentity) {
        if ($dryRun) {
            Add-Sub -List $sub -Name "Identity Ban" -Status "SKIP" -Summary "DryRun=true; identity mutation skipped."
        } elseif (-not $hasIdentityBansTable) {
            Add-Sub -List $sub -Name "Identity Ban" -Status "SKIP" -Summary "security_identity_bans table missing; cannot run identity ban test."
        } elseif ($identityInserted) {
            Add-Sub -List $sub -Name "Identity Ban" -Status "OK" -Summary "Identity ban row inserted and cleanup attempted."
        } else {
            Add-Sub -List $sub -Name "Identity Ban" -Status "WARN" -Summary "Identity test requested but row could not be created."
        }
    } else {
        Add-Sub -List $sub -Name "Identity Ban" -Status "SKIP" -Summary "Disabled by SecurityE2EIdentityBan=false."
    }

    if ($checkSupportRef) { Add-Sub -List $sub -Name "SupportRef" -Status $(if ($supportRefFound -ne "") { "OK" } else { "WARN" }) -Summary $(if ($supportRefFound -ne "") { "SupportRef detected: $supportRefFound" } else { "No SEC-xxxx support reference found in response body/redirect target/session events." }) }
    else { Add-Sub -List $sub -Name "SupportRef" -Status "SKIP" -Summary "Disabled by SecurityE2ESupportRef=false." }

    if ($checkEvents) {
        $observedText = $(if ($eventTypesObserved.Count -gt 0) { $eventTypesObserved -join ", " } else { "(none)" })
        if (-not $hasSecurityEventsTable) {
            Add-Sub -List $sub -Name "Events Check" -Status "SKIP" -Summary "security_events table missing; cannot validate events window." -Evidence @("Observed types: (n/a)")
        } elseif ($dryRun -and (-not $eventsDetected)) {
            Add-Sub -List $sub -Name "Events Check" -Status "SKIP" -Summary "DryRun=true; events window check not enforced/validated." -Evidence @("Observed types: $observedText")
        } else {
            Add-Sub -List $sub -Name "Events Check" -Status $(if ($eventsDetected) { "OK" } else { "WARN" }) -Summary $(if ($eventsDetected) { "security_events entries observed for this run window." } else { "No security_events entries observed in run window." }) -Evidence @("Observed types: $observedText")
        }
    } else {
        Add-Sub -List $sub -Name "Events Check" -Status "SKIP" -Summary "Disabled by SecurityE2EEventsCheck=false."
    }

    $details = @(
        "RunId: $runId",
        "StartedAt: $startedAtIso",
        "Attempts configured: $attempts",
        "SecurityProbe (context): $probeEnabled",
        "Lockout detected: $lockoutDetected",
        "Lockout last http status: " + $(if ($null -ne $lockoutLastStatus) { [int]$lockoutLastStatus } else { "(n/a)" }),
        "Lockout last redirect location: " + $(if ($lockoutLastLocation -ne "") { $lockoutLastLocation } else { "(n/a)" }),
        "Lockout follow-up GET /login status: " + $(if ($null -ne $lockoutFollowUpGetLoginStatus) { [int]$lockoutFollowUpGetLoginStatus } else { "(n/a)" }),
        "Lockout matched keyword(s): " + $(if ($lockoutMatchedKeywords.Count -gt 0) { ($lockoutMatchedKeywords.ToArray()) -join ", " } else { "none" }),
        "Lockout event evidence (security_events): " + [bool]$lockoutDetectedFromEvent,
        "security_settings table present: $hasSecuritySettingsTable",
        "security_events table present: $hasSecurityEventsTable",
        "security_identity_bans table present: $hasIdentityBansTable",
        "IP autoban detected: $ipAutobanDetected",
        "Device autoban detected: $deviceAutobanDetected",
        "Device autoban DB evidence (security_device_bans): " + [bool]$deviceAutobanDetectedFromDb,
        "Audit Device ID (cookie/header): " + $(if ($auditDeviceHeader -ne "") { $auditDeviceHeader } else { "(none)" }),
        "SupportRef found: " + $(if ($supportRefFound -ne "") { $supportRefFound } else { "(none)" }),
        "SupportRef(s) observed: " + $(if ($supportRefsObserved.Count -gt 0) { $supportRefsObserved -join ", " } else { "(none)" }),
        "Events observed: " + $(if ($eventTypesObserved.Count -gt 0) { $eventTypesObserved -join ", " } else { "(none)" })
    )
    if ($attemptTrace.Count -gt 0) { $details += ("Attempt trace: " + (($attemptTrace.ToArray()) -join " | ")) }
    if ($dryRun) {
        $details += "NOTE: DryRun=true (no DB mutations). Subtests requiring DB writes are SKIP/WARN and must not FAIL due to dryrun."
        $details += "DryRun scope: security_settings not changed; identity ban not inserted; cleanup not executed."
    }
    if ($restoreWarning -ne "") { $details += ("WARN restore: " + $restoreWarning) }
    if ($cleanupWarning -ne "") { $details += ("WARN cleanup: " + $cleanupWarning) }

    $ok = 0
    $warn = 0
    $fail = 0
    $skip = 0
    foreach ($s in @($sub.ToArray())) {
        switch ("" + $s.status) {
            "OK" { $ok++ }
            "WARN" { $warn++ }
            "FAIL" { $fail++ }
            "SKIP" { $skip++ }
        }
        $details += ("[" + $s.status + "] " + $s.name + " - " + $s.summary)
        foreach ($ev in @($s.evidence)) { if (("" + $ev).Trim() -ne "") { $details += ("  evidence: " + $ev) } }
    }

    $status = "OK"
    if ($fail -gt 0) { $status = "FAIL" }
    elseif ($warn -gt 0) { $status = "WARN" }

    $summary = ("E2E status: " + $status + " (OK=" + $ok + ", WARN=" + $warn + ", FAIL=" + $fail + ", SKIP=" + $skip + ")")
    if ($dryRun) { $summary += " | dryrun" }
    if ($restoreWarning -ne "") { $summary += " | restore warning present" }
    if ($cleanupWarning -ne "") { $summary += " | cleanup warning present" }

    $data["run_id"] = $runId
    $data["started_at"] = $startedAtIso
    $data["lockout_detected"] = [bool]$lockoutDetected
    $data["lockout_last_status"] = $lockoutLastStatus
    $data["lockout_last_location"] = $lockoutLastLocation
    $data["lockout_followup_get_login_status"] = $lockoutFollowUpGetLoginStatus
    $data["lockout_matched_keywords"] = @($lockoutMatchedKeywords.ToArray())
    $data["lockout_matched_keyword"] = $lockoutMatchedKeyword
    $data["lockout_event_detected"] = [bool]$lockoutDetectedFromEvent
    $data["has_security_settings_table"] = [bool]$hasSecuritySettingsTable
    $data["has_security_events_table"] = [bool]$hasSecurityEventsTable
    $data["has_security_identity_bans_table"] = [bool]$hasIdentityBansTable
    $data["ip_autoban_detected"] = [bool]$ipAutobanDetected
    $data["device_autoban_detected"] = [bool]$deviceAutobanDetected
    $data["device_autoban_db_detected"] = [bool]$deviceAutobanDetectedFromDb
    $data["audit_device_id"] = $auditDeviceHeader
    $data["support_ref"] = $supportRefFound
    $data["support_refs_observed"] = @($supportRefsObserved)
    $data["events_detected"] = [bool]$eventsDetected
    $data["events_observed_types"] = @($eventTypesObserved)
    $data["attempt_trace"] = @($attemptTrace.ToArray())
    $data["attempt_reports"] = @($attemptReports.ToArray())
    $data["restore_warning"] = $restoreWarning
    $data["cleanup_warning"] = $cleanupWarning
    $data["subchecks"] = @($sub.ToArray())

    $sw.Stop()
    return & $new -Id "security_e2e" -Title "X+) Security E2E Test" -Status $status -Summary $summary -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
}
