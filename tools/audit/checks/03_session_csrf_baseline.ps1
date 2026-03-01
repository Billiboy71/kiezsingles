# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\03a_session_csrf_baseline.ps1
# Purpose: Audit check - Session/CSRF baseline (read-only)
# Created: 28-02-2026 (Europe/Berlin)
# Version: 0.1
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
    if ((("" + $sameSite).Trim().ToLower() -eq "none") -and (-not $secure)) {
        $warns += "same_site=none but secure!=true"
    }
    if (-not $httpOnly) {
        $warns += "http_only=false"
    }
    if ((("" + $appEnv).Trim().ToLower() -eq "production") -and ((("" + $driver).Trim().ToLower()) -ne "file")) {
        $warns += ("APP_ENV=production and session.driver=" + $driver + " (expected file by current baseline policy)")
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
    }

    if ($warns.Count -gt 0) {
        return & $new -Id "session_csrf_baseline" -Title "3a) Session/CSRF baseline (read-only)" -Status "WARN" -Summary ("Baseline warnings: " + $warns.Count + ".") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    return & $new -Id "session_csrf_baseline" -Title "3a) Session/CSRF baseline (read-only)" -Status "OK" -Summary "Session/CSRF baseline captured." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
}
