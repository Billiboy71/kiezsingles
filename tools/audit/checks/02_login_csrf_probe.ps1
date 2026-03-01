# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\02a_login_csrf_probe.ps1
# Purpose: Audit check - Login/CSRF probe (optional preflight)
# Created: 28-02-2026 (Europe/Berlin)
# Changed: 01-03-2026 14:00 (Europe/Berlin)
# Version: 0.3
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_LoginCsrfProbe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $new = $Context.Helpers.NewAuditResult
    $baseUrl = ("" + $Context.BaseUrl).TrimEnd("/")
    $email = ("" + $Context.SuperadminEmail).Trim()
    $password = ("" + $Context.SuperadminPassword)

    & $Context.Helpers.WriteSection "2a) Login CSRF probe (preflight)"

    function New-IwrParamsBase {
        $p = @{
            TimeoutSec  = 12
            ErrorAction = "Stop"
            Headers     = @{ "Accept" = "text/html,application/xhtml+xml" }
        }
        try {
            $cmd = Get-Command Invoke-WebRequest -ErrorAction Stop
            if ($cmd -and $cmd.Parameters -and $cmd.Parameters.ContainsKey("UseBasicParsing")) {
                $p["UseBasicParsing"] = $true
            }
        } catch { }
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

            $finalUri = ""
            try {
                if ($resp -and $resp.BaseResponse -and $resp.BaseResponse.ResponseUri) {
                    $finalUri = ("" + $resp.BaseResponse.ResponseUri.AbsoluteUri)
                }
            } catch { $finalUri = "" }

            return [pscustomobject]@{
                ok        = $true
                status    = $status
                final_uri = $finalUri
                content   = ("" + $resp.Content)
                error     = ""
            }
        } catch {
            $resp = $null
            try {
                if ($_.Exception -and ($_.Exception | Get-Member -Name Response -ErrorAction SilentlyContinue)) {
                    $resp = $_.Exception.Response
                }
            } catch { $resp = $null }
            if ($null -eq $resp) {
                try {
                    if ($_ -and ($_ | Get-Member -Name Response -ErrorAction SilentlyContinue)) { $resp = $_.Response }
                } catch { $resp = $null }
            }

            if ($resp) {
                $status = $null
                try { $status = [int]$resp.StatusCode } catch { $status = $null }

                $finalUri = ""
                try {
                    if ($resp.ResponseUri) { $finalUri = ("" + $resp.ResponseUri.AbsoluteUri) }
                } catch { $finalUri = "" }

                $bodyText = ""
                try {
                    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
                    $bodyText = $sr.ReadToEnd()
                    $sr.Close()
                } catch { $bodyText = "" }

                return [pscustomobject]@{
                    ok        = $true
                    status    = $status
                    final_uri = $finalUri
                    content   = $bodyText
                    error     = ""
                }
            }

            return [pscustomobject]@{
                ok        = $false
                status    = $null
                final_uri = ""
                content   = ""
                error     = ("" + $_.Exception.Message)
            }
        }
    }

    $details = @()
    $data = @{}

    if ($email -eq "" -or $password -eq "") {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "missing_credentials"; status = $null }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2a) Login CSRF probe" -Status "WARN" -Summary "Skipped: missing superadmin credentials (-SuperadminEmail / -SuperadminPassword)." -Details @() -Data @{ base_url = $baseUrl } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $session = $null
    try { $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession } catch { $session = $null }
    if ($null -eq $session) {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "session_init_failed"; status = $null }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2a) Login CSRF probe" -Status "FAIL" -Summary "Cannot initialize WebRequestSession." -Details @() -Data @{ base_url = $baseUrl } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $loginUrl = $baseUrl + "/login"

    # GET /login (token preflight)
    $rGet = Invoke-IwrCapture -Uri $loginUrl -Method "GET" -Session $session -MaxRedirection 20
    if (-not $rGet.ok) {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "get_failed"; status = $null }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2a) Login CSRF probe" -Status "FAIL" -Summary ("GET /login failed: " + $rGet.error) -Details @() -Data @{ base_url = $baseUrl } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $details += ("GET /login status: " + ($(if ($null -ne $rGet.status) { [int]$rGet.status } else { "n/a" })))

    $token = ""
    try {
        $m = [regex]::Match(("" + $rGet.content), 'name\s*=\s*"[_]?token"\s+value\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { $token = ("" + $m.Groups[1].Value) }
    } catch { $token = "" }

    if ($token -eq "") {
        $sw.Stop()
        $details += "_token: missing"
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "missing_token"; status = $rGet.status }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2a) Login CSRF probe" -Status "FAIL" -Summary "GET /login did not expose _token." -Details $details -Data @{ base_url = $baseUrl; get_status = $rGet.status } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $details += ("_token: present (len=" + $token.Length + ")")

    # POST /login (single client, single WebRequestSession, follow up to 1 redirect)
    $postBody = @{
        _token    = $token
        email     = $email
        password  = $password
    }

    $rPost = Invoke-IwrCapture -Uri $loginUrl -Method "POST" -Session $session -Body $postBody -MaxRedirection 1

    $postStatus = $rPost.status
    $finalUri = ("" + $rPost.final_uri).Trim()

    $details += ("POST /login status: " + ($(if ($null -ne $postStatus) { [int]$postStatus } else { "n/a" })))
    if ($finalUri -ne "") { $details += ("POST /login final uri: " + $finalUri) }

    $data = @{
        base_url            = $baseUrl
        get_status          = $rGet.status
        post_status         = $postStatus
        post_final_uri      = $finalUri
        token_present       = $true
        token_length        = [int]$token.Length
        post_has_response   = [bool]$rPost.ok
    }

    if (-not $rPost.ok) {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "login_post_no_response"; status = $null }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2a) Login CSRF probe" -Status "FAIL" -Summary ("POST /login failed: " + $rPost.error + " (no response object)") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($postStatus -eq 419) {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "csrf_419"; status = 419 }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2a) Login CSRF probe" -Status "FAIL" -Summary "POST /login returned 419 (csrf_419)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $finalUriNorm = $finalUri
    try { $finalUriNorm = ("" + $finalUri).TrimEnd("/") } catch { $finalUriNorm = $finalUri }

    if ($finalUriNorm -match '/login$') {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "redirect_login"; status = $postStatus }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2a) Login CSRF probe" -Status "FAIL" -Summary "POST /login ended on /login (redirect_login)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($postStatus -eq 200 -and $finalUriNorm -match '/admin') {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $true; reason = "success"; status = $postStatus }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2a) Login CSRF probe" -Status "OK" -Summary "Login probe success (success)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $sw.Stop()
    try {
        $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "redirect_login"; status = $postStatus }) -Force
    } catch { }
    return & $new -Id "login_csrf_probe" -Title "2a) Login CSRF probe" -Status "FAIL" -Summary "Login probe did not reach admin (redirect_login)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
}