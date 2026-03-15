# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\auth\ks-login-attempt.psm1
# Purpose: Login attempt helper (GET /login + POST /login + redirect follow)
# Created: 06-03-2026 22:55 (Europe/Berlin)
# Changed: 15-03-2026 22:05 (Europe/Berlin)
# Version: 1.3
# =============================================================================

Set-StrictMode -Version Latest

function Post-LoginAttempt {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$Password,
        [Parameter(Mandatory=$false)][hashtable]$ExtraHeaders = @{},
        [Parameter(Mandatory=$false)][string]$DeviceCookieId = "",
        [Parameter(Mandatory=$false)][string]$ForcedAttemptIp = ""
    )

    $attemptIp = ""

    if ($script:SimulateClientIpEnabled) {

        if (-not [string]::IsNullOrWhiteSpace($ForcedAttemptIp)) {
            $attemptIp = "" + $ForcedAttemptIp
        }
        elseif (-not [string]::IsNullOrWhiteSpace($script:ForcedClientIp)) {
            $attemptIp = "" + $script:ForcedClientIp
        }
        elseif ($script:IpRotationMode -eq "per_request") {
            $attemptIp = Next-TestIp
        }
        else {
            $attemptIp = Get-StepIp
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($DeviceCookieId)) {
        $cookieName = ""
        $cookieDomain = ""
        $baseUri = $null

        try { $cookieName = "" + $script:DeviceCookieName } catch { $cookieName = "" }

        if (-not [string]::IsNullOrWhiteSpace($cookieName)) {
            try {
                $baseUri = [Uri]$BaseUrl
                $cookieDomain = "" + $baseUri.Host
            }
            catch {
                $baseUri = $null
                $cookieDomain = ""
            }

            if (-not [string]::IsNullOrWhiteSpace($cookieDomain)) {

                # Remove existing device cookies to avoid server-generated UUID taking precedence
                try {
                    if ($null -ne $baseUri) {
                        $existing = $Session.Cookies.GetCookies($baseUri)
                        foreach ($c in $existing) {
                            if ($c.Name -eq $cookieName) {
                                $c.Expired = $true
                            }
                        }
                    }
                }
                catch {
                }

                try {
                    $deviceCookie = New-Object System.Net.Cookie($cookieName, ("" + $DeviceCookieId), "/", $cookieDomain)
                    $Session.Cookies.Add($deviceCookie)
                }
                catch {
                    try {
                        if ($null -ne $baseUri) {
                            $deviceCookie = New-Object System.Net.Cookie($cookieName, ("" + $DeviceCookieId), "/", $cookieDomain)
                            $Session.Cookies.Add($baseUri, $deviceCookie)
                        }
                    }
                    catch {
                    }
                }
            }
        }
    }

    $attemptHeaders = Merge-Headers -A $ExtraHeaders -B (Get-ClientIpHeaders -ip $attemptIp)

    $login = Get-LoginPage -BaseUrl $BaseUrl -Session $Session -Headers $attemptHeaders

    $csrf = Extract-CsrfTokenFromHtml -html $login.Content

    $postUrl = "$BaseUrl/login"

    $post = Invoke-HttpNoRedirect `
        -Method 'POST' `
        -Url $postUrl `
        -Session $Session `
        -Headers $attemptHeaders `
        -Form @{
            '_token'   = $csrf
            'email'    = $Email
            'password' = $Password
        }

    $loc = Try-GetLocationHeader -resp $post

    $finalUrl = $postUrl
    $finalHtml = ""
    $usedFollow = $false

    $sc = 0
    try { $sc = [int]$post.StatusCode } catch { $sc = 0 }

    if ($script:FollowRedirectsEnabled -and ($sc -ge 300 -and $sc -lt 400) -and (-not [string]::IsNullOrWhiteSpace($loc))) {

        $target = Resolve-Url -BaseUrl $BaseUrl -CurrentUrl $postUrl -Location $loc

        if (-not [string]::IsNullOrWhiteSpace($target)) {

            $follow = Invoke-FollowRedirects `
                -BaseUrl $BaseUrl `
                -StartUrl $target `
                -Session $Session `
                -Headers $attemptHeaders `
                -Max $script:MaxRedirects

            $finalUrl  = $follow.FinalUrl
            $finalHtml = $follow.FinalHtml
            $usedFollow = $true
        }
    }

    if (-not $usedFollow) {

        try {
            if ($null -ne $post.Content) {
                $finalHtml = "" + $post.Content
            }
            elseif ($null -ne $post.RawContent) {
                $finalHtml = "" + $post.RawContent
            }
            else {
                $finalHtml = ""
            }
        }
        catch {
            $finalHtml = ""
        }
    }

    return [PSCustomObject]@{
        AttemptIp      = $attemptIp
        DeviceCookieId = ("" + $DeviceCookieId)
        PostStatus     = $post.StatusCode
        PostLocation   = $loc
        FinalUrl       = $finalUrl
        FinalHtml      = $finalHtml
        Followed       = $usedFollow
        Raw            = $post
    }
}

Export-ModuleMember -Function *