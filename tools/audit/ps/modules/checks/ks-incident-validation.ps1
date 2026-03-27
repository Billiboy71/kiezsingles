# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\checks\ks-incident-validation.ps1
# Purpose: UI-based incident, risk score and action validation for browser-first security audit
# Created: 27-03-2026 00:51 (Europe/Berlin)
# Changed: 27-03-2026 00:51 (Europe/Berlin)
# Version: 1.0
# =============================================================================

Set-StrictMode -Version Latest

function Invoke-KsAuditCheck_IncidentValidation {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl
    )

    $checkName = "IncidentRiskActionValidation"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $details = New-Object System.Collections.Generic.List[string]
    $evidence = New-Object System.Collections.Generic.List[string]
    $data = [ordered]@{
        IncidentDetected = $false
        RiskScoreValid   = $false
        ActionPresent    = $false
    }

    try {
        Write-Section "SESSION CHECK: IncidentRiskActionValidation"

        $loginSession = Get-AbuseAdminValidationLoginSession
        if ($null -eq $loginSession -or (-not [bool]$loginSession.Success)) {
            $errorMessage = ""
            try { $errorMessage = ("" + $loginSession.ErrorMessage).Trim() } catch { $errorMessage = "ADMIN_LOGIN_FAILED" }

            Write-Host ("{0} -> WARN ({1})" -f $checkName, $errorMessage)
            $details.Add(("AdminLogin: {0}" -f $errorMessage)) | Out-Null

            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary ("Admin login unavailable: {0}" -f $errorMessage) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        $baseUrlNormalized = Normalize-BaseUrl -s $BaseUrl
        $incidentsPath = "/admin/security/incidents"
        $headers = Get-RequestHeaders -ExtraHeaders (Get-DeviceHeaders) -ForcedIp ("" + $loginSession.ClientIp)
        $targetUrl = Resolve-Url -BaseUrl $baseUrlNormalized -CurrentUrl $baseUrlNormalized -Location $incidentsPath
        $response = Invoke-GetWithOptionalRedirects -BaseUrl $baseUrlNormalized -Url $targetUrl -Session $loginSession.WebSession -Headers $headers.Headers -Max $script:MaxRedirects

        $finalHtml = ""
        $finalUrl = ""
        $initialStatus = ""

        try { $finalHtml = "" + $response.FinalHtml } catch { $finalHtml = "" }
        try { $finalUrl = "" + $response.FinalUrl } catch { $finalUrl = "" }
        try { $initialStatus = "" + $response.InitialStatus } catch { $initialStatus = "" }

        $data["IncidentDetected"] = ($finalHtml -match "Incident\s*#")
        $data["RiskScoreValid"] = ($finalHtml -match "Risiko")
        $data["ActionPresent"] = ($finalHtml -match "Empfohlene Maßnahmen" -or $finalHtml -match "Automatische Maßnahme")
        $data["FinalUrl"] = $finalUrl
        $data["InitialStatus"] = $initialStatus

        $details.Add(("IncidentDetected: {0}" -f $data["IncidentDetected"])) | Out-Null
        $details.Add(("RiskScoreValid: {0}" -f $data["RiskScoreValid"])) | Out-Null
        $details.Add(("ActionPresent: {0}" -f $data["ActionPresent"])) | Out-Null
        $details.Add(("InitialStatus: {0}" -f $initialStatus)) | Out-Null
        $details.Add(("FinalUrl: {0}" -f $finalUrl)) | Out-Null

        $snippet = Convert-SessionSecurityHtmlSnippet -Html $finalHtml -MaxLength 320
        if (-not [string]::IsNullOrWhiteSpace($snippet)) {
            $evidence.Add(("ResponseSnippet: {0}" -f $snippet)) | Out-Null
        }

        if ($data["IncidentDetected"] -and $data["RiskScoreValid"] -and $data["ActionPresent"]) {
            Write-Host ("{0} -> PASS" -f $checkName)
            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "PASS" -Summary "Incident, risk score and action signals were visible in the incidents UI." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        Write-Host ("{0} -> FAIL" -f $checkName)
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "FAIL" -Summary "Incident chain UI was incomplete (incident, risk score or action signal missing)." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host ("{0} -> WARN ({1})" -f $checkName, $errorMessage)
        $details.Add(("CheckError: {0}" -f $errorMessage)) | Out-Null
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary ("Check error: {0}" -f $errorMessage) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    }
}
