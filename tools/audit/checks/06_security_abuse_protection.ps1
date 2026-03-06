Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\06_security_abuse_protection.ps1
# Purpose: Audit check - security / abuse protection block (active probes + evidence)
# Created: 01-03-2026 13:20 (Europe/Berlin)
# Changed: 05-03-2026 00:20 (Europe/Berlin)
# Version: 1.0
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
    function HVal($h, [string]$n) {
        try { foreach ($k in @($h.Keys)) { if (("" + $k).Equals($n, [System.StringComparison]::OrdinalIgnoreCase)) { return ("" + $h[$k]) } } } catch { }
        return ""
    }
    function Req([string]$u, [string]$m, $sess, $body, [int]$redir = 0) {
        $p = @{ Uri = $u; Method = $m; MaximumRedirection = $redir }; foreach ($k in (New-IwrBase).Keys) { $p[$k] = (New-IwrBase)[$k] }
        if ($null -ne $sess) { $p["WebSession"] = $sess }
        if ($null -ne $body) { $p["ContentType"] = "application/x-www-form-urlencoded"; $p["Body"] = $body }
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
            return [pscustomobject]@{ ok = $false; status = $null; location = ""; content = ""; error = ("" + $_.Exception.Message) }
        }
    }

    function New-CurlJar([string]$prefix) {
        $id = [Guid]::NewGuid().ToString("N")
        $jar = Join-Path $env:TEMP ("ks_audit_" + $prefix + "_cookies_" + $id + ".txt")
        $out = Join-Path $env:TEMP ("ks_audit_" + $prefix + "_body_" + $id + ".html")
        $hdr = Join-Path $env:TEMP ("ks_audit_" + $prefix + "_headers_" + $id + ".txt")
        return [pscustomobject]@{ jar = $jar; body = $out; headers = $hdr }
    }

    function Parse-CurlHeaders([string]$headerText) {
        $status = $null
        $location = ""
        try {
            $lines = @($headerText -split "`r?`n")
            foreach ($ln in $lines) {
                $t = ("" + $ln).Trim()
                if ($t -match '^HTTP/\d+(\.\d+)?\s+(?<code>\d{3})\b') {
                    $code = 0
                    if ([int]::TryParse(($Matches["code"]), [ref]$code)) { $status = $code }
                    continue
                }
                if ($t -match '^(?i)Location:\s*(?<loc>.+)$') {
                    $location = ("" + $Matches["loc"]).Trim()
                }
            }
        } catch { }
        return [pscustomobject]@{ status = $status; location = $location }
    }

    function Curl-Req(
        [string]$u,
        [string]$m,
        [string]$cookieJar,
        [hashtable]$form,
        [int]$maxRedirs,
        [int]$timeoutSec
    ) {
        $tmp = New-CurlJar "req"
        $args = New-Object System.Collections.Generic.List[string]
        $args.Add("-s") | Out-Null
        $args.Add("-S") | Out-Null
        $args.Add("-i") | Out-Null
        $args.Add("--compressed") | Out-Null
        $args.Add("--max-time") | Out-Null
        $args.Add([string]$timeoutSec) | Out-Null

        if ($maxRedirs -gt 0) {
            $args.Add("-L") | Out-Null
            $args.Add("--max-redirs") | Out-Null
            $args.Add([string]$maxRedirs) | Out-Null
        } else {
            $args.Add("--max-redirs") | Out-Null
            $args.Add("0") | Out-Null
        }

        if ($cookieJar -ne "") {
            $args.Add("-b") | Out-Null
            $args.Add($cookieJar) | Out-Null
            $args.Add("-c") | Out-Null
            $args.Add($cookieJar) | Out-Null
        }

        if (($m.ToUpperInvariant()) -eq "POST") {
            if ($null -ne $form) {
                foreach ($k in @($form.Keys)) {
                    $args.Add("--data-urlencode") | Out-Null
                    $args.Add(("$k=" + ("" + $form[$k]))) | Out-Null
                }
            }
        }

        $args.Add("-o") | Out-Null
        $args.Add($tmp.body) | Out-Null

        $args.Add("-D") | Out-Null
        $args.Add($tmp.headers) | Out-Null

        $args.Add($u) | Out-Null

        $exit = 0
        $err = ""
        try {
            & curl.exe @($args.ToArray()) | Out-Null
            $exit = [int]$LASTEXITCODE
        } catch {
            $exit = 999
            $err = ("" + $_.Exception.Message)
        }

        if ($exit -ne 0) {
            if ($err -eq "") { $err = "curl exitcode=$exit" }
            return [pscustomobject]@{ ok = $false; status = $null; location = ""; content = ""; error = $err }
        }

        $hdrText = ""
        $bodyText = ""
        try { if (Test-Path $tmp.headers) { $hdrText = (Get-Content $tmp.headers -Raw) } } catch { $hdrText = "" }
        try { if (Test-Path $tmp.body) { $bodyText = (Get-Content $tmp.body -Raw) } } catch { $bodyText = "" }

        $p = Parse-CurlHeaders $hdrText

        return [pscustomobject]@{
            ok = $true
            status = $p.status
            location = $p.location
            content = $bodyText
            error = ""
            _tmp = $tmp
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
    function STag([string]$s) { switch ($s) { "OK" { "[OK]" } "WARN" { "[WARN]" } "FAIL" { "[FAIL]" } "SKIP" { "[SKIP]" } default { "[WARN]" } } }
    function AddSub([System.Collections.Generic.List[object]]$arr, [string]$n, [string]$s, [string]$sum, [int]$ms, [string[]]$evidence = @()) { $arr.Add([pscustomobject]@{ name = $n; status = $s; summary = $sum; duration_ms = $ms; evidence = @($evidence) }) | Out-Null }

    function Normalize-MiddlewareToken([string]$s) {
        if ($null -eq $s) { return "" }
        $t = ("" + $s).Trim()
        if ($t -eq "") { return "" }
        $t = $t.Trim(',', ';', '[', ']', '(', ')')
        $t = $t.Trim()
        return $t
    }

    function Normalize-MethodsToken($val) {
        if ($null -eq $val) { return "" }

        if ($val -is [string]) {
            return ("" + $val).Trim()
        }

        if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
            $parts = @()
            try { $parts = @($val | ForEach-Object { ("" + $_).Trim().ToUpperInvariant() } | Where-Object { $_ -ne "" }) } catch { $parts = @() }
            if ($parts.Count -gt 0) { return (($parts | Select-Object -Unique) -join "|") }
        }

        return ("" + $val).Trim()
    }

    function Extract-MiddlewareList($it) {
        $mw = @()

        # direct "middleware" property
        try {
            if ($it.PSObject -and ($it.PSObject.Properties.Name -contains "middleware")) {
                $mwRaw = $it.middleware
                if ($mwRaw -is [string]) {
                    $mw = @($mwRaw -split "[,]+" | ForEach-Object { Normalize-MiddlewareToken $_ } | Where-Object { $_ -ne "" })
                    return @($mw)
                }
                if ($mwRaw -is [System.Collections.IEnumerable] -and -not ($mwRaw -is [string])) {
                    $mw = @($mwRaw | ForEach-Object { Normalize-MiddlewareToken $_ } | Where-Object { $_ -ne "" })
                    return @($mw)
                }
            }
        } catch { $mw = @() }

        # fallback "action.middleware" (Laravel JSON variants)
        try {
            if ($it.PSObject -and ($it.PSObject.Properties.Name -contains "action")) {
                $act = $it.action
                if ($null -ne $act -and $act.PSObject -and ($act.PSObject.Properties.Name -contains "middleware")) {
                    $mwRaw2 = $act.middleware
                    if ($mwRaw2 -is [string]) {
                        $mw = @($mwRaw2 -split "[,]+" | ForEach-Object { Normalize-MiddlewareToken $_ } | Where-Object { $_ -ne "" })
                        return @($mw)
                    }
                    if ($mwRaw2 -is [System.Collections.IEnumerable] -and -not ($mwRaw2 -is [string])) {
                        $mw = @($mwRaw2 | ForEach-Object { Normalize-MiddlewareToken $_ } | Where-Object { $_ -ne "" })
                        return @($mw)
                    }
                }
            }
        } catch { $mw = @() }

        return @()
    }

    function Try-LoadAdminRoutesFromRouteListJson([string]$Root, [int]$TimeoutSec = 120) {
        try {
            $rj = $null
            try { $rj = & $run $Root @("route:list", "--path=admin", "--json", "--no-ansi", "--no-interaction") $TimeoutSec } catch { $rj = $null }
            if ($null -eq $rj) { return [pscustomobject]@{ ok = $false; routes = @(); note = "route:list --json could not be executed." } }

            $out = ""
            try { $out = ("" + $rj.StdOut).Trim() } catch { $out = "" }
            if ($out -eq "") { return [pscustomobject]@{ ok = $false; routes = @(); note = "route:list --json returned empty output." } }

            $obj = $null
            try { $obj = $out | ConvertFrom-Json -ErrorAction Stop } catch { $obj = $null }
            if ($null -eq $obj) { return [pscustomobject]@{ ok = $false; routes = @(); note = "route:list --json output not parseable as JSON." } }

            $items = @()
            if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
                $items = @($obj)
            } elseif ($obj.PSObject -and ($obj.PSObject.Properties.Name -contains "routes")) {
                $items = @($obj.routes)
            } else {
                $items = @()
            }

            if ($items.Count -le 0) { return [pscustomobject]@{ ok = $true; routes = @(); note = "route:list --json parsed but no routes found." } }

            $routes = New-Object System.Collections.Generic.List[object]
            foreach ($it in @($items)) {
                if ($null -eq $it) { continue }

                $m = ""
                $u = ""
                $mw = @()

                try {
                    if ($it.PSObject -and ($it.PSObject.Properties.Name -contains "method")) { $m = Normalize-MethodsToken $it.method }
                    elseif ($it.PSObject -and ($it.PSObject.Properties.Name -contains "methods")) { $m = Normalize-MethodsToken $it.methods }
                } catch { $m = "" }

                try {
                    if ($it.PSObject -and ($it.PSObject.Properties.Name -contains "uri")) { $u = ("" + $it.uri).Trim() }
                } catch { $u = "" }

                try { $mw = @(Extract-MiddlewareList $it) } catch { $mw = @() }

                if ($m -eq "" -and $u -eq "") { continue }

                $routes.Add([pscustomobject]@{
                    methods = $m
                    uri = $u
                    middleware = @($mw)
                }) | Out-Null
            }

            return [pscustomobject]@{ ok = $true; routes = @($routes.ToArray()); note = "route:list --json" }
        } catch {
            return [pscustomobject]@{ ok = $false; routes = @(); note = ("route:list --json exception: " + $_.Exception.Message) }
        }
    }

    function Parse-AdminRoutesFromRouteListVerboseText([string]$Text) {
        $routes = New-Object System.Collections.Generic.List[object]
        try {
            $cur = $null
            foreach ($line in @($Text -split "`r?`n")) {
                $flat = (("" + $line) -replace "\s+", " ").Trim()

                if ($flat -match "^(?<methods>(?:GET|HEAD|POST|PUT|PATCH|DELETE|OPTIONS)(?:\|(?:GET|HEAD|POST|PUT|PATCH|DELETE|OPTIONS))*)\s+(?<uri>\S+)\s") {
                    if ($null -ne $cur) { $routes.Add($cur) | Out-Null }
                    $cur = [pscustomobject]@{ methods = ("" + $Matches["methods"]).Trim(); uri = ("" + $Matches["uri"]).Trim(); middleware = New-Object System.Collections.Generic.List[string] }
                    continue
                }

                if ($null -eq $cur) { continue }

                $t = ("" + $line).Trim()
                if ($t -eq "") { continue }

                if ($t -match '^(?i)Middleware\s*:\s*(?<mw>.+)$') {
                    $mwText = ("" + $Matches["mw"]).Trim()
                    if ($mwText -ne "") {
                        $parts = @($mwText -split "[,]+" | ForEach-Object { Normalize-MiddlewareToken $_ } | Where-Object { $_ -ne "" })
                        foreach ($p in @($parts)) { $cur.middleware.Add($p) | Out-Null }
                    }
                    continue
                }

                # Fallback: old heuristic (keep for compatibility)
                $tok = $t -split '\s+'
                $last = ""
                try { $last = ("" + $tok[$tok.Count - 1]).Trim() } catch { $last = "" }
                $last = Normalize-MiddlewareToken $last
                if ($last -ne "" -and ($last -like "*\*" -or $last -match '^[A-Za-z0-9\._:-]+$')) {
                    $cur.middleware.Add($last) | Out-Null
                }
            }
            if ($null -ne $cur) { $routes.Add($cur) | Out-Null }
        } catch { }

        return @($routes.ToArray())
    }

    $probe = [bool]$Context.SecurityProbe
    $checkIpBan = [bool]$Context.SecurityCheckIpBan
    $checkReg = [bool]$Context.SecurityCheckRegister
    $expect429 = [bool]$Context.SecurityExpect429

    $attempts = 8
    try { $attempts = [Math]::Min(10, [Math]::Max(1, [int]$Context.SecurityLoginAttempts)) } catch { $attempts = 8 }

    $baseKeywords = @(
        "too many attempts", "throttle", "locked", "lockout",
        "zu viele", "loginversuche", "sekunden", "versuchen sie es bitte"
    )
    $keywords = @($baseKeywords)

    try {
        $kw = @($Context.SecurityLockoutKeywords | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
        if ($kw.Count -gt 0) { $keywords = @($keywords + $kw) }
    } catch { }

    $expectedAttemptLimit = $null
    try {
        $r = Tinker "use Illuminate\Support\Facades\DB; try { echo (string) (DB::table('security_settings')->value('login_attempt_limit') ?? ''); } catch (\Throwable `$e) { echo ''; }"
        if ($null -ne $r -and [int]$r.ExitCode -eq 0) {
            $o = ("" + $r.StdOut).Trim()
            $n = 0
            if ([int]::TryParse($o, [ref]$n) -and $n -gt 0) { $expectedAttemptLimit = $n }
        }
    } catch { $expectedAttemptLimit = $null }

    $probeTries = $attempts
    if ($null -ne $expectedAttemptLimit) {
        $probeTries = [Math]::Max($probeTries, ($expectedAttemptLimit + 1))
    } else {
        $probeTries = [Math]::Max($probeTries, ($attempts + 1))
    }
    $probeTries = [Math]::Min(12, [Math]::Max(1, [int]$probeTries))

    $probeEmail = "audit-probe@invalid.local"
    try {
        $pe = ("" + $Context.SecurityProbeEmail).Trim()
        if ($pe -ne "") { $probeEmail = $pe }
    } catch { }

    $sub = New-Object System.Collections.Generic.List[object]
    $details = @()
    $evidence = New-Object System.Collections.Generic.List[string]
    $data = @{
        security_probe = $probe
        security_login_attempts = $attempts
        security_login_probe_tries = $probeTries
        security_login_expected_attempt_limit = $expectedAttemptLimit
        security_login_probe_email = $probeEmail
        security_check_ip_ban = $checkIpBan
        security_check_register = $checkReg
        security_expect_429 = $expect429
        security_lockout_keywords = @($keywords)
    }
    $data["matched_patterns"] = @($keywords)

    # A
    $sa = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $probe) {
        AddSub $sub "Security Login Rate Limit" "SKIP" "SecurityProbe=false (active probe disabled)." 0 @("Active probe disabled by SecurityProbe=false.")
    }
    else {
        $jar = New-CurlJar "login_probe"
        $cookieJar = $jar.jar

        $g = Curl-Req "$baseUrl/login" "GET" $cookieJar $null 3 12
        if (-not $g.ok) {
            $sa.Stop()
            AddSub $sub "Security Login Rate Limit" "FAIL" ("GET /login failed: " + $g.error) ([int]$sa.ElapsedMilliseconds) @("GET /login request error: " + $g.error)
        }
        else {
            $tok = ""
            try { $m = [regex]::Match(("" + $g.content), 'name\s*=\s*"[_]?token"\s+value\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if ($m.Success) { $tok = ("" + $m.Groups[1].Value) } } catch { $tok = "" }

            if ($tok -eq "") {
                $sa.Stop()
                AddSub $sub "Security Login Rate Limit" "FAIL" "GET /login did not expose _token." ([int]$sa.ElapsedMilliseconds) @("CSRF token missing in GET /login response.")
            }
            else {
                $sig = ""
                $found = $false
                $hit419 = $false
                $trace = New-Object System.Collections.Generic.List[string]

                for ($i = 1; $i -le $probeTries; $i++) {
                    $p = @{
                        _token   = $tok
                        email    = $probeEmail
                        password = "definitely-wrong-password"
                    }

                    $r = Curl-Req "$baseUrl/login" "POST" $cookieJar $p 0 12
                    $postStatus = "n/a"
                    try { if ($null -ne $r.status) { $postStatus = [int]$r.status } } catch { $postStatus = "n/a" }

                    if (-not $r.ok) {
                        $trace.Add(("try#${i}: post_status=0 request_error")) | Out-Null
                        $sig = "request_error: $($r.error)"
                        break
                    }

                    if ([int]$r.status -eq 419) {
                        $hit419 = $true
                        $sig = "csrf_419"
                        $trace.Add(("try#${i}: post_status=419")) | Out-Null
                        break
                    }

                    $h = Curl-Req "$baseUrl/login" "GET" $cookieJar $null 3 12
                    $getStatus = "n/a"
                    try { if ($null -ne $h.status) { $getStatus = [int]$h.status } } catch { $getStatus = "n/a" }

                    $trace.Add(("try#${i}: post_status=$postStatus get_status=$getStatus")) | Out-Null

                    if (-not $h.ok) {
                        $sig = "request_error: $($h.error)"
                        break
                    }

                    if (HasKw ("" + $h.content + " " + $r.location + " " + $r.content) $keywords) { $found = $true; $sig = "keyword at attempt $i"; break }
                    if ([int]$r.status -in @(429, 423, 403)) { $found = $true; $sig = "$($r.status) at attempt $i"; break }
                }

                $sa.Stop()
                $data["login_probe_trace"] = @($trace.ToArray())

                $ev = @(
                    "ProbeEmail: $probeEmail",
                    "HTTP Status history: " + (($trace.ToArray()) -join " | "),
                    "MatchedPatterns: " + (($keywords | ForEach-Object { "" + $_ }) -join ", "),
                    "ConfiguredAttempts: $attempts; ProbeTries: $probeTries; ExpectedAttemptLimit: " + $(if ($null -eq $expectedAttemptLimit) { "n/a" } else { [int]$expectedAttemptLimit })
                )

                if ($hit419) {
                    AddSub $sub "Security Login Rate Limit" "FAIL" "Probe invalid: POST /login returned 419 (csrf_419)." ([int]$sa.ElapsedMilliseconds) ($ev + @("419 reason: CSRF/session mismatch during active probe."))
                }
                elseif ($found -and $expect429 -and ($sig -notmatch '^429')) {
                    AddSub $sub "Security Login Rate Limit" "WARN" ("Lockout signal detected, but no 429 while SecurityExpect429=true ($sig).") ([int]$sa.ElapsedMilliseconds) ($ev + @("Expected explicit 429 but observed: " + $sig))
                }
                elseif ($found) {
                    AddSub $sub "Security Login Rate Limit" "OK" ("Lockout after <= $probeTries attempts ($sig).") ([int]$sa.ElapsedMilliseconds) ($ev + @("Lockout signal: " + $sig))
                }
                elseif ($sig -like "request_error:*") {
                    AddSub $sub "Security Login Rate Limit" "FAIL" ("Probe failed: $sig") ([int]$sa.ElapsedMilliseconds) ($ev + @("Request error encountered."))
                }
                else {
                    AddSub $sub "Security Login Rate Limit" "FAIL" ("No throttle/lockout signal after $probeTries failed logins.") ([int]$sa.ElapsedMilliseconds) ($ev + @("No lockout/keyword signal found."))
                }
            }
        }
    }

    # B
    $sb = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $probe) { AddSub $sub "Security IP Ban" "SKIP" "SecurityProbe=false (active probe disabled)." 0 @("Active probe disabled by SecurityProbe=false.") }
    elseif (-not $checkIpBan) { AddSub $sub "Security IP Ban" "SKIP" "SecurityCheckIpBan=false." 0 @("IP ban check disabled by SecurityCheckIpBan=false.") }
    else {
        $e = TblExists "security_ip_bans"; $ipBanExists = ($e.ok -and $e.exists); $ipBanCount = 0
        if ($ipBanExists) { $c = TblCount "security_ip_bans"; if ($c.ok) { $ipBanCount = [int]$c.count } }
        $ok = $false; $sig = ""; $err = ""
        $ipTrace = New-Object System.Collections.Generic.List[string]
        foreach ($u in @("$baseUrl/login", "$baseUrl/")) {
            $r = Req $u "GET" $null $null 0
            if ($r.ok) { $ipTrace.Add(("GET $u => " + [int]$r.status)) | Out-Null } else { $ipTrace.Add(("GET $u => request_error")) | Out-Null }
            if (-not $r.ok) { $err = $r.error; continue }
            if ([int]$r.status -eq 403) { $ok = $true; $sig = "403 on $u"; break }
            if ((("" + $r.content + " " + $r.location).ToLowerInvariant()) -match '\b(ip[\s_-]?ban|banned|blocked|forbidden)\b') { $ok = $true; $sig = "ban keyword on $u"; break }
        }
        $sb.Stop()
        $evIp = @("HTTP Status history: " + (($ipTrace.ToArray()) -join " | "), "security_ip_bans records: " + $ipBanCount)
        if ($ok) { AddSub $sub "Security IP Ban" "OK" ("Enforcement visible ($sig).") ([int]$sb.ElapsedMilliseconds) ($evIp + @("Signal: " + $sig)) }
        elseif ($ipBanExists -and $ipBanCount -gt 0) { AddSub $sub "Security IP Ban" "WARN" ("Ban records exist ($ipBanCount), but enforcement not visible.") ([int]$sb.ElapsedMilliseconds) ($evIp + @("Ban records exist without visible enforcement signal.")) }
        elseif ($e.ok -and -not $e.exists) { AddSub $sub "Security IP Ban" "SKIP" "security_ip_bans table not present; mechanism appears disabled." ([int]$sb.ElapsedMilliseconds) ($evIp + @("security_ip_bans table not present.")) }
        elseif ($err -ne "") { AddSub $sub "Security IP Ban" "WARN" ("Probe request issue: $err") ([int]$sb.ElapsedMilliseconds) ($evIp + @("Request error: " + $err)) }
        else { AddSub $sub "Security IP Ban" "WARN" "Not enforced or not configured." ([int]$sb.ElapsedMilliseconds) $evIp }
    }

    # C
    $sc = [System.Diagnostics.Stopwatch]::StartNew()

    $routes = @()
    $routeSourceNote = ""
    $jsonTry = Try-LoadAdminRoutesFromRouteListJson -Root $root -TimeoutSec 120
    if ($jsonTry.ok) {
        $routes = @($jsonTry.routes)
        $routeSourceNote = ("" + $jsonTry.note).Trim()
    } else {
        $rr = $null
        try { $rr = & $run $root @("route:list", "--path=admin", "-vv", "--no-ansi", "--no-interaction") 120 } catch { $rr = $null }

        if ($null -ne $rr) {
            $o = ""
            try { $o = ("" + $rr.StdOut) } catch { $o = "" }
            if (-not ([int]$rr.ExitCode -ne 0 -and $o.Trim() -eq "")) {
                $routes = @(Parse-AdminRoutesFromRouteListVerboseText -Text $o)
                $routeSourceNote = "route:list -vv (text parse)"
            } else {
                $routeSourceNote = "route:list -vv failed"
            }
        } else {
            $routeSourceNote = "route:list -vv could not be executed"
        }
    }

    if (@($routes).Count -le 0) {
        $sc.Stop()
        AddSub $sub "Security Middleware" "WARN" ("No routes available for middleware validation (" + $routeSourceNote + ").") ([int]$sc.ElapsedMilliseconds) @("Route source: " + $routeSourceNote)
    } else {
        $crit = @()
        foreach ($rt in @($routes)) {
            $m = ("" + $rt.methods).ToUpperInvariant()
            $u = ("" + $rt.uri)

            if ((($m -match '(^|\|)(PATCH|POST)(\||$)') -and ($u -match '^admin/users/\{[^}]+\}/roles$')) `
                -or (($m -match '(^|\|)DELETE(\||$)') -and ($u -match '^admin/users/\{[^}]+\}$')) `
                -or (($m -match '(^|\|)(POST|PUT|PATCH|DELETE)(\||$)') -and ($u -match '^admin/(settings/)?security'))) {
                $crit += $rt
            }
        }

        if (@($crit).Count -eq 0) {
            $sc.Stop()
            AddSub $sub "Security Middleware" "SKIP" "No critical admin routes found for step-up validation." ([int]$sc.ElapsedMilliseconds) @("No critical admin routes matched rule set.", "Route source: " + $routeSourceNote)
        } else {
            $keys = @(
                "password.confirm", "auth.session", "reauth", "re-auth", "fresh", "passwordconfirm", "confirm",
                "ensure.admin.stepup",
                "illuminate\auth\middleware\requirepassword",
                "illuminate\session\middleware\authenticatesession",
                "app\http\middleware\ensureadminstepup"
            )

            $covered = 0
            $miss = @()

            foreach ($rt in @($crit)) {
                $mwArr = @()
                try { $mwArr = @($rt.middleware) } catch { $mwArr = @() }
                $flat = ((@($mwArr) | ForEach-Object { ("" + $_).ToLowerInvariant() }) -join " ")
                $has = $false
                foreach ($k in $keys) { if ($flat.Contains($k)) { $has = $true; break } }
                if ($has) { $covered++ } else { $miss += ("$($rt.methods) $($rt.uri)") }
            }

            $sc.Stop()
            $critPreview = @($crit | ForEach-Object { "$($_.methods) $($_.uri)" })
            $evMw = @(
                "Critical routes: " + ($critPreview -join " | "),
                "MatchedPatterns: " + ($keys -join ", "),
                "Route source: " + $routeSourceNote
            )

            if ($covered -eq @($crit).Count) {
                AddSub $sub "Security Middleware" "OK" ("Step-up/fresh-session middleware present on $covered critical route(s).") ([int]$sc.ElapsedMilliseconds) ($evMw + @("Coverage: $covered/$(@($crit).Count)"))
            } elseif ($covered -gt 0) {
                AddSub $sub "Security Middleware" "WARN" ("Step-up present on $covered/$(@($crit).Count) critical route(s); missing on: " + ($miss -join ", ")) ([int]$sc.ElapsedMilliseconds) ($evMw + @("Missing: " + ($miss -join ", ")))
            } else {
                AddSub $sub "Security Middleware" "WARN" ("No step-up middleware found on $(@($crit).Count) critical route(s).") ([int]$sc.ElapsedMilliseconds) ($evMw + @("Missing: " + ($miss -join ", ")))
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
    $sd.Stop(); if ($failed) { AddSub $sub "Security Tables" "FAIL" (($tDet.ToArray()) -join "; ") ([int]$sd.ElapsedMilliseconds) @($tDet.ToArray()) } else { AddSub $sub "Security Tables" "OK" (($tDet.ToArray()) -join "; ") ([int]$sd.ElapsedMilliseconds) @($tDet.ToArray()) }

    # E
    $se = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $probe) { AddSub $sub "Security Registration Abuse" "SKIP" "SecurityProbe=false (active probe disabled)." 0 @("Active probe disabled by SecurityProbe=false.") }
    elseif (-not $checkReg) { AddSub $sub "Security Registration Abuse" "SKIP" "SecurityCheckRegister=false." 0 @("Registration check disabled by SecurityCheckRegister=false.") }
    else {
        $hasReg = $false; try { $rl = & $run $root @("route:list", "--path=register", "--no-ansi", "--no-interaction") 60; if (("" + $rl.StdOut) -match '\bregister\b') { $hasReg = $true } } catch { $hasReg = $false }
        if (-not $hasReg) { $se.Stop(); AddSub $sub "Security Registration Abuse" "SKIP" "/register route not present." ([int]$se.ElapsedMilliseconds) @("/register route not found in route:list output.") }
        else {
            $jar = New-CurlJar "register_probe"
            $cookieJar = $jar.jar

            $g = Curl-Req "$baseUrl/register" "GET" $cookieJar $null 3 12
            if (-not $g.ok) {
                $se.Stop()
                AddSub $sub "Security Registration Abuse" "WARN" ("GET /register failed: " + $g.error) ([int]$se.ElapsedMilliseconds) @("GET /register request error: " + $g.error)
            }
            else {
                $tok = ""; try { $m = [regex]::Match(("" + $g.content), 'name\s*=\s*"[_]?token"\s+value\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if ($m.Success) { $tok = ("" + $m.Groups[1].Value) } } catch { $tok = "" }
                if ($tok -eq "") {
                    $se.Stop()
                    AddSub $sub "Security Registration Abuse" "WARN" "GET /register did not expose _token." ([int]$se.ElapsedMilliseconds) @("CSRF token missing in GET /register response.")
                }
                else {
                    $hit429 = $false; $hit419 = $false; $kwHit = $false
                    $regTrace = New-Object System.Collections.Generic.List[string]
                    for ($i = 1; $i -le 6; $i++) {
                        $r = Curl-Req "$baseUrl/register" "POST" $cookieJar @{ _token = $tok; name = "Audit Probe"; email = ("invalid-email-" + $i); password = "short"; password_confirmation = "different" } 0 12
                        if ($r.ok) { $regTrace.Add(("try#${i}: status=" + $(if ($null -eq $r.status) { "n/a" } else { [int]$r.status }))) | Out-Null } else { $regTrace.Add(("try#${i}: request_error")) | Out-Null }
                        if (-not $r.ok) { continue }
                        if ([int]$r.status -eq 419) { $hit419 = $true; break }
                        if ([int]$r.status -eq 429) { $hit429 = $true; break }
                        if (HasKw ("" + $r.content + " " + $r.location) $keywords) { $kwHit = $true; break }
                    }
                    $data["register_probe_trace"] = @($regTrace.ToArray())
                    $se.Stop()
                    $evReg = @("HTTP Status history: " + (($regTrace.ToArray()) -join " | "), "MatchedPatterns: " + (($keywords | ForEach-Object { "" + $_ }) -join ", "))
                    if ($hit419) { AddSub $sub "Security Registration Abuse" "WARN" "Probe invalid: POST /register returned 419 (csrf_419)." ([int]$se.ElapsedMilliseconds) ($evReg + @("419 reason: CSRF/session mismatch during active probe.")) }
                    elseif ($hit429 -or $kwHit) { AddSub $sub "Security Registration Abuse" "OK" "Protection signal detected (429/lockout keyword)." ([int]$se.ElapsedMilliseconds) ($evReg + @("Signal: " + $(if ($hit429) { "429" } else { "keyword" }))) }
                    else { AddSub $sub "Security Registration Abuse" "WARN" "No abuse-protection signal within 6 attempts." ([int]$se.ElapsedMilliseconds) ($evReg + @("No lockout/keyword signal found.")) }
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