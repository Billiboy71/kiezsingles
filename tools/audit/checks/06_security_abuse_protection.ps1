Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\06_security_abuse_protection.ps1
# Purpose: Audit check - security / abuse protection block (active probes + evidence)
# Created: 01-03-2026 13:20 (Europe/Berlin)
# Changed: 01-03-2026 18:45 (Europe/Berlin)
# Version: 0.2
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

    $probe = [bool]$Context.SecurityProbe
    $checkIpBan = [bool]$Context.SecurityCheckIpBan
    $checkReg = [bool]$Context.SecurityCheckRegister
    $expect429 = [bool]$Context.SecurityExpect429
    $attempts = 8; try { $attempts = [Math]::Min(10, [Math]::Max(1, [int]$Context.SecurityLoginAttempts)) } catch { $attempts = 8 }
    $keywords = @("too many attempts", "throttle", "locked", "lockout")
    try { $kw = @($Context.SecurityLockoutKeywords | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" }); if ($kw.Count -gt 0) { $keywords = $kw } } catch { }

    $sub = New-Object System.Collections.Generic.List[object]
    $details = @()
    $evidence = New-Object System.Collections.Generic.List[string]
    $data = @{ security_probe = $probe; security_login_attempts = $attempts; security_check_ip_ban = $checkIpBan; security_check_register = $checkReg; security_expect_429 = $expect429; security_lockout_keywords = @($keywords) }
    $data["matched_patterns"] = @($keywords)

    # A
    $sa = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $probe) { AddSub $sub "Security Login Rate Limit" "SKIP" "SecurityProbe=false (active probe disabled)." 0 @("Active probe disabled by SecurityProbe=false.") }
    else {
        $sess = $null; try { $sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession } catch { $sess = $null }
        if ($null -eq $sess) { AddSub $sub "Security Login Rate Limit" "FAIL" "Cannot initialize WebRequestSession." 0 @("WebRequestSession initialization failed.") }
        else {
            $g = Req "$baseUrl/login" "GET" $sess $null 3
            if (-not $g.ok) { $sa.Stop(); AddSub $sub "Security Login Rate Limit" "FAIL" ("GET /login failed: " + $g.error) ([int]$sa.ElapsedMilliseconds) @("GET /login request error: " + $g.error) }
            else {
                $tok = ""; try { $m = [regex]::Match(("" + $g.content), 'name\s*=\s*"[_]?token"\s+value\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if ($m.Success) { $tok = ("" + $m.Groups[1].Value) } } catch { $tok = "" }
                if ($tok -eq "") { $sa.Stop(); AddSub $sub "Security Login Rate Limit" "FAIL" "GET /login did not expose _token." ([int]$sa.ElapsedMilliseconds) @("CSRF token missing in GET /login response.") }
                else {
                    $sig = ""; $found = $false; $hit419 = $false; $trace = New-Object System.Collections.Generic.List[string]
                    for ($i = 1; $i -le $attempts; $i++) {
                        $p = @{ _token = $tok; email = ("audit-probe+$i@invalid.local"); password = "definitely-wrong-password" }
                        $r = Req "$baseUrl/login" "POST" $sess $p 0
                        $st = "n/a"; try { $st = [int]$r.status } catch { }
                        $trace.Add(("try#${i}: status=$st")) | Out-Null
                        if (-not $r.ok) { $sig = "request_error: $($r.error)"; break }
                        if ([int]$r.status -eq 419) { $hit419 = $true; $sig = "csrf_419"; break }
                        if ([int]$r.status -in @(429, 423, 403)) { $found = $true; $sig = "$($r.status) at attempt $i"; break }
                        if (HasKw ("" + $r.location + " " + $r.content) $keywords) { $found = $true; $sig = "keyword at attempt $i"; break }
                    }
                    $sa.Stop(); $data["login_probe_trace"] = @($trace.ToArray())
                    $ev = @("HTTP Status history: " + (($trace.ToArray()) -join " | "), "MatchedPatterns: " + (($keywords | ForEach-Object { "" + $_ }) -join ", "))
                    if ($hit419) { AddSub $sub "Security Login Rate Limit" "FAIL" "Probe invalid: POST /login returned 419 (csrf_419)." ([int]$sa.ElapsedMilliseconds) ($ev + @("419 reason: CSRF/session mismatch during active probe.")) }
                    elseif ($found -and $expect429 -and ($sig -notmatch '^429')) { AddSub $sub "Security Login Rate Limit" "WARN" ("Lockout signal detected, but no 429 while SecurityExpect429=true ($sig).") ([int]$sa.ElapsedMilliseconds) ($ev + @("Expected explicit 429 but observed: " + $sig)) }
                    elseif ($found) { AddSub $sub "Security Login Rate Limit" "OK" ("Lockout after <= $attempts attempts ($sig).") ([int]$sa.ElapsedMilliseconds) ($ev + @("Lockout signal: " + $sig)) }
                    elseif ($sig -like "request_error:*") { AddSub $sub "Security Login Rate Limit" "FAIL" ("Probe failed: $sig") ([int]$sa.ElapsedMilliseconds) ($ev + @("Request error encountered.")) }
                    else { AddSub $sub "Security Login Rate Limit" "FAIL" ("No throttle/lockout signal after $attempts failed logins.") ([int]$sa.ElapsedMilliseconds) ($ev + @("No lockout/keyword signal found.")) }
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
    $rr = $null; try { $rr = & $run $root @("route:list", "--path=admin", "-vv", "--no-ansi", "--no-interaction") 120 } catch { $rr = $null }
    if ($null -eq $rr) { $sc.Stop(); AddSub $sub "Security Middleware" "WARN" "route:list -vv could not be executed." ([int]$sc.ElapsedMilliseconds) @("route:list -vv execution failed.") }
    else {
        $o = ""; try { $o = ("" + $rr.StdOut) } catch { $o = "" }
        if ([int]$rr.ExitCode -ne 0 -and $o.Trim() -eq "") { $sc.Stop(); AddSub $sub "Security Middleware" "WARN" ("route:list -vv failed (exit $($rr.ExitCode)).") ([int]$sc.ElapsedMilliseconds) @("route:list -vv exit=" + [int]$rr.ExitCode) }
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
            if (@($crit).Count -eq 0) { $sc.Stop(); AddSub $sub "Security Middleware" "SKIP" "No critical admin routes found for step-up validation." ([int]$sc.ElapsedMilliseconds) @("No critical admin routes matched rule set.") }
            else {
                $keys = @("password.confirm", "auth.session", "reauth", "re-auth", "fresh", "passwordconfirm", "confirm"); $covered = 0; $miss = @()
                foreach ($rt in @($crit)) { $flat = ((@($rt.middleware.ToArray()) | ForEach-Object { ("" + $_).ToLowerInvariant() }) -join " "); $has = $false; foreach ($k in $keys) { if ($flat.Contains($k)) { $has = $true; break } }; if ($has) { $covered++ } else { $miss += ("$($rt.methods) $($rt.uri)") } }
                $sc.Stop()
                $critPreview = @($crit | ForEach-Object { "$($_.methods) $($_.uri)" })
                $evMw = @("Critical routes: " + ($critPreview -join " | "), "MatchedPatterns: " + ($keys -join ", "))
                if ($covered -eq @($crit).Count) { AddSub $sub "Security Middleware" "OK" ("Step-up/fresh-session middleware present on $covered critical route(s).") ([int]$sc.ElapsedMilliseconds) ($evMw + @("Coverage: $covered/$(@($crit).Count)")) }
                elseif ($covered -gt 0) { AddSub $sub "Security Middleware" "WARN" ("Step-up present on $covered/$(@($crit).Count) critical route(s); missing on: " + ($miss -join ", ")) ([int]$sc.ElapsedMilliseconds) ($evMw + @("Missing: " + ($miss -join ", "))) }
                else { AddSub $sub "Security Middleware" "WARN" ("No step-up middleware found on $(@($crit).Count) critical route(s).") ([int]$sc.ElapsedMilliseconds) ($evMw + @("Missing: " + ($miss -join ", "))) }
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
            $sess = $null; try { $sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession } catch { $sess = $null }
            if ($null -eq $sess) { $se.Stop(); AddSub $sub "Security Registration Abuse" "WARN" "Cannot initialize WebRequestSession." ([int]$se.ElapsedMilliseconds) @("WebRequestSession initialization failed.") }
            else {
                $g = Req "$baseUrl/register" "GET" $sess $null 3
                if (-not $g.ok) { $se.Stop(); AddSub $sub "Security Registration Abuse" "WARN" ("GET /register failed: " + $g.error) ([int]$se.ElapsedMilliseconds) @("GET /register request error: " + $g.error) }
                else {
                    $tok = ""; try { $m = [regex]::Match(("" + $g.content), 'name\s*=\s*"[_]?token"\s+value\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if ($m.Success) { $tok = ("" + $m.Groups[1].Value) } } catch { $tok = "" }
                    if ($tok -eq "") { $se.Stop(); AddSub $sub "Security Registration Abuse" "WARN" "GET /register did not expose _token." ([int]$se.ElapsedMilliseconds) @("CSRF token missing in GET /register response.") }
                    else {
                        $hit429 = $false; $hit419 = $false; $kw = $false
                        $regTrace = New-Object System.Collections.Generic.List[string]
                        for ($i = 1; $i -le 6; $i++) {
                            $r = Req "$baseUrl/register" "POST" $sess @{ _token = $tok; name = "Audit Probe"; email = "invalid-email-$i"; password = "short"; password_confirmation = "different" } 0
                            if ($r.ok) { $regTrace.Add(("try#${i}: status=" + [int]$r.status)) | Out-Null } else { $regTrace.Add(("try#${i}: request_error")) | Out-Null }
                            if (-not $r.ok) { continue }
                            if ([int]$r.status -eq 419) { $hit419 = $true; break }
                            if ([int]$r.status -eq 429) { $hit429 = $true; break }
                            if (HasKw ("" + $r.content + " " + $r.location) $keywords) { $kw = $true; break }
                        }
                        $data["register_probe_trace"] = @($regTrace.ToArray())
                        $se.Stop()
                        $evReg = @("HTTP Status history: " + (($regTrace.ToArray()) -join " | "), "MatchedPatterns: " + (($keywords | ForEach-Object { "" + $_ }) -join ", "))
                        if ($hit419) { AddSub $sub "Security Registration Abuse" "WARN" "Probe invalid: POST /register returned 419 (csrf_419)." ([int]$se.ElapsedMilliseconds) ($evReg + @("419 reason: CSRF/session mismatch during active probe.")) }
                        elseif ($hit429 -or $kw) { AddSub $sub "Security Registration Abuse" "OK" "Protection signal detected (429/lockout keyword)." ([int]$se.ElapsedMilliseconds) ($evReg + @("Signal: " + $(if ($hit429) { "429" } else { "keyword" }))) }
                        else { AddSub $sub "Security Registration Abuse" "WARN" "No abuse-protection signal within 6 attempts." ([int]$se.ElapsedMilliseconds) ($evReg + @("No lockout/keyword signal found.")) }
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
