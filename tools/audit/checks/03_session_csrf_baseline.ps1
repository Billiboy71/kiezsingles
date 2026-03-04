# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\03a_session_csrf_baseline.ps1
# Purpose: Audit check - Session/CSRF baseline (read-only)
# Created: 28-02-2026 (Europe/Berlin)
# Changed: 03-03-2026 12:00 (Europe/Berlin)
# Version: 0.4
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_SessionCsrfBaseline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $new = $Context.Helpers.NewAuditResult
    $root = $Context.ProjectRoot

    & $Context.Helpers.WriteSection "3a) Session/CSRF baseline (read-only)"

    $envPath = Join-Path $root ".env"
    $cfgPath = Join-Path $root "config\session.php"

    function Parse-EnvFile([string]$Path) {
        $m = @{}
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $m }
        $lines = @()
        try { $lines = @((Get-Content -LiteralPath $Path -ErrorAction Stop)) } catch { $lines = @() }
        foreach ($lineRaw in $lines) {
            $line = ("" + $lineRaw).Trim()
            if ($line -eq "" -or $line.StartsWith("#")) { continue }
            if ($line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') { continue }
            $k = ("" + $Matches[1]).Trim()
            $v = ("" + $Matches[2]).Trim()
            if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
                if ($v.Length -ge 2) { $v = $v.Substring(1, $v.Length - 2) }
            }
            $m[$k] = $v
        }
        return $m
    }

    function Get-SessionConfigDefault([string]$Text, [string]$EnvKey, [string]$Fallback) {
        if ($null -eq $Text) { return $Fallback }
        $t = "" + $Text
        $pattern = "env\(\s*'" + [regex]::Escape($EnvKey) + "'\s*,\s*([^)]+)\)"
        try {
            $m = [regex]::Match($t, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if (-not $m.Success) { return $Fallback }
            $raw = ("" + $m.Groups[1].Value).Trim()
            $raw = $raw.TrimEnd(",")
            if (($raw.StartsWith("'") -and $raw.EndsWith("'")) -or ($raw.StartsWith('"') -and $raw.EndsWith('"'))) {
                if ($raw.Length -ge 2) { $raw = $raw.Substring(1, $raw.Length - 2) }
            }
            return $raw
        } catch { return $Fallback }
    }

    function Get-ConfigLiteral([string]$Text, [string]$Key, [string]$Fallback) {
        if ($null -eq $Text) { return $Fallback }
        $t = "" + $Text
        $pattern = "'" + [regex]::Escape($Key) + "'\s*=>\s*([^,\r\n]+)"
        try {
            $m = [regex]::Match($t, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if (-not $m.Success) { return $Fallback }
            $raw = ("" + $m.Groups[1].Value).Trim()
            $raw = $raw.TrimEnd(",")
            if (($raw.StartsWith("'") -and $raw.EndsWith("'")) -or ($raw.StartsWith('"') -and $raw.EndsWith('"'))) {
                if ($raw.Length -ge 2) { $raw = $raw.Substring(1, $raw.Length - 2) }
            }
            return $raw
        } catch { return $Fallback }
    }

    function Get-BoolFromText([string]$Value, [bool]$Default) {
        if ($null -eq $Value) { return $Default }
        $v = ("" + $Value).Trim().ToLower()
        if ($v -eq "") { return $Default }
        if (@("1","true","yes","on").Contains($v)) { return $true }
        if (@("0","false","no","off").Contains($v)) { return $false }
        return $Default
    }

    function Normalize-Paths($Value) {
        $out = New-Object System.Collections.Generic.List[string]
        $seen = @{}
        foreach ($v in @($Value)) {
            $s = ("" + $v).Trim()
            if ($s -eq "") { continue }
            if ($s -match "\r?\n" -or $s -match "\s" -or $s -match "[,;]") {
                $parts = @()
                try { $parts = @($s -split "[\s,;]+") } catch { $parts = @() }
                foreach ($p in @($parts)) {
                    $x = ("" + $p).Trim()
                    if ($x -eq "") { continue }
                    if (-not $x.StartsWith("/")) { $x = "/" + $x.TrimStart("/") }
                    if ($x -eq "/") { continue }
                    if ($seen.ContainsKey($x)) { continue }
                    $seen[$x] = $true
                    $out.Add($x) | Out-Null
                }
                continue
            }
            if (-not $s.StartsWith("/")) { $s = "/" + $s.TrimStart("/") }
            if ($s -eq "/") { continue }
            if ($seen.ContainsKey($s)) { continue }
            $seen[$s] = $true
            $out.Add($s) | Out-Null
        }
        return @($out.ToArray())
    }

    function Get-DefaultBaselinePaths {
        return @(
            "/admin",
            "/admin/status",
            "/admin/moderation",
            "/admin/maintenance",
            "/admin/debug",
            "/admin/users",
            "/admin/tickets",
            "/admin/develop"
        )
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
        param([Parameter(Mandatory = $false)]$Headers)
        $out = New-Object System.Collections.Generic.List[string]
        if ($null -eq $Headers) { return @() }
        try {
            if ($Headers -is [System.Collections.IDictionary]) {
                foreach ($k in @($Headers.Keys)) {
                    if (-not (("" + $k).Equals("Set-Cookie", [System.StringComparison]::OrdinalIgnoreCase))) { continue }
                    $v = $Headers[$k]
                    foreach ($x in @($v)) {
                        $sx = ("" + $x).Trim()
                        if ($sx -ne "") { $out.Add($sx) | Out-Null }
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

    function Invoke-IwrCapture {
        param(
            [Parameter(Mandatory = $true)][string]$Uri,
            [Parameter(Mandatory = $true)][string]$Method,
            [Parameter(Mandatory = $true)]$Session,
            [Parameter(Mandatory = $false)]$Body,
            [Parameter(Mandatory = $false)][int]$MaxRedirection = 0,
            [Parameter(Mandatory = $false)][hashtable]$ExtraHeaders = $null
        )

        $headers = @{
            "Accept"      = "text/html,application/xhtml+xml"
            "User-Agent"  = "ks-admin-audit/SessionCsrfBaseline"
        }

        if ($null -ne $ExtraHeaders) {
            foreach ($k in @($ExtraHeaders.Keys)) {
                try {
                    $headers["" + $k] = ("" + $ExtraHeaders[$k])
                } catch { }
            }
        }

        $params = @{
            Uri = $Uri
            Method = $Method
            MaximumRedirection = $MaxRedirection
            WebSession = $Session
            TimeoutSec = 12
            ErrorAction = "Stop"
            Headers = $headers
        }
        try {
            $cmd = Get-Command Invoke-WebRequest -ErrorAction Stop
            if ($cmd -and $cmd.Parameters -and $cmd.Parameters.ContainsKey("UseBasicParsing")) { $params["UseBasicParsing"] = $true }
        } catch { }

        if ($null -ne $Body) {
            $params["ContentType"] = "application/x-www-form-urlencoded"
            $params["Body"] = $Body
        }

        try {
            $resp = Invoke-WebRequest @params
            $status = $null
            try { $status = [int]$resp.StatusCode } catch { $status = $null }
            $setCookieLines = @()
            try { $setCookieLines = Get-SetCookieLinesFromHeaders -Headers $resp.Headers } catch { $setCookieLines = @() }
            return [pscustomobject]@{
                ok = $true
                status = $status
                location = (Get-HeaderValue -Headers $resp.Headers -Name "Location")
                set_cookie_lines = @($setCookieLines)
                content = ("" + $resp.Content)
                error = ""
            }
        } catch {
            $resp = $null
            try { if ($_.Exception -and ($_.Exception | Get-Member -Name Response -ErrorAction SilentlyContinue)) { $resp = $_.Exception.Response } } catch { $resp = $null }
            if ($null -eq $resp) {
                try { if ($_ -and ($_ | Get-Member -Name Response -ErrorAction SilentlyContinue)) { $resp = $_.Response } } catch { $resp = $null }
            }
            if ($resp) {
                $status = $null
                try { $status = [int]$resp.StatusCode } catch { $status = $null }
                $loc = ""
                try { $loc = Get-HeaderValue -Headers $resp.Headers -Name "Location" } catch { $loc = "" }
                $setCookieLines = @()
                try { $setCookieLines = Get-SetCookieLinesFromHeaders -Headers $resp.Headers } catch { }
                return [pscustomobject]@{
                    ok = $true
                    status = $status
                    location = $loc
                    set_cookie_lines = @($setCookieLines)
                    content = ""
                    error = ""
                }
            }
            return [pscustomobject]@{
                ok = $false
                status = $null
                location = ""
                set_cookie_lines = @()
                content = ""
                error = ("" + $_.Exception.Message)
            }
        }
    }

    function Parse-SetCookieFlags([string[]]$SetCookieLines) {
        $hasSession = $false
        $hasXsrf = $false
        $secure = $false
        $httpOnly = $false
        $sameSite = ""
        $domain = ""
        $path = ""

        foreach ($line in @($SetCookieLines)) {
            $s = ("" + $line)
            if ($s -match '(?i)(^|[;,]\s*)laravel_session=') { $hasSession = $true }
            if ($s -match '(?i)(^|[;,]\s*)XSRF-TOKEN=') { $hasXsrf = $true }
            if ($s -match '(?i);\s*secure(?:;|$)') { $secure = $true }
            if ($s -match '(?i);\s*httponly(?:;|$)') { $httpOnly = $true }
            if ($sameSite -eq "" -and $s -match '(?i);\s*samesite=([^;]+)') { $sameSite = (("" + $Matches[1]).Trim()) }
            if ($domain -eq "" -and $s -match '(?i);\s*domain=([^;]+)') { $domain = (("" + $Matches[1]).Trim()) }
            if ($path -eq "" -and $s -match '(?i);\s*path=([^;]+)') { $path = (("" + $Matches[1]).Trim()) }
        }

        return [pscustomobject]@{
            laravel_session = [bool]$hasSession
            xsrf_token = [bool]$hasXsrf
            secure = [bool]$secure
            http_only = [bool]$httpOnly
            same_site = $sameSite
            domain = $domain
            path = $path
        }
    }

    function Extract-CsrfTokenFromHtml([string]$Html) {
        $token = ""
        if ($null -eq $Html) { return "" }
        $h = "" + $Html
        if ($h.Trim() -eq "") { return "" }

        # 1) Standard Blade form token: <input ... name="_token" ... value="...">
        try {
            $m = [regex]::Match($h, '<input[^>]*\bname\s*=\s*["'']_token["''][^>]*\bvalue\s*=\s*["'']([^"''<>]+)["'']', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($m.Success) { $token = ("" + $m.Groups[1].Value).Trim() }
        } catch { $token = "" }

        # 2) Attribute order reversed: value before name
        if ($token -eq "") {
            try {
                $m2 = [regex]::Match($h, '<input[^>]*\bvalue\s*=\s*["'']([^"''<>]+)["''][^>]*\bname\s*=\s*["'']_token["'']', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($m2.Success) { $token = ("" + $m2.Groups[1].Value).Trim() }
            } catch { $token = "" }
        }

        return $token
    }

    function Login-RoleSession([string]$BaseUrl, [string]$Email, [string]$Password) {
        if (("" + $Email).Trim() -eq "" -or ("" + $Password) -eq "") {
            return [pscustomobject]@{ ok = $false; reason = "missing_credentials"; session = $null }
        }

        $session = $null
        try { $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession } catch { $session = $null }
        if ($null -eq $session) { return [pscustomobject]@{ ok = $false; reason = "session_init_failed"; session = $null } }

        $loginUrl = $BaseUrl + "/login"

        $rGet = Invoke-IwrCapture -Uri $loginUrl -Method "GET" -Session $session -MaxRedirection 20 -ExtraHeaders @{ "Referer" = $loginUrl }
        if (-not $rGet.ok) { return [pscustomobject]@{ ok = $false; reason = "login_get_failed"; session = $null } }

        $token = ""
        try { $token = Extract-CsrfTokenFromHtml -Html ("" + $rGet.content) } catch { $token = "" }
        if ($token -eq "") { return [pscustomobject]@{ ok = $false; reason = "missing_token"; session = $null } }

        $postHeaders = @{
            "Referer" = $loginUrl
            "Origin"  = $BaseUrl
            "X-CSRF-TOKEN" = $token
        }

        $rPost = Invoke-IwrCapture -Uri $loginUrl -Method "POST" -Session $session -Body @{ _token = $token; email = $Email; password = $Password } -MaxRedirection 1 -ExtraHeaders $postHeaders
        if (-not $rPost.ok) { return [pscustomobject]@{ ok = $false; reason = "login_post_failed"; session = $null } }
        if ($rPost.status -eq 419) { return [pscustomobject]@{ ok = $false; reason = "csrf_419"; session = $null } }
        if (("" + $rPost.location) -match '(?i)/login(?:$|[/?#])') { return [pscustomobject]@{ ok = $false; reason = "redirect_login"; session = $null } }

        return [pscustomobject]@{ ok = $true; reason = "ok"; session = $session }
    }

    $envMap = Parse-EnvFile -Path $envPath
    $cfgText = ""
    try { if (Test-Path -LiteralPath $cfgPath -PathType Leaf) { $cfgText = [string](Get-Content -LiteralPath $cfgPath -Raw -ErrorAction Stop) } } catch { $cfgText = "" }

    $appEnv = ""
    try { if ($envMap.ContainsKey("APP_ENV")) { $appEnv = ("" + $envMap["APP_ENV"]).Trim() } } catch { $appEnv = "" }
    if ($appEnv -eq "") { $appEnv = "production" }

    $driverDefault = Get-SessionConfigDefault -Text $cfgText -EnvKey "SESSION_DRIVER" -Fallback "file"
    $lifetimeDefault = Get-SessionConfigDefault -Text $cfgText -EnvKey "SESSION_LIFETIME" -Fallback "120"
    $cookieDefault = Get-SessionConfigDefault -Text $cfgText -EnvKey "SESSION_COOKIE" -Fallback "laravel_session"
    $secureDefault = Get-SessionConfigDefault -Text $cfgText -EnvKey "SESSION_SECURE_COOKIE" -Fallback "null"
    $sameSiteDefault = Get-SessionConfigDefault -Text $cfgText -EnvKey "SESSION_SAME_SITE" -Fallback "lax"
    $domainDefault = Get-SessionConfigDefault -Text $cfgText -EnvKey "SESSION_DOMAIN" -Fallback "null"
    $pathDefault = Get-SessionConfigDefault -Text $cfgText -EnvKey "SESSION_PATH" -Fallback "/"
    $partitionedDefault = Get-SessionConfigDefault -Text $cfgText -EnvKey "SESSION_PARTITIONED_COOKIE" -Fallback "false"
    $httpOnlyDefault = Get-ConfigLiteral -Text $cfgText -Key "http_only" -Fallback "true"

    $driver = $driverDefault
    try { if ($envMap.ContainsKey("SESSION_DRIVER")) { $driver = ("" + $envMap["SESSION_DRIVER"]).Trim() } } catch { }
    $lifetime = $lifetimeDefault
    try { if ($envMap.ContainsKey("SESSION_LIFETIME")) { $lifetime = ("" + $envMap["SESSION_LIFETIME"]).Trim() } } catch { }
    $cookie = $cookieDefault
    try { if ($envMap.ContainsKey("SESSION_COOKIE")) { $cookie = ("" + $envMap["SESSION_COOKIE"]).Trim() } } catch { }
    $secureText = $secureDefault
    try { if ($envMap.ContainsKey("SESSION_SECURE_COOKIE")) { $secureText = ("" + $envMap["SESSION_SECURE_COOKIE"]).Trim() } } catch { }
    $sameSite = $sameSiteDefault
    try { if ($envMap.ContainsKey("SESSION_SAME_SITE")) { $sameSite = ("" + $envMap["SESSION_SAME_SITE"]).Trim() } } catch { }
    $domain = $domainDefault
    try { if ($envMap.ContainsKey("SESSION_DOMAIN")) { $domain = ("" + $envMap["SESSION_DOMAIN"]).Trim() } } catch { }
    $path = $pathDefault
    try { if ($envMap.ContainsKey("SESSION_PATH")) { $path = ("" + $envMap["SESSION_PATH"]).Trim() } } catch { }
    $partitionedText = $partitionedDefault
    try { if ($envMap.ContainsKey("SESSION_PARTITIONED_COOKIE")) { $partitionedText = ("" + $envMap["SESSION_PARTITIONED_COOKIE"]).Trim() } } catch { }
    $httpOnlyText = $httpOnlyDefault
    try { if ($envMap.ContainsKey("SESSION_HTTP_ONLY")) { $httpOnlyText = ("" + $envMap["SESSION_HTTP_ONLY"]).Trim() } } catch { }

    $secure = Get-BoolFromText -Value $secureText -Default:$false
    $httpOnly = Get-BoolFromText -Value $httpOnlyText -Default:$true
    $partitioned = Get-BoolFromText -Value $partitionedText -Default:$false

    $warns = @()
    if (("" + $appEnv).Trim().ToLower() -ne "local" -and (-not $secure)) {
        $warns += "APP_ENV!=local and session.secure!=true"
    }
    if (("" + $sameSite).Trim() -eq "" -or (("" + $sameSite).Trim().ToLower() -eq "null")) {
        $warns += "session.same_site is empty/null"
    }
    if (("" + $sameSite).Trim().ToLower() -eq "none" -and (-not $secure)) {
        $warns += "same_site=none but secure!=true"
    }
    if (-not $httpOnly) {
        $warns += "http_only=false"
    }

    $details = @()
    $details += ("APP_ENV: " + $appEnv)
    $details += ("session.driver: " + $driver)
    $details += ("session.lifetime: " + $lifetime)
    $details += ("session.cookie: " + $cookie)
    $details += ("session.secure: " + $secure)
    $details += ("session.http_only: " + $httpOnly)
    $details += ("session.same_site: " + $sameSite)
    $details += ("session.domain: " + $domain)
    $details += ("session.path: " + $path)
    $details += ("session.partitioned: " + $partitioned)

    $pathsSource = @()
    $pathsSourceName = ""
    try {
        $rsp = Normalize-Paths $Context.RoleSmokePaths
        if (@($rsp).Count -gt 0) { $pathsSource = @($rsp); $pathsSourceName = "RoleSmokePaths" }
    } catch { }
    if (@($pathsSource).Count -le 0) {
        try {
            $pp = Normalize-Paths $Context.ProbePaths
            if (@($pp).Count -gt 0) { $pathsSource = @($pp); $pathsSourceName = "ProbePaths" }
        } catch { }
    }
    if (@($pathsSource).Count -le 0) {
        try {
            $def = Normalize-Paths (Get-DefaultBaselinePaths)
            if (@($def).Count -gt 0) {
                $pathsSource = @($def)
                $pathsSourceName = "DefaultPaths"
            }
        } catch { }
    }
    if (@($pathsSource).Count -le 0) {
        $pathsSource = @()
        $pathsSourceName = "none"
    }

    $details += ""
    $details += ("Path source: " + $pathsSourceName)
    $details += ("Path count: " + @($pathsSource).Count)

    $roles = @(
        @{ name = "superadmin"; email = ("" + $Context.SuperadminEmail); password = ("" + $Context.SuperadminPassword) },
        @{ name = "admin"; email = ("" + $Context.AdminEmail); password = ("" + $Context.AdminPassword) },
        @{ name = "moderator"; email = ("" + $Context.ModeratorEmail); password = ("" + $Context.ModeratorPassword) }
    )

    $rolePathRows = New-Object System.Collections.Generic.List[object]
    $hardFails = 0

    if (@($pathsSource).Count -gt 0) {
        foreach ($r in @($roles)) {
            $roleName = ("" + $r.name).Trim().ToLower()
            $login = Login-RoleSession -BaseUrl (("" + $Context.BaseUrl).TrimEnd("/")) -Email ("" + $r.email) -Password ("" + $r.password)

            if (-not [bool]$login.ok) {
                $details += ""
                $details += ("Role: " + $roleName + " -> SKIPPED (" + $login.reason + ")")
                continue
            }

            $details += ""
            $details += ("Role: " + $roleName)

            foreach ($p in @($pathsSource)) {
                $url = (("" + $Context.BaseUrl).TrimEnd("/")) + ("" + $p)
                $res = Invoke-IwrCapture -Uri $url -Method "GET" -Session $login.session -MaxRedirection 0 -ExtraHeaders @{ "Referer" = $url }
                $fallbackFollow = $false
                if (-not $res.ok) {
                    $resRetry = Invoke-IwrCapture -Uri $url -Method "GET" -Session $login.session -MaxRedirection 1 -ExtraHeaders @{ "Referer" = $url }
                    if ($resRetry.ok) {
                        $res = $resRetry
                        $fallbackFollow = $true
                    }
                }

                $statusText = "n/a"
                if ($null -ne $res.status) { $statusText = ("" + [int]$res.status) }
                $loc = ("" + $res.location).Trim()

                $flags = Parse-SetCookieFlags -SetCookieLines $res.set_cookie_lines
                $cookieSummary = ("laravel_session=" + $flags.laravel_session + ", XSRF-TOKEN=" + $flags.xsrf_token + ", Secure=" + $flags.secure + ", HttpOnly=" + $flags.http_only + ", SameSite=" + $flags.same_site + ", Domain=" + $flags.domain + ", Path=" + $flags.path)

                $result = "OK"
                if ($null -ne $res.status -and [int]$res.status -ge 500) { $result = "FAIL" }
                if ($result -eq "FAIL") { $hardFails++ }

                $line = ("  " + $p + " -> status=" + $statusText)
                if ($loc -ne "") { $line += (", location=" + $loc) }
                if ($fallbackFollow) { $line += ", fallback_followed=True" }
                if (-not $res.ok -and ("" + $res.error).Trim() -ne "") { $line += (", error=" + ("" + $res.error).Trim()) }
                $line += (", cookies: " + $cookieSummary + ", result=" + $result)
                $details += $line

                $rolePathRows.Add([pscustomobject]@{
                    role = $roleName
                    path = ("" + $p)
                    status = $res.status
                    location = $loc
                    laravel_session = [bool]$flags.laravel_session
                    xsrf_token = [bool]$flags.xsrf_token
                    secure = [bool]$flags.secure
                    http_only = [bool]$flags.http_only
                    same_site = ("" + $flags.same_site)
                    domain = ("" + $flags.domain)
                    cookie_path = ("" + $flags.path)
                    result = $result
                }) | Out-Null
            }
        }
    }

    if ($warns.Count -gt 0) {
        $details += ""
        $details += "Warnings:"
        foreach ($w in @($warns)) { $details += ("  - " + $w) }
    }

    $sw.Stop()
    $data = @{
        app_env = $appEnv
        driver = $driver
        lifetime = $lifetime
        cookie = $cookie
        secure = $secure
        http_only = $httpOnly
        same_site = $sameSite
        domain = $domain
        path = $path
        partitioned = $partitioned
        warning_count = [int]$warns.Count
        path_source = $pathsSourceName
        path_count = [int](@($pathsSource).Count)
        role_path_rows = @($rolePathRows.ToArray())
        hard_fail_count = [int]$hardFails
    }

    if ($hardFails -gt 0) {
        return & $new -Id "session_csrf_baseline" -Title "3a) Session/CSRF baseline (read-only)" -Status "FAIL" -Summary ("Session/CSRF baseline found " + $hardFails + " hard fail(s).") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($warns.Count -gt 0) {
        return & $new -Id "session_csrf_baseline" -Title "3a) Session/CSRF baseline (read-only)" -Status "WARN" -Summary ("Baseline warnings: " + $warns.Count + ".") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    return & $new -Id "session_csrf_baseline" -Title "3a) Session/CSRF baseline (read-only)" -Status "OK" -Summary "Session/CSRF baseline captured." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
}