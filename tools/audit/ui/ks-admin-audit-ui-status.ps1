# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ui\ks-admin-audit-ui-status.ps1
# Purpose: Status and output helper functions for ks-admin-audit-ui
# Created: 14-03-2026 02:52 (Europe/Berlin)
# Changed: 14-03-2026 21:23 (Europe/Berlin)
# Version: 0.3
# =============================================================================

function New-AuditStatusLabel([string]$Key) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Tag = $Key
    $lbl.Width = 54
    $lbl.Height = 20
    $lbl.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    return $lbl
}

function Set-StatusVisual([System.Windows.Forms.Label]$Label, [string]$Status) {
    if ($null -eq $Label) { return }
    $value = "-"
    try { $value = ("" + $Status).Trim().ToUpperInvariant() } catch { $value = "-" }
    if ($value -eq "") { $value = "-" }

    try {
        $Label.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $Label.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    } catch { }

    switch ($value) {
        "PASS" {
            $Label.Text = "PASS"
            $Label.BackColor = [System.Drawing.Color]::FromArgb(209, 244, 214)
            $Label.ForeColor = [System.Drawing.Color]::FromArgb(32, 96, 40)
        }
        "FAIL" {
            $Label.Text = "FAIL"
            $Label.BackColor = [System.Drawing.Color]::FromArgb(249, 213, 213)
            $Label.ForeColor = [System.Drawing.Color]::FromArgb(150, 32, 32)
        }
        "WARN" {
            $Label.Text = "WARN"
            $Label.BackColor = [System.Drawing.Color]::FromArgb(252, 237, 179)
            $Label.ForeColor = [System.Drawing.Color]::FromArgb(128, 88, 0)
        }
        "SKIP" {
            $Label.Text = "SKIP"
            $Label.BackColor = [System.Drawing.Color]::FromArgb(231, 231, 231)
            $Label.ForeColor = [System.Drawing.Color]::FromArgb(96, 96, 96)
        }
        default {
            $Label.Text = "-"
            $Label.BackColor = [System.Drawing.Color]::FromArgb(243, 243, 243)
            $Label.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 110)
        }
    }
}

function Set-QuickActionRunStatus([string]$FinalStatus, [string]$ExitCodeText) {
    if ($null -eq $lblStatus) { return }

    $statusValue = "-"
    try { $statusValue = ("" + $FinalStatus).Trim().ToUpperInvariant() } catch { $statusValue = "-" }
    if ($statusValue -eq "") { $statusValue = "-" }

    $exitDisplay = ""
    try {
        $exitDisplay = ("" + $ExitCodeText).Trim()
    } catch {
        $exitDisplay = ""
    }

    $text = "Bereit"
    $backColor = [System.Drawing.Color]::Transparent
    $foreColor = [System.Drawing.Color]::FromArgb(70, 70, 70)

    switch ($statusValue) {
        "OK" {
            $text = $(if ($exitDisplay -ne "") { "FERTIG - OK (ExitCode $exitDisplay)" } else { "FERTIG - OK" })
            $backColor = [System.Drawing.Color]::FromArgb(209, 244, 214)
            $foreColor = [System.Drawing.Color]::FromArgb(32, 96, 40)
        }
        "PASS" {
            $text = $(if ($exitDisplay -ne "") { "FERTIG - OK (ExitCode $exitDisplay)" } else { "FERTIG - OK" })
            $backColor = [System.Drawing.Color]::FromArgb(209, 244, 214)
            $foreColor = [System.Drawing.Color]::FromArgb(32, 96, 40)
        }
        "WARN" {
            $text = $(if ($exitDisplay -ne "") { "WARNUNG (ExitCode $exitDisplay)" } else { "WARNUNG" })
            $backColor = [System.Drawing.Color]::FromArgb(252, 237, 179)
            $foreColor = [System.Drawing.Color]::FromArgb(128, 88, 0)
        }
        "FAIL" {
            $text = $(if ($exitDisplay -ne "") { "FEHLER (ExitCode $exitDisplay)" } else { "FEHLER" })
            $backColor = [System.Drawing.Color]::FromArgb(249, 213, 213)
            $foreColor = [System.Drawing.Color]::FromArgb(150, 32, 32)
        }
        "CRITICAL" {
            $text = $(if ($exitDisplay -ne "") { "KRITISCH (ExitCode $exitDisplay)" } else { "KRITISCH" })
            $backColor = [System.Drawing.Color]::FromArgb(233, 176, 176)
            $foreColor = [System.Drawing.Color]::FromArgb(120, 16, 16)
        }
        default {
            $text = $(if ($exitDisplay -ne "") { "Fertig (ExitCode $exitDisplay)" } else { "Bereit" })
            $backColor = [System.Drawing.Color]::Transparent
            $foreColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
        }
    }

    try {
        $lblStatus.AutoSize = $false
        $lblStatus.Height = 20
        $lblStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $lblStatus.Text = $text
        $lblStatus.BackColor = $backColor
        $lblStatus.ForeColor = $foreColor
    } catch { }
}

function Reset-AuditStatuses {
    foreach ($entry in $statusLabels.GetEnumerator()) {
        Set-StatusVisual -Label $entry.Value -Status "-"
    }
    Set-QuickActionRunStatus -FinalStatus "-" -ExitCodeText ""
}

function Set-UiAuditStatus([string]$Key, [string]$Status) {
    if ($null -eq $statusLabels) { return }
    $targetKey = ""
    try { $targetKey = ("" + $Key).Trim() } catch { $targetKey = "" }
    if ($targetKey -eq "") { return }
    if (-not $statusLabels.ContainsKey($targetKey)) { return }
    Set-StatusVisual -Label $statusLabels[$targetKey] -Status $Status
}

function Convert-ParsedStatus([string]$RawStatus) {
    $value = ""
    try { $value = ("" + $RawStatus).Trim().ToUpperInvariant() } catch { $value = "" }
    switch ($value) {
        "OK" { return "PASS" }
        "PASS" { return "PASS" }
        "FAIL" { return "FAIL" }
        "CRITICAL" { return "FAIL" }
        "WARN" { return "WARN" }
        "SKIP" { return "SKIP" }
        default { return "-" }
    }
}

function Get-UiCheckKeyFromTitle([string]$Title) {
    $t = ""
    try { $t = ("" + $Title).Trim().ToLowerInvariant() } catch { $t = "" }

    if ($t -match '^routes / collisions / admin scope$') { return "core_routes" }
    if ($t -match '^route:list option scan') { return "core_route_option_scan" }
    if ($t -match '^security / abuse protection$') { return "core_security_baseline" }

    if ($t -match '^http-probe$') { return "http_probe" }
    if ($t -match '^http probe$') { return "http_probe" }
    if ($t -match '^http exposure probe') { return "http_probe" }

    if ($t -match '^tail laravel\.log$') { return "tail_log" }
    if ($t -match '^routes verbose inspection$' -or $t -eq 'routesverbose') { return "routes_verbose" }
    if ($t -match '^route list filter \(admin-only\)$' -or $t -eq 'routelistfindstradmin') { return "route_list_findstr_admin" }
    if ($t -match '^governance: superadmin fail-safe') { return "superadmin_count" }
    if ($t -match '^laravel log snapshot$') { return "log_snapshot" }
    if ($t -match '^login csrf probe$') { return "login_csrf_probe" }
    if ($t -match '^role access smoke test') { return "role_smoke_test" }
    if ($t -match '^session/csrf baseline') { return "session_csrf_baseline" }

    return ""
}

function Get-SectionSubStatus([string]$SectionText, [string]$SubcheckName) {
    $rawText = ""
    try { $rawText = "" + $SectionText } catch { $rawText = "" }
    if ($rawText.Trim() -eq "") { return "-" }

    $escapedName = [System.Text.RegularExpressions.Regex]::Escape($SubcheckName)

    if ($rawText -match ('(?m)^\s*(?:-\s+)?\[(OK|WARN|FAIL|SKIP)\]\s+' + $escapedName + '\s+-')) {
        return (Convert-ParsedStatus $matches[1])
    }

    if ($rawText -match ('(?m)^\s*-\s+' + $escapedName + ':\s+Active probe disabled')) {
        return "SKIP"
    }

    return "-"
}

function Get-AuditRunOutcome([string]$RawText) {
    $result = [ordered]@{
        FinalStatus = ""
        ExitCode    = ""
    }

    $text = ""
    try { $text = "" + $RawText } catch { $text = "" }
    if ($text.Trim() -eq "") { return $result }

    if ($text -match '(?m)^FinalStatus:\s+([A-Z]+)\s*$') {
        $result.FinalStatus = ("" + $matches[1]).Trim().ToUpperInvariant()
    }

    if ($text -match '(?m)^ExitCode:\s+([0-9]+)\s*$') {
        $result.ExitCode = ("" + $matches[1]).Trim()
    }

    return $result
}

function Parse-AuditOutput {
    $script:AuditSectionsByKey = @{}
    Reset-AuditStatuses

    $raw = ""
    try { $raw = "" + $script:AuditOutputRaw } catch { $raw = "" }
    if ($raw.Trim() -eq "") { return }

    $lines = @($raw -split "`r`n")
    $currentKey = ""
    $currentLines = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match '^\[(OK|FAIL|WARN|SKIP|CRITICAL)\]\s+(?:Test\s+\d+|Null-Lauf)\s+-\s+(.+)$') {
            if ($currentKey -ne "" -and $currentLines.Count -gt 0) {
                $script:AuditSectionsByKey[$currentKey] = (($currentLines.ToArray()) -join "`r`n")
            }

            $currentLines = New-Object System.Collections.Generic.List[string]
            $currentLines.Add($line) | Out-Null
            $currentKey = Get-UiCheckKeyFromTitle $matches[2]

            if ($currentKey -ne "") {
                $parsedStatus = Convert-ParsedStatus $matches[1]
                Set-UiAuditStatus -Key $currentKey -Status $parsedStatus

                if ($currentKey -eq "core_security_baseline") {
                    Set-UiAuditStatus -Key "security_probe" -Status $parsedStatus
                }
            }
        } elseif ($currentLines.Count -gt 0) {
            $currentLines.Add($line) | Out-Null
        }
    }

    if ($currentKey -ne "" -and $currentLines.Count -gt 0) {
        $script:AuditSectionsByKey[$currentKey] = (($currentLines.ToArray()) -join "`r`n")
    }

    if ($script:AuditSectionsByKey.ContainsKey("core_security_baseline")) {
        $securitySection = "" + $script:AuditSectionsByKey["core_security_baseline"]

        $securityLoginRateStatus = Get-SectionSubStatus -SectionText $securitySection -SubcheckName "Security Login Rate Limit"
        $securityIpBanStatus = Get-SectionSubStatus -SectionText $securitySection -SubcheckName "Security IP Ban"
        $securityRegisterStatus = Get-SectionSubStatus -SectionText $securitySection -SubcheckName "Security Registration Abuse"

        if ($securityLoginRateStatus -ne "-") {
            Set-UiAuditStatus -Key "security_probe" -Status $securityLoginRateStatus
        }

        if ($securityIpBanStatus -ne "-") {
            Set-UiAuditStatus -Key "security_check_ip_ban" -Status $securityIpBanStatus
        }

        if ($securityRegisterStatus -ne "-") {
            Set-UiAuditStatus -Key "security_check_register" -Status $securityRegisterStatus
        }
    }

    if ($chkShowCheckDetails.Checked) {
        Set-StatusVisual -Label $statusLabels["show_check_details"] -Status "PASS"
    }

    if ($chkExportLogs.Checked -and $raw -match '(?m)^\s{2}Log:\s+exported -> ') {
        Set-StatusVisual -Label $statusLabels["export_logs"] -Status "PASS"
    }

    if ($chkAutoOpenExportFolder.Checked -and $chkExportLogs.Checked) {
        Set-StatusVisual -Label $statusLabels["auto_open_export_folder"] -Status "PASS"
    }

    if ($chkLogClearBefore.Checked) {
        Set-StatusVisual -Label $statusLabels["log_clear_before"] -Status "PASS"
    }

    if ($chkLogClearAfter.Checked) {
        Set-StatusVisual -Label $statusLabels["log_clear_after"] -Status "PASS"
    }

    $outcome = Get-AuditRunOutcome -RawText $raw
    Set-QuickActionRunStatus -FinalStatus $outcome.FinalStatus -ExitCodeText $outcome.ExitCode
}