# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\checks\check-security-event-logging.ps1
# Purpose: Security event logging integrity check for browser-first security audit
# Created: 16-03-2026 19:04 (Europe/Berlin)
# Changed: 17-03-2026 00:18 (Europe/Berlin)
# Version: 1.1
# =============================================================================

Set-StrictMode -Version Latest

function Get-SessionSecurityEventColumnName {
    param(
        [Parameter(Mandatory=$true)][string[]]$Candidates
    )

    $columns = @()
    try { $columns = @(Get-AbuseAdminValidationSecurityEventsColumns) } catch { $columns = @() }

    foreach ($candidate in @($Candidates)) {
        foreach ($column in @($columns)) {
            if ((("" + $column).Trim()).Equals(("" + $candidate).Trim(), [System.StringComparison]::OrdinalIgnoreCase)) {
                return ("" + $column).Trim()
            }
        }
    }

    return ""
}

function Convert-SessionSecuritySqlValue {
    param(
        [Parameter(Mandatory=$false)][string]$Value
    )

    $text = ""
    try { $text = "" + $Value } catch { $text = "" }
    return ("'" + $text.Replace("'", "''") + "'")
}

function Invoke-SessionSecurityEventsQuery {
    param(
        [Parameter(Mandatory=$true)][string]$Query
    )

    return @(Invoke-AbuseAdminValidationMySqlQuery -Query $Query)
}

function Get-SessionSecurityEventCount {
    param(
        [Parameter(Mandatory=$true)][string]$WhereClause
    )

    $query = "SELECT COUNT(*) FROM security_events WHERE {0};" -f $WhereClause
    $lines = @(Invoke-SessionSecurityEventsQuery -Query $query)

    foreach ($line in $lines) {
        $count = 0
        if ([int]::TryParse((("" + $line).Trim()), [ref]$count)) {
            return [int]$count
        }
    }

    throw "SECURITY_EVENTS_COUNT_PARSE_FAILED"
}

function Get-SessionSecurityRecentEvents {
    $typeColumn = Get-SessionSecurityEventColumnName -Candidates @("type", "event_type")
    $ipColumn = Get-SessionSecurityEventColumnName -Candidates @("ip")
    $deviceHashColumn = Get-SessionSecurityEventColumnName -Candidates @("device_hash")
    $createdAtColumn = Get-SessionSecurityEventColumnName -Candidates @("created_at")

    if ([string]::IsNullOrWhiteSpace($typeColumn) -or [string]::IsNullOrWhiteSpace($ipColumn) -or [string]::IsNullOrWhiteSpace($deviceHashColumn) -or [string]::IsNullOrWhiteSpace($createdAtColumn)) {
        return @()
    }

    $query = "SELECT COALESCE({0},''), COALESCE({1},''), COALESCE({2},''), DATE_FORMAT({3}, '%Y-%m-%d %H:%i:%s') FROM security_events ORDER BY {3} DESC LIMIT 10;" -f $typeColumn, $ipColumn, $deviceHashColumn, $createdAtColumn
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($line in @(Invoke-SessionSecurityEventsQuery -Query $query)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = @($line -split "`t")
        while ($parts.Count -lt 4) {
            $parts += ""
        }

        $rows.Add([PSCustomObject]@{
            EventType  = ("" + $parts[0]).Trim()
            Ip         = ("" + $parts[1]).Trim()
            DeviceHash = ("" + $parts[2]).Trim()
            CreatedAt  = ("" + $parts[3]).Trim()
        }) | Out-Null
    }

    return @($rows.ToArray())
}

function Export-SessionSecurityCheckArtifacts {
    param(
        [Parameter(Mandatory=$true)]$Checks
    )

    $exports = [ordered]@{
        TxtPath  = ""
        JsonPath = ""
        CsvPath  = ""
    }

    $effectiveExportRunDir = ""
    try { $effectiveExportRunDir = ("" + $script:ExportRunDir).Trim() } catch { $effectiveExportRunDir = "" }

    if ([string]::IsNullOrWhiteSpace($effectiveExportRunDir)) {
        $exportHtmlDir = ""
        try { $exportHtmlDir = ("" + $script:ExportHtmlDir).Trim() } catch { $exportHtmlDir = "" }

        if (-not [string]::IsNullOrWhiteSpace($exportHtmlDir)) {
            $effectiveExportRunDir = Join-Path $exportHtmlDir $script:RunId
        }
    }

    if ([string]::IsNullOrWhiteSpace($effectiveExportRunDir)) {
        return [PSCustomObject]$exports
    }

    if (-not (Test-Path -LiteralPath $effectiveExportRunDir)) {
        [void](New-Item -ItemType Directory -Path $effectiveExportRunDir -Force)
    }

    $script:ExportRunDir = $effectiveExportRunDir
    try {
        if (Get-Command Set-AuditModuleRuntimeVariable -ErrorAction SilentlyContinue) {
            Set-AuditModuleRuntimeVariable -Name 'ExportRunDir' -Value $script:ExportRunDir
        }
    } catch {
    }

    $txtPath = Join-Path $effectiveExportRunDir ("{0}_session_security_checks.txt" -f $script:RunId)
    $jsonPath = Join-Path $effectiveExportRunDir ("{0}_session_security_checks.json" -f $script:RunId)
    $csvPath = Join-Path $effectiveExportRunDir ("{0}_session_security_checks.csv" -f $script:RunId)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("SESSION SECURITY CHECKS")
    $lines.Add(("RunId: {0}" -f $script:RunId))
    $lines.Add(("GeneratedAt: {0}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")))
    $lines.Add("")

    foreach ($check in @($Checks)) {
        $lines.Add(("{0} -> {1}" -f $check.CheckName, $check.Result))
        $lines.Add(("  Summary: {0}" -f $check.Summary))

        foreach ($detail in @($check.Details)) {
            $lines.Add(("  Detail: {0}" -f $detail))
        }

        foreach ($ev in @($check.Evidence)) {
            $lines.Add(("  Evidence: {0}" -f $ev))
        }

        $lines.Add("")
    }

    [System.IO.File]::WriteAllLines($txtPath, $lines, [System.Text.Encoding]::UTF8)

    $jsonObject = [PSCustomObject]@{
        RunId       = $script:RunId
        GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Checks      = @($Checks)
        Summary     = [PSCustomObject]@{
            Pass = @($Checks | Where-Object { $_.Result -eq "PASS" }).Count
            Warn = @($Checks | Where-Object { $_.Result -eq "WARN" }).Count
            Fail = @($Checks | Where-Object { $_.Result -eq "FAIL" }).Count
        }
    }

    ($jsonObject | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    @($Checks) |
        Select-Object CheckName, Result, Summary, DurationMs |
        Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    $exports["TxtPath"] = $txtPath
    $exports["JsonPath"] = $jsonPath
    $exports["CsvPath"] = $csvPath

    return [PSCustomObject]$exports
}

function Invoke-SecurityEventLoggingCheck {
    $checkName = "SecurityEventLogging"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $details = New-Object System.Collections.Generic.List[string]
    $evidence = New-Object System.Collections.Generic.List[string]
    $data = [ordered]@{}

    try {
        Write-Section "SESSION CHECK: SecurityEventLogging"

        $typeColumn = Get-SessionSecurityEventColumnName -Candidates @("type", "event_type")
        $ipColumn = Get-SessionSecurityEventColumnName -Candidates @("ip")
        $deviceHashColumn = Get-SessionSecurityEventColumnName -Candidates @("device_hash")
        $createdAtColumn = Get-SessionSecurityEventColumnName -Candidates @("created_at")

        if ([string]::IsNullOrWhiteSpace($typeColumn) -or [string]::IsNullOrWhiteSpace($ipColumn) -or [string]::IsNullOrWhiteSpace($deviceHashColumn) -or [string]::IsNullOrWhiteSpace($createdAtColumn)) {
            Write-Host ("{0} -> WARN (SECURITY_EVENTS_REQUIRED_COLUMNS_MISSING)" -f $checkName)
            $details.Add("Required columns missing in security_events.") | Out-Null
            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary "security_events schema is missing required columns." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        $windowStart = (Get-Date).AddMinutes(-15).ToString("yyyy-MM-dd HH:mm:ss")
        $failedIp = "198.51.100.221"
        $successIp = "198.51.100.222"
        $lockoutIp = "198.51.100.223"
        $deviceIp = "198.51.100.224"
        $deviceCookieFailed = "ks-event-failed-001"
        $deviceCookieSuccess = "ks-event-success-001"
        $deviceCookieDevice = "ks-event-device-001"
        $failedDeviceHash = Get-Sha256Hex -Value $deviceCookieFailed
        $successDeviceHash = Get-Sha256Hex -Value $deviceCookieSuccess
        $deviceDetectionHash = Get-Sha256Hex -Value $deviceCookieDevice

        [void](Post-LoginAttempt -BaseUrl $script:BaseUrl -Session (New-Session) -Email ("" + $script:RegisteredEmail) -Password ("" + $script:WrongPassword) -ExtraHeaders (Get-DeviceHeaders) -DeviceCookieId $deviceCookieFailed -ForcedAttemptIp $failedIp)

        $loginSession = $null
        $originalDeviceCookieId = ""
        $originalAdminValidationTestIp = ""
        try { $originalDeviceCookieId = ("" + $script:AdminValidationDeviceCookieId).Trim() } catch { $originalDeviceCookieId = "" }
        try { $originalAdminValidationTestIp = ("" + $script:AdminValidationTestIp).Trim() } catch { $originalAdminValidationTestIp = "" }

        try {
            $script:AdminValidationDeviceCookieId = $deviceCookieSuccess
            $script:AdminValidationTestIp = $successIp
            try {
                if (Get-Command Set-AuditModuleRuntimeVariable -ErrorAction SilentlyContinue) {
                    Set-AuditModuleRuntimeVariable -Name 'AdminValidationDeviceCookieId' -Value $script:AdminValidationDeviceCookieId
                    Set-AuditModuleRuntimeVariable -Name 'AdminValidationTestIp' -Value $script:AdminValidationTestIp
                }
            } catch {
            }
            $loginSession = Get-AbuseAdminValidationLoginSession
        } finally {
            $script:AdminValidationDeviceCookieId = $originalDeviceCookieId
            $script:AdminValidationTestIp = $originalAdminValidationTestIp
            try {
                if (Get-Command Set-AuditModuleRuntimeVariable -ErrorAction SilentlyContinue) {
                    Set-AuditModuleRuntimeVariable -Name 'AdminValidationDeviceCookieId' -Value $script:AdminValidationDeviceCookieId
                    Set-AuditModuleRuntimeVariable -Name 'AdminValidationTestIp' -Value $script:AdminValidationTestIp
                }
            } catch {
            }
        }

        [void](Post-LoginAttempt -BaseUrl $script:BaseUrl -Session (New-Session) -Email ("" + $script:RegisteredEmail) -Password ("" + $script:WrongPassword) -ExtraHeaders (Get-DeviceHeaders) -DeviceCookieId $deviceCookieDevice -ForcedAttemptIp $deviceIp)
        $lockoutResult = Run-Scenario -ScenarioName "security_event_lockout" -Email ("" + $script:UnregisteredEmail) -WrongPassword ("" + $script:WrongPassword) -Attempts ([int]$script:LockoutAttempts) -DeviceCookieId $deviceCookieFailed -ForcedAttemptIp $lockoutIp -SkipSupportFlow $true

        $successLoginAvailable = ($null -ne $loginSession -and [bool]$loginSession.Success)
        $lockoutTriggered = $false
        try { $lockoutTriggered = [bool]$lockoutResult.LockoutDetected } catch { $lockoutTriggered = $false }

        $failedWhere = "{0} >= {1} AND {2} = 'login_failed' AND COALESCE({3},'') = {4} AND COALESCE({5},'') = {6} AND COALESCE({7},'') <> ''" -f $createdAtColumn, (Convert-SessionSecuritySqlValue -Value $windowStart), $typeColumn, $ipColumn, (Convert-SessionSecuritySqlValue -Value $failedIp), $deviceHashColumn, (Convert-SessionSecuritySqlValue -Value $failedDeviceHash), $createdAtColumn
        $successWhere = "{0} >= {1} AND {2} = 'login_success' AND COALESCE({3},'') = {4} AND COALESCE({5},'') = {6} AND COALESCE({7},'') <> ''" -f $createdAtColumn, (Convert-SessionSecuritySqlValue -Value $windowStart), $typeColumn, $ipColumn, (Convert-SessionSecuritySqlValue -Value $successIp), $deviceHashColumn, (Convert-SessionSecuritySqlValue -Value $successDeviceHash), $createdAtColumn
        $lockoutWhere = "{0} >= {1} AND {2} = 'login_lockout' AND COALESCE({3},'') = {4} AND COALESCE({5},'') <> '' AND COALESCE({6},'') <> ''" -f $createdAtColumn, (Convert-SessionSecuritySqlValue -Value $windowStart), $typeColumn, $ipColumn, (Convert-SessionSecuritySqlValue -Value $lockoutIp), $deviceHashColumn, $createdAtColumn
        $deviceWhere = "{0} >= {1} AND COALESCE({2},'') = {3} AND COALESCE({4},'') = {5} AND COALESCE({6},'') <> '' AND COALESCE({7},'') <> ''" -f $createdAtColumn, (Convert-SessionSecuritySqlValue -Value $windowStart), $deviceHashColumn, (Convert-SessionSecuritySqlValue -Value $deviceDetectionHash), $ipColumn, (Convert-SessionSecuritySqlValue -Value $deviceIp), $typeColumn, $createdAtColumn

        $failedCount = Get-SessionSecurityEventCount -WhereClause $failedWhere
        $successCount = $(if ($successLoginAvailable) { Get-SessionSecurityEventCount -WhereClause $successWhere } else { 0 })
        $lockoutCount = $(if ($lockoutTriggered) { Get-SessionSecurityEventCount -WhereClause $lockoutWhere } else { 0 })
        $deviceCount = Get-SessionSecurityEventCount -WhereClause $deviceWhere
        $recentEvents = @(Get-SessionSecurityRecentEvents)

        $details.Add("FailedLoginTriggered: True") | Out-Null
        $details.Add(("FailedLoginEvents: {0}" -f $failedCount)) | Out-Null
        $details.Add(("SuccessfulLoginTriggered: {0}" -f $successLoginAvailable)) | Out-Null
        $details.Add(("SuccessfulLoginEvents: {0}" -f $successCount)) | Out-Null
        $details.Add(("LockoutTriggered: {0}" -f $lockoutTriggered)) | Out-Null
        $details.Add(("LockoutEvents: {0}" -f $lockoutCount)) | Out-Null
        $details.Add("DeviceDetectionTriggered: True") | Out-Null
        $details.Add(("DeviceDetectionEvents: {0}" -f $deviceCount)) | Out-Null

        foreach ($row in @($recentEvents)) {
            $evidence.Add(("RecentEvent: {0} | {1} | {2} | {3}" -f $row.EventType, $row.Ip, $row.DeviceHash, $row.CreatedAt)) | Out-Null
        }

        $data["FailedLoginEvents"] = $failedCount
        $data["SuccessfulLoginEvents"] = $successCount
        $data["LockoutEvents"] = $lockoutCount
        $data["DeviceDetectionEvents"] = $deviceCount
        $data["RecentEvents"] = @($recentEvents)
        $data["WindowStart"] = $windowStart

        $missing = New-Object System.Collections.Generic.List[string]
        $triggerWarnings = New-Object System.Collections.Generic.List[string]
        if ($failedCount -le 0) { $missing.Add("failed_login") | Out-Null }
        if ($successLoginAvailable -and $successCount -le 0) { $missing.Add("successful_login") | Out-Null }
        if ($lockoutTriggered -and $lockoutCount -le 0) { $missing.Add("lockout_trigger") | Out-Null }
        if ($deviceCount -le 0) { $missing.Add("device_detection") | Out-Null }
        if (-not $successLoginAvailable) { $triggerWarnings.Add("successful_login_not_triggered") | Out-Null }
        if (-not $lockoutTriggered) { $triggerWarnings.Add("lockout_not_triggered") | Out-Null }

        if ($missing.Count -eq 0) {
            if ($triggerWarnings.Count -gt 0) {
                Write-Host ("{0} -> WARN" -f $checkName)
                $details.Add(("TriggerWarnings: {0}" -f (($triggerWarnings.ToArray()) -join ", "))) | Out-Null
                $sw.Stop()
                return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary ("Events found, but not all trigger actions completed: {0}" -f (($triggerWarnings.ToArray()) -join ", ")) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
            }

            Write-Host ("{0} -> PASS" -f $checkName)
            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "PASS" -Summary "Triggered security actions were persisted in security_events." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        Write-Host ("{0} -> FAIL" -f $checkName)
        $details.Add(("MissingEvents: {0}" -f (($missing.ToArray()) -join ", "))) | Out-Null
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "FAIL" -Summary ("Missing security events for: {0}" -f (($missing.ToArray()) -join ", ")) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host ("{0} -> WARN ({1})" -f $checkName, $errorMessage)
        $details.Add(("CheckError: {0}" -f $errorMessage)) | Out-Null
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary ("Check error: {0}" -f $errorMessage) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    }
}
