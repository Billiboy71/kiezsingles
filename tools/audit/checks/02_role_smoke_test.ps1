# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\02b_role_smoke_test.ps1
# Purpose: Audit check - Role access smoke test (GET-only)
# Created: 28-02-2026 (Europe/Berlin)
# Changed: 13-03-2026 01:07 (Europe/Berlin)
# Version: 0.8
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_RoleSmokeTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $new = $Context.Helpers.NewAuditResult
    $baseUrl = ("" + $Context.BaseUrl).TrimEnd("/")
    $paths = @($Context.RoleSmokePaths)

    & $Context.Helpers.WriteSection "2b) Role access smoke test (GET-only)"

    $preflight = $null
    try { $preflight = $Context.LoginCsrfProbeState } catch { $preflight = $null }
    $preflightOk = $false
    $preflightReason = ""
    $preflightStatus = $null
    if ($null -ne $preflight) {
        try { $preflightOk = [bool]$preflight.ok } catch { $preflightOk = $false }
        try { $preflightReason = ("" + $preflight.reason) } catch { $preflightReason = "" }
        try { $preflightStatus = $preflight.status } catch { $preflightStatus = $null }
    }

    if ($null -ne $preflight -and ((-not $preflightOk) -or $preflightStatus -eq 419)) {
        $sw.Stop()
        $preStatusText = ""
        if ($null -ne $preflightStatus) { $preStatusText = "" + [int]$preflightStatus } else { $preStatusText = "n/a" }
        return & $new -Id "role_smoke_test" -Title "2b) Role access smoke test (GET-only)" -Status "FAIL" -Summary ("Skipped: login flow broken (reason=" + $preflightReason + ", status=" + $preStatusText + ").") -Details @("Role smoke test requires a healthy login/session flow.") -Data @{ base_url = $baseUrl; preflight_reason = $preflightReason; preflight_status = $preflightStatus } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if (@($paths).Count -le 0) {
        $sw.Stop()
        return & $new -Id "role_smoke_test" -Title "2b) Role access smoke test (GET-only)" -Status "WARN" -Summary "No RoleSmokePaths configured." -Details @() -Data @{ base_url = $baseUrl } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    function New-IwrParamsBase {
        $p = @{
            TimeoutSec   = 12
            ErrorAction  = "Stop"
            Headers      = @{ "Accept" = "text/html,application/xhtml+xml" }
        }
        try {
            $cmd = Get-Command Invoke-WebRequest -ErrorAction Stop
            if ($cmd -and $cmd.Parameters -and $cmd.Parameters.ContainsKey("UseBasicParsing")) {
                $p["UseBasicParsing"] = $true
            }
        } catch { }
        return $p
    }

    function Get-HeaderValue {
        param(
            [Parameter(Mandatory = $false)]$Headers,
            [Parameter(Mandatory = $true)][string]$Name
        )
        try {
            if ($Headers -is [System.Collections.IDictionary]) {
                foreach ($k in @($Headers.Keys)) {
                    if (("" + $k).Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $v = $Headers[$k]
                        if ($null -eq $v) { return "" }
                        if ($v -is [string]) { return ("" + $v) }
                        try { return ((@($v) | ForEach-Object { "" + $_ }) -join ", ") } catch { return ("" + $v) }
                    }
                }
            }
        } catch { }
        return ""
    }

    function Get-SetCookieLinesFromHeaders {
        param(
            [Parameter(Mandatory = $false)]$Headers
        )

        $out = New-Object System.Collections.Generic.List[string]
        if ($null -eq $Headers) { return @() }

        try {
            if ($Headers -is [System.Collections.IDictionary]) {
                foreach ($k in @($Headers.Keys)) {
                    if (-not (("" + $k).Equals("Set-Cookie", [System.StringComparison]::OrdinalIgnoreCase))) { continue }
                    $v = $Headers[$k]
                    if ($null -eq $v) { continue }
                    if ($v -is [string]) {
                        $sv = ("" + $v).Trim()
                        if ($sv -ne "") { $out.Add($sv) | Out-Null }
                    } else {
                        try {
                            foreach ($x in @($v)) {
                                $sx = ("" + $x).Trim()
                                if ($sx -ne "") { $out.Add($sx) | Out-Null }
                            }
                        } catch {
                            $sv2 = ("" + $v).Trim()
                            if ($sv2 -ne "") { $out.Add($sv2) | Out-Null }
                        }
                    }
                }
            } else {
                try {
                    $vals = $Headers.GetValues("Set-Cookie")
                    foreach ($x in @($vals)) {
                        $sx = ("" + $x).Trim()
                        if ($sx -ne "") { $out.Add($sx) | Out-Null }
                    }
                } catch { }
            }
        } catch { }

        return @($out.ToArray())
    }

    function Get-SetCookieLinesFromRawHeaderText([string]$Text) {
        $out = New-Object System.Collections.Generic.List[string]
        if ($null -eq $Text) { return @() }
        try {
            $lines = @($Text -split "`r?`n")
            foreach ($line in @($lines)) {
                $s = ("" + $line)
                if ($s -match '^(?i)\s*Set-Cookie\s*:\s*(.+)$') {
                    $v = ("" + $Matches[1]).Trim()
                    if ($v -ne "") { $out.Add($v) | Out-Null }
                }
            }
        } catch { }
        return @($out.ToArray())
    }

    function Merge-SetCookieLines([string[]]$A, [string[]]$B) {
        $out = New-Object System.Collections.Generic.List[string]
        $seen = @{}
        foreach ($v in @($A) + @($B)) {
            $s = ("" + $v).Trim()
            if ($s -eq "") { continue }
            if ($seen.ContainsKey($s)) { continue }
            $seen[$s] = $true
            $out.Add($s) | Out-Null
        }
        return @($out.ToArray())
    }

    function Update-SessionCookiesFromSetCookieLines {
        param(
            [Parameter(Mandatory = $true)]$Session,
            [Parameter(Mandatory = $true)][string]$Uri,
            [Parameter(Mandatory = $false)][string[]]$SetCookieLines
        )

        if ($null -eq $Session) { return }
        if ($null -eq $SetCookieLines -or @($SetCookieLines).Count -le 0) { return }

        $u = $null
        $okUri = $false
        try { $okUri = [System.Uri]::TryCreate($Uri, [System.UriKind]::Absolute, [ref]$u) } catch { $okUri = $false }
        if (-not $okUri -or $null -eq $u) { return }

        foreach ($line in @($SetCookieLines)) {
            $s = ("" + $line).Trim()
            if ($s -eq "") { continue }
            if ($s -notmatch '^\s*([^=;\s]+)=([^;]*)') { continue }
            $name = ("" + $Matches[1]).Trim()
            $value = ("" + $Matches[2]).Trim()
            if ($name -eq "") { continue }

            $path = "/"
            $domain = ("" + $u.Host)
            if ($s -match '(?i);\s*path=([^;]+)') { $path = ("" + $Matches[1]).Trim() }
            if ($s -match '(?i);\s*domain=([^;]+)') { $domain = ("" + $Matches[1]).Trim().TrimStart(".") }
            if ($path -eq "") { $path = "/" }
            if ($domain -eq "") { $domain = ("" + $u.Host) }

            try {
                $cookie = New-Object System.Net.Cookie($name, $value, $path, $domain)
                $Session.Cookies.Add($u, $cookie)
            } catch { }
        }
    }

    function Redact-Snippet([string]$BodyText) {
        if ($null -eq $BodyText) { return "" }
        $s = "" + $BodyText
        if ($s.Length -gt 200) { $s = $s.Substring(0, 200) }
        $s = $s -replace '(?i)(name\s*=\s*"password"\s+value\s*=\s*")[^"]*(")', '$1<redacted>$2'
        $s = $s -replace '(?i)(name\s*=\s*"email"\s+value\s*=\s*")[^"]*(")', '$1<redacted>$2'
        $s = $s -replace '(?i)(name\s*=\s*"_token"\s+value\s*=\s*")[^"]*(")', '$1<redacted>$2'
        return $s
    }

    function Normalize-Path([string]$Path) {
        $p = ("" + $Path).Trim()
        if ($p -eq "") { return "/" }
        if (-not $p.StartsWith("/")) { $p = "/" + $p }
        return $p
    }

    function Invoke-IwrCapture {
        param(
            [Parameter(Mandatory = $true)][string]$Uri,
            [Parameter(Mandatory = $true)][string]$Method,
            [Parameter(Mandatory = $true)]$Session,
            [Parameter(Mandatory = $false)]$Body,
            [Parameter(Mandatory = $false)][int]$MaxRedirection = 20
        )

        $base = New-IwrParamsBase
        $params = @{
            Uri                = $Uri
            Method             = $Method
            MaximumRedirection = $MaxRedirection
            WebSession         = $Session
        }
        foreach ($k in @($base.Keys)) { $params[$k] = $base[$k] }

        if ($null -ne $Body) {
            $params["ContentType"] = "application/x-www-form-urlencoded"
            $params["Body"] = $Body
        }

        try {
            $resp = Invoke-WebRequest @params
            $status = $null
            try { $status = [int]$resp.StatusCode } catch { $status = $null }
            $setCookieLines = @()
            try {
                $setCookieLines = Merge-SetCookieLines -A (Get-SetCookieLinesFromHeaders -Headers $resp.Headers) -B (Get-SetCookieLinesFromRawHeaderText -Text ("" + $resp.RawContent))
            } catch { $setCookieLines = @() }
            return [pscustomobject]@{
                ok = $true
                status = $status
                location = (Get-HeaderValue -Headers $resp.Headers -Name "Location")
                final_uri = $(try { ("" + $resp.BaseResponse.ResponseUri.AbsoluteUri).Trim() } catch { "" })
                set_cookie_lines = @($setCookieLines)
                content = ("" + $resp.Content)
                response = $resp
                error = ""
            }
        } catch {
            $resp = $null
            try {
                if ($_.Exception -and ($_.Exception | Get-Member -Name Response -ErrorAction SilentlyContinue)) { $resp = $_.Exception.Response }
            } catch { $resp = $null }
            if ($null -eq $resp) {
                try {
                    if ($_ -and ($_ | Get-Member -Name Response -ErrorAction SilentlyContinue)) { $resp = $_.Response }
                } catch { $resp = $null }
            }
            if ($resp) {
                $status = $null
                try { $status = [int]$resp.StatusCode } catch { $status = $null }
                $loc = ""
                try { $loc = Get-HeaderValue -Headers $resp.Headers -Name "Location" } catch { $loc = "" }
                $finalUri = ""
                try { $finalUri = ("" + $resp.ResponseUri.AbsoluteUri).Trim() } catch { $finalUri = "" }
                if ($finalUri -eq "") {
                    try { $finalUri = ("" + $resp.BaseResponse.ResponseUri.AbsoluteUri).Trim() } catch { $finalUri = "" }
                }
                $setCookieLines = @()
                try { $setCookieLines = Get-SetCookieLinesFromHeaders -Headers $resp.Headers } catch { $setCookieLines = @() }
                return [pscustomobject]@{
                    ok = $true
                    status = $status
                    location = $loc
                    final_uri = $finalUri
                    set_cookie_lines = @($setCookieLines)
                    content = ""
                    response = $resp
                    error = ""
                }
            }
            return [pscustomobject]@{
                ok = $false
                status = $null
                location = ""
                final_uri = ""
                set_cookie_lines = @()
                content = ""
                response = $null
                error = ("" + $_.Exception.Message)
            }
        }
    }

    function Is-PathMatch([string]$LocationValue, [string]$ExpectedPath) {
        $loc = ("" + $LocationValue).Trim()
        if ($loc -eq "") { return $false }
        $expected = (Normalize-Path $ExpectedPath).TrimEnd("/")
        if ($expected -eq "") { $expected = "/" }
        try {
            $u = $null
            $ok = $false
            try { $ok = [System.Uri]::TryCreate($loc, [System.UriKind]::Absolute, [ref]$u) } catch { $ok = $false }
            if ($ok -and $u -and $u.AbsolutePath) {
                $p = ("" + $u.AbsolutePath).TrimEnd("/")
                if ($p -eq "") { $p = "/" }
                return ($p -ieq $expected)
            }
        } catch { }
        if ($loc.StartsWith("/")) {
            $p2 = $loc.TrimEnd("/")
            if ($p2 -eq "") { $p2 = "/" }
            return ($p2 -ieq $expected)
        }
        return $false
    }

    function Build-DefaultExpectations {
        $o = @{}
        $o["superadmin|/admin"] = @{ allowed_statuses = @(200); maintenance_redirect = "FAIL" }
        $o["superadmin|/admin/users"] = @{ allowed_statuses = @(200); maintenance_redirect = "FAIL" }
        $o["superadmin|/admin/moderation"] = @{ allowed_statuses = @(200); maintenance_redirect = "FAIL" }
        $o["superadmin|/admin/tickets"] = @{ allowed_statuses = @(200); maintenance_redirect = "FAIL" }
        $o["superadmin|/admin/maintenance"] = @{ allowed_statuses = @(200); maintenance_redirect = "FAIL" }
        $o["superadmin|/admin/debug"] = @{ allowed_statuses = @(200); maintenance_redirect = "FAIL" }
        $o["superadmin|/admin/develop"] = @{ allowed_statuses = @(200); maintenance_redirect = "FAIL" }
        $o["superadmin|/admin/status"] = @{ allowed_statuses = @(200); maintenance_redirect = "FAIL" }

        $o["admin|/admin"] = @{ allowed_statuses = @(200); maintenance_redirect = "WARN" }
        $o["admin|/admin/users"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["admin|/admin/moderation"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["admin|/admin/tickets"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["admin|/admin/maintenance"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["admin|/admin/debug"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["admin|/admin/develop"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["admin|/admin/status"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }

        $o["moderator|/admin"] = @{ allowed_statuses = @(200); maintenance_redirect = "WARN" }
        $o["moderator|/admin/users"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["moderator|/admin/moderation"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["moderator|/admin/tickets"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["moderator|/admin/maintenance"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["moderator|/admin/debug"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["moderator|/admin/develop"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        $o["moderator|/admin/status"] = @{ allowed_statuses = @(200, 403); maintenance_redirect = "WARN" }
        return $o
    }

    function Merge-Expectations([hashtable]$Defaults, $Overrides) {
        $m = @{}
        foreach ($k in @($Defaults.Keys)) { $m[$k] = $Defaults[$k] }

        if ($null -eq $Overrides) { return $m }
        if (-not ($Overrides -is [System.Collections.IDictionary])) { return $m }

        foreach ($k in @($Overrides.Keys)) {
            if (-not $k) { continue }
            $key = ("" + $k).Trim().ToLower()
            if ($key -eq "") { continue }
            $v = $Overrides[$k]
            if ($v -is [System.Collections.IDictionary]) {
                $allowed = @()
                $mode = "FAIL"
                try { if ($v.Contains("allowed_statuses")) { $allowed = @($v["allowed_statuses"] | ForEach-Object { [int]$_ }) } } catch { $allowed = @() }
                try { if ($v.Contains("maintenance_redirect")) { $mode = ("" + $v["maintenance_redirect"]).Trim().ToUpper() } } catch { $mode = "FAIL" }
                if ($allowed.Count -gt 0) {
                    $m[$key] = @{ allowed_statuses = $allowed; maintenance_redirect = $mode }
                }
                continue
            }
        }

        return $m
    }

    function Login-RoleSession([string]$RoleName, [string]$Email, [string]$Password) {
        if ((("" + $Email).Trim() -eq "") -or (("" + $Password) -eq "")) {
            return [pscustomobject]@{ ok = $false; reason = "missing_credentials"; session = $null; status = $null; location = ""; final_uri = ""; snippet = "" }
        }

        $session = $null
        try { $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession } catch { $session = $null }
        if ($null -eq $session) {
            return [pscustomobject]@{ ok = $false; reason = "session_init_failed"; session = $null; status = $null; location = ""; final_uri = ""; snippet = "" }
        }

        $rGet = Invoke-IwrCapture -Uri ($baseUrl + "/login") -Method "GET" -Session $session -MaxRedirection 20
        if (-not $rGet.ok) {
            return [pscustomobject]@{ ok = $false; reason = "login_get_failed"; session = $null; status = $null; location = ""; final_uri = ""; snippet = (Redact-Snippet ("" + $rGet.content)) }
        }
        try { Update-SessionCookiesFromSetCookieLines -Session $session -Uri ($baseUrl + "/login") -SetCookieLines $rGet.set_cookie_lines } catch { }

        $token = ""
        try {
            $m = [regex]::Match(("" + $rGet.content), 'name\s*=\s*"[_]?token"\s+value\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($m.Success) { $token = ("" + $m.Groups[1].Value) }
        } catch { $token = "" }
        if ($token -eq "") {
            return [pscustomobject]@{ ok = $false; reason = "missing_token"; session = $null; status = $rGet.status; location = ""; final_uri = ""; snippet = (Redact-Snippet ("" + $rGet.content)) }
        }

        $postBody = @{
            _token = $token
            email = $Email
            password = $Password
        }
        $rPost = Invoke-IwrCapture -Uri ($baseUrl + "/login") -Method "POST" -Session $session -Body $postBody -MaxRedirection 1
        if (-not $rPost.ok) {
            return [pscustomobject]@{ ok = $false; reason = "login_post_failed"; session = $null; status = $null; location = ""; final_uri = ""; snippet = (Redact-Snippet ("" + $rPost.content)) }
        }
        try { Update-SessionCookiesFromSetCookieLines -Session $session -Uri ($baseUrl + "/login") -SetCookieLines $rPost.set_cookie_lines } catch { }

        $st = $rPost.status
        $loc = ("" + $rPost.location).Trim()
        $final = ("" + $rPost.final_uri).Trim()
        if ($loc -eq "" -and $final -ne "") { $loc = $final }
        if ($st -eq 419) {
            return [pscustomobject]@{ ok = $false; reason = "csrf_419"; session = $null; status = 419; location = $loc; final_uri = $final; snippet = (Redact-Snippet ("" + $rPost.content)) }
        }

        if ($loc -match '(?i)/login(?:$|[/?#])' -or $final -match '(?i)/login(?:$|[/?#])') {
            return [pscustomobject]@{ ok = $false; reason = "redirect_login"; session = $null; status = $st; location = $loc; final_uri = $final; snippet = (Redact-Snippet ("" + $rPost.content)) }
        }

        return [pscustomobject]@{ ok = $true; reason = "ok"; session = $session; status = $st; location = $loc; final_uri = $final; snippet = "" }
    }

    function Test-IsLoginUri([string]$UriValue) {
        return (Is-PathMatch -LocationValue $UriValue -ExpectedPath "/login")
    }

    function Test-IsMaintenanceUri([string]$UriValue) {
        return (Is-PathMatch -LocationValue $UriValue -ExpectedPath "/admin/maintenance")
    }

    function Test-IsMaintenanceLoginGateBlocked($Probe, $ProbeFollow) {
        $status = $null
        $location = ""
        $followStatus = $null
        $followFinalUri = ""
        $followLocation = ""

        try { $status = $Probe.status } catch { $status = $null }
        try { $location = ("" + $Probe.location).Trim() } catch { $location = "" }
        try { $followStatus = $ProbeFollow.status } catch { $followStatus = $null }
        try { $followFinalUri = ("" + $ProbeFollow.final_uri).Trim() } catch { $followFinalUri = "" }
        try { $followLocation = ("" + $ProbeFollow.location).Trim() } catch { $followLocation = "" }

        if (($null -ne $status) -and (([int]$status -eq 301) -or ([int]$status -eq 302)) -and (Test-IsLoginUri $location)) {
            return $true
        }
        if (($null -ne $followStatus) -and (Test-IsLoginUri $followFinalUri -or Test-IsLoginUri $followLocation)) {
            return $true
        }
        return $false
    }

    function Invoke-RoleMaintenanceGateProbe([string]$RoleName, $Session) {
        $role = ("" + $RoleName).Trim().ToLower()
        if ($role -eq "superadmin") {
            return [pscustomobject]@{ blocked = $false; no_redirect_status = $null; no_redirect_location = ""; fallback_followed = $false; final_status = $null; final_uri = ""; result = "OK"; reason = ""; description = "" }
        }
        if ($null -eq $Session) {
            return [pscustomobject]@{ blocked = $false; no_redirect_status = $null; no_redirect_location = ""; fallback_followed = $false; final_status = $null; final_uri = ""; result = "OK"; reason = ""; description = "" }
        }

        $gateUrl = $baseUrl + "/admin/maintenance"
        $probe = Invoke-IwrCapture -Uri $gateUrl -Method "GET" -Session $Session -MaxRedirection 0
        $probeFollow = $null
        $fallbackFollowed = $false
        if (-not $probe.ok -or $null -eq $probe.status -or [int]$probe.status -eq 301 -or [int]$probe.status -eq 302) {
            $probeFollow = Invoke-IwrCapture -Uri $gateUrl -Method "GET" -Session $Session -MaxRedirection 1
            if ($probeFollow.ok) { $fallbackFollowed = $true }
        }

        $blocked = Test-IsMaintenanceLoginGateBlocked -Probe $probe -ProbeFollow $probeFollow
        $noRedirectStatus = $null
        $noRedirectLocation = ""
        $finalStatus = $null
        $finalUri = ""
        try { $noRedirectStatus = $probe.status } catch { $noRedirectStatus = $null }
        try { $noRedirectLocation = ("" + $probe.location).Trim() } catch { $noRedirectLocation = "" }
        try { if ($null -ne $probeFollow) { $finalStatus = $probeFollow.status } } catch { $finalStatus = $null }
        try { if ($null -ne $probeFollow) { $finalUri = ("" + $probeFollow.final_uri).Trim() } } catch { $finalUri = "" }

        if ($blocked) {
            return [pscustomobject]@{
                blocked = $true
                no_redirect_status = $noRedirectStatus
                no_redirect_location = $noRedirectLocation
                fallback_followed = [bool]$fallbackFollowed
                final_status = $finalStatus
                final_uri = $finalUri
                result = "WARN"
                reason = "maintenance_login_gate_blocked"
                description = "maintenance gate active; login blocked by maintenance mode; role/path access not evaluated normally"
            }
        }

        return [pscustomobject]@{
            blocked = $false
            no_redirect_status = $noRedirectStatus
            no_redirect_location = $noRedirectLocation
            fallback_followed = [bool]$fallbackFollowed
            final_status = $finalStatus
            final_uri = $finalUri
            result = "OK"
            reason = ""
            description = ""
        }
    }

    function Get-RoleMaintenanceGateState([string]$RoleName, $LoginResult) {
        $role = ("" + $RoleName).Trim().ToLower()
        if ($role -eq "superadmin") {
            return [pscustomobject]@{ blocked = $false; result = "OK"; reason = ""; description = "" }
        }
        if ($null -eq $LoginResult) {
            return [pscustomobject]@{ blocked = $false; result = "OK"; reason = ""; description = "" }
        }

        $loginReason = ""
        $loginLocation = ""
        $loginFinalUri = ""
        try { $loginReason = ("" + $LoginResult.reason).Trim().ToLower() } catch { $loginReason = "" }
        try { $loginLocation = ("" + $LoginResult.location).Trim() } catch { $loginLocation = "" }
        try { $loginFinalUri = ("" + $LoginResult.final_uri).Trim() } catch { $loginFinalUri = "" }

        if (($role -eq "admin" -or $role -eq "moderator") -and $loginReason -eq "redirect_login" -and ((Test-IsLoginUri $loginLocation) -or (Test-IsLoginUri $loginFinalUri))) {
            return [pscustomobject]@{
                blocked = $true
                result = "WARN"
                reason = "maintenance_login_gate_blocked"
                description = "maintenance gate active; login blocked by maintenance mode; role/path access not evaluated normally"
            }
        }

        return [pscustomobject]@{ blocked = $false; result = "OK"; reason = ""; description = "" }
    }

    $defaults = Build-DefaultExpectations
    $overrides = $null
    try { $overrides = $Context.RoleSmokeExpectations } catch { $overrides = $null }
    $expect = Merge-Expectations -Defaults $defaults -Overrides $overrides

    $roles = @(
        @{ name = "superadmin"; email = ("" + $Context.SuperadminEmail); password = ("" + $Context.SuperadminPassword) },
        @{ name = "admin"; email = ("" + $Context.AdminEmail); password = ("" + $Context.AdminPassword) },
        @{ name = "moderator"; email = ("" + $Context.ModeratorEmail); password = ("" + $Context.ModeratorPassword) }
    )

    $details = @()
    $findings = New-Object System.Collections.Generic.List[object]
    $failCount = 0
    $warnCount = 0
    $okCount = 0
    $maintenanceGateBlockedCount = 0

    foreach ($r in @($roles)) {
        $roleName = ("" + $r.name).Trim().ToLower()
        $details += ("Role: " + $roleName)

        $login = Login-RoleSession -RoleName $roleName -Email ("" + $r.email) -Password ("" + $r.password)
        $gateState = Get-RoleMaintenanceGateState -RoleName $roleName -LoginResult $login
        if (-not [bool]$login.ok) {
            $loginStatusText = ""
            if ($null -ne $login.status) { $loginStatusText = "" + [int]$login.status } else { $loginStatusText = "n/a" }
            $loginFinalUri = ""
            try { $loginFinalUri = ("" + $login.final_uri).Trim() } catch { $loginFinalUri = "" }
            if ([bool]$gateState.blocked) {
                $maintenanceGateBlockedCount += @($paths).Count
                $warnCount += @($paths).Count
                $details += ("  LoginGate: BLOCKED (" + $gateState.description + ", status=" + $loginStatusText + ", reason=" + $login.reason + ")")
                if ($login.location -and ("" + $login.location).Trim() -ne "") {
                    $details += ("  Login-Location: " + ("" + $login.location).Trim())
                }
                if ($loginFinalUri -ne "") {
                    $details += ("  Login-FinalUri: " + $loginFinalUri)
                }
                $details += "  RoleEvaluation: skipped (maintenance/login gate)"
                foreach ($rp in @($paths)) {
                    $path = Normalize-Path ("" + $rp)
                    $details += ("  " + $path + " => GATED (" + $gateState.reason + ")")
                    $findings.Add([pscustomobject]@{
                        role = $roleName
                        path = $path
                        status = $null
                        location = ("" + $login.location)
                        final_uri = $loginFinalUri
                        fallback_followed = $false
                        result = $gateState.result
                        reason = $gateState.reason
                        gate_blocked = $true
                        gate_description = $gateState.description
                    }) | Out-Null
                }
                $details += ""
                continue
            }

            $failCount++
            $details += ("  Login: FAIL (" + $login.reason + ", status=" + $loginStatusText + ")")
            if ($login.location -and ("" + $login.location).Trim() -ne "") {
                $details += ("  Login-Location: " + ("" + $login.location).Trim())
            }
            if ($loginFinalUri -ne "") {
                $details += ("  Login-FinalUri: " + $loginFinalUri)
            }
            if ($login.snippet -and ("" + $login.snippet).Trim() -ne "") {
                $details += ("  Login-Body-Snippet: " + ("" + $login.snippet).Trim())
            }
            foreach ($rp in @($paths)) {
                $path = Normalize-Path ("" + $rp)
                $findings.Add([pscustomobject]@{
                    role = $roleName
                    path = $path
                    status = $null
                    location = ("" + $login.location)
                    result = "FAIL"
                    reason = ("login_failed:" + $login.reason)
                }) | Out-Null
            }
            $details += ""
            continue
        }

        $details += ("  Login: OK (status=" + ($(if ($null -ne $login.status) { [int]$login.status } else { "n/a" })) + ")")
        $roleSession = $login.session
        $maintenanceGateProbe = Invoke-RoleMaintenanceGateProbe -RoleName $roleName -Session $roleSession
        if ([bool]$maintenanceGateProbe.blocked) {
            $maintenanceGateBlockedCount += @($paths).Count
            $warnCount += @($paths).Count
            $gateStatusText = "n/a"
            $gateFinalStatusText = "n/a"
            try { if ($null -ne $maintenanceGateProbe.no_redirect_status) { $gateStatusText = "" + [int]$maintenanceGateProbe.no_redirect_status } } catch { $gateStatusText = "n/a" }
            try { if ($null -ne $maintenanceGateProbe.final_status) { $gateFinalStatusText = "" + [int]$maintenanceGateProbe.final_status } } catch { $gateFinalStatusText = "n/a" }
            $details += ("  MaintenanceGate: ACTIVE (" + $maintenanceGateProbe.description + ")")
            $details += ("  MaintenanceGateProbe: no_redirect_status=" + $gateStatusText + ", fallback_followed=" + $(if ($maintenanceGateProbe.fallback_followed) { "true" } else { "false" }) + $(if ($maintenanceGateProbe.no_redirect_location -ne "") { ", no_redirect_location=" + $maintenanceGateProbe.no_redirect_location } else { "" }) + $(if ($gateFinalStatusText -ne "n/a") { ", final_status=" + $gateFinalStatusText } else { "" }) + $(if (($maintenanceGateProbe.final_uri) -and ("" + $maintenanceGateProbe.final_uri).Trim() -ne "") { ", final_uri=" + ("" + $maintenanceGateProbe.final_uri).Trim() } else { "" }))
            $details += "  RoleEvaluation: skipped (maintenance gate active; login blocked by maintenance mode)"
            foreach ($rp in @($paths)) {
                $path = Normalize-Path ("" + $rp)
                $details += ("  " + $path + " => WARN (" + $maintenanceGateProbe.reason + "; role/path access not evaluated normally)")
                $findings.Add([pscustomobject]@{
                    role = $roleName
                    path = $path
                    status = $maintenanceGateProbe.no_redirect_status
                    location = ("" + $maintenanceGateProbe.no_redirect_location)
                    final_status = $maintenanceGateProbe.final_status
                    final_uri = ("" + $maintenanceGateProbe.final_uri)
                    fallback_followed = [bool]$maintenanceGateProbe.fallback_followed
                    result = $maintenanceGateProbe.result
                    reason = $maintenanceGateProbe.reason
                    gate_blocked = $true
                    gate_description = $maintenanceGateProbe.description
                    expected_allowed_statuses = @()
                    expected_maintenance_redirect = "WARN"
                }) | Out-Null
            }
            $details += ""
            continue
        }

        foreach ($rp in @($paths)) {
            $path = Normalize-Path ("" + $rp)
            $url = $baseUrl + $path
            $probe = Invoke-IwrCapture -Uri $url -Method "GET" -Session $roleSession -MaxRedirection 0
            $probeFollow = $null
            $fallbackFollowed = $false
            $followStatus = $null
            $followFinalUri = ""
            $followLocation = ""
            $followError = ""
            if (-not $probe.ok -or $null -eq $probe.status -or [int]$probe.status -eq 302 -or [int]$probe.status -eq 301) {
                $probeFollow = Invoke-IwrCapture -Uri $url -Method "GET" -Session $roleSession -MaxRedirection 1
                if ($probeFollow.ok) {
                    $fallbackFollowed = $true
                    $followStatus = $probeFollow.status
                    try { $followFinalUri = ("" + $probeFollow.final_uri).Trim() } catch { $followFinalUri = "" }
                    try { $followLocation = ("" + $probeFollow.location).Trim() } catch { $followLocation = "" }
                } else {
                    try { $followError = ("" + $probeFollow.error).Trim() } catch { $followError = "" }
                }
            }

            $status = $probe.status
            $loc = ("" + $probe.location).Trim()
            $finalUri = ""
            try { $finalUri = ("" + $probe.final_uri).Trim() } catch { $finalUri = "" }
            $result = "OK"
            $reason = ""

            $expectKey = ($roleName + "|" + $path).ToLower()
            $cfg = $null
            if ($expect.ContainsKey($expectKey)) { $cfg = $expect[$expectKey] }
            if ($null -eq $cfg) { $cfg = @{ allowed_statuses = @(200, 403); maintenance_redirect = "FAIL" } }

            $allowed = @(200, 403)
            $maintenanceMode = "FAIL"
            try { if ($cfg.Contains("allowed_statuses")) { $allowed = @($cfg["allowed_statuses"] | ForEach-Object { [int]$_ }) } } catch { $allowed = @(200, 403) }
            try { if ($cfg.Contains("maintenance_redirect")) { $maintenanceMode = ("" + $cfg["maintenance_redirect"]).Trim().ToUpper() } } catch { $maintenanceMode = "FAIL" }

            $effectiveStatus = $status
            if ($fallbackFollowed -and $null -ne $followStatus) { $effectiveStatus = $followStatus }

            if (-not $probe.ok -and -not $fallbackFollowed) {
                $result = "FAIL"
                $reason = ("request_error:" + $probe.error)
            } elseif ($status -eq 302 -and (Is-PathMatch -LocationValue $loc -ExpectedPath "/login") -and -not $fallbackFollowed) {
                $result = "FAIL"
                $reason = "redirect_login"
            } elseif ($status -eq 302 -and (Is-PathMatch -LocationValue $loc -ExpectedPath "/admin/maintenance") -and -not $fallbackFollowed) {
                if ($maintenanceMode -eq "WARN") {
                    $result = "WARN"
                    $reason = "redirect_maintenance"
                } else {
                    $result = "FAIL"
                    $reason = "redirect_maintenance"
                }
            } elseif ($fallbackFollowed -and (Test-IsLoginUri $followFinalUri -or Test-IsLoginUri $followLocation)) {
                $result = "FAIL"
                $reason = "fallback_followed_login"
            } elseif ($fallbackFollowed -and (Test-IsMaintenanceUri $followFinalUri -or Test-IsMaintenanceUri $followLocation)) {
                if ($maintenanceMode -eq "WARN") {
                    $result = "WARN"
                    $reason = "fallback_followed_maintenance"
                } else {
                    $result = "FAIL"
                    $reason = "fallback_followed_maintenance"
                }
            } elseif (@($allowed) -contains $effectiveStatus) {
                $result = "OK"
                if ($fallbackFollowed) {
                    if ([int]$effectiveStatus -eq 200) { $reason = "fallback_followed_access_allowed" }
                    elseif ([int]$effectiveStatus -eq 403) { $reason = "fallback_followed_access_forbidden" }
                    else { $reason = "fallback_followed_as_expected" }
                } else {
                    if ([int]$effectiveStatus -eq 200) { $reason = "access_allowed" }
                    elseif ([int]$effectiveStatus -eq 403) { $reason = "access_forbidden" }
                    else { $reason = "as_expected" }
                }
            } else {
                $result = "FAIL"
                $reason = "unexpected_status"
            }

            if ($result -eq "OK") { $okCount++ }
            elseif ($result -eq "WARN") { $warnCount++ }
            else { $failCount++ }

            $statusText = ""
            if ($null -ne $status) { $statusText = "" + [int]$status } else { $statusText = "n/a" }
            $followStatusText = ""
            if ($null -ne $followStatus) { $followStatusText = "" + [int]$followStatus } else { $followStatusText = "n/a" }
            $errText = ""
            if ($reason -like "request_error:*") {
                try { $errText = ("" + $probe.error).Trim() } catch { $errText = "" }
            }
            $details += ("  " + $path + " => no_redirect_status=" + $statusText + ", fallback_followed=" + $(if ($fallbackFollowed) { "true" } else { "false" }) + $(if ($loc -ne "") { ", no_redirect_location=" + $loc } else { "" }) + $(if ($fallbackFollowed -and $followStatusText -ne "n/a") { ", final_status=" + $followStatusText } else { "" }) + $(if ($fallbackFollowed -and $followFinalUri -ne "") { ", final_uri=" + $followFinalUri } else { "" }) + $(if ($errText -ne "") { ", error=" + $errText } elseif ($fallbackFollowed -and $followError -ne "") { ", fallback_error=" + $followError } else { "" }) + " => " + $result + " (" + $reason + ")")
            $findings.Add([pscustomobject]@{
                role = $roleName
                path = $path
                status = $status
                location = $loc
                final_status = $followStatus
                final_uri = $followFinalUri
                fallback_followed = [bool]$fallbackFollowed
                result = $result
                reason = $reason
                error = $(try { ("" + $probe.error) } catch { "" })
                expected_allowed_statuses = @($allowed)
                expected_maintenance_redirect = $maintenanceMode
            }) | Out-Null
        }

        $details += ""
    }

    $sw.Stop()
    $data = @{
        base_url = $baseUrl
        role_paths = @($paths)
        findings = @($findings.ToArray())
        ok_count = [int]$okCount
        warn_count = [int]$warnCount
        fail_count = [int]$failCount
        maintenance_gate_blocked_count = [int]$maintenanceGateBlockedCount
        role_count = [int](@($roles).Count)
        path_count = [int](@($paths).Count)
        expected_probe_count = [int](@($roles).Count * @($paths).Count)
        actual_probe_count = [int](@($findings.ToArray()).Count)
    }

    $expectedProbeCount = [int]$data.expected_probe_count
    $actualProbeCount = [int]$data.actual_probe_count

    try {
        $Context | Add-Member -NotePropertyName RoleSmokeTestState -NotePropertyValue ([pscustomobject]@{
            ok = ($failCount -eq 0 -and $warnCount -eq 0 -and $actualProbeCount -eq $expectedProbeCount)
            expected_probe_count = $expectedProbeCount
            actual_probe_count = $actualProbeCount
            ok_count = [int]$okCount
            warn_count = [int]$warnCount
            fail_count = [int]$failCount
            maintenance_gate_blocked_count = [int]$maintenanceGateBlockedCount
            findings = @($findings.ToArray())
        }) -Force
    } catch { }

    if ($actualProbeCount -ne $expectedProbeCount) {
        return & $new -Id "role_smoke_test" -Title "2b) Role access smoke test (GET-only)" -Status "FAIL" -Summary ("Probe consistency mismatch: actual " + $actualProbeCount + " / expected " + $expectedProbeCount + ".") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($failCount -gt 0) {
        return & $new -Id "role_smoke_test" -Title "2b) Role access smoke test (GET-only)" -Status "FAIL" -Summary ("Failures detected: " + $failCount + " (OK=" + $okCount + ", WARN=" + $warnCount + ", MaintenanceGate=" + $maintenanceGateBlockedCount + ", expected probes=" + $expectedProbeCount + ").") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }
    if ($warnCount -gt 0) {
        if ($maintenanceGateBlockedCount -gt 0) {
            return & $new -Id "role_smoke_test" -Title "2b) Role access smoke test (GET-only)" -Status "WARN" -Summary ("Maintenance/Login-Gate blocked " + $maintenanceGateBlockedCount + " probe(s) before role evaluation (OK=" + $okCount + ", WARN=" + $warnCount + ", expected probes=" + $expectedProbeCount + ").") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }
        return & $new -Id "role_smoke_test" -Title "2b) Role access smoke test (GET-only)" -Status "WARN" -Summary ("No hard failures (OK=" + $okCount + ", WARN=" + $warnCount + ", expected probes=" + $expectedProbeCount + ").") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    return & $new -Id "role_smoke_test" -Title "2b) Role access smoke test (GET-only)" -Status "OK" -Summary ("All probes as expected (OK=" + $okCount + ", expected probes=" + $expectedProbeCount + ").") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
}
