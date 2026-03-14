# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ui\ks-admin-audit-ui-status.ps1
# Purpose: Status and output helper functions for ks-admin-audit-ui
# Created: 14-03-2026 02:52 (Europe/Berlin)
# Changed: 14-03-2026 02:52 (Europe/Berlin)
# Version: 0.1
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

function Reset-AuditStatuses {
    foreach ($entry in $statusLabels.GetEnumerator()) {
        Set-StatusVisual -Label $entry.Value -Status "-"
    }
}

function Convert-ParsedStatus([string]$RawStatus) {
    $value = ""
    try { $value = ("" + $RawStatus).Trim().ToUpperInvariant() } catch { $value = "" }
    switch ($value) {
        "OK" { return "PASS" }
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
    if ($t -match '^http exposure probe$') { return "http_probe" }
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
            if ($currentKey -ne "" -and $statusLabels.ContainsKey($currentKey)) {
                Set-StatusVisual -Label $statusLabels[$currentKey] -Status (Convert-ParsedStatus $matches[1])
            }
        } elseif ($currentLines.Count -gt 0) {
            $currentLines.Add($line) | Out-Null
        }
    }
    if ($currentKey -ne "" -and $currentLines.Count -gt 0) {
        $script:AuditSectionsByKey[$currentKey] = (($currentLines.ToArray()) -join "`r`n")
    }
    if ($chkShowCheckDetails.Checked) { Set-StatusVisual -Label $statusLabels["show_check_details"] -Status "PASS" }
    if ($chkExportLogs.Checked -and $raw -match '(?m)^\s{2}Log:\s+exported -> ') { Set-StatusVisual -Label $statusLabels["export_logs"] -Status "PASS" }
}
