Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\06_security_abuse_protection.ps1
# Purpose: Audit check - security / abuse protection block (active probes + evidence)
# Created: 01-03-2026 13:20 (Europe/Berlin)
# Changed: 04-03-2026 02:24 (Europe/Berlin)
# Version: 1.4
# =============================================================================

function Invoke-KsAuditCheck_SecurityAbuseProtection {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Context)

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $new = $Context.Helpers.NewAuditResult
    $run = $Context.Helpers.RunPHPArtisan
    $root = ("" + $Context.ProjectRoot).Trim()
    $baseUrl = ("" + $Context.BaseUrl).TrimEnd("/")
    & $Context.Helpers.WriteSection "X) Security / Abuse Protection"

    function New-IwrBase {
        $p = @{ TimeoutSec = 12; ErrorAction = "Stop"; Headers = @{ "Accept" = "text/html,application/xhtml+xml" } }
        try { if ((Get-Command Invoke-WebRequest).Parameters.ContainsKey("UseBasicParsing")) { $p["UseBasicParsing"] = $true } } catch { }
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
    function HVal($h, [string]$n) {
        try { foreach ($k in @($h.Keys)) { if (("" + $k).Equals($n, [System.StringComparison]::OrdinalIgnoreCase)) { return ("" + $h[$k]) } } } catch { }
        return ""
    }
    function GetCookieValue($session, [string]$base, [string]$cookieName) {
        try {
            $u = [System.Uri]$base
            $cookies = $session.Cookies.GetCookies($u)
            foreach ($c in @($cookies)) {
                if ((("" + $c.Name).Trim()).Equals($cookieName, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return ("" + $c.Value)
                }
            }
        } catch { }
        return ""
    }
    function ToAbsUrl([string]$loc) {
        $l = ("" + $loc).Trim()
        if ($l -eq "") { return "" }
        if ($l -match '^(?i)https?://') { return $l }
        if ($l.StartsWith("/")) { return ($baseUrl + $l) }
        return ($baseUrl + "/" + $l)
    }
    function Req([string]$u, [string]$m, $sess, $body, [int]$redir = 0, [hashtable]$headers = $null) {
        function ReqNet([string]$u2, [string]$m2, $sess2, $body2, [int]$redir2, [hashtable]$headers2 = $null) {
            try {
                $req = [System.Net.HttpWebRequest]::Create($u2)
                $req.Method = $m2
                $req.Timeout = 12000
                $req.ReadWriteTimeout = 12000
                $req.AllowAutoRedirect = ($redir2 -gt 0)
                if ($req.AllowAutoRedirect) {
                    $mr = $redir2
                    if ($mr -lt 1) { $mr = 1 }
                    if ($mr -gt 50) { $mr = 50 }
                    $req.MaximumAutomaticRedirections = $mr
                }
                $req.Accept = "text/html,application/xhtml+xml"

                if ($null -ne $sess2 -and $null -ne $sess2.Cookies) {
                    $req.CookieContainer = $sess2.Cookies
                } else {
                    $req.CookieContainer = New-Object System.Net.CookieContainer
                }

                if ($null -ne $headers2) {
                    foreach ($hk in @($headers2.Keys)) {
                        $hn = ("" + $hk).Trim()
                        $hv = ("" + $headers2[$hk])
                        if ($hn -eq "") { continue }
                        if ($hn.Equals("Accept", [System.StringComparison]::OrdinalIgnoreCase)) { $req.Accept = $hv; continue }
                        if ($hn.Equals("User-Agent", [System.StringComparison]::OrdinalIgnoreCase)) { $req.UserAgent = $hv; continue }
                        if ($hn.Equals("Content-Type", [System.StringComparison]::OrdinalIgnoreCase)) { $req.ContentType = $hv; continue }
                        if ($hn.Equals("Host", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                        try { $req.Headers[$hn] = $hv } catch { }
                    }
                }

                if ($null -ne $body2) {
                    $payload = ToFormBody $body2
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes(("" + $payload))
                    if (-not $req.ContentType -or $req.ContentType.Trim() -eq "") { $req.ContentType = "application/x-www-form-urlencoded" }
                    $req.ContentLength = $bytes.Length
                    $rs = $req.GetRequestStream()
                    $rs.Write($bytes, 0, $bytes.Length)
                    $rs.Close()
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

                $status = [int]$resp.StatusCode
                $location = ""
                try { $location = ("" + $resp.Headers["Location"]) } catch { $location = "" }
                $content = ""
                try {
                    $stream = $resp.GetResponseStream()
                    if ($null -ne $stream) {
                        $reader = New-Object System.IO.StreamReader($stream)
                        $content = $reader.ReadToEnd()
                        $reader.Close()
                        $stream.Close()
                    }
                } catch { $content = "" }
                try { $resp.Close() } catch { }

                return [pscustomobject]@{ ok = $true; status = $status; location = $location; content = ("" + $content); error = "" }
            } catch {
                return [pscustomobject]@{ ok = $false; status = $null; location = ""; content = ""; error = ("" + $_.Exception.Message) }
            }
        }

        $b = New-IwrBase
        $p = @{ Uri = $u; Method = $m; MaximumRedirection = $redir }
        foreach ($k in $b.Keys) { $p[$k] = $b[$k] }
        if ($null -ne $headers -and $headers.Count -gt 0) {
            $merged = @{}
            try {
                foreach ($k in @($p["Headers"].Keys)) { $merged[$k] = $p["Headers"][$k] }
            } catch { }
            foreach ($k in @($headers.Keys)) { $merged[$k] = $headers[$k] }
            $p["Headers"] = $merged
        }
        if ($null -ne $sess) { $p["WebSession"] = $sess }
        if ($null -ne $body) { $p["ContentType"] = "application/x-www-form-urlencoded"; $p["Body"] = (ToFormBody $body) }
        try {
            $r = Invoke-WebRequest @p
            return [pscustomobject]@{ ok = $true; status = [int]$r.StatusCode; location = (HVal $r.Headers "Location"); content = ("" + $r.Content); error = "" }
        } catch {
            $resp = $null
            try { $resp = $_.Exception.Response } catch { $resp = $null }
            if ($resp) {
                $txt = ""
                try { $sr = New-Object System.IO.StreamReader($resp.GetResponseStream()); $txt = $sr.ReadToEnd(); $sr.Close() } catch { $txt = "" }
                return [pscustomobject]@{ ok = $true; status = [int]$resp.StatusCode; location = (HVal $resp.Headers "Location"); content = $txt; error = "" }
            }

            # Deterministic fallback path: raw HttpWebRequest keeps status/location
            # even when Invoke-WebRequest throws invalid-state transport errors.
            $netRes = ReqNet $u $m $sess $body $redir $headers
            if ($netRes.ok) { return $netRes }

            # Secondary fallback without custom headers.
            if ($null -ne $headers -and $headers.Count -gt 0) {
                $netResNoHeaders = ReqNet $u $m $sess $body $redir $null
                if ($netResNoHeaders.ok) { return $netResNoHeaders }
            }

            return [pscustomobject]@{ ok = $false; status = $null; location = ""; content = ""; error = ("" + $_.Exception.Message) }
        }
    }
    function Tinker([string]$code, [int]$timeout = 40) { try { return (& $run $root @("tinker", "--execute=$code", "--no-interaction") $timeout) } catch { return $null } }
    function TblExists([string]$t) {
        $r = Tinker "use Illuminate\Support\Facades\Schema; echo Schema::hasTable('$t') ? '1' : '0';"
        if ($null -eq $r) { return [pscustomobject]@{ ok = $false; exists = $false; msg = "tinker failed" } }
        $o = ("" + $r.StdOut).Trim(); if ([int]$r.ExitCode -ne 0) { return [pscustomobject]@{ ok = $false; exists = $false; msg = "exit=$($r.ExitCode)" } }
        if ($o -eq "1") { return [pscustomobject]@{ ok = $true; exists = $true; msg = "" } }
        if ($o -eq "0") { return [pscustomobject]@{ ok = $true; exists = $false; msg = "" } }
        return [pscustomobject]@{ ok = $false; exists = $false; msg = "out=$o" }
    }
    function TblCount([string]$t) {
        $r = Tinker "use Illuminate\Support\Facades\DB; try { echo (string) DB::table('$t')->count(); } catch (\Throwable `$e) { echo 'ERR:' . `$e->getMessage(); }"
        if ($null -eq $r) { return [pscustomobject]@{ ok = $false; count = 0; msg = "tinker failed" } }
        $o = ("" + $r.StdOut).Trim(); if ([int]$r.ExitCode -ne 0) { return [pscustomobject]@{ ok = $false; count = 0; msg = "exit=$($r.ExitCode)" } }
        if ($o -match '^ERR:') { return [pscustomobject]@{ ok = $false; count = 0; msg = $o } }
        $n = 0; if ([int]::TryParse($o, [ref]$n)) { return [pscustomobject]@{ ok = $true; count = [int]$n; msg = "" } }
        return [pscustomobject]@{ ok = $false; count = 0; msg = "out=$o" }
    }
    function HasKw([string]$txt, [string[]]$keywords) { foreach ($k in @($keywords)) { if ((("" + $txt).ToLowerInvariant()).Contains((("" + $k).ToLowerInvariant()))) { return $true } }; return $false }
    function FindKw([string]$txt, [string[]]$keywords) {
        $hay = ("" + $txt).ToLowerInvariant()
        foreach ($k in @($keywords)) {
            $x = ("" + $k).Trim()
            if ($x -eq "") { continue }
            if ($hay.Contains($x.ToLowerInvariant())) { return $x }
        }
        return ""
    }
    function FindSecRef([string]$txt) {
        try {
            $m = [regex]::Match(("" + $txt), '\bSEC-[A-Z0-9]{6,12}\b')
            if ($m.Success) { return ("" + $m.Value).Trim() }
        } catch { }
        return ""
    }
    function STag([string]$s) { switch ($s) { "OK" { "[OK]" } "WARN" { "[WARN]" } "FAIL" { "[FAIL]" } "SKIP" { "[SKIP]" } default { "[WARN]" } } }
    function AddSub(
        [System.Collections.Generic.List[object]]$arr,
        [string]$n,
        [string]$s,
        [string]$sum,
        [int]$ms,
        [string[]]$evidence = @(),
        [hashtable]$report = $null
    ) {
        if ($null -eq $report) { $report = @{} }
        $arr.Add([pscustomobject]@{
            name = $n
            status = $s
            summary = $sum
            duration_ms = $ms
            evidence = @($evidence)
            report = $report
        }) | Out-Null
    }

    $probe = [bool]$Context.SecurityProbe
    $checkIpBan = [bool]$Context.SecurityCheckIpBan
    $checkReg = [bool]$Context.SecurityCheckRegister
    $expect429 = [bool]$Context.SecurityExpect429
    $attempts = 8; try { $attempts = [Math]::Min(10, [Math]::Max(1, [int]$Context.SecurityLoginAttempts)) } catch { $attempts = 8 }

    # Default keywords: include common Laravel/Breeze throttle phrasing (EN/DE) + generic lockout signals
    $keywords = @(
        "too many attempts",
        "too many login attempts",
        "throttle",
        "locked",
        "lockout",
        "zu viele versuche",
        "zu viele anmeld",
        "zu viele login"
    )
    try { $kw = @($Context.SecurityLockoutKeywords | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" }); if ($kw.Count -gt 0) { $keywords = $kw } } catch { }

    $sub = New-Object System.Collections.Generic.List[object]
    $details = @()
    $evidence = New-Object System.Collections.Generic.List[string]
    $data = @{
        security_probe = $probe
        security_login_attempts = $attempts
        security_check_ip_ban = $checkIpBan
        security_check_register = $checkReg
        security_expect_429 = $expect429
        security_lockout_keywords = @($keywords)
    }
    $data["matched_patterns"] = @($keywords)

    # A
    $sa = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $probe) {
        AddSub $sub "Security Login Rate Limit" "SKIP" "SecurityProbe=false (active probe disabled)." 0 @("Active probe disabled by SecurityProbe=false.") @{ subtest = "login_rate_limit" }
    }
    else {
        $sess = $null; try { $sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession } catch { $sess = $null }
        if ($null -eq $sess) {
            $sa.Stop()
            AddSub $sub "Security Login Rate Limit" "FAIL" "Cannot initialize WebRequestSession." 0 @("WebRequestSession initialization failed.") @{ subtest = "login_rate_limit" }
        }
        else {
            $g = Req "$baseUrl/login" "GET" $sess $null 3
            if (-not $g.ok) {
                $sa.Stop()
                AddSub $sub "Security Login Rate Limit" "FAIL" ("GET /login failed: " + $g.error) ([int]$sa.ElapsedMilliseconds) @("GET /login request error: " + $g.error) @{
                    subtest = "login_rate_limit"
                    http_code = $null
                    redirect_location = ""
                }
            }
            else {
                $tok = ""; try { $m = [regex]::Match(("" + $g.content), 'name\s*=\s*"[_]?token"\s+value\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if ($m.Success) { $tok = ("" + $m.Groups[1].Value) } } catch { $tok = "" }
                if ($tok -eq "") {
                    $sa.Stop()
                    AddSub $sub "Security Login Rate Limit" "FAIL" "GET /login did not expose _token." ([int]$sa.ElapsedMilliseconds) @("CSRF token missing in GET /login response.") @{
                        subtest = "login_rate_limit"
                        http_code = [int]$g.status
                        redirect_location = ("" + $g.location)
                    }
                }
                else {
                    $sig = ""
                    $found = $false
                    $hit419 = $false
                    $trace = New-Object System.Collections.Generic.List[string]

                    $lastStatus = $null
                    $lastLoc = ""
                    $matchedKeyword = ""
                    $matchedKeywords = New-Object System.Collections.Generic.List[string]
                    $secRef = ""
                    $followUpGetLoginStatus = $null
                    $acceptedLockoutStatusCodes = @(429, 422, 302)

                    $loginHeaders = @{ "X-Requested-With" = "XMLHttpRequest" }
                    $xsrfRaw = GetCookieValue $sess $baseUrl "XSRF-TOKEN"
                    $xsrfDecoded = ""
                    try { $xsrfDecoded = [System.Net.WebUtility]::UrlDecode($xsrfRaw) } catch { $xsrfDecoded = $xsrfRaw }
                    if ($xsrfDecoded -ne "") { $loginHeaders["X-XSRF-TOKEN"] = $xsrfDecoded }

                    $probeLoginIdentifier = "audit-probe-lockout@invalid.local"
                    for ($i = 1; $i -le $attempts; $i++) {
                        $p = @{ _token = $tok; email = $probeLoginIdentifier; password = "definitely-wrong-password" }
                        $r = Req "$baseUrl/login" "POST" $sess $p 0 $loginHeaders

                        $st = "n/a"; try { $st = [int]$r.status } catch { }
                        $loc = ("" + $r.location).Trim()
                        if ($loc -ne "") { $trace.Add(("try#${i}: status=$st loc=$loc")) | Out-Null } else { $trace.Add(("try#${i}: status=$st")) | Out-Null }

                        if (-not $r.ok) {
                            if ($sig -eq "") { $sig = "request_error: $($r.error)" }
                            continue
                        }

                        $lastStatus = [int]$r.status
                        $lastLoc = ("" + $r.location).Trim()

                        if ([int]$r.status -eq 419) { $hit419 = $true; $sig = "csrf_419"; break }

                        $payload = ("" + $r.content + " " + $r.location)
                        if ($matchedKeyword -eq "") { $matchedKeyword = FindKw $payload $keywords }
                        if ($matchedKeyword -ne "" -and (-not (@($matchedKeywords.ToArray()) -contains $matchedKeyword))) { $matchedKeywords.Add($matchedKeyword) | Out-Null }
                        if ($secRef -eq "") { $secRef = FindSecRef $payload }
                        if ($secRef -eq "") { $secRef = FindSecRef $lastLoc }

                        $isRedirect = ([int]$r.status -ge 300 -and [int]$r.status -lt 400 -and $lastLoc -ne "")
                        $redirKw = $false
                        $redirNote = ""
                        $redirectToLoginNoKeyword = $false

                        if ($isRedirect) {
                            $followUri = ""
                            $redirectToLogin = $false
                            if ([int]$r.status -eq 302) {
                                try {
                                    $locPath = $lastLoc
                                    if ($lastLoc -match '^(?i)https?://') { $locPath = ("" + ([System.Uri]$lastLoc).AbsolutePath) }
                                    $locPathLower = $locPath.ToLowerInvariant()
                                    if ($locPathLower -eq "/login" -or $locPathLower -eq "login") { $redirectToLogin = $true }
                                } catch { }
                            }

                            if ($redirectToLogin) {
                                $followUri = ($baseUrl + "/login")
                            } else {
                                $followUri = ToAbsUrl $lastLoc
                            }

                            if ($followUri -ne "") {
                                $f = Req $followUri "GET" $sess $null 3
                                if ($f.ok) {
                                    if ($redirectToLogin) { $followUpGetLoginStatus = [int]$f.status }
                                    $fPayload = ("" + $f.content + " " + $f.location)
                                    if ($matchedKeyword -eq "") { $matchedKeyword = FindKw $fPayload $keywords }
                                    if ($matchedKeyword -ne "" -and (-not (@($matchedKeywords.ToArray()) -contains $matchedKeyword))) { $matchedKeywords.Add($matchedKeyword) | Out-Null }
                                    if ($secRef -eq "") { $secRef = FindSecRef $fPayload }

                                    if (HasKw $fPayload $keywords) {
                                        $redirKw = $true
                                        if ($redirectToLogin) {
                                            $redirNote = "302->/login keyword $($r.status)->$($f.status)"
                                        } else {
                                            $redirNote = "redirect_kw $($r.status)->$($f.status)"
                                        }
                                    } elseif ($redirectToLogin -and $i -ge 3) {
                                        $redirectToLoginNoKeyword = $true
                                        $redirNote = "302->/login no-keyword $($r.status)->$($f.status)"
                                    }
                                }
                            }
                        }

                        if ($redirKw) { $found = $true; $sig = "$redirNote at attempt $i"; break }
                        if ($redirectToLoginNoKeyword) { $found = $true; $sig = "$redirNote at attempt $i"; break }

                        # Treat Laravel/Breeze lockout as "detected" if:
                        # - 429 (explicit throttle), or
                        # - 422 (ValidationException) + keyword match, or
                        # - any >=400 + keyword match, or
                        # - redirect chain reveals keyword (handled above), or
                        # - repeated 302->/login after failed attempts (handled above)
                        if ([int]$r.status -eq 429) { $found = $true; $sig = "429 at attempt $i"; break }
                        if ([int]$r.status -eq 422 -and (HasKw $payload $keywords)) { $found = $true; $sig = "422+keyword at attempt $i"; break }
                        if ([int]$r.status -ge 400 -and (HasKw $payload $keywords)) { $found = $true; $sig = "status $($r.status)+keyword at attempt $i"; break }

                        # fallback: location/content contains keyword
                        if (HasKw $payload $keywords) { $found = $true; $sig = "keyword at attempt $i"; break }
                    }

                    $sa.Stop()
                    $data["login_probe_trace"] = @($trace.ToArray())

                    $ev = @(
                        "HTTP Status history: " + (($trace.ToArray()) -join " | "),
                        "MatchedPatterns: " + (($keywords | ForEach-Object { "" + $_ }) -join ", ")
                    )
                    $ev += ("FollowUp GET /login status: " + $(if ($null -ne $followUpGetLoginStatus) { [int]$followUpGetLoginStatus } else { "(n/a)" }))
                    if ($matchedKeywords.Count -gt 0) { $ev += ("Matched keyword(s): " + (($matchedKeywords.ToArray()) -join ", ")) } else { $ev += "Matched keyword(s): none" }
                    if ($secRef -ne "") { $ev += ("SEC-Ref: " + $secRef) }
                    if ($null -ne $lastStatus) { $ev += ("LastStatus: " + [int]$lastStatus) }
                    if ($lastLoc -ne "") { $ev += ("LastLocation: " + $lastLoc) }

                    $rep = @{
                        subtest = "login_rate_limit"
                        http_code = $lastStatus
                        redirect_location = $lastLoc
                        followup_get_login_status = $followUpGetLoginStatus
                        matched_keywords = @($matchedKeywords.ToArray())
                        matched_keyword = $matchedKeyword
                        sec_ref = $secRef
                        expected_http_codes = @($acceptedLockoutStatusCodes)
                        observed_signal = $sig
                    }

                    if ($hit419) {
                        AddSub $sub "Security Login Rate Limit" "FAIL" "Probe invalid: POST /login returned 419 (csrf_419)." ([int]$sa.ElapsedMilliseconds) ($ev + @("419 reason: CSRF/session mismatch during active probe.")) $rep
                    }
                    elseif ($found) {
                        if ($expect429 -and ($null -ne $lastStatus) -and ([int]$lastStatus -notin @(429, 422))) {
                            AddSub $sub "Security Login Rate Limit" "OK" ("Lockout signal detected after <= $attempts attempts ($sig).") ([int]$sa.ElapsedMilliseconds) ($ev + @("NOTE: SecurityExpect429=true but observed HTTP code was " + [int]$lastStatus + " (accepted via keyword/redirect evidence).")) $rep
                        } else {
                            AddSub $sub "Security Login Rate Limit" "OK" ("Lockout signal detected after <= $attempts attempts ($sig).") ([int]$sa.ElapsedMilliseconds) ($ev + @("Lockout signal: " + $sig)) $rep
                        }
                    }
                    elseif ($sig -like "request_error:*" -and $null -eq $lastStatus) {
                        AddSub $sub "Security Login Rate Limit" "WARN" ("Probe transport issue: $sig") ([int]$sa.ElapsedMilliseconds) ($ev + @("No valid HTTP response captured during login probe.")) $rep
                    }
                    else {
                        AddSub $sub "Security Login Rate Limit" "WARN" ("No throttle/lockout signal after $attempts failed logins.") ([int]$sa.ElapsedMilliseconds) ($ev + @("No lockout/keyword signal found.")) $rep
                    }
                }
            }
        }
    }

    # B
    $sb = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $probe) {
        AddSub $sub "Security IP Ban" "SKIP" "SecurityProbe=false (active probe disabled)." 0 @("Active probe disabled by SecurityProbe=false.") @{ subtest = "ip_ban" }
    }
    elseif (-not $checkIpBan) {
        AddSub $sub "Security IP Ban" "SKIP" "SecurityCheckIpBan=false." 0 @("IP ban check disabled by SecurityCheckIpBan=false.") @{ subtest = "ip_ban" }
    }
    else {
        $e = TblExists "security_ip_bans"; $ipBanExists = ($e.ok -and $e.exists); $ipBanCount = 0
        if ($ipBanExists) { $c = TblCount "security_ip_bans"; if ($c.ok) { $ipBanCount = [int]$c.count } }

        $ok = $false; $sig = ""; $err = ""
        $ipTrace = New-Object System.Collections.Generic.List[string]
        $lastStatus = $null
        $lastLoc = ""
        $matchedKeyword = ""
        $secRef = ""

        foreach ($u in @("$baseUrl/login", "$baseUrl/")) {
            $r = Req $u "GET" $null $null 0
            if ($r.ok) {
                $ipTrace.Add(("GET $u => " + [int]$r.status + $(if (("" + $r.location).Trim() -ne "") { " loc=" + ("" + $r.location).Trim() } else { "" }))) | Out-Null
            } else {
                $ipTrace.Add(("GET $u => request_error")) | Out-Null
            }

            if (-not $r.ok) { $err = $r.error; continue }

            $lastStatus = [int]$r.status
            $lastLoc = ("" + $r.location).Trim()

            $payload = ("" + $r.content + " " + $r.location)
            if ($matchedKeyword -eq "") { $matchedKeyword = FindKw $payload @("ip ban", "banned", "blocked", "forbidden") }
            if ($secRef -eq "") { $secRef = FindSecRef $payload }

            if ([int]$r.status -eq 403) { $ok = $true; $sig = "403 on $u"; break }
            if ($matchedKeyword -ne "") { $ok = $true; $sig = "keyword on $u"; break }
        }

        $sb.Stop()
        $evIp = @("HTTP Status history: " + (($ipTrace.ToArray()) -join " | "), "security_ip_bans records: " + $ipBanCount)
        if ($matchedKeyword -ne "") { $evIp += ("MatchedKeyword: " + $matchedKeyword) }
        if ($secRef -ne "") { $evIp += ("SEC-Ref: " + $secRef) }

        $rep = @{
            subtest = "ip_ban"
            http_code = $lastStatus
            redirect_location = $lastLoc
            matched_keyword = $matchedKeyword
            sec_ref = $secRef
            observed_signal = $sig
        }

        if ($ok) {
            AddSub $sub "Security IP Ban" "OK" ("Enforcement visible ($sig).") ([int]$sb.ElapsedMilliseconds) ($evIp + @("Signal: " + $sig)) $rep
        }
        elseif ($ipBanExists -and $ipBanCount -gt 0) {
            AddSub $sub "Security IP Ban" "WARN" ("Ban records exist ($ipBanCount), but enforcement not visible.") ([int]$sb.ElapsedMilliseconds) ($evIp + @("Ban records exist without visible enforcement signal.")) $rep
        }
        elseif ($e.ok -and -not $e.exists) {
            AddSub $sub "Security IP Ban" "SKIP" "security_ip_bans table not present; mechanism appears disabled." ([int]$sb.ElapsedMilliseconds) ($evIp + @("security_ip_bans table not present.")) $rep
        }
        elseif ($err -ne "") {
            AddSub $sub "Security IP Ban" "WARN" ("Probe request issue: $err") ([int]$sb.ElapsedMilliseconds) ($evIp + @("Request error: " + $err)) $rep
        }
        else {
            AddSub $sub "Security IP Ban" "WARN" "Not enforced or not configured." ([int]$sb.ElapsedMilliseconds) $evIp $rep
        }
    }

    # C
    $sc = [System.Diagnostics.Stopwatch]::StartNew()
    $rr = $null; try { $rr = & $run $root @("route:list", "--path=admin", "-vv", "--no-ansi", "--no-interaction") 120 } catch { $rr = $null }
    if ($null -eq $rr) { $sc.Stop(); AddSub $sub "Security Middleware" "WARN" "route:list -vv could not be executed." ([int]$sc.ElapsedMilliseconds) @("route:list -vv execution failed.") @{ subtest = "middleware" } }
    else {
        $o = ""; try { $o = ("" + $rr.StdOut) } catch { $o = "" }
        if ([int]$rr.ExitCode -ne 0 -and $o.Trim() -eq "") { $sc.Stop(); AddSub $sub "Security Middleware" "WARN" ("route:list -vv failed (exit $($rr.ExitCode)).") ([int]$sc.ElapsedMilliseconds) @("route:list -vv exit=" + [int]$rr.ExitCode) @{ subtest = "middleware" } }
        else {
            $routes = New-Object System.Collections.Generic.List[object]; $cur = $null
            foreach ($line in @($o -split "`r?`n")) {
                $flat = (("" + $line) -replace "\s+", " ").Trim()
                if ($flat -match "^(?<methods>(?:GET|HEAD|POST|PUT|PATCH|DELETE|OPTIONS)(?:\|(?:GET|HEAD|POST|PUT|PATCH|DELETE|OPTIONS))*)\s+(?<uri>\S+)\s") {
                    if ($null -ne $cur) { $routes.Add($cur) | Out-Null }
                    $cur = [pscustomobject]@{ methods = ("" + $Matches["methods"]).Trim(); uri = ("" + $Matches["uri"]).Trim(); middleware = New-Object System.Collections.Generic.List[string] }; continue
                }
                if ($null -ne $cur) { $t = ("" + $line).Trim(); if ($t -ne "") { $tok = $t -split '\s+'; $last = ("" + $tok[$tok.Count - 1]).Trim(); if ($last -like "*\*" -or $last -match '^[A-Za-z0-9\._:-]+$') { $cur.middleware.Add($last) | Out-Null } } }
            }
            if ($null -ne $cur) { $routes.Add($cur) | Out-Null }
            $crit = @(); foreach ($rt in @($routes.ToArray())) { $m = ("" + $rt.methods).ToUpperInvariant(); $u = ("" + $rt.uri); if ((($m -match '(^|\|)(PATCH|POST)(\||$)') -and ($u -match '^admin/users/\{[^}]+\}/roles$')) -or (($m -match '(^|\|)DELETE(\||$)') -and ($u -match '^admin/users/\{[^}]+\}$')) -or (($m -match '(^|\|)(POST|PUT|PATCH|DELETE)(\||$)') -and ($u -match '^admin/(settings/)?security'))) { $crit += $rt } }
            if (@($crit).Count -eq 0) { $sc.Stop(); AddSub $sub "Security Middleware" "SKIP" "No critical admin routes found for step-up validation." ([int]$sc.ElapsedMilliseconds) @("No critical admin routes matched rule set.") @{ subtest = "middleware" } }
            else {
                $keys = @("password.confirm", "auth.session", "reauth", "re-auth", "fresh", "passwordconfirm", "confirm", "ensureadminstepup", "ensure_admin_step_up", "ensure-admin-step-up"); $covered = 0; $miss = @()
                foreach ($rt in @($crit)) { $flat = ((@($rt.middleware.ToArray()) | ForEach-Object { ("" + $_).ToLowerInvariant() }) -join " "); $has = $false; foreach ($k in $keys) { if ($flat.Contains($k)) { $has = $true; break } }; if ($has) { $covered++ } else { $miss += ("$($rt.methods) $($rt.uri)") } }
                $sc.Stop()
                $critPreview = @($crit | ForEach-Object { "$($_.methods) $($_.uri)" })
                $evMw = @("Critical routes: " + ($critPreview -join " | "), "MatchedPatterns: " + ($keys -join ", "))
                $rep = @{
                    subtest = "middleware"
                    critical_routes = @($critPreview)
                    matched_patterns = @($keys)
                    covered = [int]$covered
                    total = [int]@($crit).Count
                    missing = @($miss)
                }
                if ($covered -eq @($crit).Count) { AddSub $sub "Security Middleware" "OK" ("Step-up/fresh-session middleware present on $covered critical route(s).") ([int]$sc.ElapsedMilliseconds) ($evMw + @("Coverage: $covered/$(@($crit).Count)")) $rep }
                elseif ($covered -gt 0) { AddSub $sub "Security Middleware" "WARN" ("Step-up present on $covered/$(@($crit).Count) critical route(s); missing on: " + ($miss -join ", ")) ([int]$sc.ElapsedMilliseconds) ($evMw + @("Missing: " + ($miss -join ", "))) $rep }
                else { AddSub $sub "Security Middleware" "WARN" ("No step-up middleware found on $(@($crit).Count) critical route(s).") ([int]$sc.ElapsedMilliseconds) ($evMw + @("Missing: " + ($miss -join ", "))) $rep }
            }
        }
    }

    # D
    $sd = [System.Diagnostics.Stopwatch]::StartNew(); $tDet = New-Object System.Collections.Generic.List[string]; $failed = $false
    foreach ($t in @("security_events")) {
        $e = TblExists $t
        if (-not $e.ok) { $failed = $true; $tDet.Add("${t}: existence check failed ($($e.msg))") | Out-Null; continue }
        if (-not $e.exists) { $failed = $true; $tDet.Add("${t}: missing (required)") | Out-Null; continue }
        $c = TblCount $t
        if (-not $c.ok) { $failed = $true; $tDet.Add("${t}: count query failed ($($c.msg))") | Out-Null; continue }
        $tDet.Add("${t}: OK (count=$($c.count))") | Out-Null
    }
    foreach ($t in @("security_incidents", "security_ip_bans")) {
        $e = TblExists $t
        if (-not $e.ok) { $tDet.Add("${t}: WARN existence check failed ($($e.msg))") | Out-Null; continue }
        if (-not $e.exists) { $tDet.Add("${t}: SKIP (not present)") | Out-Null; continue }
        $c = TblCount $t
        if (-not $c.ok) { $tDet.Add("${t}: WARN count query failed ($($c.msg))") | Out-Null; continue }
        $tDet.Add("${t}: OK (count=$($c.count))") | Out-Null
    }
    $sd.Stop()
    if ($failed) {
        AddSub $sub "Security Tables" "FAIL" (($tDet.ToArray()) -join "; ") ([int]$sd.ElapsedMilliseconds) @($tDet.ToArray()) @{ subtest = "tables" }
    } else {
        AddSub $sub "Security Tables" "OK" (($tDet.ToArray()) -join "; ") ([int]$sd.ElapsedMilliseconds) @($tDet.ToArray()) @{ subtest = "tables" }
    }

    # E
    $se = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $probe) {
        AddSub $sub "Security Registration Abuse" "SKIP" "SecurityProbe=false (active probe disabled)." 0 @("Active probe disabled by SecurityProbe=false.") @{ subtest = "register_abuse" }
    }
    elseif (-not $checkReg) {
        AddSub $sub "Security Registration Abuse" "SKIP" "SecurityCheckRegister=false." 0 @("Registration check disabled by SecurityCheckRegister=false.") @{ subtest = "register_abuse" }
    }
    else {
        $hasReg = $false; try { $rl = & $run $root @("route:list", "--path=register", "--no-ansi", "--no-interaction") 60; if (("" + $rl.StdOut) -match '\bregister\b') { $hasReg = $true } } catch { $hasReg = $false }
        if (-not $hasReg) {
            $se.Stop()
            AddSub $sub "Security Registration Abuse" "SKIP" "/register route not present." ([int]$se.ElapsedMilliseconds) @("/register route not found in route:list output.") @{ subtest = "register_abuse"; reason = "route_missing" }
        }
        else {
            $sess = $null; try { $sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession } catch { $sess = $null }
            if ($null -eq $sess) {
                $se.Stop()
                AddSub $sub "Security Registration Abuse" "WARN" "Cannot initialize WebRequestSession." ([int]$se.ElapsedMilliseconds) @("WebRequestSession initialization failed.") @{ subtest = "register_abuse" }
            }
            else {
                $g = Req "$baseUrl/register" "GET" $sess $null 3
                if (-not $g.ok) {
                    $se.Stop()
                    AddSub $sub "Security Registration Abuse" "WARN" ("GET /register failed: " + $g.error) ([int]$se.ElapsedMilliseconds) @("GET /register request error: " + $g.error) @{ subtest = "register_abuse" }
                }
                else {
                    $tok = ""; try { $m = [regex]::Match(("" + $g.content), 'name\s*=\s*"[_]?token"\s+value\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if ($m.Success) { $tok = ("" + $m.Groups[1].Value) } } catch { $tok = "" }
                    if ($tok -eq "") {
                        $se.Stop()
                        AddSub $sub "Security Registration Abuse" "WARN" "GET /register did not expose _token." ([int]$se.ElapsedMilliseconds) @("CSRF token missing in GET /register response.") @{ subtest = "register_abuse"; http_code = [int]$g.status; redirect_location = ("" + $g.location) }
                    }
                    else {
                        $hit429 = $false; $hit419 = $false; $kw = $false
                        $regTrace = New-Object System.Collections.Generic.List[string]

                        $lastStatus = $null
                        $lastLoc = ""
                        $matchedKeyword = ""
                        $secRef = ""
                        $sig = ""

                        $registerHeaders = @{ "X-Requested-With" = "XMLHttpRequest" }
                        $regXsrfRaw = GetCookieValue $sess $baseUrl "XSRF-TOKEN"
                        $regXsrfDecoded = ""
                        try { $regXsrfDecoded = [System.Net.WebUtility]::UrlDecode($regXsrfRaw) } catch { $regXsrfDecoded = $regXsrfRaw }
                        if ($regXsrfDecoded -ne "") { $registerHeaders["X-XSRF-TOKEN"] = $regXsrfDecoded }

                        for ($i = 1; $i -le 6; $i++) {
                            $r = Req "$baseUrl/register" "POST" $sess @{ _token = $tok; name = "Audit Probe"; email = "invalid-email-$i"; password = "short"; password_confirmation = "different" } 0 $registerHeaders

                            $st = "n/a"; try { $st = [int]$r.status } catch { }
                            $loc = ("" + $r.location).Trim()
                            if ($r.ok) {
                                if ($loc -ne "") { $regTrace.Add(("try#${i}: status=$st loc=$loc")) | Out-Null } else { $regTrace.Add(("try#${i}: status=$st")) | Out-Null }
                            } else {
                                $regTrace.Add(("try#${i}: request_error")) | Out-Null
                            }

                            if (-not $r.ok) { continue }

                            $lastStatus = [int]$r.status
                            $lastLoc = ("" + $r.location).Trim()

                            if ([int]$r.status -eq 419) { $hit419 = $true; $sig = "csrf_419"; break }
                            if ([int]$r.status -eq 429) { $hit429 = $true; $sig = "429"; break }

                            $payload = ("" + $r.content + " " + $r.location)
                            if ($matchedKeyword -eq "") { $matchedKeyword = FindKw $payload $keywords }
                            if ($secRef -eq "") { $secRef = FindSecRef $payload }

                            $isRedirect = ([int]$r.status -ge 300 -and [int]$r.status -lt 400 -and $lastLoc -ne "")
                            if ($isRedirect) {
                                $abs = ToAbsUrl $lastLoc
                                if ($abs -ne "") {
                                    $f = Req $abs "GET" $sess $null 3
                                    if ($f.ok) {
                                        $fPayload = ("" + $f.content + " " + $f.location)
                                        if ($matchedKeyword -eq "") { $matchedKeyword = FindKw $fPayload $keywords }
                                        if ($secRef -eq "") { $secRef = FindSecRef $fPayload }
                                        if (HasKw $fPayload $keywords) { $kw = $true; $sig = "redirect+keyword"; break }
                                    }
                                }
                            }

                            if ([int]$r.status -eq 422) {
                                if (HasKw $payload $keywords) { $kw = $true; $sig = "422+keyword"; break }
                            }

                            if (HasKw $payload $keywords) { $kw = $true; $sig = "keyword"; break }
                        }

                        $data["register_probe_trace"] = @($regTrace.ToArray())
                        $se.Stop()

                        $evReg = @(
                            "HTTP Status history: " + (($regTrace.ToArray()) -join " | "),
                            "MatchedPatterns: " + (($keywords | ForEach-Object { "" + $_ }) -join ", ")
                        )
                        if ($matchedKeyword -ne "") { $evReg += ("MatchedKeyword: " + $matchedKeyword) }
                        if ($secRef -ne "") { $evReg += ("SEC-Ref: " + $secRef) }
                        if ($null -ne $lastStatus) { $evReg += ("LastStatus: " + [int]$lastStatus) }
                        if ($lastLoc -ne "") { $evReg += ("LastLocation: " + $lastLoc) }

                        $rep = @{
                            subtest = "register_abuse"
                            http_code = $lastStatus
                            redirect_location = $lastLoc
                            matched_keyword = $matchedKeyword
                            sec_ref = $secRef
                            expected_http_codes = @(
                                429,
                                422
                            )
                            observed_signal = $sig
                        }

                        if ($hit419) {
                            AddSub $sub "Security Registration Abuse" "WARN" "Probe invalid: POST /register returned 419 (csrf_419)." ([int]$se.ElapsedMilliseconds) ($evReg + @("419 reason: CSRF/session mismatch during active probe.")) $rep
                        }
                        elseif ($hit429 -or $kw) {
                            AddSub $sub "Security Registration Abuse" "OK" "Protection signal detected (429/422+keyword/redirect+keyword/keyword)." ([int]$se.ElapsedMilliseconds) ($evReg + @("Signal: " + $(if ($hit429) { "429" } else { $sig }))) $rep
                        }
                        else {
                            AddSub $sub "Security Registration Abuse" "WARN" "No abuse-protection signal within 6 attempts." ([int]$se.ElapsedMilliseconds) ($evReg + @("No lockout/keyword signal found.")) $rep
                        }
                    }
                }
            }
        }
    }

    $ok = 0; $warn = 0; $fail = 0; $skip = 0
    foreach ($s in @($sub.ToArray())) {
        switch ("" + $s.status) { "OK" { $ok++ } "WARN" { $warn++ } "FAIL" { $fail++ } "SKIP" { $skip++ } }
        $details += ((STag $s.status) + " " + $s.name + " - " + $s.summary + " (" + [int]$s.duration_ms + "ms)")
        foreach ($evLine in @($s.evidence)) { if (("" + $evLine).Trim() -ne "") { $evidence.Add(($s.name + ": " + ("" + $evLine))) | Out-Null } }
    }
    $status = "OK"; $block = "PASS"
    if ($fail -gt 0) { $status = "FAIL"; $block = "FAIL" } elseif ($warn -gt 0 -or ($ok -eq 0 -and $skip -gt 0)) { $status = "WARN"; $block = "PASS_WITH_WARNINGS" }
    $details += ""; $details += ("Summary: $block (OK=$ok, WARN=$warn, FAIL=$fail, SKIP=$skip)")
    $data["subchecks"] = @($sub.ToArray()); $data["summary"] = $block
    $data["evidence"] = @($evidence.ToArray())

    $sw.Stop()
    $detailsText = ""
    try { $detailsText = (($details | ForEach-Object { "" + $_ }) -join "`n") } catch { $detailsText = "" }
    return & $new -Id "security_abuse" -Title "X) Security / Abuse Protection" -Status $status -Summary ("Block status: " + $block) -Details $details -Data $data -DetailsText $detailsText -Evidence @($evidence.ToArray()) -DurationMs ([int]$sw.ElapsedMilliseconds)
}