# =====================================================================
# File: (run manually) lockout_precheck.ps1
# Purpose: Precheck if lockout/throttle signal appears in /login HTML
#          after repeated failed logins, using the same session cookies.
# Compatible: Windows PowerShell 5.1 + PowerShell 7
# =====================================================================

param(
    [string]$BaseUrl = "http://kiezsingles.test",
    [string]$Email = "audit-test@kiezsingles.local",
    [string]$WrongPassword = "WRONG-PASSWORD",
    [int]$Attempts = 10,
    [string[]]$Keywords = @("too many attempts", "throttle", "locked", "lockout", "zu viele", "versuche"),
    [switch]$DebugDumpHtml
)

$ErrorActionPreference = "Stop"

function Coalesce($value, $fallback) {
    if ($null -ne $value -and ("" + $value) -ne "") { return $value }
    return $fallback
}

function Get-AbsoluteUrl([string]$base, [string]$pathOrUrl) {
    if ($pathOrUrl -match '^https?://') { return $pathOrUrl }
    if (-not $pathOrUrl.StartsWith("/")) { $pathOrUrl = "/" + $pathOrUrl }
    return ($base.TrimEnd("/") + $pathOrUrl)
}

function Try-ExtractCsrfToken([string]$html) {
    # Laravel default: <input type="hidden" name="_token" value="...">
    $m = [regex]::Match($html, 'name="_token"\s+value="([^"]+)"', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Get-ResponseBodyText($resp) {
    if ($null -eq $resp) { return "" }
    return [string]$resp.Content
}

function Invoke-IwrNoRedirect([string]$uri, [string]$method, $session, $body = $null, [string]$contentType = $null) {
    # Returns a PSCustomObject with: ok(bool), status(int?), location(string?), response(object), error(string?)
    $result = [pscustomobject]@{
        ok = $false
        status = $null
        location = $null
        response = $null
        error = $null
    }

    try {
        $params = @{
            Uri = $uri
            Method = $method
            WebSession = $session
            MaximumRedirection = 0
            UseBasicParsing = $true
        }

        if ($null -ne $body) { $params["Body"] = $body }
        if ($contentType) { $params["ContentType"] = $contentType }

        $r = Invoke-WebRequest @params
        $result.ok = $true
        $result.response = $r
        try { $result.status = [int]$r.StatusCode } catch { $result.status = $null }
        try { $result.location = [string]$r.Headers["Location"] } catch { $result.location = $null }
        return $result
    } catch {
        $ex = $_.Exception
        $result.ok = $false
        try { $result.error = ("" + $ex.Message) } catch { $result.error = "unknown_error" }

        # In Windows PowerShell, non-2xx / redirects with MaximumRedirection 0 can throw WebException.
        try {
            if ($null -ne $ex.Response) {
                $resp = $ex.Response
                try { $result.status = [int]$resp.StatusCode } catch { $result.status = $null }
                try { $result.location = [string]$resp.Headers["Location"] } catch { $result.location = $null }
            }
        } catch { }

        return $result
    }
}

$loginUrl = Get-AbsoluteUrl $BaseUrl "/login"

Write-Host ("BaseUrl:   " + $BaseUrl)
Write-Host ("LoginUrl:  " + $loginUrl)
Write-Host ("Attempts:  " + $Attempts)
Write-Host ("Keywords:  " + ($Keywords -join ", "))
Write-Host ""

# Use one session for everything
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

# 1) GET /login to get session cookie + CSRF token
Write-Host "[1/3] GET /login (initial)"
$respLogin = Invoke-IwrNoRedirect -uri $loginUrl -method "GET" -session $session
$loginHtml = ""
if ($respLogin.ok -and $null -ne $respLogin.response) { $loginHtml = Get-ResponseBodyText $respLogin.response }
$csrf = Try-ExtractCsrfToken $loginHtml

if (-not $csrf) {
    Write-Host "CSRF token not found in /login HTML." -ForegroundColor Yellow
} else {
    Write-Host "CSRF token extracted: OK"
}

# 2) Repeated failed POST /login attempts
Write-Host ""
Write-Host "[2/3] POST /login (failed attempts)"

for ($i = 1; $i -le $Attempts; $i++) {
    # Refresh token each time (Laravel may rotate session/token)
    $respLogin = Invoke-IwrNoRedirect -uri $loginUrl -method "GET" -session $session
    $html = ""
    if ($respLogin.ok -and $null -ne $respLogin.response) { $html = Get-ResponseBodyText $respLogin.response }
    $csrf = Try-ExtractCsrfToken $html

    $form = @{
        _token   = $csrf
        email    = $Email
        password = $WrongPassword
    }

    $r = Invoke-IwrNoRedirect -uri $loginUrl -method "POST" -session $session -body $form -contentType "application/x-www-form-urlencoded"

    if ($r.ok) {
        $statusOut = Coalesce $r.status "(n/a)"
        $locOut = Coalesce $r.location "(none)"
        Write-Host ("try#{0}: status={1} loc={2}" -f $i, $statusOut, $locOut)
    } else {
        $statusOut = Coalesce $r.status "(n/a)"
        $locOut = Coalesce $r.location "(n/a)"
        Write-Host ("try#{0}: ERROR ({1}) status={2} loc={3}" -f $i, (Coalesce $r.error "error"), $statusOut, $locOut) -ForegroundColor Yellow
    }
}

# 3) Final: GET /login and scan HTML for keywords
Write-Host ""
Write-Host "[3/3] GET /login (final) + keyword scan"

$final = Invoke-IwrNoRedirect -uri $loginUrl -method "GET" -session $session
$finalStatus = Coalesce $final.status "(n/a)"
$finalLoc = Coalesce $final.location "(none)"
Write-Host ("final GET /login: status={0} loc={1}" -f $finalStatus, $finalLoc)

$haystack = ""
if ($final.ok -and $null -ne $final.response) {
    $haystack = Get-ResponseBodyText $final.response
}

# If final GET is a redirect (rare), try to fetch redirect target HTML
try {
    if ($final.status -ge 300 -and $final.status -lt 400 -and $final.location) {
        $target = Get-AbsoluteUrl $BaseUrl $final.location
        Write-Host ("following redirect target (GET): " + $target)
        $targetResp = Invoke-IwrNoRedirect -uri $target -method "GET" -session $session
        if ($targetResp.ok -and $null -ne $targetResp.response) {
            $haystack = Get-ResponseBodyText $targetResp.response
            Write-Host ("target status=" + (Coalesce $targetResp.status "(n/a)"))
        }
    }
} catch { }

$matched = @()
foreach ($k in $Keywords) {
    if ($haystack -match [regex]::Escape($k)) { $matched += $k }
}

if ($matched.Count -gt 0) {
    Write-Host ("LOCKOUT SIGNAL FOUND in HTML: " + ($matched -join ", ")) -ForegroundColor Green
} else {
    Write-Host "NO LOCKOUT KEYWORD found in HTML." -ForegroundColor Yellow
    Write-Host "Interpretation: server may still be locking out, but message/keywords differ OR not rendered in HTML."
}

if ($DebugDumpHtml) {
    $out = Join-Path $PSScriptRoot "lockout_precheck_last_login.html"
    [IO.File]::WriteAllText($out, $haystack, [Text.Encoding]::UTF8)
    Write-Host ("Saved HTML dump: " + $out)
}