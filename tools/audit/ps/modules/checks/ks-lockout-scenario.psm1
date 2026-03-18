# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\checks\ks-lockout-scenario.psm1
# Purpose: Lockout / wrong-credentials scenario check for KiezSingles audit PowerShell scripts
# Created: 06-03-2026 22:46 (Europe/Berlin)
# Changed: 17-03-2026 13:11 (Europe/Berlin)
# Version: 1.6
# =============================================================================

Set-StrictMode -Version Latest

function Convert-ToScenarioString {
    param(
        [Parameter(Mandatory=$false)]$Value
    )

    try {
        if ($null -eq $Value) {
            return ""
        }

        if ($Value -is [System.Array]) {
            if ($Value.Count -eq 0) {
                return ""
            }

            return ("" + $Value[0])
        }

        return ("" + $Value)
    } catch {
        return ""
    }
}

function Convert-ToScenarioBool {
    param(
        [Parameter(Mandatory=$false)]$Value,
        [Parameter(Mandatory=$false)][bool]$Default = $false
    )

    try {
        if ($null -eq $Value) {
            return $Default
        }

        if ($Value -is [bool]) {
            return [bool]$Value
        }

        if ($Value -is [System.Array]) {
            if ($Value.Count -eq 0) {
                return $Default
            }

            return [System.Convert]::ToBoolean($Value[0])
        }

        return [System.Convert]::ToBoolean($Value)
    } catch {
        return $Default
    }
}

function Convert-ToScenarioHeaders {
    param(
        [Parameter(Mandatory=$false)]$Value
    )

    if ($null -eq $Value) {
        return @{}
    }

    if ($Value -is [hashtable]) {
        return $Value
    }

    $headers = @{}

    try {
        if ($Value.PSObject -and $Value.PSObject.Properties) {
            foreach ($prop in $Value.PSObject.Properties) {
                $name = Convert-ToScenarioString -Value $prop.Name
                if ([string]::IsNullOrWhiteSpace($name)) {
                    continue
                }

                $headers[$name] = $prop.Value
            }
        }
    } catch {
    }

    return $headers
}

function Get-ScenarioDefaultDeviceCookieId {
    param(
        [Parameter(Mandatory=$false)][string]$RequestedDeviceCookieId = ""
    )

    $resolved = Convert-ToScenarioString -Value $RequestedDeviceCookieId
    if (-not [string]::IsNullOrWhiteSpace($resolved)) {
        return $resolved
    }

    $testDeviceCookieId = ""
    try { $testDeviceCookieId = Convert-ToScenarioString -Value $script:TestDeviceCookieId } catch { $testDeviceCookieId = "" }

    if (-not [string]::IsNullOrWhiteSpace($testDeviceCookieId)) {
        return $testDeviceCookieId
    }

    $pinnedDeviceCookieId = ""
    try { $pinnedDeviceCookieId = Convert-ToScenarioString -Value $script:PinnedDeviceCookieId } catch { $pinnedDeviceCookieId = "" }

    if (-not [string]::IsNullOrWhiteSpace($pinnedDeviceCookieId)) {
        return $pinnedDeviceCookieId
    }

    return ""
}

function Get-ScenarioDefaultAttemptIp {
    param(
        [Parameter(Mandatory=$false)][string]$RequestedAttemptIp = ""
    )

    $resolved = Convert-ToScenarioString -Value $RequestedAttemptIp
    if (-not [string]::IsNullOrWhiteSpace($resolved)) {
        return $resolved
    }

    $resolvedLockoutTestIp = ""
    try { $resolvedLockoutTestIp = Convert-ToScenarioString -Value $script:ResolvedLockoutTestIp } catch { $resolvedLockoutTestIp = "" }

    if (-not [string]::IsNullOrWhiteSpace($resolvedLockoutTestIp)) {
        return $resolvedLockoutTestIp
    }

    $clientIpPool = @()
    try { $clientIpPool = @($script:ClientIpPool) } catch { $clientIpPool = @() }

    foreach ($ip in $clientIpPool) {
        $candidate = Convert-ToScenarioString -Value $ip
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate
        }
    }

    return ""
}

function New-ScenarioDefaultResult {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$false)][string]$DeviceCookieId = "",
        [Parameter(Mandatory=$false)][string]$AttemptIp = "",
        [Parameter(Mandatory=$false)][string]$SkipReason = ""
    )

    return [PSCustomObject]@{
        ScenarioName             = $ScenarioName
        Email                    = $Email
        DeviceCookieId           = $DeviceCookieId
        AttemptIp                = $AttemptIp
        WrongCredsDetected       = $false
        LockoutDetected          = $false
        LockoutSeconds           = ""
        SupportCodeDetected      = $false
        SupportCodeValue         = ""
        SupportFlowResult        = $(if ([string]::IsNullOrWhiteSpace($SkipReason)) { "SKIP_NO_SUPPORT_REF" } else { $SkipReason })
        SupportLinkFound         = $false
        SupportLinkUrl           = ""
        SupportTargetUrl         = ""
        SupportTargetPathOk      = $false
        SupportTargetCsrfPresent = $false
        SupportCodeOnTarget      = ""
        SupportCodeMatch         = $false
        TicketSubmitAttempted    = $false
        TicketSubmitResult       = $(if ([string]::IsNullOrWhiteSpace($SkipReason)) { "SKIP_NOT_RUN" } else { $SkipReason })
        TicketSubmitUrl          = ""
        TicketSubmitFinalUrl     = ""
        TicketSubmitHttp         = ""
        TicketSupportCode        = ""
        MailSupportCode          = ""
        MailResult               = "INFO_NOT_RUN"
        SecE2EResult             = "FAIL"
        SkipReason               = $SkipReason
    }
}

function Invoke-ScenarioLoginAttempt {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$WrongPassword,
        [Parameter(Mandatory=$false)]$ExtraHeaders = @{},
        [Parameter(Mandatory=$false)]$DeviceCookieId = "",
        [Parameter(Mandatory=$false)]$ForcedAttemptIp = ""
    )

    $resolvedHeaders = Convert-ToScenarioHeaders -Value $ExtraHeaders
    $resolvedDeviceCookieId = Convert-ToScenarioString -Value $DeviceCookieId
    $resolvedForcedAttemptIp = Convert-ToScenarioString -Value $ForcedAttemptIp

    Begin-StepIp
    try {
        $attempt = Post-LoginAttempt `
            -BaseUrl $BaseUrl `
            -Session $Session `
            -Email $Email `
            -Password $WrongPassword `
            -ExtraHeaders $resolvedHeaders `
            -DeviceCookieId $resolvedDeviceCookieId `
            -ForcedAttemptIp $resolvedForcedAttemptIp
    } finally {
        End-StepIp
    }

    $html = ""
    try { $html = "" + $attempt.FinalHtml } catch { $html = "" }

    $analysis = Analyze-Html -html $html

    return [PSCustomObject]@{
        Attempt  = $attempt
        Analysis = $analysis
        Html     = $html
    }
}

function Run-Scenario {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$WrongPassword,
        [Parameter(Mandatory=$true)][int]$Attempts,
        [Parameter(Mandatory=$false)]$ExtraHeaders = @{},
        [Parameter(Mandatory=$false)]$DeviceCookieId = "",
        [Parameter(Mandatory=$false)]$ForcedAttemptIp = "",
        [Parameter(Mandatory=$false)]$SkipSupportFlow = $false
    )

    $resolvedHeaders = Convert-ToScenarioHeaders -Value $ExtraHeaders
    $requestedDeviceCookieId = Convert-ToScenarioString -Value $DeviceCookieId
    $requestedForcedAttemptIp = Convert-ToScenarioString -Value $ForcedAttemptIp
    $resolvedSkipSupportFlow = Convert-ToScenarioBool -Value $SkipSupportFlow -Default $false

    $supportFlow = New-DefaultSupportFlowResult
    $effectiveForcedAttemptIp = ""
    $effectiveDeviceCookieId = ""
    $lastAttemptIp = ""
    $lastDeviceCookieId = ""
    $forcedClientIpEntered = $false

    try {
        Write-Section ("SCENARIO: {0}" -f $ScenarioName)
        Write-Host "Email:" $Email
        Write-Host "Attempts:" $Attempts

        Reset-ClientIpRotation -Pool $script:ClientIpPool
        $session = New-Session

        $effectiveForcedAttemptIp = Get-ScenarioDefaultAttemptIp -RequestedAttemptIp $requestedForcedAttemptIp
        $effectiveDeviceCookieId = Get-ScenarioDefaultDeviceCookieId -RequestedDeviceCookieId $requestedDeviceCookieId

        if (-not [string]::IsNullOrWhiteSpace($requestedDeviceCookieId)) {
            Write-Host "RequestedDeviceCookieId:" $requestedDeviceCookieId
        }

        if (-not [string]::IsNullOrWhiteSpace($requestedForcedAttemptIp)) {
            Write-Host "RequestedForcedAttemptIp:" $requestedForcedAttemptIp
        }

        Write-Host "EffectiveDeviceCookieId:" $effectiveDeviceCookieId
        Write-Host "EffectiveAttemptIp:" $effectiveForcedAttemptIp

        if (-not [string]::IsNullOrWhiteSpace($effectiveForcedAttemptIp)) {
            Enter-ForcedClientIp $effectiveForcedAttemptIp
            $forcedClientIpEntered = $true
        }

        Begin-StepIp
        try {
            $hGet = Get-RequestHeaders -ExtraHeaders $resolvedHeaders -ForcedIp $effectiveForcedAttemptIp
            $r = Get-LoginPage $BaseUrl $session $hGet.Headers
        } finally {
            End-StepIp
        }

        $csrf = Extract-CsrfTokenFromHtml $r.Content

        Write-Host "GET /login Status:" $r.StatusCode `
                   "CSRF present:" (![string]::IsNullOrWhiteSpace($csrf)) `
                   "ClientIp:" $hGet.Ip

        $exportGet = Export-LoginHtml -label ("scenario_{0}_get_login" -f $ScenarioName) -html ("" + $r.Content)
        if ($exportGet -ne "") { Write-Host "Exported HTML:" $exportGet }

        $attempt1Result = Invoke-ScenarioLoginAttempt `
            -BaseUrl $BaseUrl `
            -Session $session `
            -Email $Email `
            -WrongPassword $WrongPassword `
            -ExtraHeaders $resolvedHeaders `
            -DeviceCookieId $effectiveDeviceCookieId `
            -ForcedAttemptIp $effectiveForcedAttemptIp

        $a1 = $attempt1Result.Attempt
        $an1 = $attempt1Result.Analysis
        $html1 = $attempt1Result.Html

        $lastAttemptIp = Convert-ToScenarioString -Value $a1.AttemptIp
        $lastDeviceCookieId = Convert-ToScenarioString -Value $a1.DeviceCookieId

        Write-Host "Attempt 1 Status:" $a1.PostStatus `
                   "Followed:" $a1.Followed `
                   "FinalUrl:" $a1.FinalUrl `
                   "ClientIp:" $a1.AttemptIp `
                   "DeviceCookieId:" $a1.DeviceCookieId

        Write-Host "Attempt 1 -> WrongCredsFound:" $an1.WrongCredsFound `
                   "LockoutFound:" $an1.LockoutFound `
                   "Seconds:" $an1.LockoutSeconds `
                   "SEC:" $an1.SecFound

        $export1 = Export-LoginHtml -label ("scenario_{0}_attempt_1_final_html" -f $ScenarioName) -html $html1
        if ($export1 -ne "") { Write-Host "Exported HTML:" $export1 }

        $lockHit = $false
        $last = $an1
        $lastHtml = $html1
        $lastUrl = $a1.FinalUrl
        $exportLock = ""

        for ($i = 2; $i -le $Attempts; $i++) {

            $attemptResult = Invoke-ScenarioLoginAttempt `
                -BaseUrl $BaseUrl `
                -Session $session `
                -Email $Email `
                -WrongPassword $WrongPassword `
                -ExtraHeaders $resolvedHeaders `
                -DeviceCookieId $effectiveDeviceCookieId `
                -ForcedAttemptIp $effectiveForcedAttemptIp

            $a = $attemptResult.Attempt
            $an = $attemptResult.Analysis
            $html = $attemptResult.Html

            $last = $an
            $lastHtml = $html
            $lastUrl = $a.FinalUrl
            $lastAttemptIp = Convert-ToScenarioString -Value $a.AttemptIp
            $lastDeviceCookieId = Convert-ToScenarioString -Value $a.DeviceCookieId

            Write-Host ("Attempt {0} Status:" -f $i) $a.PostStatus `
                       "Followed:" $a.Followed `
                       "FinalUrl:" $a.FinalUrl `
                       "ClientIp:" $a.AttemptIp `
                       "DeviceCookieId:" $a.DeviceCookieId

            Write-Host ("Attempt {0} -> WrongCredsFound:" -f $i) $an.WrongCredsFound `
                       "LockoutFound:" $an.LockoutFound `
                       "Seconds:" $an.LockoutSeconds `
                       "SEC:" $an.SecFound

            if ($a.PostStatus -eq 429 -or $an.LockoutFound) {

                $lockHit = $true

                $exportLock = Export-LoginHtml `
                    -label ("scenario_{0}_lockout_attempt_{1}_final_html" -f $ScenarioName, $i) `
                    -html $html

                break
            }
        }

        if ($lockHit) {

            Write-Host "Lockout detected"

            if ($last.LockoutFound) {
                Write-Host "Lockout seconds:" $last.LockoutSeconds
                Write-Host "Lockout snippet:"
                Write-Host $last.LockoutSnippet
            }

            if ($exportLock -ne "") { Write-Host "Exported HTML:" $exportLock }

        } else {

            Write-Host "Lockout NOT detected"

            $exportNo = Export-LoginHtml `
                -label ("scenario_{0}_lockout_not_detected_final_html_after_{1}_attempts" -f $ScenarioName, $Attempts) `
                -html $lastHtml

            if ($exportNo -ne "") { Write-Host "Exported HTML:" $exportNo }
        }

        if ((-not $resolvedSkipSupportFlow) -and $last.SecFound) {

            Write-Host "SupportRef:" $last.SecValue

            $supportFlow = Invoke-SupportContactFlowCheck `
                -FlowName ("scenario_{0}" -f $ScenarioName) `
                -BaseUrl $BaseUrl `
                -Session $session `
                -SourceUrl $lastUrl `
                -SourceHtml $lastHtml `
                -Headers $resolvedHeaders `
                -FallbackSupportCode $last.SecValue

            Write-Host "SupportContactFlow:" $supportFlow.Result `
                       "LinkFound:" $supportFlow.SupportLinkFound `
                       "TargetPathOk:" $supportFlow.TargetPathOk `
                       "TargetCsrfPresent:" $supportFlow.TargetCsrfPresent `
                       "SecMatch:" $supportFlow.SupportCodeMatch

            Write-Host "SupportTicketSubmit:" $supportFlow.TicketSubmitResult `
                       "Attempted:" $supportFlow.TicketSubmitAttempted `
                       "HTTP:" $supportFlow.TicketSubmitHttp

            if (-not [string]::IsNullOrWhiteSpace($supportFlow.SupportLinkUrl)) {
                Write-Host "SupportContactLink:" $supportFlow.SupportLinkUrl
            }

            if (-not [string]::IsNullOrWhiteSpace($supportFlow.FinalUrl)) {
                Write-Host "SupportContactTarget:" $supportFlow.FinalUrl
            }

            if (-not [string]::IsNullOrWhiteSpace($supportFlow.TargetSupportCode)) {
                Write-Host "TargetSupportRef:" $supportFlow.TargetSupportCode
            }

            if (-not [string]::IsNullOrWhiteSpace($supportFlow.TicketSubmitUrl)) {
                Write-Host "SupportTicketSubmitUrl:" $supportFlow.TicketSubmitUrl
            }

            if (-not [string]::IsNullOrWhiteSpace($supportFlow.TicketSubmitFinalUrl)) {
                Write-Host "SupportTicketSubmitTarget:" $supportFlow.TicketSubmitFinalUrl
            }
        }

        return [PSCustomObject]@{
            ScenarioName             = $ScenarioName
            Email                    = $Email
            DeviceCookieId           = $lastDeviceCookieId
            AttemptIp                = $lastAttemptIp
            WrongCredsDetected       = $an1.WrongCredsFound
            LockoutDetected          = $last.LockoutFound
            LockoutSeconds           = $last.LockoutSeconds
            SupportCodeDetected      = $last.SecFound
            SupportCodeValue         = $last.SecValue
            SupportFlowResult        = $supportFlow.Result
            SupportLinkFound         = $supportFlow.SupportLinkFound
            SupportLinkUrl           = $supportFlow.SupportLinkUrl
            SupportTargetUrl         = $supportFlow.FinalUrl
            SupportTargetPathOk      = $supportFlow.TargetPathOk
            SupportTargetCsrfPresent = $supportFlow.TargetCsrfPresent
            SupportCodeOnTarget      = $supportFlow.TargetSupportCode
            SupportCodeMatch         = $supportFlow.SupportCodeMatch
            TicketSubmitAttempted    = $supportFlow.TicketSubmitAttempted
            TicketSubmitResult       = $supportFlow.TicketSubmitResult
            TicketSubmitUrl          = $supportFlow.TicketSubmitUrl
            TicketSubmitFinalUrl     = $supportFlow.TicketSubmitFinalUrl
            TicketSubmitHttp         = $supportFlow.TicketSubmitHttp
            TicketSupportCode        = $supportFlow.TicketSupportCode
            MailSupportCode          = $supportFlow.MailSupportCode
            MailResult               = $supportFlow.MailResult
            SecE2EResult             = $supportFlow.SecE2EResult
            SkipReason               = ""
        }
    } catch {
        $errorMessage = Convert-ToScenarioString -Value $_.Exception.Message

        Write-Host ("SCENARIO ERROR: {0}" -f $errorMessage)

        return (New-ScenarioDefaultResult `
            -ScenarioName $ScenarioName `
            -Email $Email `
            -DeviceCookieId $lastDeviceCookieId `
            -AttemptIp $lastAttemptIp `
            -SkipReason ("SCENARIO_ERROR: {0}" -f $errorMessage))
    } finally {
        if ($forcedClientIpEntered) {
            Exit-ForcedClientIp
        }
    }
}

Export-ModuleMember -Function *
