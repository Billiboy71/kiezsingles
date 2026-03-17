# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\checks\check-session-reuse.ps1
# Purpose: Session reuse protection check for browser-first security audit
# Created: 16-03-2026 19:04 (Europe/Berlin)
# Changed: 16-03-2026 19:04 (Europe/Berlin)
# Version: 1.0
# =============================================================================

Set-StrictMode -Version Latest

function New-SessionSecurityCheckResult {
    param(
        [Parameter(Mandatory=$true)][string]$CheckName,
        [Parameter(Mandatory=$true)][string]$Result,
        [Parameter(Mandatory=$true)][string]$Summary,
        [Parameter(Mandatory=$false)][string[]]$Details = @(),
        [Parameter(Mandatory=$false)][string[]]$Evidence = @(),
        [Parameter(Mandatory=$false)][hashtable]$Data = @{},
        [Parameter(Mandatory=$false)][int]$DurationMs = 0
    )

    return [PSCustomObject]@{
        CheckName  = $CheckName
        Result     = $Result
        Summary    = $Summary
        Details    = @($Details)
        Evidence   = @($Evidence)
        Data       = $Data
        DurationMs = $DurationMs
    }
}

function Convert-SessionSecurityHtmlSnippet {
    param(
        [Parameter(Mandatory=$false)][string]$Html,
        [Parameter(Mandatory=$false)][int]$MaxLength = 260
    )

    $text = ""
    try { $text = Convert-ToSearchText -text $Html } catch { $text = "" }

    if ([string]::IsNullOrWhiteSpace($text)) {
        return ""
    }

    if ($text.Length -gt $MaxLength) {
        return $text.Substring(0, $MaxLength)
    }

    return $text
}

function Get-SessionSecurityAlternateClientIp {
    param(
        [Parameter(Mandatory=$false)][string]$ExcludeIp = ""
    )

    $candidateIps = New-Object System.Collections.Generic.List[string]

    try {
        $adminValidationTestIp = ("" + $script:AdminValidationTestIp).Trim()
        if (-not [string]::IsNullOrWhiteSpace($adminValidationTestIp)) {
            $candidateIps.Add($adminValidationTestIp) | Out-Null
        }
    } catch {
    }

    try {
        foreach ($ip in @($script:ClientIpPool)) {
            $candidate = ("" + $ip).Trim()
            if ([string]::IsNullOrWhiteSpace($candidate)) {
                continue
            }

            if ($candidateIps -notcontains $candidate) {
                $candidateIps.Add($candidate) | Out-Null
            }
        }
    } catch {
    }

    foreach ($candidateIp in @($candidateIps.ToArray())) {
        if (-not [string]::IsNullOrWhiteSpace($candidateIp) -and $candidateIp -ne ("" + $ExcludeIp).Trim()) {
            return $candidateIp
        }
    }

    if (("198.51.100.210") -ne ("" + $ExcludeIp).Trim()) {
        return "198.51.100.210"
    }

    return "198.51.100.211"
}

function Invoke-SessionReuseProtectionCheck {
    $checkName = "SessionReuseProtection"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $details = New-Object System.Collections.Generic.List[string]
    $evidence = New-Object System.Collections.Generic.List[string]
    $data = [ordered]@{}

    try {
        Write-Section "SESSION CHECK: SessionReuseProtection"

        $loginSession = Get-AbuseAdminValidationLoginSession
        if ($null -eq $loginSession -or (-not [bool]$loginSession.Success)) {
            $errorMessage = ""
            try { $errorMessage = ("" + $loginSession.ErrorMessage).Trim() } catch { $errorMessage = "ADMIN_LOGIN_FAILED" }

            Write-Host ("{0} -> WARN ({1})" -f $checkName, $errorMessage)
            $details.Add(("AdminLogin: {0}" -f $errorMessage)) | Out-Null

            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary ("Admin login unavailable: {0}" -f $errorMessage) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        $adminEventsPath = "/admin/security/events"
        try {
            $configuredPath = ("" + $script:AdminValidationEventsPath).Trim()
            if (-not [string]::IsNullOrWhiteSpace($configuredPath)) {
                $adminEventsPath = $configuredPath
            }
        } catch {
        }

        $baseUrl = Normalize-BaseUrl -s ("" + $script:BaseUrl)
        $sessionCookieValue = Get-SessionCookieValue -Session $loginSession.WebSession -BaseUrl $baseUrl -CookieName "laravel_session"
        $deviceCookieName = ""
        $deviceCookieValue = ""

        try { $deviceCookieName = ("" + $script:DeviceCookieName).Trim() } catch { $deviceCookieName = "" }
        if (-not [string]::IsNullOrWhiteSpace($deviceCookieName)) {
            $deviceCookieValue = Get-SessionCookieValue -Session $loginSession.WebSession -BaseUrl $baseUrl -CookieName $deviceCookieName
        }

        if ([string]::IsNullOrWhiteSpace($sessionCookieValue)) {
            Write-Host ("{0} -> WARN (SESSION_COOKIE_NOT_FOUND)" -f $checkName)
            $details.Add("laravel_session cookie not found after successful login.") | Out-Null

            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary "Session cookie not available after login." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        $reusedSession = New-Session
        Set-SessionCookieValue -Session $reusedSession -BaseUrl $baseUrl -CookieName "laravel_session" -CookieValue $sessionCookieValue

        if (-not [string]::IsNullOrWhiteSpace($deviceCookieName) -and -not [string]::IsNullOrWhiteSpace($deviceCookieValue)) {
            Set-SessionCookieValue -Session $reusedSession -BaseUrl $baseUrl -CookieName $deviceCookieName -CookieValue $deviceCookieValue
        }

        $alternateIp = Get-SessionSecurityAlternateClientIp -ExcludeIp ("" + $loginSession.ClientIp)
        $headers = Get-RequestHeaders -ExtraHeaders (Get-DeviceHeaders) -ForcedIp $alternateIp
        $targetUrl = Resolve-Url -BaseUrl $baseUrl -CurrentUrl $baseUrl -Location $adminEventsPath
        $response = Invoke-GetWithOptionalRedirects -BaseUrl $baseUrl -Url $targetUrl -Session $reusedSession -Headers $headers.Headers -Max $script:MaxRedirects

        $initialStatus = ""
        $finalUrl = ""
        $finalHtml = ""
        $sessionCookieAfter = ""
        $statusInt = 0

        try { $initialStatus = "" + $response.InitialStatus } catch { $initialStatus = "" }
        try { $finalUrl = "" + $response.FinalUrl } catch { $finalUrl = "" }
        try { $finalHtml = "" + $response.FinalHtml } catch { $finalHtml = "" }
        try { $statusInt = [int]$response.InitialStatus } catch { $statusInt = 0 }

        $sessionCookieAfter = Get-SessionCookieValue -Session $reusedSession -BaseUrl $baseUrl -CookieName "laravel_session"
        $snippet = Convert-SessionSecurityHtmlSnippet -Html $finalHtml

        $looksLikeLogin = $false
        $looksLikeConfirmPassword = $false
        $redirectedToLogin = $false
        $statusPass = $false

        try { $looksLikeLogin = Test-AbuseAdminValidationLooksLikeLoginHtml -Html $finalHtml } catch { $looksLikeLogin = $false }
        try { $looksLikeConfirmPassword = Test-AbuseAdminValidationLooksLikeConfirmPasswordHtml -Html $finalHtml } catch { $looksLikeConfirmPassword = $false }
        try { $redirectedToLogin = (Test-UrlLooksLikeLogin -u $finalUrl) -or (Test-UrlLooksLikeLogin -u (Try-GetLocationHeader -resp $response.Raw)) } catch { $redirectedToLogin = $false }

        if ($statusInt -in @(401, 419)) {
            $statusPass = $true
        } elseif ($redirectedToLogin -or $looksLikeLogin -or $looksLikeConfirmPassword) {
            $statusPass = $true
        } elseif ($finalUrl -match '/confirm-password(?:\?|$)') {
            $statusPass = $true
        }

        $data["InitialStatus"] = $initialStatus
        $data["FinalUrl"] = $finalUrl
        $data["AlternateIp"] = $alternateIp
        $data["SessionCookieAfterExists"] = (-not [string]::IsNullOrWhiteSpace($sessionCookieAfter))

        $details.Add(("InitialStatus: {0}" -f $initialStatus)) | Out-Null
        $details.Add(("FinalUrl: {0}" -f $finalUrl)) | Out-Null
        $details.Add(("AlternateIp: {0}" -f $alternateIp)) | Out-Null
        $details.Add(("LooksLikeLogin: {0}" -f $looksLikeLogin)) | Out-Null
        $details.Add(("LooksLikeConfirmPassword: {0}" -f $looksLikeConfirmPassword)) | Out-Null
        $details.Add(("SessionCookieAfterExists: {0}" -f (-not [string]::IsNullOrWhiteSpace($sessionCookieAfter)))) | Out-Null

        if (-not [string]::IsNullOrWhiteSpace($snippet)) {
            $evidence.Add(("ResponseSnippet: {0}" -f $snippet)) | Out-Null
        }

        if ($statusPass) {
            Write-Host ("{0} -> PASS" -f $checkName)
            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "PASS" -Summary "Session reuse from alternate IP was blocked." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        Write-Host ("{0} -> FAIL" -f $checkName)
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "FAIL" -Summary "Session cookie remained usable from alternate IP." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host ("{0} -> WARN ({1})" -f $checkName, $errorMessage)
        $details.Add(("CheckError: {0}" -f $errorMessage)) | Out-Null
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary ("Check error: {0}" -f $errorMessage) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    }
}
