# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ui\ks-admin-audit-ui-form.ps1
# Purpose: Form/layout/control helpers for ks-admin-audit-ui
# Created: 14-03-2026 03:28 (Europe/Berlin)
# Changed: 14-03-2026 03:55 (Europe/Berlin)
# Version: 0.3
# =============================================================================

function Set-RoundButtonShape([System.Windows.Forms.Button]$Button) {
    if ($null -eq $Button) { return }
    try {
        $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $Button.FlatAppearance.BorderSize = 1
        $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
        $Button.BackColor = [System.Drawing.Color]::WhiteSmoke
        $Button.Width = 22
        $Button.Height = 22
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse(0, 0, $Button.Width - 1, $Button.Height - 1)
        $Button.Region = New-Object System.Drawing.Region($path)
    } catch { }
}

function New-KsAuditStackPanel {
    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = "Fill"
    $panel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $panel.WrapContents = $false
    $panel.AutoScroll = $true
    return $panel
}

function Add-KsAuditStackRow([System.Windows.Forms.Control]$Parent, [System.Windows.Forms.Control]$Row) {
    if ($null -eq $Parent -or $null -eq $Row) { return }
    try { $Row.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8) } catch { }
    $Parent.Controls.Add($Row)
}

function New-KsAuditStatusRow([System.Windows.Forms.Control]$Content, [System.Windows.Forms.Label]$StatusLabel, [int]$Height = 30) {
    $row = New-Object System.Windows.Forms.Panel
    $row.Height = $Height
    $row.Width = 760
    $row.Anchor = "Left,Right,Top"

    if ($null -ne $StatusLabel) {
        $StatusLabel.Width = 54
        $StatusLabel.Height = 20
        $StatusLabel.Left = $row.Width - $StatusLabel.Width
        $StatusLabel.Top = [Math]::Max(0, [int](($Height - $StatusLabel.Height) / 2))
        $StatusLabel.Anchor = "Top,Right"
        $row.Controls.Add($StatusLabel)
    }

    if ($null -ne $Content) {
        $Content.Left = 0
        $Content.Top = 0
        $Content.Width = $row.Width - $(if ($null -ne $StatusLabel) { 68 } else { 0 })
        $Content.Height = $Height
        $Content.Anchor = "Top,Left,Right"
        $row.Controls.Add($Content)
    }

    $row.Add_Resize({
        try {
            if ($null -ne $StatusLabel) { $StatusLabel.Left = $this.ClientSize.Width - $StatusLabel.Width }
            if ($null -ne $Content) { $Content.Width = [Math]::Max(120, $this.ClientSize.Width - $(if ($null -ne $StatusLabel) { 68 } else { 0 })) }
        } catch { }
    })

    return $row
}

function New-KsAuditLabeledFieldRow([string]$LabelText, [System.Windows.Forms.Control]$Field, [System.Windows.Forms.Label]$StatusLabel = $null, [int]$Height = 52) {
    $content = New-Object System.Windows.Forms.Panel
    $content.Height = $Height
    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $true
    $label.Left = 0
    $label.Top = 2
    $label.Text = $LabelText
    $content.Controls.Add($label)
    $Field.Left = 0
    $Field.Top = 22
    $Field.Anchor = "Top,Left,Right"
    $content.Controls.Add($Field)
    $content.Add_Resize({ try { $Field.Width = [Math]::Max(160, $this.ClientSize.Width) } catch { } })
    return (New-KsAuditStatusRow -Content $content -StatusLabel $StatusLabel -Height $Height)
}

function New-KsAuditCredentialRow([string]$LabelText, [System.Windows.Forms.TextBox]$EmailBox, [System.Windows.Forms.TextBox]$PasswordBox, [System.Windows.Forms.Button]$SaveButton, [System.Windows.Forms.Button]$ClearButton) {
    $row = New-Object System.Windows.Forms.Panel
    $row.Height = 52
    $row.Width = 760
    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $true
    $label.Left = 0
    $label.Top = 2
    $label.Text = $LabelText
    $row.Controls.Add($label)
    $EmailBox.Top = 22
    $PasswordBox.Top = 22
    $EmailBox.Left = 0
    $PasswordBox.Left = 228
    $row.Controls.Add($EmailBox)
    $row.Controls.Add($PasswordBox)
    Set-RoundButtonShape -Button $SaveButton
    Set-RoundButtonShape -Button $ClearButton
    $SaveButton.Top = 22
    $ClearButton.Top = 22
    $row.Controls.Add($SaveButton)
    $row.Controls.Add($ClearButton)
    $row.Add_Resize({
        try {
            $usable = [Math]::Max(260, $this.ClientSize.Width - 56)
            $EmailBox.Width = [Math]::Max(140, [int]($usable * 0.46))
            $PasswordBox.Left = $EmailBox.Right + 8
            $PasswordBox.Width = [Math]::Max(140, $usable - $EmailBox.Width - 8)
            $SaveButton.Left = $this.ClientSize.Width - 48
            $ClearButton.Left = $this.ClientSize.Width - 24
        } catch { }
    })
    return $row
}

function Show-AuditGui() {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $uiScriptDir = $(if ($script:KsAuditUiScriptRoot) { $script:KsAuditUiScriptRoot } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path })
    $uiProjectRoot = Resolve-Path (Join-Path $uiScriptDir "..\..") | Select-Object -ExpandProperty Path
    Confirm-ProjectRoot $uiProjectRoot

    $uiPathsConfigFile = $(if ($PathsConfigFile -and ("" + $PathsConfigFile).Trim() -ne "") { if ([System.IO.Path]::IsPathRooted($PathsConfigFile)) { ("" + $PathsConfigFile).Trim() } else { Join-Path $uiProjectRoot $PathsConfigFile } } else { Join-Path $uiProjectRoot "tools\audit\ks-admin-audit-paths.json" })
    $cfgObj = Get-KsAuditPathsConfig -ConfigPath $uiPathsConfigFile
    if ($null -ne $cfgObj) {
        if (-not $PSBoundParameters.ContainsKey("ProbePaths")) { try { $ProbePaths = @($cfgObj.probe_paths | Where-Object { ("" + $_).Trim() -ne "" }) } catch { } }
        if (-not $PSBoundParameters.ContainsKey("RoleSmokePaths")) { try { $RoleSmokePaths = @($cfgObj.role_smoke_paths | Where-Object { ("" + $_).Trim() -ne "" }) } catch { } }
    }

    $uiCredsConfigFile = Join-Path $uiProjectRoot "tools\audit\ks-admin-audit-credentials.json"
    $credsObj = Get-KsAuditCredentialsConfig -ConfigPath $uiCredsConfigFile
    if ($null -ne $credsObj) {
        if (-not $PSBoundParameters.ContainsKey("SuperadminEmail")) { try { $SuperadminEmail = ("" + $credsObj.superadmin.email) } catch { } }
        if (-not $PSBoundParameters.ContainsKey("SuperadminPassword")) { try { $SuperadminPassword = ("" + $credsObj.superadmin.password) } catch { } }
        if (-not $PSBoundParameters.ContainsKey("AdminEmail")) { try { $AdminEmail = ("" + $credsObj.admin.email) } catch { } }
        if (-not $PSBoundParameters.ContainsKey("AdminPassword")) { try { $AdminPassword = ("" + $credsObj.admin.password) } catch { } }
        if (-not $PSBoundParameters.ContainsKey("ModeratorEmail")) { try { $ModeratorEmail = ("" + $credsObj.moderator.email) } catch { } }
        if (-not $PSBoundParameters.ContainsKey("ModeratorPassword")) { try { $ModeratorPassword = ("" + $credsObj.moderator.password) } catch { } }
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "KiezSingles Admin Audit"
    $form.Width = 1060
    $form.Height = 860
    $form.StartPosition = "CenterScreen"
    $form.MinimumSize = New-Object System.Drawing.Size(920, 720)

    $script:AuditOutputRaw = ""
    $script:AuditOutputViewRaw = ""
    $script:AuditSectionsByKey = @{}
    $script:AuditSelectedKey = ""

    $mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $mainLayout.Dock = "Fill"
    $mainLayout.ColumnCount = 1
    $mainLayout.RowCount = 3
    $mainLayout.Padding = New-Object System.Windows.Forms.Padding(12)
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 214)))
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
    $form.Controls.Add($mainLayout)

    $headerCard = New-Object System.Windows.Forms.Panel
    $headerCard.Dock = "Fill"
    $headerCard.Padding = New-Object System.Windows.Forms.Padding(14, 12, 14, 12)
    $headerCard.BackColor = [System.Drawing.Color]::White
    $headerCard.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $mainLayout.Controls.Add($headerCard, 0, 0)

    $headerLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $headerLayout.Dock = "Fill"
    $headerLayout.ColumnCount = 1
    $headerLayout.RowCount = 5
    $headerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 22)))
    $headerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
    $headerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 22)))
    $headerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 86)))
    $headerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $headerCard.Controls.Add($headerLayout)

    $lblHeaderTitle = New-Object System.Windows.Forms.Label
    $lblHeaderTitle.AutoSize = $true
    $lblHeaderTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblHeaderTitle.Text = "Audit Dashboard"
    $headerLayout.Controls.Add($lblHeaderTitle, 0, 0)

    $baseRow = New-Object System.Windows.Forms.Panel
    $baseRow.Dock = "Fill"
    $headerLayout.Controls.Add($baseRow, 0, 1)
    $lblBaseUrlGlobal = New-Object System.Windows.Forms.Label
    $lblBaseUrlGlobal.AutoSize = $true
    $lblBaseUrlGlobal.Text = "Base-URL (global)"
    $lblBaseUrlGlobal.Left = 0
    $lblBaseUrlGlobal.Top = 2
    $baseRow.Controls.Add($lblBaseUrlGlobal)

    $cmbBaseUrl = New-Object System.Windows.Forms.ComboBox
    $cmbBaseUrl.Left = 0
    $cmbBaseUrl.Top = 22
    $cmbBaseUrl.Width = 660
    $cmbBaseUrl.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$cmbBaseUrl.Items.Add("http://kiezsingles.test")
    [void]$cmbBaseUrl.Items.Add("http://127.0.0.1:8000")
    [void]$cmbBaseUrl.Items.Add("localhost:8000")
    $baseRow.Controls.Add($cmbBaseUrl)
    $initialBaseUrl = ("" + $BaseUrl).Trim()
    if (-not $PSBoundParameters.ContainsKey("BaseUrl")) { $initialBaseUrl = "http://kiezsingles.test" }
    if ($initialBaseUrl -eq "") { $initialBaseUrl = "http://kiezsingles.test" }
    $idxBase = $cmbBaseUrl.Items.IndexOf($initialBaseUrl)
    if ($idxBase -ge 0) { $cmbBaseUrl.SelectedIndex = $idxBase } else { [void]$cmbBaseUrl.Items.Add($initialBaseUrl); $cmbBaseUrl.SelectedIndex = ($cmbBaseUrl.Items.Count - 1) }

    $lblProbePaths = New-Object System.Windows.Forms.Label
    $lblProbePaths.AutoSize = $true
    $lblProbePaths.Text = "ProbePaths / RoleSmokePaths (gemeinsam, je Zeile ein relativer Pfad)"
    $headerLayout.Controls.Add($lblProbePaths, 0, 2)

    $sharedPaths = New-Object System.Collections.Generic.List[string]
    $sharedSeen = @{}
    foreach ($p in @($ProbePaths) + @($RoleSmokePaths)) {
        $x = ("" + $p).Trim()
        if ($x -eq "" -or $sharedSeen.ContainsKey($x)) { continue }
        $sharedSeen[$x] = $true
        $sharedPaths.Add($x) | Out-Null
    }
    if ($sharedPaths.Count -le 0) { foreach ($x in @('/admin','/admin/status','/admin/moderation','/admin/maintenance','/admin/debug','/admin/users','/admin/tickets','/admin/develop')) { $sharedPaths.Add($x) | Out-Null } }

    $txtProbePaths = New-Object System.Windows.Forms.TextBox
    $txtProbePaths.Multiline = $true
    $txtProbePaths.ScrollBars = "Vertical"
    $txtProbePaths.WordWrap = $false
    $txtProbePaths.Dock = "Fill"
    $txtProbePaths.Text = (($sharedPaths | ForEach-Object { "" + $_ }) -join "`r`n")
    $headerLayout.Controls.Add($txtProbePaths, 0, 3)

    $actionRow = New-Object System.Windows.Forms.FlowLayoutPanel
    $actionRow.Dock = "Fill"
    $actionRow.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $actionRow.WrapContents = $true
    $actionRow.Padding = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)
    $headerLayout.Controls.Add($actionRow, 0, 4)

    $btnSavePaths = New-Object System.Windows.Forms.Button
    $btnSavePaths.Text = "Save Paths"
    $btnSavePaths.Width = 110
    $btnSavePaths.Height = 30
    $actionRow.Controls.Add($btnSavePaths)
    $btnOpenDetails = New-Object System.Windows.Forms.Button
    $btnOpenDetails.Text = "Open Details"
    $btnOpenDetails.Width = 110
    $btnOpenDetails.Height = 30
    $btnOpenDetails.Enabled = $false
    $actionRow.Controls.Add($btnOpenDetails)
    $btnShowFullOutput = New-Object System.Windows.Forms.Button
    $btnShowFullOutput.Text = "Open Full Output"
    $btnShowFullOutput.Width = 122
    $btnShowFullOutput.Height = 30
    $btnShowFullOutput.Enabled = $false
    $actionRow.Controls.Add($btnShowFullOutput)
    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "Copy Output"
    $btnCopy.Width = 104
    $btnCopy.Height = 30
    $btnCopy.Enabled = $false
    $actionRow.Controls.Add($btnCopy)
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = "Run"
    $btnRun.Width = 82
    $btnRun.Height = 30
    $actionRow.Controls.Add($btnRun)
    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = "Clear"
    $btnClear.Width = 82
    $btnClear.Height = 30
    $actionRow.Controls.Add($btnClear)
    $lblDetailTitle = New-Object System.Windows.Forms.Label
    $lblDetailTitle.AutoSize = $true
    $lblDetailTitle.Margin = New-Object System.Windows.Forms.Padding(18, 8, 0, 0)
    $lblDetailTitle.Text = "Detailansicht: Gesamtausgabe"
    $actionRow.Controls.Add($lblDetailTitle)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = "Fill"
    $mainLayout.Controls.Add($tabs, 0, 1)
    $tabChecks = New-Object System.Windows.Forms.TabPage
    $tabChecks.Text = "Checks"
    $tabs.TabPages.Add($tabChecks)
    $tabSecurity = New-Object System.Windows.Forms.TabPage
    $tabSecurity.Text = "Security"
    $tabs.TabPages.Add($tabSecurity)
    $tabLogs = New-Object System.Windows.Forms.TabPage
    $tabLogs.Text = "Logs & Export"
    $tabs.TabPages.Add($tabLogs)
    $stackChecks = New-KsAuditStackPanel
    $stackChecks.Padding = New-Object System.Windows.Forms.Padding(12, 12, 12, 8)
    $tabChecks.Controls.Add($stackChecks)
    $stackSecurity = New-KsAuditStackPanel
    $stackSecurity.Padding = New-Object System.Windows.Forms.Padding(12, 12, 12, 8)
    $tabSecurity.Controls.Add($stackSecurity)
    $stackLogs = New-KsAuditStackPanel
    $stackLogs.Padding = New-Object System.Windows.Forms.Padding(12, 12, 12, 8)
    $tabLogs.Controls.Add($stackLogs)

    $footerPanel = New-Object System.Windows.Forms.Panel
    $footerPanel.Dock = "Fill"
    $mainLayout.Controls.Add($footerPanel, 0, 2)
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.AutoSize = $true
    $lblStatus.Left = 2
    $lblStatus.Top = 6
    $footerPanel.Controls.Add($lblStatus)

    $txt = New-Object System.Windows.Forms.RichTextBox
    $txt.Multiline = $true
    $txt.ScrollBars = "Both"
    $txt.WordWrap = $false
    $txt.ReadOnly = $true
    $txt.HideSelection = $false
    $txt.Font = New-Object System.Drawing.Font("Consolas", 9)
    $txtFilter = New-Object System.Windows.Forms.TextBox
    $chkFilterIgnoreCase = New-Object System.Windows.Forms.CheckBox
    $chkFilterIgnoreCase.Checked = $true
    $chkFilterRegex = New-Object System.Windows.Forms.CheckBox
    $lblFilterStatus = New-Object System.Windows.Forms.Label

    $chkCoreRoutes = New-Object System.Windows.Forms.CheckBox
    $chkCoreRoutes.Text = "Core: Routes / collisions / admin scope"
    $chkCoreRoutes.Checked = $true
    $chkCoreRoutes.AutoCheck = $false
    $chkCoreRouteOptionScan = New-Object System.Windows.Forms.CheckBox
    $chkCoreRouteOptionScan.Text = "Core: Route:list option scan"
    $chkCoreRouteOptionScan.Checked = $true
    $chkCoreRouteOptionScan.AutoCheck = $false
    $chkCoreSecurityBaseline = New-Object System.Windows.Forms.CheckBox
    $chkCoreSecurityBaseline.Text = "Core: Security / abuse protection"
    $chkCoreSecurityBaseline.Checked = $true
    $chkCoreSecurityBaseline.AutoCheck = $false
    $chkHttpProbe = New-Object System.Windows.Forms.CheckBox
    $chkHttpProbe.Text = "HTTPProbe"
    $chkHttpProbe.Checked = [bool]$HttpProbe
    $chkTailLog = New-Object System.Windows.Forms.CheckBox
    $chkTailLog.Text = "TailLog"
    $chkTailLog.Checked = [bool]$TailLog
    $lblTailMode = New-Object System.Windows.Forms.Label
    $lblTailMode.Text = "Tail-Modus"
    $cmbTailMode = New-Object System.Windows.Forms.ComboBox
    $cmbTailMode.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$cmbTailMode.Items.Add("live (nur neue Zeilen)")
    [void]$cmbTailMode.Items.Add("history (letzte 200 Zeilen)")
    if (("" + $TailLogMode).Trim().ToLower() -eq "history") { $cmbTailMode.SelectedIndex = 1 } else { $cmbTailMode.SelectedIndex = 0 }
    $chkRoutesVerbose = New-Object System.Windows.Forms.CheckBox
    $chkRoutesVerbose.Text = "RoutesVerbose"
    $chkRoutesVerbose.Checked = [bool]$RoutesVerbose
    $chkRouteListFindstrAdmin = New-Object System.Windows.Forms.CheckBox
    $chkRouteListFindstrAdmin.Text = "RouteListFindstrAdmin"
    $chkRouteListFindstrAdmin.Checked = [bool]$RouteListFindstrAdmin
    $chkSuperadminCount = New-Object System.Windows.Forms.CheckBox
    $chkSuperadminCount.Text = "SuperadminCount"
    $chkSuperadminCount.Checked = [bool]$SuperadminCount
    $lblLaravelLogHistory = New-Object System.Windows.Forms.Label
    $lblLaravelLogHistory.Text = "Laravel Log Snapshot / History"
    $cmbLaravelLogHistory = New-Object System.Windows.Forms.ComboBox
    $cmbLaravelLogHistory.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    foreach ($x in @('OFF','200','500','1000')) { [void]$cmbLaravelLogHistory.Items.Add($x) }
    $cmbLaravelLogHistory.SelectedItem = $(if ([bool]$LogSnapshot) { if ([int]$LogSnapshotLines -eq 500) { '500' } elseif ([int]$LogSnapshotLines -eq 1000) { '1000' } else { '200' } } else { 'OFF' })
    if ($null -eq $cmbLaravelLogHistory.SelectedItem) { $cmbLaravelLogHistory.SelectedItem = 'OFF' }

    $chkLoginCsrfProbe = New-Object System.Windows.Forms.CheckBox
    $chkLoginCsrfProbe.Text = "LoginCsrfProbe"
    $chkLoginCsrfProbe.Checked = [bool]$LoginCsrfProbe
    $chkRoleSmokeTest = New-Object System.Windows.Forms.CheckBox
    $chkRoleSmokeTest.Text = "RoleSmokeTest"
    $chkRoleSmokeTest.Checked = [bool]$RoleSmokeTest
    $chkSessionCsrfBaseline = New-Object System.Windows.Forms.CheckBox
    $chkSessionCsrfBaseline.Text = "SessionCsrfBaseline"
    $chkSessionCsrfBaseline.Checked = [bool]$SessionCsrfBaseline
    $chkSecurityProbe = New-Object System.Windows.Forms.CheckBox
    $chkSecurityProbe.Text = "SecurityProbe"
    $chkSecurityProbe.Checked = [bool]$SecurityProbe
    $chkSecurityCheckIpBan = New-Object System.Windows.Forms.CheckBox
    $chkSecurityCheckIpBan.Text = "SecurityCheckIpBan"
    $chkSecurityCheckIpBan.Checked = [bool]$SecurityCheckIpBan
    $chkSecurityCheckRegister = New-Object System.Windows.Forms.CheckBox
    $chkSecurityCheckRegister.Text = "SecurityCheckRegister"
    $chkSecurityCheckRegister.Checked = [bool]$SecurityCheckRegister
    $cmbSecurityLoginAttempts = New-Object System.Windows.Forms.ComboBox
    $cmbSecurityLoginAttempts.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    foreach ($n in 1..10) { [void]$cmbSecurityLoginAttempts.Items.Add(("" + $n)) }
    $idxLoginAttempts = $cmbSecurityLoginAttempts.Items.IndexOf(("" + $SecurityLoginAttempts).Trim())
    if ($idxLoginAttempts -ge 0) { $cmbSecurityLoginAttempts.SelectedIndex = $idxLoginAttempts } else { $cmbSecurityLoginAttempts.SelectedItem = '8' }
    $lblRoleCreds = New-Object System.Windows.Forms.Label
    $lblRoleCreds.AutoSize = $true
    $lblRoleCreds.Text = "Credentials fuer Login / RoleSmoke"

    $lblSuperadminEmail = New-Object System.Windows.Forms.Label
    $txtSuperadminEmail = New-Object System.Windows.Forms.TextBox
    $txtSuperadminEmail.Text = ("" + $SuperadminEmail)
    $txtSuperadminPassword = New-Object System.Windows.Forms.TextBox
    $txtSuperadminPassword.UseSystemPasswordChar = $true
    $txtSuperadminPassword.Text = ("" + $SuperadminPassword)
    $btnSaveSuperadmin = New-Object System.Windows.Forms.Button
    $btnSaveSuperadmin.Text = 'S'
    $btnClearSuperadmin = New-Object System.Windows.Forms.Button
    $btnClearSuperadmin.Text = 'C'
    $lblAdminEmail = New-Object System.Windows.Forms.Label
    $txtAdminEmail = New-Object System.Windows.Forms.TextBox
    $txtAdminEmail.Text = ("" + $AdminEmail)
    $txtAdminPassword = New-Object System.Windows.Forms.TextBox
    $txtAdminPassword.UseSystemPasswordChar = $true
    $txtAdminPassword.Text = ("" + $AdminPassword)
    $btnSaveAdmin = New-Object System.Windows.Forms.Button
    $btnSaveAdmin.Text = 'S'
    $btnClearAdmin = New-Object System.Windows.Forms.Button
    $btnClearAdmin.Text = 'C'
    $lblModeratorEmail = New-Object System.Windows.Forms.Label
    $txtModeratorEmail = New-Object System.Windows.Forms.TextBox
    $txtModeratorEmail.Text = ("" + $ModeratorEmail)
    $txtModeratorPassword = New-Object System.Windows.Forms.TextBox
    $txtModeratorPassword.UseSystemPasswordChar = $true
    $txtModeratorPassword.Text = ("" + $ModeratorPassword)
    $btnSaveModerator = New-Object System.Windows.Forms.Button
    $btnSaveModerator.Text = 'S'
    $btnClearModerator = New-Object System.Windows.Forms.Button
    $btnClearModerator.Text = 'C'

    $chkLogClearBefore = New-Object System.Windows.Forms.CheckBox
    $chkLogClearBefore.Text = "LogClearBefore"
    $chkLogClearBefore.Checked = [bool]$LogClearBefore
    $chkLogClearAfter = New-Object System.Windows.Forms.CheckBox
    $chkLogClearAfter.Text = "LogClearAfter"
    $chkLogClearAfter.Checked = [bool]$LogClearAfter
    $chkShowCheckDetails = New-Object System.Windows.Forms.CheckBox
    $chkShowCheckDetails.Text = "ShowCheckDetails"
    $chkShowCheckDetails.Checked = [bool](("" + $ShowCheckDetails).Trim() -notmatch '^(?i:0|false|\$false|no|off)$')
    $chkExportLogs = New-Object System.Windows.Forms.CheckBox
    $chkExportLogs.Text = "ExportLogs"
    $chkExportLogs.Checked = [bool](("" + $ExportLogs).Trim() -match '^(?i:1|true|\$true|yes|on)$')
    $cmbExportLogsLines = New-Object System.Windows.Forms.ComboBox
    $cmbExportLogsLines.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    foreach ($value in @(50,100,200,500,1000)) { [void]$cmbExportLogsLines.Items.Add(("" + $value)) }
    $idxExportLines = $cmbExportLogsLines.Items.IndexOf(("" + [int]$ExportLogsLines))
    if ($idxExportLines -ge 0) { $cmbExportLogsLines.SelectedIndex = $idxExportLines } else { $cmbExportLogsLines.SelectedItem = '200' }
    $chkAutoOpenExportFolder = New-Object System.Windows.Forms.CheckBox
    $chkAutoOpenExportFolder.Text = "AutoOpenExportFolder"
    $chkAutoOpenExportFolder.Checked = [bool](("" + $AutoOpenExportFolder).Trim() -match '^(?i:1|true|\$true|yes|on)$')

    $statusLabels = @{ core_routes = (New-AuditStatusLabel 'core_routes'); core_route_option_scan = (New-AuditStatusLabel 'core_route_option_scan'); core_security_baseline = (New-AuditStatusLabel 'core_security_baseline'); http_probe = (New-AuditStatusLabel 'http_probe'); tail_log = (New-AuditStatusLabel 'tail_log'); routes_verbose = (New-AuditStatusLabel 'routes_verbose'); route_list_findstr_admin = (New-AuditStatusLabel 'route_list_findstr_admin'); superadmin_count = (New-AuditStatusLabel 'superadmin_count'); log_snapshot = (New-AuditStatusLabel 'log_snapshot'); login_csrf_probe = (New-AuditStatusLabel 'login_csrf_probe'); role_smoke_test = (New-AuditStatusLabel 'role_smoke_test'); session_csrf_baseline = (New-AuditStatusLabel 'session_csrf_baseline'); show_check_details = (New-AuditStatusLabel 'show_check_details'); export_logs = (New-AuditStatusLabel 'export_logs'); auto_open_export_folder = (New-AuditStatusLabel 'auto_open_export_folder'); log_clear_before = (New-AuditStatusLabel 'log_clear_before'); log_clear_after = (New-AuditStatusLabel 'log_clear_after') }
    $checkMap = @{ core_routes = $chkCoreRoutes; core_route_option_scan = $chkCoreRouteOptionScan; core_security_baseline = $chkCoreSecurityBaseline; http_probe = $chkHttpProbe; tail_log = $chkTailLog; routes_verbose = $chkRoutesVerbose; route_list_findstr_admin = $chkRouteListFindstrAdmin; superadmin_count = $chkSuperadminCount; log_snapshot = $lblLaravelLogHistory; login_csrf_probe = $chkLoginCsrfProbe; role_smoke_test = $chkRoleSmokeTest; session_csrf_baseline = $chkSessionCsrfBaseline; show_check_details = $chkShowCheckDetails; export_logs = $chkExportLogs; auto_open_export_folder = $chkAutoOpenExportFolder; log_clear_before = $chkLogClearBefore; log_clear_after = $chkLogClearAfter }

    $grpCore = New-Object System.Windows.Forms.GroupBox
    $grpCore.Text = 'Core Checks'
    $grpCore.AutoSize = $true
    $grpCore.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $coreBody = New-KsAuditStackPanel
    $coreBody.AutoScroll = $false
    $coreBody.AutoSize = $true
    $coreBody.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $grpCore.Controls.Add($coreBody)
    Add-KsAuditStackRow $stackChecks $grpCore
    Add-KsAuditStackRow $coreBody (New-KsAuditStatusRow -Content $chkCoreRoutes -StatusLabel $statusLabels['core_routes'] -Height 28)
    Add-KsAuditStackRow $coreBody (New-KsAuditStatusRow -Content $chkCoreRouteOptionScan -StatusLabel $statusLabels['core_route_option_scan'] -Height 28)
    Add-KsAuditStackRow $coreBody (New-KsAuditStatusRow -Content $chkCoreSecurityBaseline -StatusLabel $statusLabels['core_security_baseline'] -Height 28)

    $grpChecks = New-Object System.Windows.Forms.GroupBox
    $grpChecks.Text = 'Optional Checks'
    $grpChecks.AutoSize = $true
    $grpChecks.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $checksBody = New-KsAuditStackPanel
    $checksBody.AutoScroll = $false
    $checksBody.AutoSize = $true
    $checksBody.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $grpChecks.Controls.Add($checksBody)
    Add-KsAuditStackRow $stackChecks $grpChecks
    Add-KsAuditStackRow $checksBody (New-KsAuditStatusRow -Content $chkHttpProbe -StatusLabel $statusLabels['http_probe'] -Height 28)
    Add-KsAuditStackRow $checksBody (New-KsAuditStatusRow -Content $chkTailLog -StatusLabel $statusLabels['tail_log'] -Height 28)
    Add-KsAuditStackRow $checksBody (New-KsAuditLabeledFieldRow -LabelText 'TailLog-Modus' -Field $cmbTailMode -Height 52)
    Add-KsAuditStackRow $checksBody (New-KsAuditStatusRow -Content $chkRoutesVerbose -StatusLabel $statusLabels['routes_verbose'] -Height 28)
    Add-KsAuditStackRow $checksBody (New-KsAuditStatusRow -Content $chkRouteListFindstrAdmin -StatusLabel $statusLabels['route_list_findstr_admin'] -Height 28)
    Add-KsAuditStackRow $checksBody (New-KsAuditStatusRow -Content $chkSuperadminCount -StatusLabel $statusLabels['superadmin_count'] -Height 28)
    Add-KsAuditStackRow $checksBody (New-KsAuditLabeledFieldRow -LabelText 'Laravel Log Snapshot / History' -Field $cmbLaravelLogHistory -StatusLabel $statusLabels['log_snapshot'] -Height 52)

    $grpSecurity = New-Object System.Windows.Forms.GroupBox
    $grpSecurity.Text = 'Security Checks'
    $grpSecurity.AutoSize = $true
    $grpSecurity.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $securityBody = New-KsAuditStackPanel
    $securityBody.AutoScroll = $false
    $securityBody.AutoSize = $true
    $securityBody.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $grpSecurity.Controls.Add($securityBody)
    Add-KsAuditStackRow $stackSecurity $grpSecurity
    Add-KsAuditStackRow $securityBody (New-KsAuditStatusRow -Content $chkLoginCsrfProbe -StatusLabel $statusLabels['login_csrf_probe'] -Height 28)
    Add-KsAuditStackRow $securityBody (New-KsAuditStatusRow -Content $chkRoleSmokeTest -StatusLabel $statusLabels['role_smoke_test'] -Height 28)
    Add-KsAuditStackRow $securityBody (New-KsAuditStatusRow -Content $chkSessionCsrfBaseline -StatusLabel $statusLabels['session_csrf_baseline'] -Height 28)
    Add-KsAuditStackRow $securityBody (New-KsAuditStatusRow -Content $chkSecurityProbe -StatusLabel $statusLabels['core_security_baseline'] -Height 28)
    Add-KsAuditStackRow $securityBody (New-KsAuditLabeledFieldRow -LabelText 'SecurityLoginAttempts' -Field $cmbSecurityLoginAttempts -Height 52)
    Add-KsAuditStackRow $securityBody (New-KsAuditStatusRow -Content $chkSecurityCheckIpBan -StatusLabel $null -Height 28)
    Add-KsAuditStackRow $securityBody (New-KsAuditStatusRow -Content $chkSecurityCheckRegister -StatusLabel $null -Height 28)

    $grpCreds = New-Object System.Windows.Forms.GroupBox
    $grpCreds.Text = 'Credentials'
    $grpCreds.AutoSize = $true
    $grpCreds.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $credsBody = New-KsAuditStackPanel
    $credsBody.AutoScroll = $false
    $credsBody.AutoSize = $true
    $credsBody.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $grpCreds.Controls.Add($credsBody)
    Add-KsAuditStackRow $stackSecurity $grpCreds
    Add-KsAuditStackRow $credsBody $lblRoleCreds
    Add-KsAuditStackRow $credsBody (New-KsAuditCredentialRow -LabelText 'Superadmin' -EmailBox $txtSuperadminEmail -PasswordBox $txtSuperadminPassword -SaveButton $btnSaveSuperadmin -ClearButton $btnClearSuperadmin)
    Add-KsAuditStackRow $credsBody (New-KsAuditCredentialRow -LabelText 'Admin' -EmailBox $txtAdminEmail -PasswordBox $txtAdminPassword -SaveButton $btnSaveAdmin -ClearButton $btnClearAdmin)
    Add-KsAuditStackRow $credsBody (New-KsAuditCredentialRow -LabelText 'Moderator' -EmailBox $txtModeratorEmail -PasswordBox $txtModeratorPassword -SaveButton $btnSaveModerator -ClearButton $btnClearModerator)

    $grpLogs = New-Object System.Windows.Forms.GroupBox
    $grpLogs.Text = 'Logs & Export'
    $grpLogs.AutoSize = $true
    $grpLogs.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $logsBody = New-KsAuditStackPanel
    $logsBody.AutoScroll = $false
    $logsBody.AutoSize = $true
    $logsBody.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $grpLogs.Controls.Add($logsBody)
    Add-KsAuditStackRow $stackLogs $grpLogs
    Add-KsAuditStackRow $logsBody (New-KsAuditStatusRow -Content $chkLogClearBefore -StatusLabel $statusLabels['log_clear_before'] -Height 28)
    Add-KsAuditStackRow $logsBody (New-KsAuditStatusRow -Content $chkLogClearAfter -StatusLabel $statusLabels['log_clear_after'] -Height 28)
    Add-KsAuditStackRow $logsBody (New-KsAuditStatusRow -Content $chkShowCheckDetails -StatusLabel $statusLabels['show_check_details'] -Height 28)
    Add-KsAuditStackRow $logsBody (New-KsAuditStatusRow -Content $chkExportLogs -StatusLabel $statusLabels['export_logs'] -Height 28)
    Add-KsAuditStackRow $logsBody (New-KsAuditLabeledFieldRow -LabelText 'ExportLogsLines' -Field $cmbExportLogsLines -Height 52)
    Add-KsAuditStackRow $logsBody (New-KsAuditStatusRow -Content $chkAutoOpenExportFolder -StatusLabel $statusLabels['auto_open_export_folder'] -Height 28)

    function Update-UiGroupWidths {
        try {
            $w = [Math]::Max(620, $tabs.ClientSize.Width - 42)
            foreach ($g in @($grpCore, $grpChecks, $grpSecurity, $grpCreds, $grpLogs)) { $g.Width = $w }
        } catch { }
    }

    function Register-AuditDetailBinding([System.Windows.Forms.Control]$Control, [string]$Key) {
        if ($null -eq $Control) { return }
        $Control.Tag = $Key
        try { $Control.Add_Click({ try { Select-AuditDetail ([string]$this.Tag) } catch { } }) } catch { }
    }

    foreach ($entry in $statusLabels.GetEnumerator()) { $entry.Value.Cursor = [System.Windows.Forms.Cursors]::Hand; $entry.Value.Add_Click({ try { Select-AuditDetail ([string]$this.Tag) } catch { } }) }
    foreach ($binding in @(@($chkCoreRoutes,'core_routes'),@($chkCoreRouteOptionScan,'core_route_option_scan'),@($chkCoreSecurityBaseline,'core_security_baseline'),@($chkHttpProbe,'http_probe'),@($chkTailLog,'tail_log'),@($chkRoutesVerbose,'routes_verbose'),@($chkRouteListFindstrAdmin,'route_list_findstr_admin'),@($chkSuperadminCount,'superadmin_count'),@($lblLaravelLogHistory,'log_snapshot'),@($chkLoginCsrfProbe,'login_csrf_probe'),@($chkRoleSmokeTest,'role_smoke_test'),@($chkSessionCsrfBaseline,'session_csrf_baseline'),@($chkShowCheckDetails,'show_check_details'),@($chkExportLogs,'export_logs'),@($chkAutoOpenExportFolder,'auto_open_export_folder'),@($chkLogClearBefore,'log_clear_before'),@($chkLogClearAfter,'log_clear_after'))) { Register-AuditDetailBinding $binding[0] $binding[1] }

    $candidate = Join-Path $uiScriptDir 'ks-admin-audit.ps1'
    if (-not (Test-Path -LiteralPath $candidate)) { throw ('CLI core not found next to UI: ' + $candidate) }
    $corePath = $candidate

    $script:form = $form; $script:uiProjectRoot = $uiProjectRoot; $script:uiPathsConfigFile = $uiPathsConfigFile; $script:uiCredsConfigFile = $uiCredsConfigFile; $script:corePath = $corePath; $script:statusLabels = $statusLabels; $script:checkMap = $checkMap
    $script:txt = $txt; $script:txtFilter = $txtFilter; $script:chkFilterIgnoreCase = $chkFilterIgnoreCase; $script:chkFilterRegex = $chkFilterRegex; $script:lblFilterStatus = $lblFilterStatus; $script:lblDetailTitle = $lblDetailTitle; $script:lblStatus = $lblStatus
    $script:btnCopy = $btnCopy; $script:btnRun = $btnRun; $script:btnClear = $btnClear; $script:btnSavePaths = $btnSavePaths; $script:btnOpenDetails = $btnOpenDetails; $script:btnShowFullOutput = $btnShowFullOutput
    $script:lblProbePaths = $lblProbePaths; $script:txtProbePaths = $txtProbePaths; $script:cmbBaseUrl = $cmbBaseUrl; $script:chkHttpProbe = $chkHttpProbe; $script:chkTailLog = $chkTailLog; $script:lblTailMode = $lblTailMode; $script:cmbTailMode = $cmbTailMode; $script:chkRoutesVerbose = $chkRoutesVerbose; $script:chkRouteListFindstrAdmin = $chkRouteListFindstrAdmin; $script:chkSuperadminCount = $chkSuperadminCount; $script:lblLaravelLogHistory = $lblLaravelLogHistory; $script:cmbLaravelLogHistory = $cmbLaravelLogHistory
    $script:chkLoginCsrfProbe = $chkLoginCsrfProbe; $script:chkRoleSmokeTest = $chkRoleSmokeTest; $script:chkSessionCsrfBaseline = $chkSessionCsrfBaseline; $script:chkSecurityProbe = $chkSecurityProbe; $script:chkSecurityCheckIpBan = $chkSecurityCheckIpBan; $script:chkSecurityCheckRegister = $chkSecurityCheckRegister; $script:cmbSecurityLoginAttempts = $cmbSecurityLoginAttempts
    $script:lblRoleCreds = $lblRoleCreds; $script:lblSuperadminEmail = $lblSuperadminEmail; $script:txtSuperadminEmail = $txtSuperadminEmail; $script:txtSuperadminPassword = $txtSuperadminPassword; $script:btnSaveSuperadmin = $btnSaveSuperadmin; $script:btnClearSuperadmin = $btnClearSuperadmin; $script:lblAdminEmail = $lblAdminEmail; $script:txtAdminEmail = $txtAdminEmail; $script:txtAdminPassword = $txtAdminPassword; $script:btnSaveAdmin = $btnSaveAdmin; $script:btnClearAdmin = $btnClearAdmin; $script:lblModeratorEmail = $lblModeratorEmail; $script:txtModeratorEmail = $txtModeratorEmail; $script:txtModeratorPassword = $txtModeratorPassword; $script:btnSaveModerator = $btnSaveModerator; $script:btnClearModerator = $btnClearModerator
    $script:chkLogClearBefore = $chkLogClearBefore; $script:chkLogClearAfter = $chkLogClearAfter; $script:chkShowCheckDetails = $chkShowCheckDetails; $script:chkExportLogs = $chkExportLogs; $script:cmbExportLogsLines = $cmbExportLogsLines; $script:chkAutoOpenExportFolder = $chkAutoOpenExportFolder

    $tabs.Add_Resize({ Update-UiGroupWidths })
    $form.Add_Shown({ Update-UiGroupWidths; try { Sync-OutputPopupButtons } catch { } })

    $chkHttpProbe.Add_CheckedChanged({ Sync-HttpFieldsEnabled })
    Sync-HttpFieldsEnabled
    $chkTailLog.Add_CheckedChanged({ Sync-TailFieldsEnabled })
    Sync-TailFieldsEnabled
    $chkRoleSmokeTest.Add_CheckedChanged({ Sync-RoleSmokeFieldsEnabled })
    $chkLoginCsrfProbe.Add_CheckedChanged({ Sync-RoleSmokeFieldsEnabled })
    Sync-RoleSmokeFieldsEnabled

    $btnOpenDetails.Add_Click({ Open-AuditDetailPopup })
    $btnShowFullOutput.Add_Click({ Open-AuditFullOutputPopup })
    $btnRun.Add_Click({ Invoke-UiAuditRun })
    $btnCopy.Add_Click({ Copy-AuditViewerOutput })
    $btnClear.Add_Click({ Clear-AuditViewerOutput })
    $chkFilterIgnoreCase.Add_CheckedChanged({ try { Set-OutputFilterView } catch { } })
    $chkFilterRegex.Add_CheckedChanged({ try { Set-OutputFilterView } catch { } })

    $btnSavePaths.Add_Click({
        try {
            $ppLines = @(("" + $txtProbePaths.Text) -split "`r?`n" | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
            Save-KsAuditPathsConfig -ConfigPath $uiPathsConfigFile -ProbePathsToSave @($ppLines) -RoleSmokePathsToSave @($ppLines)
            $lblStatus.Text = ('Pfade gespeichert: ' + $uiPathsConfigFile)
        } catch {
            $lblStatus.Text = ('Save Paths fehlgeschlagen: ' + $_.Exception.Message)
        }
    })

    $btnSaveSuperadmin.Add_Click({ try { Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role 'superadmin' -Email ("" + $txtSuperadminEmail.Text).Trim() -Password ("" + $txtSuperadminPassword.Text); $lblStatus.Text = 'Superadmin gespeichert' } catch { $lblStatus.Text = ('Save Superadmin fehlgeschlagen: ' + $_.Exception.Message) } })
    $btnClearSuperadmin.Add_Click({ try { $txtSuperadminEmail.Text = ''; $txtSuperadminPassword.Text = ''; Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role 'superadmin' -Email '' -Password '' -ClearRole:$true; $lblStatus.Text = 'Superadmin geloescht' } catch { $lblStatus.Text = ('Clear Superadmin fehlgeschlagen: ' + $_.Exception.Message) } })
    $btnSaveAdmin.Add_Click({ try { Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role 'admin' -Email ("" + $txtAdminEmail.Text).Trim() -Password ("" + $txtAdminPassword.Text); $lblStatus.Text = 'Admin gespeichert' } catch { $lblStatus.Text = ('Save Admin fehlgeschlagen: ' + $_.Exception.Message) } })
    $btnClearAdmin.Add_Click({ try { $txtAdminEmail.Text = ''; $txtAdminPassword.Text = ''; Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role 'admin' -Email '' -Password '' -ClearRole:$true; $lblStatus.Text = 'Admin geloescht' } catch { $lblStatus.Text = ('Clear Admin fehlgeschlagen: ' + $_.Exception.Message) } })
    $btnSaveModerator.Add_Click({ try { Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role 'moderator' -Email ("" + $txtModeratorEmail.Text).Trim() -Password ("" + $txtModeratorPassword.Text); $lblStatus.Text = 'Moderator gespeichert' } catch { $lblStatus.Text = ('Save Moderator fehlgeschlagen: ' + $_.Exception.Message) } })
    $btnClearModerator.Add_Click({ try { $txtModeratorEmail.Text = ''; $txtModeratorPassword.Text = ''; Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role 'moderator' -Email '' -Password '' -ClearRole:$true; $lblStatus.Text = 'Moderator geloescht' } catch { $lblStatus.Text = ('Clear Moderator fehlgeschlagen: ' + $_.Exception.Message) } })

    [void]$form.ShowDialog()
}
