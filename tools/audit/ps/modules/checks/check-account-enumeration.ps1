# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\checks\check-account-enumeration.ps1
# Purpose: Account enumeration protection check for browser-first security audit
# Created: 16-03-2026 19:04 (Europe/Berlin)
# Changed: 16-03-2026 19:04 (Europe/Berlin)
# Version: 1.0
# =============================================================================

Set-StrictMode -Version Latest

function Get-SessionSecurityPrimaryTestIp {
    try {
        $resolved = ("" + $script:ResolvedLockoutTestIp).Trim()
        if (-not [string]::IsNullOrWhiteSpace($resolved)) {
            return $resolved
        }
    } catch {
    }

    try {
        foreach ($ip in @($script:ClientIpPool)) {
            $candidate = ("" + $ip).Trim()
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                return $candidate
            }
        }
    } catch {
    }

    return "198.51.100.211"
}

function Get-SessionSecurityErrorSignature {
    param(
        [Parameter(Mandatory=$false)][string]$Html
    )

    $searchText = ""
    try { $searchText = Convert-ToSearchText -text $Html } catch { $searchText = "" }

    if ([string]::IsNullOrWhiteSpace($searchText)) {
        return ""
    }

    $match = $null
    try { $match = [regex]::Match($searchText, $script:WrongCredsPattern, 'IgnoreCase') } catch { $match = $null }

    if ($null -ne $match -and $match.Success) {
        return ("" + $match.Value).Trim()
    }

    if ($searchText.Length -gt 220) {
        return $searchText.Substring(0, 220)
    }

    return $searchText
}

function Invoke-SessionSecurityMeasuredLoginAttempt {
    param(
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$Password,
        [Parameter(Mandatory=$false)][string]$ForcedAttemptIp = "",
        [Parameter(Mandatory=$false)][string]$DeviceCookieId = ""
    )

    $session = New-Session
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $attempt = Post-LoginAttempt -BaseUrl $script:BaseUrl -Session $session -Email $Email -Password $Password -ExtraHeaders (Get-DeviceHeaders) -DeviceCookieId $DeviceCookieId -ForcedAttemptIp $ForcedAttemptIp
    $sw.Stop()

    $status = ""
    $finalUrl = ""
    $html = ""

    try { $status = "" + $attempt.PostStatus } catch { $status = "" }
    try { $finalUrl = "" + $attempt.FinalUrl } catch { $finalUrl = "" }
    try { $html = "" + $attempt.FinalHtml } catch { $html = "" }

    return [PSCustomObject]@{
        Status         = $status
        FinalUrl       = $finalUrl
        Html           = $html
        ErrorText      = (Get-SessionSecurityErrorSignature -Html $html)
        ResponseSize   = $(if ($null -ne $html) { ("" + $html).Length } else { 0 })
        ResponseMs     = [int]$sw.ElapsedMilliseconds
        AttemptIp      = ("" + $attempt.AttemptIp)
        DeviceCookieId = ("" + $attempt.DeviceCookieId)
    }
}

function Invoke-AccountEnumerationProtectionCheck {
    $checkName = "AccountEnumerationProtection"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $details = New-Object System.Collections.Generic.List[string]
    $evidence = New-Object System.Collections.Generic.List[string]
    $data = [ordered]@{}

    try {
        Write-Section "SESSION CHECK: AccountEnumerationProtection"

        $forcedAttemptIp = Get-SessionSecurityPrimaryTestIp
        $deviceCookieId = ""
        try { $deviceCookieId = ("" + $script:AdminValidationDeviceCookieId).Trim() } catch { $deviceCookieId = "" }
        if ([string]::IsNullOrWhiteSpace($deviceCookieId)) {
            $deviceCookieId = "ks-session-enum-device-001"
        }

        $registeredAttempt = Invoke-SessionSecurityMeasuredLoginAttempt -Email ("" + $script:RegisteredEmail) -Password ("" + $script:WrongPassword) -ForcedAttemptIp $forcedAttemptIp -DeviceCookieId $deviceCookieId
        $unregisteredAttempt = Invoke-SessionSecurityMeasuredLoginAttempt -Email ("" + $script:UnregisteredEmail) -Password ("" + $script:WrongPassword) -ForcedAttemptIp $forcedAttemptIp -DeviceCookieId $deviceCookieId

        $sizeDelta = [Math]::Abs(([int]$registeredAttempt.ResponseSize) - ([int]$unregisteredAttempt.ResponseSize))
        $maxSize = [Math]::Max([int]$registeredAttempt.ResponseSize, [int]$unregisteredAttempt.ResponseSize)
        $sizeSimilar = ($sizeDelta -le 120)
        if (-not $sizeSimilar -and $maxSize -gt 0) {
            $sizeSimilar = (([double]$sizeDelta / [double]$maxSize) -le 0.15)
        }

        $timeDelta = [Math]::Abs(([int]$registeredAttempt.ResponseMs) - ([int]$unregisteredAttempt.ResponseMs))
        $timeSimilar = ($timeDelta -le 2500)

        $statusMatches = ((("" + $registeredAttempt.Status).Trim()) -eq (("" + $unregisteredAttempt.Status).Trim()))
        $messageMatches = ((("" + $registeredAttempt.ErrorText).Trim()) -eq (("" + $unregisteredAttempt.ErrorText).Trim()))

        $details.Add(("RegisteredEmail Status: {0}" -f $registeredAttempt.Status)) | Out-Null
        $details.Add(("UnregisteredEmail Status: {0}" -f $unregisteredAttempt.Status)) | Out-Null
        $details.Add(("RegisteredEmail ResponseSize: {0}" -f $registeredAttempt.ResponseSize)) | Out-Null
        $details.Add(("UnregisteredEmail ResponseSize: {0}" -f $unregisteredAttempt.ResponseSize)) | Out-Null
        $details.Add(("RegisteredEmail ResponseMs: {0}" -f $registeredAttempt.ResponseMs)) | Out-Null
        $details.Add(("UnregisteredEmail ResponseMs: {0}" -f $unregisteredAttempt.ResponseMs)) | Out-Null
        $details.Add(("StatusMatches: {0}" -f $statusMatches)) | Out-Null
        $details.Add(("MessageMatches: {0}" -f $messageMatches)) | Out-Null
        $details.Add(("SizeSimilar: {0}" -f $sizeSimilar)) | Out-Null
        $details.Add(("TimeSimilar: {0}" -f $timeSimilar)) | Out-Null

        if (-not [string]::IsNullOrWhiteSpace($registeredAttempt.ErrorText)) {
            $evidence.Add(("RegisteredEmail Message: {0}" -f $registeredAttempt.ErrorText)) | Out-Null
        }

        if (-not [string]::IsNullOrWhiteSpace($unregisteredAttempt.ErrorText)) {
            $evidence.Add(("UnregisteredEmail Message: {0}" -f $unregisteredAttempt.ErrorText)) | Out-Null
        }

        $data["RegisteredEmailStatus"] = $registeredAttempt.Status
        $data["UnregisteredEmailStatus"] = $unregisteredAttempt.Status
        $data["RegisteredEmailMessage"] = $registeredAttempt.ErrorText
        $data["UnregisteredEmailMessage"] = $unregisteredAttempt.ErrorText
        $data["RegisteredEmailResponseSize"] = [int]$registeredAttempt.ResponseSize
        $data["UnregisteredEmailResponseSize"] = [int]$unregisteredAttempt.ResponseSize
        $data["RegisteredEmailResponseMs"] = [int]$registeredAttempt.ResponseMs
        $data["UnregisteredEmailResponseMs"] = [int]$unregisteredAttempt.ResponseMs
        $data["ForcedAttemptIp"] = $forcedAttemptIp

        if ($statusMatches -and $messageMatches -and $sizeSimilar) {
            if ($timeSimilar) {
                Write-Host ("{0} -> PASS" -f $checkName)
                $sw.Stop()
                return (New-SessionSecurityCheckResult -CheckName $checkName -Result "PASS" -Summary "Registered and unregistered login failures looked equivalent." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
            }

            Write-Host ("{0} -> WARN" -f $checkName)
            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary "Responses matched, but response times differed noticeably." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        Write-Host ("{0} -> FAIL" -f $checkName)
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "FAIL" -Summary "Login responses exposed detectable differences between existing and non-existing accounts." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host ("{0} -> WARN ({1})" -f $checkName, $errorMessage)
        $details.Add(("CheckError: {0}" -f $errorMessage)) | Out-Null
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary ("Check error: {0}" -f $errorMessage) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    }
}
