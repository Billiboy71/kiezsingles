# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ui\ks-admin-audit-ui-runner.ps1
# Purpose: Runner/core bridge helpers for ks-admin-audit-ui
# Created: 14-03-2026 03:09 (Europe/Berlin)
# Changed: 21-03-2026 15:16 (Europe/Berlin)
# Version: 0.7
# =============================================================================

function ConvertTo-NormalizedText([string]$s) {
    if ($null -eq $s) { return "" }
    $t = "" + $s

    try { $t = [System.Text.RegularExpressions.Regex]::Replace($t, "\x1B\[[0-9;?]*[ -/]*[@-~]", "") } catch { }
    try { $t = [System.Text.RegularExpressions.Regex]::Replace($t, "(?<!\r)\n", "`r`n") } catch { }
    try { $t = [System.Text.RegularExpressions.Regex]::Replace($t, "\r(?!\n)", "`r`n") } catch { }

    return $t
}

function Invoke-ProcessToFiles(
    [string]$File,
    [string[]]$ArgumentList,
    [int]$TimeoutSeconds = 120,
    [string]$WorkingDirectory = ""
) {
    $stdout = ""
    $stderr = ""

    try {
        if ($null -eq $ArgumentList) { $ArgumentList = @() }
        $ArgumentList = @($ArgumentList | Where-Object { $_ -ne $null })

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = ("" + $File)

        $quotedArgs = New-Object System.Collections.Generic.List[string]
        foreach ($a in $ArgumentList) {
            $t = "" + $a
            if ($t -eq "") {
                $quotedArgs.Add('""') | Out-Null
                continue
            }

            if ($t -match '[\s"]') {
                $q = $t -replace '(\\*)"', '$1$1\"'
                $q = $q -replace '(\\+)$', '$1$1'
                $quotedArgs.Add('"' + $q + '"') | Out-Null
                continue
            }

            $quotedArgs.Add($t) | Out-Null
        }

        $psi.Arguments = ($quotedArgs -join " ")
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true

        if ($WorkingDirectory -and ($WorkingDirectory.Trim() -ne "")) {
            $psi.WorkingDirectory = $WorkingDirectory
        }

        try { $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
        try { $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8 } catch { }

        $p = [System.Diagnostics.Process]::new()
        $p.StartInfo = $psi
        $null = $p.Start()

        try {
            $p.StandardInput.Write("")
            $p.StandardInput.Close()
        } catch { }

        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()

        $exited = $p.WaitForExit($TimeoutSeconds * 1000)

        if (-not $exited) {
            try { $p.Kill($true) } catch { }

            try { $stdout = $outTask.GetAwaiter().GetResult() } catch { $stdout = "" }
            try { $stderr = $errTask.GetAwaiter().GetResult() } catch { $stderr = "" }

            $argString = ($ArgumentList -join " ")
            return [pscustomobject]@{
                ExitCode = -1
                StdOut   = $stdout
                StdErr   = ("TIMEOUT after {0}s while running: {1} {2}" -f $TimeoutSeconds, $File, $argString) + "`n" + $stderr
            }
        }

        try { $p.WaitForExit() } catch { }
        try { $stdout = $outTask.GetAwaiter().GetResult() } catch { $stdout = "" }
        try { $stderr = $errTask.GetAwaiter().GetResult() } catch { $stderr = "" }

        $exitCode = 0
        try { $exitCode = [int]$p.ExitCode } catch { $exitCode = 0 }

        return [pscustomobject]@{
            ExitCode = [int]$exitCode
            StdOut   = $stdout
            StdErr   = $stderr
        }
    } catch {
        $msg = ""
        try { $msg = $_.Exception.Message } catch { $msg = "unknown_error" }

        return [pscustomobject]@{
            ExitCode = 2
            StdOut   = ""
            StdErr   = ("PROCESS RUNNER ERROR: " + $msg)
        }
    }
}

function Start-UiProcessAsync(
    [string]$File,
    [string[]]$ArgumentList,
    [string]$WorkingDirectory = ""
) {
    if ($null -eq $ArgumentList) { $ArgumentList = @() }
    $ArgumentList = @($ArgumentList | Where-Object { $_ -ne $null })

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = ("" + $File)

    $quotedArgs = New-Object System.Collections.Generic.List[string]
    foreach ($a in $ArgumentList) {
        $t = "" + $a
        if ($t -eq "") {
            $quotedArgs.Add('""') | Out-Null
            continue
        }

        if ($t -match '[\s"]') {
            $q = $t -replace '(\\*)"', '$1$1\"'
            $q = $q -replace '(\\+)$', '$1$1'
            $quotedArgs.Add('"' + $q + '"') | Out-Null
            continue
        }

        $quotedArgs.Add($t) | Out-Null
    }

    $psi.Arguments = ($quotedArgs -join " ")
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    if ($WorkingDirectory -and ($WorkingDirectory.Trim() -ne "")) {
        $psi.WorkingDirectory = $WorkingDirectory
    }

    try { $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
    try { $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8 } catch { }

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $null = $proc.Start()

    try {
        $proc.StandardInput.Write("")
        $proc.StandardInput.Close()
    } catch { }

    return [pscustomobject]@{
        Process = $proc
        OutTask = $proc.StandardOutput.ReadToEndAsync()
        ErrTask = $proc.StandardError.ReadToEndAsync()
    }
}

function Get-UiAuditRunContext {
    try {
        $var = Get-Variable -Scope Script -Name UiAuditRunContext -ErrorAction SilentlyContinue
        if ($null -eq $var) { return $null }
        return $var.Value
    } catch {
        return $null
    }
}

function Write-StdStreams($procResult) {
    if ($null -eq $procResult) { return }

    if ($procResult.StdErr -and ($procResult.StdErr.Trim() -ne "")) {
        Write-Host ""
        Write-Host "--- STDERR ---"
        $normErr = ConvertTo-NormalizedText $procResult.StdErr
        $lines = $normErr -split "`r`n"
        foreach ($line in $lines) {
            Write-Host $line
        }
    }

    if ($procResult.StdOut -and ($procResult.StdOut.Trim() -ne "")) {
        Write-Host ""
        Write-Host "--- STDOUT ---"
        $normOut = ConvertTo-NormalizedText $procResult.StdOut
        $lines = $normOut -split "`r`n"
        foreach ($line in $lines) {
            Write-Host $line
        }
    }
}

function Start-LaravelTailWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [ValidateSet("live","history")][string]$Mode = "live"
    )

    $logPath = Join-Path $ProjectRoot "storage\logs\laravel.log"

    $m = "live"
    try { $m = ("" + $Mode).Trim().ToLower() } catch { $m = "live" }

    $cmd = @()
    $cmd += "try { chcp 65001 | Out-Null } catch { }"
    $cmd += "try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(`$false) } catch { }"
    $cmd += "try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new(`$false) } catch { }"
    $cmd += "if (-not (Test-Path -LiteralPath " + (ConvertTo-QuotedArg $logPath) + ")) { return }"

    if ($m -eq "history") {
        $cmd += "Get-Content -LiteralPath " + (ConvertTo-QuotedArg $logPath) + " -Encoding UTF8 -Tail 200"
    } else {
        $cmd += "Get-Content -LiteralPath " + (ConvertTo-QuotedArg $logPath) + " -Encoding UTF8 -Tail 0 -Wait"
    }

    $tailArgs = New-Object System.Collections.Generic.List[string]
    $tailArgs.Add("-NoExit") | Out-Null
    $tailArgs.Add("-NoProfile") | Out-Null
    $tailArgs.Add("-ExecutionPolicy") | Out-Null
    $tailArgs.Add("Bypass") | Out-Null
    $tailArgs.Add("-Command") | Out-Null
    $tailArgs.Add(($cmd -join "; ")) | Out-Null

    Start-Process -FilePath "powershell.exe" -WorkingDirectory $ProjectRoot -ArgumentList @($tailArgs) | Out-Null
}

function Sync-HttpFieldsEnabled() {
    $httpOn = [bool]$chkHttpProbe.Checked

    $txtProbePaths.Enabled = $true
    $lblProbePaths.Enabled = $true
}

function Sync-TailFieldsEnabled() {
    $tailOn = [bool]$chkTailLog.Checked
    $cmbTailMode.Enabled = $tailOn
    $lblTailMode.Enabled = $tailOn
    if (-not $tailOn) { }
}

function Sync-RoleSmokeFieldsEnabled() {
    $roleOn = [bool]$chkRoleSmokeTest.Checked
    $loginProbeOn = [bool]$chkLoginCsrfProbe.Checked
    $superadminEnabled = ($roleOn -or $loginProbeOn)

    $lblRoleCreds.Enabled = ($roleOn -or $loginProbeOn)
    $lblSuperadminEmail.Enabled = $superadminEnabled
    $txtSuperadminEmail.Enabled = $superadminEnabled
    $txtSuperadminPassword.Enabled = $superadminEnabled
    $btnSaveSuperadmin.Enabled = $superadminEnabled
    $btnClearSuperadmin.Enabled = $superadminEnabled
    $lblAdminEmail.Enabled = $roleOn
    $txtAdminEmail.Enabled = $roleOn
    $txtAdminPassword.Enabled = $roleOn
    $btnSaveAdmin.Enabled = $roleOn
    $btnClearAdmin.Enabled = $roleOn
    $lblModeratorEmail.Enabled = $roleOn
    $txtModeratorEmail.Enabled = $roleOn
    $txtModeratorPassword.Enabled = $roleOn
    $btnSaveModerator.Enabled = $roleOn
    $btnClearModerator.Enabled = $roleOn
}

function Build-UiRunPlanNotice() {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Run Plan") | Out-Null
    $lines.Add("--------") | Out-Null

    $lines.Add("Null-Lauf:") | Out-Null
    $lines.Add("- Cache Clear") | Out-Null
    $lines.Add("") | Out-Null

    $selectedItems = New-Object System.Collections.Generic.List[string]
    if ($chkHttpProbe.Checked) { $selectedItems.Add("HTTP-Probe") | Out-Null }
    if ($chkLoginCsrfProbe.Checked) { $selectedItems.Add("Login CSRF Probe") | Out-Null }
    if ($chkRoleSmokeTest.Checked) { $selectedItems.Add("Role Smoke Test") | Out-Null }
    if ($chkSuperadminCount.Checked) { $selectedItems.Add("Governance: Superadmin Fail-Safe") | Out-Null }
    if ($chkSessionCsrfBaseline.Checked) { $selectedItems.Add("Session/CSRF Baseline") | Out-Null }
    if ($chkSecurityProbe.Checked) { $selectedItems.Add("Security Probe") | Out-Null }
    if ($chkSecurityCheckIpBan.Checked) { $selectedItems.Add("Security: IP Ban Probe") | Out-Null }
    if ($chkSecurityCheckRegister.Checked) { $selectedItems.Add("Security: Register Probe") | Out-Null }
    if ($chkRoutesVerbose.Checked) { $selectedItems.Add("Routes Verbose Inspection") | Out-Null }
    if ($chkRouteListFindstrAdmin.Checked) { $selectedItems.Add("Route List Filter (admin-only)") | Out-Null }

    $snapshotSelection = "OFF"
    try { $snapshotSelection = ("" + $cmbLaravelLogHistory.Text).Trim().ToUpper() } catch { $snapshotSelection = "OFF" }
    if ($snapshotSelection -ne "OFF") { $selectedItems.Add("Laravel Log Snapshot") | Out-Null }
    if ($chkTailLog.Checked) { $selectedItems.Add("Tail Laravel Log (GUI)") | Out-Null }

    $lines.Add("Ausgewaehlt:") | Out-Null
    if ($selectedItems.Count -gt 0) {
        $i = 0
        foreach ($item in @($selectedItems.ToArray())) {
            $i++
            $lines.Add(("Test {0} - {1}" -f $i, $item)) | Out-Null
        }
    } else {
        $lines.Add("(keine)") | Out-Null
    }

    return (($lines.ToArray()) -join "`r`n")
}

function Complete-UiAuditRun([bool]$TimedOut = $false) {
    $ctx = $null
    try { $ctx = Get-UiAuditRunContext } catch { $ctx = $null }
    if ($null -eq $ctx) { return }

    try {
        $proc = $ctx.Process
        $outTask = $ctx.OutTask
        $errTask = $ctx.ErrTask
        $preRunNotice = "" + $ctx.PreRunNotice
        $childCmdLine = "" + $ctx.ChildCmdLine
        $timedOutSeconds = 0
        try { $timedOutSeconds = [int]$ctx.TimeoutSeconds } catch { $timedOutSeconds = 0 }

        $out = ""
        $err = ""
        try { $out = "" + $outTask.GetAwaiter().GetResult() } catch { $out = "" }
        try { $err = "" + $errTask.GetAwaiter().GetResult() } catch { $err = "" }

        if ($TimedOut) {
            $timeoutText = "TIMEOUT"
            if ($timedOutSeconds -gt 0) {
                $timeoutText = ("TIMEOUT after {0}s" -f $timedOutSeconds)
            }
            if (($err.Trim()) -ne "") {
                $err = $timeoutText + "`r`n" + $err
            } else {
                $err = $timeoutText
            }
        }

        $out = ConvertTo-NormalizedText $out
        $err = ConvertTo-NormalizedText $err

        $combined = ""
        if ($err -and ($err.Trim() -ne "")) { $combined += $err.TrimEnd() + "`r`n" }
        if ($out -and ($out.Trim() -ne "")) { $combined += $out.TrimEnd() + "`r`n" }

        if ($combined.Trim() -eq "") {
            $combined = "(keine Ausgabe)`r`n"
            $combined += "Hinweis: Der Prozess hat nichts auf STDOUT/STDERR geschrieben.`r`n"
        }

        if ($preRunNotice -and ($preRunNotice.Trim() -ne "")) {
            $combined = $preRunNotice + "`r`n`r`n" + $combined
        }

        if ($childCmdLine -and ($childCmdLine.Trim() -ne "")) {
            $combined += "`r`n=== Core-Command (subprocess, hidden) ===`r`n" + $childCmdLine.TrimEnd() + "`r`n"
        }

        if ($chkTailLog.Checked) {
            $modeLabel = "live"
            try { if ($cmbTailMode.SelectedIndex -eq 1) { $modeLabel = "history" } else { $modeLabel = "live" } } catch { $modeLabel = "live" }

            $combined += "`r`n`r`n=== Hinweis TailLog (GUI) ===`r`n"
            $combined += "TailLog wird von der GUI geoeffnet (separates PowerShell-Fenster).`r`n"
            $combined += ("Modus: " + $modeLabel + "`r`n")

            if ($modeLabel -eq "history") {
                $combined += "history = letzte 200 Zeilen (kein Follow).`r`n"
            } else {
                $combined += "live = nur neue Zeilen (Follow).`r`n"
            }

            $combined += "Das ist NICHT dasselbe wie 'Laravel log (Snapshot)' (Core -LogSnapshot).`r`n"
        }

        $combined = ConvertTo-NormalizedText $combined

        $script:AuditOutputRaw = $combined
        $script:AuditOutputViewRaw = $combined
        Parse-AuditOutput
        Update-UiStatusesFromAuditOutput -OutputText $combined
        Set-OutputFilterView

        $btnCopy.Enabled = $true
        try { Sync-OutputPopupButtons } catch { }

        $ec = 0
        try { $ec = [int]$proc.ExitCode } catch { $ec = 0 }
        if ($TimedOut) {
            $lblStatus.Text = "Fehler"
        } elseif ($ec -eq 0) {
            $lblStatus.Text = "Fertig"
        } else {
            $lblStatus.Text = ("Fertig (ExitCode " + $ec + ")")
        }
    } catch {
        $argDump = ""
        try {
            if ($ctx.ChildCmdLine -and (("" + $ctx.ChildCmdLine).Trim() -ne "")) {
                $argDump = "`r`n`r`nCore-Command:`r`n" + $ctx.ChildCmdLine
            }
        } catch { }

        $combinedErr = ConvertTo-NormalizedText ("GUI-Fehler:`r`n" + ($_ | Out-String).TrimEnd() + $argDump)
        $script:AuditOutputRaw = $combinedErr
        $script:AuditOutputViewRaw = $combinedErr
        Parse-AuditOutput
        Update-UiStatusesFromAuditOutput -OutputText $combinedErr
        Set-OutputFilterView

        $lblStatus.Text = "Fehler"
        try { Sync-OutputPopupButtons } catch { }
    } finally {
        try {
            if ($null -ne $ctx.Timer) {
                $ctx.Timer.Stop()
                $ctx.Timer.Dispose()
            }
        } catch { }
        $script:UiAuditRunContext = $null
        $btnRun.Enabled = $true
    }
}

function Get-UiArgs() {
    $argsList = New-Object System.Collections.Generic.List[string]

    $effectiveBaseUrl = ""
    try { $effectiveBaseUrl = ("" + $cmbBaseUrl.Text).Trim() } catch { $effectiveBaseUrl = "" }
    if ($effectiveBaseUrl -eq "") { $effectiveBaseUrl = ("" + $BaseUrl).Trim() }
    if ($effectiveBaseUrl -eq "") { $effectiveBaseUrl = "http://127.0.0.1:8000" }

    if ($effectiveBaseUrl -notmatch '^(?i)https?://') {
        $effectiveBaseUrl = "http://" + $effectiveBaseUrl
    }

    $u = $null
    $ok = $false
    try { $ok = [System.Uri]::TryCreate($effectiveBaseUrl, [System.UriKind]::Absolute, [ref]$u) } catch { $ok = $false }
    if (-not $ok) { throw ("Base URL is not a valid absolute URL: " + $effectiveBaseUrl) }

    $argsList.Add("-BaseUrl") | Out-Null
    $argsList.Add($effectiveBaseUrl) | Out-Null

    if ($uiPathsConfigFile -and ("" + $uiPathsConfigFile).Trim() -ne "") {
        $argsList.Add("-PathsConfigFile") | Out-Null
        $argsList.Add($uiPathsConfigFile) | Out-Null
    }

    $ppLines = @()
    try { $ppLines = ("" + $txtProbePaths.Text) -split "`r?`n" } catch { $ppLines = @() }
    $ppLines = @($ppLines | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })

    if ($ppLines.Count -gt 0) {
        $argsList.Add("-ProbePaths") | Out-Null
        $argsList.Add((($ppLines | ForEach-Object { "" + $_ }) -join " ")) | Out-Null
    }

    if ($chkHttpProbe.Checked) { $argsList.Add("-HttpProbe") | Out-Null }
    if ($chkRoutesVerbose.Checked) { $argsList.Add("-RoutesVerbose") | Out-Null }
    if ($chkRouteListFindstrAdmin.Checked) { $argsList.Add("-RouteListFindstrAdmin") | Out-Null }
    if ($chkSuperadminCount.Checked) { $argsList.Add("-SuperadminCount") | Out-Null }
    $snapshotSelection = "OFF"
    try { $snapshotSelection = ("" + $cmbLaravelLogHistory.Text).Trim().ToUpper() } catch { $snapshotSelection = "OFF" }
    if ($snapshotSelection -ne "OFF") {
        $snapshotLines = 200
        if ($snapshotSelection -eq "500") { $snapshotLines = 500 }
        elseif ($snapshotSelection -eq "1000") { $snapshotLines = 1000 }

        $argsList.Add("-LogSnapshot") | Out-Null
        $argsList.Add("-LogSnapshotLines") | Out-Null
        $argsList.Add(("" + $snapshotLines)) | Out-Null
    }

    if ($chkLogClearBefore.Checked) { $argsList.Add("-LogClearBefore") | Out-Null }
    if ($chkLogClearAfter.Checked) { $argsList.Add("-LogClearAfter") | Out-Null }
    $argsList.Add("-ShowCheckDetails") | Out-Null
    $argsList.Add($(if ($chkShowCheckDetails.Checked) { "true" } else { "false" })) | Out-Null
    $argsList.Add("-ExportLogs") | Out-Null
    $argsList.Add($(if ($chkExportLogs.Checked) { "true" } else { "false" })) | Out-Null
    $exportLines = "200"
    try { $exportLines = ("" + $cmbExportLogsLines.Text).Trim() } catch { $exportLines = "200" }
    if ($exportLines -eq "") { $exportLines = "200" }
    $argsList.Add("-ExportLogsLines") | Out-Null
    $argsList.Add($exportLines) | Out-Null
    $argsList.Add("-AutoOpenExportFolder") | Out-Null
    $argsList.Add($(if ($chkAutoOpenExportFolder.Checked) { "true" } else { "false" })) | Out-Null
    if ($chkLoginCsrfProbe.Checked) { $argsList.Add("-LoginCsrfProbe") | Out-Null }
    if ($chkRoleSmokeTest.Checked) { $argsList.Add("-RoleSmokeTest") | Out-Null }
    if ($chkSessionCsrfBaseline.Checked) { $argsList.Add("-SessionCsrfBaseline") | Out-Null }
    if ($chkSecurityProbe.Checked) { $argsList.Add("-SecurityProbe") | Out-Null }
    if ($chkSecurityCheckIpBan.Checked) { $argsList.Add("-SecurityCheckIpBan") | Out-Null }
    if ($chkSecurityCheckRegister.Checked) { $argsList.Add("-SecurityCheckRegister") | Out-Null }
    $securityLoginAttempts = "8"
    try { $securityLoginAttempts = ("" + $cmbSecurityLoginAttempts.Text).Trim() } catch { $securityLoginAttempts = "8" }
    if ($securityLoginAttempts -eq "") { $securityLoginAttempts = "8" }
    $argsList.Add("-SecurityLoginAttempts") | Out-Null
    $argsList.Add($securityLoginAttempts) | Out-Null

    if ($chkRoleSmokeTest.Checked) {
        $rsLines = @()
        try { $rsLines = ("" + $txtProbePaths.Text) -split "`r?`n" } catch { $rsLines = @() }
        $rsLines = @($rsLines | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })

        if ($rsLines.Count -gt 0) {
            $argsList.Add("-RoleSmokePaths") | Out-Null
            $argsList.Add(($rsLines -join " ")) | Out-Null
        }

        $saEmail = ("" + $txtSuperadminEmail.Text).Trim()
        $saPass = ("" + $txtSuperadminPassword.Text)
        $adEmail = ("" + $txtAdminEmail.Text).Trim()
        $adPass = ("" + $txtAdminPassword.Text)
        $moEmail = ("" + $txtModeratorEmail.Text).Trim()
        $moPass = ("" + $txtModeratorPassword.Text)

        if ($saEmail -ne "") { $argsList.Add("-SuperadminEmail") | Out-Null; $argsList.Add($saEmail) | Out-Null }
        if ($saPass -ne "") { $argsList.Add("-SuperadminPassword") | Out-Null; $argsList.Add($saPass) | Out-Null }
        if ($adEmail -ne "") { $argsList.Add("-AdminEmail") | Out-Null; $argsList.Add($adEmail) | Out-Null }
        if ($adPass -ne "") { $argsList.Add("-AdminPassword") | Out-Null; $argsList.Add($adPass) | Out-Null }
        if ($moEmail -ne "") { $argsList.Add("-ModeratorEmail") | Out-Null; $argsList.Add($moEmail) | Out-Null }
        if ($moPass -ne "") { $argsList.Add("-ModeratorPassword") | Out-Null; $argsList.Add($moPass) | Out-Null }
    } elseif ($chkLoginCsrfProbe.Checked) {
        $saEmail = ("" + $txtSuperadminEmail.Text).Trim()
        $saPass = ("" + $txtSuperadminPassword.Text)
        if ($saEmail -ne "") { $argsList.Add("-SuperadminEmail") | Out-Null; $argsList.Add($saEmail) | Out-Null }
        if ($saPass -ne "") { $argsList.Add("-SuperadminPassword") | Out-Null; $argsList.Add($saPass) | Out-Null }
    }

    return @($argsList.ToArray())
}

function Convert-AuditStatusToken([string]$Token) {
    $value = ""
    try { $value = ("" + $Token).Trim().ToUpperInvariant() } catch { $value = "" }

    switch ($value) {
        "OK" { return "PASS" }
        "PASS" { return "PASS" }
        "WARN" { return "WARN" }
        "FAIL" { return "FAIL" }
        "CRITICAL" { return "FAIL" }
        "SKIP" { return "SKIP" }
        default { return "-" }
    }
}

function Set-UiStatusLabelValue([string]$Key, [string]$Value) {
    try {
        if ($null -eq $statusLabels) { return }
        if (-not $statusLabels.ContainsKey($Key)) { return }
        $statusLabels[$Key].Text = (Convert-AuditStatusToken $Value)
    } catch { }
}

function Get-AuditStatusFromPatterns([string]$Text, [string[]]$Patterns) {
    $source = ""
    try { $source = "" + $Text } catch { $source = "" }
    if ($source -eq "") { return "" }

    foreach ($pattern in @($Patterns)) {
        if ($pattern -eq "") { continue }

        $m = $null
        try { $m = [System.Text.RegularExpressions.Regex]::Match($source, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline) } catch { $m = $null }
        if ($null -eq $m) { continue }
        if (-not $m.Success) { continue }

        try {
            $statusValue = ("" + $m.Groups["status"].Value).Trim()
            if ($statusValue -ne "") { return $statusValue }
        } catch { }
    }

    return ""
}

function Update-UiStatusesFromAuditOutput([string]$OutputText) {
    $source = ""
    try { $source = ConvertTo-NormalizedText $OutputText } catch { $source = "" }

    if ($source -eq "") {
        foreach ($key in @(
            'core_routes',
            'core_route_option_scan',
            'core_security_baseline',
            'http_probe',
            'tail_log',
            'routes_verbose',
            'route_list_findstr_admin',
            'superadmin_count',
            'log_snapshot',
            'login_csrf_probe',
            'role_smoke_test',
            'session_csrf_baseline',
            'security_probe',
            'security_check_ip_ban',
            'security_check_register'
        )) {
            Set-UiStatusLabelValue -Key $key -Value "SKIP"
        }
        return
    }

    $patternMap = @{
        core_routes = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Test\s+\d+\s+-\s+Routes\s*/\s*collisions\s*/\s*admin\s*scope\b'
        )
        core_route_option_scan = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Test\s+\d+\s+-\s+route:list option scan\b'
        )
        core_security_baseline = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Test\s+\d+\s+-\s+Security\s*/\s*Abuse\s*Protection\b'
        )
        http_probe = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Test\s+\d+\s+-\s+HTTP-Probe\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*HTTP exposure probe\b'
        )
        tail_log = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Tail Laravel Log\b'
        )
        routes_verbose = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Test\s+\d+\s+-\s+Routes Verbose Inspection\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Routes verbose inspection\b'
        )
        route_list_findstr_admin = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Test\s+\d+\s+-\s+Route List Filter \(admin-only\)\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Route list filter\b'
        )
        superadmin_count = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Superadmin count\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Governance: Superadmin Fail-Safe\b'
        )
        log_snapshot = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Laravel Log Snapshot\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Log snapshot\b'
        )
        login_csrf_probe = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Test\s+\d+\s+-\s+Login CSRF Probe\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Login CSRF\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Login/CSRF probe\b'
        )
        role_smoke_test = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Test\s+\d+\s+-\s+Role Smoke Test\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Role access smoke test\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Role smoke test\b'
        )
        session_csrf_baseline = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Test\s+\d+\s+-\s+Session/CSRF Baseline\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Session/CSRF baseline\b'
        )
        security_probe = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Security Login Rate Limit\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Security IP Ban\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Security Registration Abuse\b'
        )
        security_check_ip_ban = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Security IP Ban\b'
        )
        security_check_register = @(
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\]\s+Security Registration Abuse\b',
            '^\[(?<status>OK|PASS|WARN|FAIL|CRITICAL|SKIP)\].*Register Probe\b'
        )
    }

    foreach ($entry in $patternMap.GetEnumerator()) {
        $key = "" + $entry.Key
        $statusValue = Get-AuditStatusFromPatterns -Text $source -Patterns @($entry.Value)
        if ($statusValue -ne "") {
            Set-UiStatusLabelValue -Key $key -Value $statusValue
        }
    }

    $controlFallbacks = @(
        @{ Key = 'core_routes'; Enabled = $true },
        @{ Key = 'core_route_option_scan'; Enabled = $true },
        @{ Key = 'core_security_baseline'; Enabled = $true },
        @{ Key = 'http_probe'; Enabled = [bool]$chkHttpProbe.Checked },
        @{ Key = 'tail_log'; Enabled = [bool]$chkTailLog.Checked },
        @{ Key = 'routes_verbose'; Enabled = [bool]$chkRoutesVerbose.Checked },
        @{ Key = 'route_list_findstr_admin'; Enabled = [bool]$chkRouteListFindstrAdmin.Checked },
        @{ Key = 'superadmin_count'; Enabled = [bool]$chkSuperadminCount.Checked },
        @{ Key = 'log_snapshot'; Enabled = (((("" + $cmbLaravelLogHistory.Text).Trim().ToUpper()) -ne "OFF")) },
        @{ Key = 'login_csrf_probe'; Enabled = [bool]$chkLoginCsrfProbe.Checked },
        @{ Key = 'role_smoke_test'; Enabled = [bool]$chkRoleSmokeTest.Checked },
        @{ Key = 'session_csrf_baseline'; Enabled = [bool]$chkSessionCsrfBaseline.Checked },
        @{ Key = 'security_probe'; Enabled = [bool]$chkSecurityProbe.Checked },
        @{ Key = 'security_check_ip_ban'; Enabled = [bool]$chkSecurityCheckIpBan.Checked },
        @{ Key = 'security_check_register'; Enabled = [bool]$chkSecurityCheckRegister.Checked }
    )

    foreach ($item in @($controlFallbacks)) {
        $key = "" + $item.Key
        $enabled = [bool]$item.Enabled

        if ($null -eq $statusLabels) { continue }
        if (-not $statusLabels.ContainsKey($key)) { continue }

        $current = ""
        try { $current = ("" + $statusLabels[$key].Text).Trim().ToUpperInvariant() } catch { $current = "" }

        if ($current -eq "" -or $current -eq "-") {
            if ($enabled) {
                Set-UiStatusLabelValue -Key $key -Value "SKIP"
            } else {
                Set-UiStatusLabelValue -Key $key -Value "SKIP"
            }
        }
    }
}

function Invoke-UiAuditRun {
    if ($null -ne (Get-UiAuditRunContext)) { return }

    $btnRun.Enabled = $false
    $btnCopy.Enabled = $false
    $txt.Clear()
    $lblFilterStatus.Text = ""
    $script:AuditOutputRaw = ""
    $script:AuditOutputViewRaw = ""
    $script:AuditSectionsByKey = @{}
    $script:AuditSelectedKey = ""
    Reset-AuditStatuses
    $lblDetailTitle.Text = "Detailansicht: Gesamtausgabe"
    $lblStatus.Text = "Laeuft..."
    try { Sync-OutputPopupButtons } catch { }
    $preRunNotice = ""

    $argsList = $null
    $childCmdLine = ""

    try {
        if ($chkTailLog.Checked) {
            $mode = "live"
            try { if ($cmbTailMode.SelectedIndex -eq 1) { $mode = "history" } else { $mode = "live" } } catch { $mode = "live" }
            try { Start-LaravelTailWindow -ProjectRoot $uiProjectRoot -Mode $mode } catch { }
        }

        $argsList = @(Get-UiArgs)

        $snapshotSelectionNow = "OFF"
        try { $snapshotSelectionNow = ("" + $cmbLaravelLogHistory.Text).Trim().ToUpper() } catch { $snapshotSelectionNow = "OFF" }
        $preRunNotice = Build-UiRunPlanNotice
        if ($snapshotSelectionNow -ne "OFF" -and [bool]$chkLogClearBefore.Checked) {
            $preRunNotice += "`r`n`r`nHinweis: LogClearBefore ist aktiv. Wenn waehrend des Audits keine neuen Logzeilen entstehen, kann der Snapshot leer sein."
        }

        $psArgs = New-Object System.Collections.Generic.List[string]
        $psArgs.Add("-NoProfile") | Out-Null
        $psArgs.Add("-ExecutionPolicy") | Out-Null
        $psArgs.Add("Bypass") | Out-Null
        $psArgs.Add("-File") | Out-Null
        $psArgs.Add($corePath) | Out-Null
        foreach ($a in $argsList) { $psArgs.Add(("" + $a)) | Out-Null }

        $maskedPsArgs = @(Get-MaskedArgumentList -InputArgs @($psArgs.ToArray()))
        $childCmdLine = ("powershell.exe " + (($maskedPsArgs | ForEach-Object { ConvertTo-QuotedArg $_ }) -join " ")).Trim()

        $asyncProc = Start-UiProcessAsync -File "powershell.exe" -ArgumentList @($psArgs.ToArray()) -WorkingDirectory $uiProjectRoot
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 300

        $script:UiAuditRunContext = [pscustomobject]@{
            Process        = $asyncProc.Process
            OutTask        = $asyncProc.OutTask
            ErrTask        = $asyncProc.ErrTask
            PreRunNotice   = $preRunNotice
            ChildCmdLine   = $childCmdLine
            StartedAt      = [DateTime]::Now
            TimeoutSeconds = 600
            Timer          = $timer
        }

        $timer.Add_Tick({
            try {
                $ctx = $script:UiAuditRunContext
                if ($null -eq $ctx) {
                    $this.Stop()
                    return
                }

                $elapsedSeconds = 0
                try { $elapsedSeconds = [int]([DateTime]::Now - $ctx.StartedAt).TotalSeconds } catch { $elapsedSeconds = 0 }
                if ($elapsedSeconds -ge [int]$ctx.TimeoutSeconds) {
                    try { $ctx.Process.Kill($true) } catch { }
                    Complete-UiAuditRun -TimedOut:$true
                    return
                }

                if ($ctx.Process.HasExited) {
                    Complete-UiAuditRun -TimedOut:$false
                }
            } catch {
                Complete-UiAuditRun -TimedOut:$false
            }
        })

        $timer.Start()
    } catch {
        $argDump = ""
        try {
            if ($childCmdLine -and ($childCmdLine.Trim() -ne "")) {
                $argDump = "`r`n`r`nCore-Command:`r`n" + $childCmdLine
            }
        } catch { }

        $combinedErr = ConvertTo-NormalizedText ("GUI-Fehler:`r`n" + ($_ | Out-String).TrimEnd() + $argDump)
        $script:AuditOutputRaw = $combinedErr
        $script:AuditOutputViewRaw = $combinedErr
        Parse-AuditOutput
        Update-UiStatusesFromAuditOutput -OutputText $combinedErr
        Set-OutputFilterView

        $lblStatus.Text = "Fehler"
        try { Sync-OutputPopupButtons } catch { }
    }
}
