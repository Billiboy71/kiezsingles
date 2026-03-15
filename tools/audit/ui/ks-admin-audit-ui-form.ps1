# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ui\ks-admin-audit-ui-form.ps1
# Purpose: Form/layout/control helpers for ks-admin-audit-ui
# Created: 14-03-2026 03:28 (Europe/Berlin)
# Changed: 15-03-2026 20:51 (Europe/Berlin)
# Version: 2.1
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

function Set-KsAuditCredentialActionButtonStyle([System.Windows.Forms.Button]$Button, [string]$Mode = 'default') {
    if ($null -eq $Button) { return }
    try {
        $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $Button.FlatAppearance.BorderSize = 1
        $Button.Width = 54
        $Button.Height = 24
        $Button.Region = $null

        switch (("" + $Mode).Trim().ToLowerInvariant()) {
            'save' {
                $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(88, 133, 88)
                $Button.BackColor = [System.Drawing.Color]::FromArgb(235, 245, 235)
                break
            }
            'clear' {
                $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
                $Button.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
                break
            }
            default {
                $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
                $Button.BackColor = [System.Drawing.Color]::WhiteSmoke
                break
            }
        }
    } catch { }
}

function Set-KsAuditFixedCheckStyle([System.Windows.Forms.CheckBox]$CheckBox) {
    if ($null -eq $CheckBox) { return }
    try {
        $baseText = ("" + $CheckBox.Text).Trim()
        if ($baseText -notmatch '\(immer aktiv\)$') {
            $CheckBox.Text = ($baseText + " (immer aktiv)")
        }
        $CheckBox.AutoCheck = $false
        $CheckBox.Cursor = [System.Windows.Forms.Cursors]::Default
        $CheckBox.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
    } catch { }
}

function Set-KsAuditStatusLabelVisual([System.Windows.Forms.Label]$Label) {
    if ($null -eq $Label) { return }

    try {
        $value = ("" + $Label.Text).Trim().ToUpperInvariant()

        $Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $Label.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $Label.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $Label.BackColor = [System.Drawing.Color]::White
        $Label.ForeColor = [System.Drawing.Color]::FromArgb(96, 96, 96)

        switch ($value) {
            'PASS' {
                $Label.BackColor = [System.Drawing.Color]::FromArgb(222, 245, 226)
                $Label.ForeColor = [System.Drawing.Color]::FromArgb(28, 120, 52)
                break
            }
            'WARN' {
                $Label.BackColor = [System.Drawing.Color]::FromArgb(255, 244, 214)
                $Label.ForeColor = [System.Drawing.Color]::FromArgb(128, 88, 0)
                break
            }
            'FAIL' {
                $Label.BackColor = [System.Drawing.Color]::FromArgb(248, 223, 223)
                $Label.ForeColor = [System.Drawing.Color]::FromArgb(150, 32, 32)
                break
            }
            'SKIP' {
                $Label.BackColor = [System.Drawing.Color]::FromArgb(225, 239, 255)
                $Label.ForeColor = [System.Drawing.Color]::FromArgb(34, 92, 163)
                break
            }
            default {
                $Label.BackColor = [System.Drawing.Color]::White
                $Label.ForeColor = [System.Drawing.Color]::FromArgb(96, 96, 96)
                break
            }
        }
    } catch { }
}

function New-KsAuditStackPanel {
    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = "Fill"
    $panel.AutoScroll = $true
    $panel.ColumnCount = 1
    $panel.RowCount = 0
    $panel.GrowStyle = [System.Windows.Forms.TableLayoutPanelGrowStyle]::AddRows
    [void]$panel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    return $panel
}

function Add-KsAuditStackRow([System.Windows.Forms.Control]$Parent, [System.Windows.Forms.Control]$Row) {
    if ($null -eq $Parent -or $null -eq $Row) { return }
    try { $Row.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10) } catch { }
    try { $Row.Anchor = "Top,Left,Right" } catch { }
    try { $Row.Dock = "Top" } catch { }
    $nextRow = 0
    try { $nextRow = [int]$Parent.RowCount } catch { $nextRow = 0 }
    try { $Parent.RowCount = $nextRow + 1 } catch { }
    try { [void]$Parent.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) } catch { }
    try { [void]$Parent.Controls.Add($Row, 0, $nextRow) } catch { $Parent.Controls.Add($Row) }
}

function Update-KsAuditGroupBoxHeight([System.Windows.Forms.GroupBox]$GroupBox) {
    if ($null -eq $GroupBox) { return }

    try {
        if ($GroupBox.Controls.Count -le 0) { return }
        $body = $GroupBox.Controls[0]
        if ($null -eq $body) { return }

        $bodyHeight = 0
        foreach ($row in @($body.Controls)) {
            if ($null -eq $row) { continue }
            $rowHeight = 0
            try { $rowHeight = [int]$row.Height } catch { $rowHeight = 0 }
            if ($rowHeight -lt 1) {
                try { $rowHeight = [int]$row.PreferredSize.Height } catch { $rowHeight = 0 }
            }
            if ($rowHeight -lt 1) { $rowHeight = 30 }

            $marginBottom = 0
            try { $marginBottom = [int]$row.Margin.Bottom } catch { $marginBottom = 0 }

            $bodyHeight += ($rowHeight + $marginBottom)
        }

        $targetHeight = [Math]::Max(72, $bodyHeight + 40)
        $GroupBox.Height = $targetHeight
    } catch { }
}

function Update-KsAuditStackLayout([System.Windows.Forms.Control]$Container) {
    if ($null -eq $Container) { return }
    $targetWidth = 0
    try { $targetWidth = [Math]::Max(280, $Container.ClientSize.Width - $Container.Padding.Horizontal - 24) } catch { $targetWidth = 280 }

    foreach ($child in @($Container.Controls)) {
        if ($null -eq $child) { continue }
        try { $child.Width = $targetWidth } catch { }

        if ($child -is [System.Windows.Forms.GroupBox] -and $child.Controls.Count -gt 0) {
            $body = $child.Controls[0]
            try { $body.Width = [Math]::Max(240, $child.ClientSize.Width - 18) } catch { }
            foreach ($row in @($body.Controls)) {
                try { $row.Width = [Math]::Max(220, $body.ClientSize.Width - 8) } catch { }
            }
            Update-KsAuditGroupBoxHeight -GroupBox $child
        }
    }
}

function New-KsAuditStatusRow([System.Windows.Forms.Control]$Content, [System.Windows.Forms.Label]$StatusLabel, [int]$Height = 30) {
    $row = New-Object System.Windows.Forms.Panel
    $row.Height = $Height
    $row.Width = 760
    $row.Anchor = "Left,Right,Top"

    if ($null -ne $StatusLabel) {
        $StatusLabel.Width = 78
        $StatusLabel.Height = 28
        $StatusLabel.Left = $row.Width - $StatusLabel.Width
        $StatusLabel.Top = [Math]::Max(0, [int](($Height - $StatusLabel.Height) / 2))
        $StatusLabel.Anchor = "Top,Right"
        Set-KsAuditStatusLabelVisual -Label $StatusLabel
        $row.Controls.Add($StatusLabel)
    }

    if ($null -ne $Content) {
        $Content.Left = 0
        $Content.Top = 0
        $Content.Width = $row.Width - $(if ($null -ne $StatusLabel) { 90 } else { 0 })
        $Content.Height = $Height
        $Content.Anchor = "Top,Left,Right"
        $row.Controls.Add($Content)
    }

    $row.Add_Resize({
        try {
            if ($null -ne $StatusLabel) { $StatusLabel.Left = $this.ClientSize.Width - $StatusLabel.Width }
            if ($null -ne $Content) { $Content.Width = [Math]::Max(120, $this.ClientSize.Width - $(if ($null -ne $StatusLabel) { 90 } else { 0 })) }
        } catch { }
    })

    return $row
}

function New-KsAuditLabeledFieldRow([string]$LabelText, [System.Windows.Forms.Control]$Field, [System.Windows.Forms.Label]$StatusLabel = $null, [int]$Height = 56) {
    $content = New-Object System.Windows.Forms.Panel
    $content.Height = $Height

    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $true
    $label.Left = 0
    $label.Top = 2
    $label.Text = $LabelText
    $content.Controls.Add($label)

    $Field.Left = 0
    $Field.Top = 24
    $Field.Height = 28
    $Field.Anchor = "Top,Left,Right"
    $content.Controls.Add($Field)

    $content.Add_Resize({
        try { $Field.Width = [Math]::Max(160, $this.ClientSize.Width) } catch { }
    })

    return (New-KsAuditStatusRow -Content $content -StatusLabel $StatusLabel -Height $Height)
}

function New-KsAuditCredentialRow([string]$LabelText, [System.Windows.Forms.TextBox]$EmailBox, [System.Windows.Forms.TextBox]$PasswordBox, [System.Windows.Forms.Button]$SaveButton, [System.Windows.Forms.Button]$ClearButton) {
    $row = New-Object System.Windows.Forms.Panel
    $row.Height = 86
    $row.Width = 760
    $row.Anchor = "Top,Left,Right"

    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $true
    $label.Left = 0
    $label.Top = 2
    $label.Text = $LabelText
    $row.Controls.Add($label)

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Left = 0
    $layout.Top = 24
    $layout.Width = 430
    $layout.Height = 54
    $layout.ColumnCount = 3
    $layout.RowCount = 2
    $layout.Margin = New-Object System.Windows.Forms.Padding(0)
    $layout.Padding = New-Object System.Windows.Forms.Padding(0)
    $layout.Anchor = "Top,Left"
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 300)))
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 60)))
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 60)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 27)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 27)))
    $row.Controls.Add($layout)

    $EmailBox.Width = 300
    $EmailBox.Height = 24
    $EmailBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 3)
    $EmailBox.Anchor = "Left"
    $layout.Controls.Add($EmailBox, 0, 0)

    $PasswordBox.Width = 300
    $PasswordBox.Height = 24
    $PasswordBox.Margin = New-Object System.Windows.Forms.Padding(0, 3, 0, 0)
    $PasswordBox.Anchor = "Left"
    $layout.Controls.Add($PasswordBox, 0, 1)

    Set-KsAuditCredentialActionButtonStyle -Button $SaveButton -Mode 'save'
    Set-KsAuditCredentialActionButtonStyle -Button $ClearButton -Mode 'clear'

    $SaveButton.Anchor = "None"
    $ClearButton.Anchor = "None"
    $layout.Controls.Add($SaveButton, 1, 1)
    $layout.Controls.Add($ClearButton, 2, 1)

    $layoutCredentialRow = {
        try {
            $layout.Width = [Math]::Min(430, [Math]::Max(300, $this.ClientSize.Width))
            $EmailBox.Width = 300
            $PasswordBox.Width = 300
        } catch { }
    }

    $row.Add_Resize($layoutCredentialRow)
    & $layoutCredentialRow

    return $row
}

function New-KsAuditSectionHost {
    $sectionHost = New-Object System.Windows.Forms.Panel
    $sectionHost.Dock = "Fill"
    $sectionHost.Padding = New-Object System.Windows.Forms.Padding(12)

    $stack = New-KsAuditStackPanel
    $stack.Dock = "Fill"
    $stack.AutoScroll = $true
    $stack.AutoSize = $false
    $stack.Padding = New-Object System.Windows.Forms.Padding(0)
    [void]$sectionHost.Controls.Add($stack)
    $stack.Add_ControlAdded({ try { Update-KsAuditStackLayout -Container $this } catch { } })
    $sectionHost.Add_Resize({ try { Update-KsAuditStackLayout -Container $stack } catch { } })

    return [pscustomobject]@{
        Host  = $sectionHost
        Stack = $stack
    }
}

function New-KsAuditGroupBox([string]$Title) {
    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = $Title
    $group.AutoSize = $false
    $group.Dock = "Top"
    $group.Anchor = "Top,Left,Right"
    $group.Width = 760
    $group.Padding = New-Object System.Windows.Forms.Padding(10, 18, 10, 10)

    $body = New-KsAuditStackPanel
    $body.Dock = "Fill"
    $body.AutoSize = $false
    $body.AutoScroll = $false
    $body.Padding = New-Object System.Windows.Forms.Padding(0)
    [void]$group.Controls.Add($body)
    $group.Height = 120

    $body.Add_ControlAdded({
        try { Update-KsAuditGroupBoxHeight -GroupBox $this.Parent } catch { }
    })

    $group.Add_Resize({
        try {
            if ($this.Controls.Count -gt 0) {
                $inner = $this.Controls[0]
                $inner.Width = [Math]::Max(220, $this.ClientSize.Width - 18)
                foreach ($row in @($inner.Controls)) {
                    try { $row.Width = [Math]::Max(220, $inner.ClientSize.Width - 8) } catch { }
                }
            }
            Update-KsAuditGroupBoxHeight -GroupBox $this
        } catch { }
    })

    return [pscustomobject]@{
        Group = $group
        Body  = $body
    }
}

function New-KsAuditTwoColumnPage {
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = "Fill"
    $layout.ColumnCount = 2
    $layout.RowCount = 1
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 56)))
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 44)))

    $left = New-KsAuditSectionHost
    $right = New-KsAuditSectionHost
    [void]$layout.Controls.Add($left.Host, 0, 0)
    [void]$layout.Controls.Add($right.Host, 1, 0)

    return [pscustomobject]@{
        Layout     = $layout
        LeftHost   = $left.Host
        LeftStack  = $left.Stack
        RightHost  = $right.Host
        RightStack = $right.Stack
    }
}

function Get-KsAuditTabAggregateStatus([string[]]$Keys) {
    $statuses = New-Object System.Collections.Generic.List[string]

    foreach ($key in @($Keys)) {
        if (-not $statusLabels.ContainsKey($key)) { continue }
        $value = ""
        try { $value = ("" + $statusLabels[$key].Text).Trim().ToUpperInvariant() } catch { $value = "" }
        if ($value -eq "") { $value = "-" }
        $statuses.Add($value) | Out-Null
    }

    if ($statuses.Count -le 0) { return "-" }
    if ($statuses.Contains("FAIL")) { return "FAIL" }
    if ($statuses.Contains("WARN")) { return "WARN" }
    if ($statuses.Contains("PASS")) { return "PASS" }
    if ($statuses.Contains("SKIP")) { return "SKIP" }
    return "-"
}

function Set-KsAuditTabState([System.Windows.Forms.TabPage]$TabPage, [string]$Status, [bool]$Colorize = $true) {
    if ($null -eq $TabPage) { return }

    $baseText = ""
    try {
        if ($null -ne $TabPage.Tag -and ("" + $TabPage.Tag).Trim() -ne "") {
            $baseText = "" + $TabPage.Tag
        } else {
            $baseText = "" + $TabPage.Text
        }
    } catch {
        $baseText = "" + $TabPage.Text
    }

    $value = "-"
    try { $value = ("" + $Status).Trim().ToUpperInvariant() } catch { $value = "-" }
    if ($value -eq "") { $value = "-" }

    try {
        $TabPage.Tag = $baseText
        if ($Colorize -and $value -ne "-") {
            $TabPage.Text = ("[{0}] {1}" -f $value, $baseText)
        } else {
            $TabPage.Text = $baseText
        }
    } catch { }
}

function Update-KsAuditTabStatuses {
    if ($null -eq $tabChecks -or $null -eq $tabSecurity -or $null -eq $tabLogs) { return }

    $checksStatus = Get-KsAuditTabAggregateStatus @(
        'core_routes',
        'core_route_option_scan',
        'core_security_baseline',
        'http_probe',
        'tail_log',
        'routes_verbose',
        'route_list_findstr_admin',
        'superadmin_count',
        'log_snapshot'
    )

    $securityStatus = Get-KsAuditTabAggregateStatus @(
        'login_csrf_probe',
        'role_smoke_test',
        'session_csrf_baseline',
        'security_probe',
        'security_check_ip_ban',
        'security_check_register'
    )

    Set-KsAuditTabState -TabPage $tabChecks -Status $checksStatus -Colorize:$true
    Set-KsAuditTabState -TabPage $tabSecurity -Status $securityStatus -Colorize:$true
    Set-KsAuditTabState -TabPage $tabLogs -Status "-" -Colorize:$false
}

function Show-AuditGui() {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $uiScriptDir = $(if ($script:KsAuditUiScriptRoot) { $script:KsAuditUiScriptRoot } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path })
    $uiProjectRoot = Resolve-Path (Join-Path $uiScriptDir "..\..") | Select-Object -ExpandProperty Path
    Confirm-ProjectRoot $uiProjectRoot

    $displayGuiVersion = $(if ($script:KsAuditGuiVersion -and ("" + $script:KsAuditGuiVersion).Trim() -ne "") { "" + $script:KsAuditGuiVersion } else { "2.1" })

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
    $form.Text = ("KiezSingles Admin Audit v" + $displayGuiVersion)
    $form.Width = 1180
    $form.Height = 860
    $form.StartPosition = "CenterScreen"
    $form.MinimumSize = New-Object System.Drawing.Size(980, 720)
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

    $script:AuditOutputRaw = ""
    $script:AuditOutputViewRaw = ""
    $script:AuditSectionsByKey = @{}
    $script:AuditSelectedKey = ""

    $mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $mainLayout.Dock = "Fill"
    $mainLayout.ColumnCount = 1
    $mainLayout.RowCount = 3
    $mainLayout.Padding = New-Object System.Windows.Forms.Padding(12)
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 268)))
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 0)))
    $form.Controls.Add($mainLayout)

    $headerCard = New-Object System.Windows.Forms.Panel
    $headerCard.Dock = "Fill"
    $headerCard.Padding = New-Object System.Windows.Forms.Padding(16, 14, 16, 14)
    $headerCard.BackColor = [System.Drawing.Color]::White
    $headerCard.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $mainLayout.Controls.Add($headerCard, 0, 0)

    $headerLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $headerLayout.Dock = "Fill"
    $headerLayout.ColumnCount = 2
    $headerLayout.RowCount = 3
    $headerLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $headerLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 360)))
    $headerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 26)))
    $headerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 54)))
    $headerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $headerCard.Controls.Add($headerLayout)

    $lblHeaderTitle = New-Object System.Windows.Forms.Label
    $lblHeaderTitle.AutoSize = $true
    $lblHeaderTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $lblHeaderTitle.Text = "Audit Dashboard"
    $headerLayout.Controls.Add($lblHeaderTitle, 0, 0)

    $lblHeaderHint = New-Object System.Windows.Forms.Label
    $lblHeaderHint.Dock = "Fill"
    $lblHeaderHint.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $lblHeaderHint.Text = "Details nur per Popup"
    $headerLayout.Controls.Add($lblHeaderHint, 1, 0)

    $baseRow = New-Object System.Windows.Forms.Panel
    $baseRow.Dock = "Fill"
    $headerLayout.Controls.Add($baseRow, 0, 1)

    $lblBaseUrlGlobal = New-Object System.Windows.Forms.Label
    $lblBaseUrlGlobal.AutoSize = $true
    $lblBaseUrlGlobal.Text = "Base-URL"
    $lblBaseUrlGlobal.Left = 0
    $lblBaseUrlGlobal.Top = 4
    $baseRow.Controls.Add($lblBaseUrlGlobal)

    $cmbBaseUrl = New-Object System.Windows.Forms.ComboBox
    $cmbBaseUrl.Left = 0
    $cmbBaseUrl.Top = 24
    $cmbBaseUrl.Width = 640
    $cmbBaseUrl.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
    [void]$cmbBaseUrl.Items.Add("http://kiezsingles.test")
    [void]$cmbBaseUrl.Items.Add("https://kiezsingles.de")
    $baseRow.Controls.Add($cmbBaseUrl)
    $initialBaseUrl = ("" + $BaseUrl).Trim()
    if (-not $PSBoundParameters.ContainsKey("BaseUrl")) { $initialBaseUrl = "http://kiezsingles.test" }
    if ($initialBaseUrl -eq "") { $initialBaseUrl = "http://kiezsingles.test" }
    $cmbBaseUrl.Text = $initialBaseUrl
    $baseRow.Add_Resize({ try { $cmbBaseUrl.Width = [Math]::Max(220, $this.ClientSize.Width - 4) } catch { } })

    $actionsCard = New-Object System.Windows.Forms.Panel
    $actionsCard.Dock = "Fill"
    $actionsCard.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $actionsCard.BackColor = [System.Drawing.Color]::FromArgb(249, 250, 251)
    $actionsCard.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
    $headerLayout.Controls.Add($actionsCard, 1, 1)
    $headerLayout.SetRowSpan($actionsCard, 2)

    $actionsLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $actionsLayout.Dock = "Fill"
    $actionsLayout.ColumnCount = 2
    $actionsLayout.RowCount = 7
    $actionsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
    $actionsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
    $actionsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 22)))
    $actionsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
    $actionsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
    $actionsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
    $actionsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
    $actionsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
    $actionsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $actionsCard.Controls.Add($actionsLayout)

    $lblActionsTitle = New-Object System.Windows.Forms.Label
    $lblActionsTitle.AutoSize = $true
    $lblActionsTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblActionsTitle.Text = "Quick Actions"
    $actionsLayout.Controls.Add($lblActionsTitle, 0, 0)

    $lblVersion = New-Object System.Windows.Forms.Label
    $lblVersion.Dock = "Fill"
    $lblVersion.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $lblVersion.ForeColor = [System.Drawing.Color]::DimGray
    $lblVersion.Text = ("Version " + $displayGuiVersion)
    $actionsLayout.Controls.Add($lblVersion, 1, 0)

    $lblRunStatus = New-Object System.Windows.Forms.Label
    $lblRunStatus.Dock = "Fill"
    $lblRunStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $lblRunStatus.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
    $lblRunStatus.Text = "Bereit"
    $actionsLayout.Controls.Add($lblRunStatus, 0, 1)
    $actionsLayout.SetColumnSpan($lblRunStatus, 2)
    $lblRunStatus.Add_TextChanged({
        try {
            $rawText = ("" + $this.Text).Trim()
            $normalized = $rawText -replace '\s*\(ExitCode\s+\d+\)\s*$', ''

            $this.AutoSize = $false
            $this.Height = 20
            $this.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

            switch -Regex ($normalized.ToUpperInvariant()) {
                '^FERTIG' {
                    $this.Text = 'Fertig'
                    $this.ForeColor = [System.Drawing.Color]::FromArgb(32, 96, 40)
                    $this.BackColor = [System.Drawing.Color]::Transparent
                    $this.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
                    break
                }
                '^WARN' {
                    $this.Text = 'Warnung'
                    $this.ForeColor = [System.Drawing.Color]::FromArgb(128, 88, 0)
                    $this.BackColor = [System.Drawing.Color]::Transparent
                    $this.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
                    break
                }
                '^FEHLER' {
                    $this.Text = 'Fehler'
                    $this.ForeColor = [System.Drawing.Color]::FromArgb(150, 32, 32)
                    $this.BackColor = [System.Drawing.Color]::Transparent
                    $this.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
                    break
                }
                '^KRITISCH' {
                    $this.Text = 'Kritisch'
                    $this.ForeColor = [System.Drawing.Color]::FromArgb(120, 16, 16)
                    $this.BackColor = [System.Drawing.Color]::Transparent
                    $this.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
                    break
                }
                default {
                    $this.Text = $(if ($normalized -ne '') { $normalized } else { 'Bereit' })
                    $this.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
                    $this.BackColor = [System.Drawing.Color]::Transparent
                    $this.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
                    break
                }
            }
        } catch { }
    })

    $btnSavePaths = New-Object System.Windows.Forms.Button
    $btnSavePaths.Text = "Save Paths"
    $btnSavePaths.Dock = "Fill"
    $actionsLayout.Controls.Add($btnSavePaths, 0, 2)

    $btnOpenDetails = New-Object System.Windows.Forms.Button
    $btnOpenDetails.Text = "Open Errors"
    $btnOpenDetails.Dock = "Fill"
    $btnOpenDetails.Enabled = $false
    $actionsLayout.Controls.Add($btnOpenDetails, 1, 2)

    $btnShowFullOutput = New-Object System.Windows.Forms.Button
    $btnShowFullOutput.Text = "Open Full Output"
    $btnShowFullOutput.Dock = "Fill"
    $btnShowFullOutput.Enabled = $false
    $actionsLayout.Controls.Add($btnShowFullOutput, 0, 3)
    $actionsLayout.SetColumnSpan($btnShowFullOutput, 2)

    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "Copy Output"
    $btnCopy.Dock = "Fill"
    $btnCopy.Enabled = $false

    $btnStop = New-Object System.Windows.Forms.Button
    $btnStop.Text = "Stop"
    $btnStop.Dock = "Fill"
    $btnStop.BackColor = [System.Drawing.Color]::FromArgb(255, 199, 206)
    $actionsLayout.Controls.Add($btnStop, 0, 4)

    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = "Clear"
    $btnClear.Dock = "Fill"
    $btnClear.BackColor = [System.Drawing.Color]::FromArgb(255, 235, 156)
    $actionsLayout.Controls.Add($btnClear, 1, 4)

    [System.Windows.Forms.Button]$btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = "Run"
    $btnRun.Dock = "Fill"
    $btnRun.BackColor = [System.Drawing.Color]::FromArgb(198, 239, 206)
    $script:btnRun = $btnRun
    $actionsLayout.Controls.Add($btnRun, 0, 5)
    $actionsLayout.SetColumnSpan($btnRun, 2)

    $lblDetailTitle = New-Object System.Windows.Forms.Label
    $lblDetailTitle.Dock = "Fill"
    $lblDetailTitle.Text = "Auswahl: Gesamtausgabe"
    $lblDetailTitle.ForeColor = [System.Drawing.Color]::FromArgb(83, 91, 99)
    $actionsLayout.Controls.Add($lblDetailTitle, 0, 6)
    $actionsLayout.SetColumnSpan($lblDetailTitle, 2)

    $pathsPanel = New-Object System.Windows.Forms.Panel
    $pathsPanel.Dock = "Fill"
    $headerLayout.Controls.Add($pathsPanel, 0, 2)

    $pathsCaption = New-Object System.Windows.Forms.TableLayoutPanel
    $pathsCaption.Dock = "Top"
    $pathsCaption.ColumnCount = 2
    $pathsCaption.RowCount = 1
    $pathsCaption.Height = 20
    $pathsCaption.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $pathsCaption.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 220)))
    $pathsPanel.Controls.Add($pathsCaption)

    $lblProbePaths = New-Object System.Windows.Forms.Label
    $lblProbePaths.AutoSize = $true
    $lblProbePaths.Text = "ProbePaths / RoleSmokePaths (gemeinsam, je Zeile ein relativer Pfad)"
    $pathsCaption.Controls.Add($lblProbePaths, 0, 0)

    $lblPathsHint = New-Object System.Windows.Forms.Label
    $lblPathsHint.Dock = "Fill"
    $lblPathsHint.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $lblPathsHint.Text = "Save Paths schreibt beide Listen"
    $pathsCaption.Controls.Add($lblPathsHint, 1, 0)

    $sharedPaths = New-Object System.Collections.Generic.List[string]
    $sharedSeen = @{}
    foreach ($p in @($ProbePaths) + @($RoleSmokePaths)) {
        $x = ("" + $p).Trim()
        if ($x -eq "" -or $sharedSeen.ContainsKey($x)) { continue }
        $sharedSeen[$x] = $true
        $sharedPaths.Add($x) | Out-Null
    }
    if ($sharedPaths.Count -le 0) {
        foreach ($x in @('/admin','/admin/status','/admin/moderation','/admin/maintenance','/admin/debug','/admin/users','/admin/tickets','/admin/develop')) {
            $sharedPaths.Add($x) | Out-Null
        }
    }

    $txtProbePaths = New-Object System.Windows.Forms.TextBox
    $txtProbePaths.Multiline = $true
    $txtProbePaths.ScrollBars = "Vertical"
    $txtProbePaths.WordWrap = $false
    $txtProbePaths.Dock = "Fill"
    $txtProbePaths.Top = 24
    $txtProbePaths.Height = 130
    $txtProbePaths.Text = (($sharedPaths | ForEach-Object { "" + $_ }) -join "`r`n")
    $pathsPanel.Controls.Add($txtProbePaths)
    $txtProbePaths.BringToFront()

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = "Fill"
    $tabs.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
    $tabs.SizeMode = [System.Windows.Forms.TabSizeMode]::Fixed
    $tabs.ItemSize = New-Object System.Drawing.Size(140, 24)
    $tabs.Add_DrawItem({
        try {
            $tabPage = $this.TabPages[$_.Index]
            $bounds = $this.GetTabRect($_.Index)
            $text = "" + $tabPage.Text
            $font = $this.Font
            $isSelected = (($_.State -band [System.Windows.Forms.DrawItemState]::Selected) -eq [System.Windows.Forms.DrawItemState]::Selected)

            $backColor = $(if ($isSelected) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::FromArgb(246, 247, 249) })
            $foreColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
            $borderColor = [System.Drawing.Color]::FromArgb(210, 214, 219)

            $baseName = $(if ($null -ne $tabPage.Tag -and ("" + $tabPage.Tag).Trim() -ne "") { ("" + $tabPage.Tag).Trim() } else { ("" + $tabPage.Text).Trim() })

            if ($baseName -eq 'Checks') {
                switch -Regex ($text) {
                    '^\[FAIL\]' { $foreColor = [System.Drawing.Color]::FromArgb(150, 32, 32); break }
                    '^\[WARN\]' { $foreColor = [System.Drawing.Color]::FromArgb(128, 88, 0); break }
                    '^\[PASS\]' { $foreColor = [System.Drawing.Color]::FromArgb(28, 120, 52); break }
                    '^\[SKIP\]' { $foreColor = [System.Drawing.Color]::FromArgb(34, 92, 163); break }
                }
            } elseif ($baseName -eq 'Security') {
                switch -Regex ($text) {
                    '^\[FAIL\]' { $foreColor = [System.Drawing.Color]::FromArgb(150, 32, 32); break }
                    '^\[WARN\]' { $foreColor = [System.Drawing.Color]::FromArgb(128, 88, 0); break }
                    '^\[PASS\]' { $foreColor = [System.Drawing.Color]::FromArgb(28, 120, 52); break }
                    '^\[SKIP\]' { $foreColor = [System.Drawing.Color]::FromArgb(34, 92, 163); break }
                }
            }

            $brush = New-Object System.Drawing.SolidBrush($backColor)
            $borderPen = New-Object System.Drawing.Pen($borderColor)
            $_.Graphics.FillRectangle($brush, $bounds)
            $_.Graphics.DrawRectangle($borderPen, $bounds.X, $bounds.Y, $bounds.Width - 1, $bounds.Height - 1)

            $textBounds = New-Object System.Drawing.Rectangle(
                ($bounds.X + 8),
                ($bounds.Y + 2),
                [Math]::Max(4, $bounds.Width - 16),
                [Math]::Max(4, $bounds.Height - 4)
            )

            [System.Windows.Forms.TextRenderer]::DrawText(
                $_.Graphics,
                $text,
                $font,
                $textBounds,
                $foreColor,
                [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
                [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor
                [System.Windows.Forms.TextFormatFlags]::EndEllipsis -bor
                [System.Windows.Forms.TextFormatFlags]::SingleLine
            )

            $brush.Dispose()
            $borderPen.Dispose()
        } catch { }
    })
    $mainLayout.Controls.Add($tabs, 0, 1)

    $tabChecks = New-Object System.Windows.Forms.TabPage
    $tabChecks.Text = "Checks"
    $tabChecks.Tag = "Checks"
    $tabs.TabPages.Add($tabChecks)

    $tabSecurity = New-Object System.Windows.Forms.TabPage
    $tabSecurity.Text = "Security"
    $tabSecurity.Tag = "Security"
    $tabs.TabPages.Add($tabSecurity)

    $tabLogs = New-Object System.Windows.Forms.TabPage
    $tabLogs.Text = "Logs & Export"
    $tabLogs.Tag = "Logs & Export"
    $tabs.TabPages.Add($tabLogs)

    $checksPage = New-KsAuditTwoColumnPage
    $tabChecks.Controls.Add($checksPage.Layout)
    $securityPage = New-KsAuditTwoColumnPage
    $tabSecurity.Controls.Add($securityPage.Layout)
    $logsHost = New-KsAuditSectionHost
    $tabLogs.Controls.Add($logsHost.Host)

    $footerPanel = New-Object System.Windows.Forms.Panel
    $footerPanel.Dock = "Fill"
    $footerPanel.Visible = $false
    $mainLayout.Controls.Add($footerPanel, 0, 2)
    $lblStatus = $lblRunStatus

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
    Set-KsAuditFixedCheckStyle -CheckBox $chkCoreRoutes

    $chkCoreRouteOptionScan = New-Object System.Windows.Forms.CheckBox
    $chkCoreRouteOptionScan.Text = "Core: Route:list option scan"
    $chkCoreRouteOptionScan.Checked = $true
    $chkCoreRouteOptionScan.AutoCheck = $false
    Set-KsAuditFixedCheckStyle -CheckBox $chkCoreRouteOptionScan

    $chkCoreSecurityBaseline = New-Object System.Windows.Forms.CheckBox
    $chkCoreSecurityBaseline.Text = "Core: Security / abuse protection"
    $chkCoreSecurityBaseline.Checked = $true
    $chkCoreSecurityBaseline.AutoCheck = $false
    Set-KsAuditFixedCheckStyle -CheckBox $chkCoreSecurityBaseline

    $chkHttpProbe = New-Object System.Windows.Forms.CheckBox
    $chkHttpProbe.Text = "HTTPProbe"
    $chkHttpProbe.Checked = [bool]$HttpProbe
    $chkTailLog = New-Object System.Windows.Forms.CheckBox
    $chkTailLog.Text = "TailLog"
    $chkTailLog.Checked = [bool]$TailLog
    $lblTailMode = New-Object System.Windows.Forms.Label
    $lblTailMode.Text = "TailLog-Modus"
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
    $btnSaveSuperadmin.Text = 'Save'
    $btnClearSuperadmin = New-Object System.Windows.Forms.Button
    $btnClearSuperadmin.Text = 'Clear'
    $lblAdminEmail = New-Object System.Windows.Forms.Label
    $txtAdminEmail = New-Object System.Windows.Forms.TextBox
    $txtAdminEmail.Text = ("" + $AdminEmail)
    $txtAdminPassword = New-Object System.Windows.Forms.TextBox
    $txtAdminPassword.UseSystemPasswordChar = $true
    $txtAdminPassword.Text = ("" + $AdminPassword)
    $btnSaveAdmin = New-Object System.Windows.Forms.Button
    $btnSaveAdmin.Text = 'Save'
    $btnClearAdmin = New-Object System.Windows.Forms.Button
    $btnClearAdmin.Text = 'Clear'
    $lblModeratorEmail = New-Object System.Windows.Forms.Label
    $txtModeratorEmail = New-Object System.Windows.Forms.TextBox
    $txtModeratorEmail.Text = ("" + $ModeratorEmail)
    $txtModeratorPassword = New-Object System.Windows.Forms.TextBox
    $txtModeratorPassword.UseSystemPasswordChar = $true
    $txtModeratorPassword.Text = ("" + $ModeratorPassword)
    $btnSaveModerator = New-Object System.Windows.Forms.Button
    $btnSaveModerator.Text = 'Save'
    $btnClearModerator = New-Object System.Windows.Forms.Button
    $btnClearModerator.Text = 'Clear'

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

    $statusLabels = @{
        core_routes = (New-AuditStatusLabel 'core_routes')
        core_route_option_scan = (New-AuditStatusLabel 'core_route_option_scan')
        core_security_baseline = (New-AuditStatusLabel 'core_security_baseline')
        http_probe = (New-AuditStatusLabel 'http_probe')
        tail_log = (New-AuditStatusLabel 'tail_log')
        routes_verbose = (New-AuditStatusLabel 'routes_verbose')
        route_list_findstr_admin = (New-AuditStatusLabel 'route_list_findstr_admin')
        superadmin_count = (New-AuditStatusLabel 'superadmin_count')
        log_snapshot = (New-AuditStatusLabel 'log_snapshot')
        login_csrf_probe = (New-AuditStatusLabel 'login_csrf_probe')
        role_smoke_test = (New-AuditStatusLabel 'role_smoke_test')
        session_csrf_baseline = (New-AuditStatusLabel 'session_csrf_baseline')
        security_probe = (New-AuditStatusLabel 'security_probe')
        security_check_ip_ban = (New-AuditStatusLabel 'security_check_ip_ban')
        security_check_register = (New-AuditStatusLabel 'security_check_register')
        show_check_details = (New-AuditStatusLabel 'show_check_details')
        export_logs = (New-AuditStatusLabel 'export_logs')
        auto_open_export_folder = (New-AuditStatusLabel 'auto_open_export_folder')
        log_clear_before = (New-AuditStatusLabel 'log_clear_before')
        log_clear_after = (New-AuditStatusLabel 'log_clear_after')
    }
    $checkMap = @{
        core_routes = $chkCoreRoutes
        core_route_option_scan = $chkCoreRouteOptionScan
        core_security_baseline = $chkCoreSecurityBaseline
        http_probe = $chkHttpProbe
        tail_log = $chkTailLog
        routes_verbose = $chkRoutesVerbose
        route_list_findstr_admin = $chkRouteListFindstrAdmin
        superadmin_count = $chkSuperadminCount
        log_snapshot = $cmbLaravelLogHistory
        login_csrf_probe = $chkLoginCsrfProbe
        role_smoke_test = $chkRoleSmokeTest
        session_csrf_baseline = $chkSessionCsrfBaseline
        security_probe = $chkSecurityProbe
        security_check_ip_ban = $chkSecurityCheckIpBan
        security_check_register = $chkSecurityCheckRegister
        show_check_details = $chkShowCheckDetails
        export_logs = $chkExportLogs
        auto_open_export_folder = $chkAutoOpenExportFolder
        log_clear_before = $chkLogClearBefore
        log_clear_after = $chkLogClearAfter
    }

    $grpCore = New-KsAuditGroupBox 'Core Checks'
    Add-KsAuditStackRow $checksPage.LeftStack $grpCore.Group
    Add-KsAuditStackRow $grpCore.Body (New-KsAuditStatusRow -Content $chkCoreRoutes -StatusLabel $statusLabels['core_routes'] -Height 30)
    Add-KsAuditStackRow $grpCore.Body (New-KsAuditStatusRow -Content $chkCoreRouteOptionScan -StatusLabel $statusLabels['core_route_option_scan'] -Height 30)
    Add-KsAuditStackRow $grpCore.Body (New-KsAuditStatusRow -Content $chkCoreSecurityBaseline -StatusLabel $statusLabels['core_security_baseline'] -Height 30)

    $grpHttpRoutes = New-KsAuditGroupBox 'HTTP / Routes'
    Add-KsAuditStackRow $checksPage.LeftStack $grpHttpRoutes.Group
    Add-KsAuditStackRow $grpHttpRoutes.Body (New-KsAuditStatusRow -Content $chkHttpProbe -StatusLabel $statusLabels['http_probe'] -Height 30)
    Add-KsAuditStackRow $grpHttpRoutes.Body (New-KsAuditStatusRow -Content $chkRoutesVerbose -StatusLabel $statusLabels['routes_verbose'] -Height 30)
    Add-KsAuditStackRow $grpHttpRoutes.Body (New-KsAuditStatusRow -Content $chkRouteListFindstrAdmin -StatusLabel $statusLabels['route_list_findstr_admin'] -Height 30)

    $grpAuditOps = New-KsAuditGroupBox 'Audit Operations'
    Add-KsAuditStackRow $checksPage.RightStack $grpAuditOps.Group
    Add-KsAuditStackRow $grpAuditOps.Body (New-KsAuditStatusRow -Content $chkTailLog -StatusLabel $statusLabels['tail_log'] -Height 30)
    Add-KsAuditStackRow $grpAuditOps.Body (New-KsAuditLabeledFieldRow -LabelText 'TailLog-Modus' -Field $cmbTailMode -Height 56)
    Add-KsAuditStackRow $grpAuditOps.Body (New-KsAuditStatusRow -Content $chkSuperadminCount -StatusLabel $statusLabels['superadmin_count'] -Height 30)
    Add-KsAuditStackRow $grpAuditOps.Body (New-KsAuditLabeledFieldRow -LabelText 'Laravel Log Snapshot / History' -Field $cmbLaravelLogHistory -StatusLabel $statusLabels['log_snapshot'] -Height 56)

    $grpChecksHint = New-KsAuditGroupBox 'Popup Output'
    Add-KsAuditStackRow $checksPage.RightStack $grpChecksHint.Group
    $lblPopupHint = New-Object System.Windows.Forms.Label
    $lblPopupHint.AutoSize = $true
    $lblPopupHint.Text = "Open Errors zeigt den ausgewaehlten Check. Open Full Output zeigt die gesamte Audit-Ausgabe."
    Add-KsAuditStackRow $grpChecksHint.Body $lblPopupHint

    $grpSecurity = New-KsAuditGroupBox 'Security Checks'
    Add-KsAuditStackRow $securityPage.LeftStack $grpSecurity.Group
    Add-KsAuditStackRow $grpSecurity.Body (New-KsAuditStatusRow -Content $chkLoginCsrfProbe -StatusLabel $statusLabels['login_csrf_probe'] -Height 30)
    Add-KsAuditStackRow $grpSecurity.Body (New-KsAuditStatusRow -Content $chkRoleSmokeTest -StatusLabel $statusLabels['role_smoke_test'] -Height 30)
    Add-KsAuditStackRow $grpSecurity.Body (New-KsAuditStatusRow -Content $chkSessionCsrfBaseline -StatusLabel $statusLabels['session_csrf_baseline'] -Height 30)
    Add-KsAuditStackRow $grpSecurity.Body (New-KsAuditStatusRow -Content $chkSecurityProbe -StatusLabel $statusLabels['security_probe'] -Height 30)
    Add-KsAuditStackRow $grpSecurity.Body (New-KsAuditLabeledFieldRow -LabelText 'SecurityLoginAttempts' -Field $cmbSecurityLoginAttempts -Height 56)
    Add-KsAuditStackRow $grpSecurity.Body (New-KsAuditStatusRow -Content $chkSecurityCheckIpBan -StatusLabel $statusLabels['security_check_ip_ban'] -Height 30)
    Add-KsAuditStackRow $grpSecurity.Body (New-KsAuditStatusRow -Content $chkSecurityCheckRegister -StatusLabel $statusLabels['security_check_register'] -Height 30)

    $grpCreds = New-KsAuditGroupBox 'Credentials'
    Add-KsAuditStackRow $securityPage.RightStack $grpCreds.Group
    Add-KsAuditStackRow $grpCreds.Body $lblRoleCreds
    Add-KsAuditStackRow $grpCreds.Body (New-KsAuditCredentialRow -LabelText 'Superadmin' -EmailBox $txtSuperadminEmail -PasswordBox $txtSuperadminPassword -SaveButton $btnSaveSuperadmin -ClearButton $btnClearSuperadmin)
    Add-KsAuditStackRow $grpCreds.Body (New-KsAuditCredentialRow -LabelText 'Admin' -EmailBox $txtAdminEmail -PasswordBox $txtAdminPassword -SaveButton $btnSaveAdmin -ClearButton $btnClearAdmin)
    Add-KsAuditStackRow $grpCreds.Body (New-KsAuditCredentialRow -LabelText 'Moderator' -EmailBox $txtModeratorEmail -PasswordBox $txtModeratorPassword -SaveButton $btnSaveModerator -ClearButton $btnClearModerator)

    $grpLogs = New-KsAuditGroupBox 'Logs & Export'
    Add-KsAuditStackRow $logsHost.Stack $grpLogs.Group
    Add-KsAuditStackRow $grpLogs.Body (New-KsAuditStatusRow -Content $chkLogClearBefore -StatusLabel $statusLabels['log_clear_before'] -Height 30)
    Add-KsAuditStackRow $grpLogs.Body (New-KsAuditStatusRow -Content $chkLogClearAfter -StatusLabel $statusLabels['log_clear_after'] -Height 30)
    Add-KsAuditStackRow $grpLogs.Body (New-KsAuditStatusRow -Content $chkShowCheckDetails -StatusLabel $statusLabels['show_check_details'] -Height 30)
    Add-KsAuditStackRow $grpLogs.Body (New-KsAuditStatusRow -Content $chkExportLogs -StatusLabel $statusLabels['export_logs'] -Height 30)
    Add-KsAuditStackRow $grpLogs.Body (New-KsAuditLabeledFieldRow -LabelText 'ExportLogsLines' -Field $cmbExportLogsLines -Height 56)
    Add-KsAuditStackRow $grpLogs.Body (New-KsAuditStatusRow -Content $chkAutoOpenExportFolder -StatusLabel $statusLabels['auto_open_export_folder'] -Height 30)

    function Register-AuditDetailBinding([System.Windows.Forms.Control]$Control, [string]$Key) {
        if ($null -eq $Control) { return }
        $Control.Tag = $Key
        try { $Control.Add_Click({ try { Select-AuditDetail ([string]$this.Tag) } catch { } }) } catch { }
    }

    foreach ($entry in $statusLabels.GetEnumerator()) {
        $entry.Value.Cursor = [System.Windows.Forms.Cursors]::Hand
        Set-KsAuditStatusLabelVisual -Label $entry.Value
        $entry.Value.Add_Click({ try { Select-AuditDetail ([string]$this.Tag) } catch { } })
        $entry.Value.Add_TextChanged({
            try {
                Set-KsAuditStatusLabelVisual -Label $this
                Update-KsAuditTabStatuses
            } catch { }
        })
    }

    foreach ($binding in @(
        @($chkCoreRoutes,'core_routes'),
        @($chkCoreRouteOptionScan,'core_route_option_scan'),
        @($chkCoreSecurityBaseline,'core_security_baseline'),
        @($chkHttpProbe,'http_probe'),
        @($chkTailLog,'tail_log'),
        @($chkRoutesVerbose,'routes_verbose'),
        @($chkRouteListFindstrAdmin,'route_list_findstr_admin'),
        @($chkSuperadminCount,'superadmin_count'),
        @($cmbLaravelLogHistory,'log_snapshot'),
        @($chkLoginCsrfProbe,'login_csrf_probe'),
        @($chkRoleSmokeTest,'role_smoke_test'),
        @($chkSessionCsrfBaseline,'session_csrf_baseline'),
        @($chkSecurityProbe,'security_probe'),
        @($chkSecurityCheckIpBan,'security_check_ip_ban'),
        @($chkSecurityCheckRegister,'security_check_register'),
        @($chkShowCheckDetails,'show_check_details'),
        @($chkExportLogs,'export_logs'),
        @($chkAutoOpenExportFolder,'auto_open_export_folder'),
        @($chkLogClearBefore,'log_clear_before'),
        @($chkLogClearAfter,'log_clear_after')
    )) {
        Register-AuditDetailBinding $binding[0] $binding[1]
    }

    $candidate = Join-Path $uiScriptDir 'ks-admin-audit.ps1'
    if (-not (Test-Path -LiteralPath $candidate)) { throw ('CLI core not found next to UI: ' + $candidate) }
    $corePath = $candidate

    $script:form = $form; $script:uiProjectRoot = $uiProjectRoot; $script:uiPathsConfigFile = $uiPathsConfigFile; $script:uiCredsConfigFile = $uiCredsConfigFile; $script:corePath = $corePath; $script:statusLabels = $statusLabels; $script:checkMap = $checkMap
    $script:txt = $txt; $script:txtFilter = $txtFilter; $script:chkFilterIgnoreCase = $chkFilterIgnoreCase; $script:chkFilterRegex = $chkFilterRegex; $script:lblFilterStatus = $lblFilterStatus; $script:lblDetailTitle = $lblDetailTitle; $script:lblStatus = $lblStatus
    $script:btnCopy = $btnCopy; $script:btnRun = $btnRun; $script:btnClear = $btnClear; $script:btnStop = $btnStop; $script:btnSavePaths = $btnSavePaths; $script:btnOpenDetails = $btnOpenDetails; $script:btnShowFullOutput = $btnShowFullOutput
    $script:lblProbePaths = $lblProbePaths; $script:txtProbePaths = $txtProbePaths; $script:cmbBaseUrl = $cmbBaseUrl; $script:chkHttpProbe = $chkHttpProbe; $script:chkTailLog = $chkTailLog; $script:lblTailMode = $lblTailMode; $script:cmbTailMode = $cmbTailMode; $script:chkRoutesVerbose = $chkRoutesVerbose; $script:chkRouteListFindstrAdmin = $chkRouteListFindstrAdmin; $script:chkSuperadminCount = $chkSuperadminCount; $script:cmbLaravelLogHistory = $cmbLaravelLogHistory
    $script:chkLoginCsrfProbe = $chkLoginCsrfProbe; $script:chkRoleSmokeTest = $chkRoleSmokeTest; $script:chkSessionCsrfBaseline = $chkSessionCsrfBaseline; $script:chkSecurityProbe = $chkSecurityProbe; $script:chkSecurityCheckIpBan = $chkSecurityCheckIpBan; $script:chkSecurityCheckRegister = $chkSecurityCheckRegister; $script:cmbSecurityLoginAttempts = $cmbSecurityLoginAttempts
    $script:lblRoleCreds = $lblRoleCreds; $script:lblSuperadminEmail = $lblSuperadminEmail; $script:txtSuperadminEmail = $txtSuperadminEmail; $script:txtSuperadminPassword = $txtSuperadminPassword; $script:btnSaveSuperadmin = $btnSaveSuperadmin; $script:btnClearSuperadmin = $btnClearSuperadmin; $script:lblAdminEmail = $lblAdminEmail; $script:txtAdminEmail = $txtAdminEmail; $script:txtAdminPassword = $txtAdminPassword; $script:btnSaveAdmin = $btnSaveAdmin; $script:btnClearAdmin = $btnClearAdmin; $script:lblModeratorEmail = $lblModeratorEmail; $script:txtModeratorEmail = $txtModeratorEmail; $script:txtModeratorPassword = $txtModeratorPassword; $script:btnSaveModerator = $btnSaveModerator; $script:btnClearModerator = $btnClearModerator
    $script:chkLogClearBefore = $chkLogClearBefore; $script:chkLogClearAfter = $chkLogClearAfter; $script:chkShowCheckDetails = $chkShowCheckDetails; $script:chkExportLogs = $chkExportLogs; $script:cmbExportLogsLines = $cmbExportLogsLines; $script:chkAutoOpenExportFolder = $chkAutoOpenExportFolder
    $script:tabChecks = $tabChecks; $script:tabSecurity = $tabSecurity; $script:tabLogs = $tabLogs

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
    $btnStop.Add_Click({
        try {
            $killed = 0
            $coreNeedle = ("" + $script:corePath).Trim().ToLowerInvariant()
            $uiRunContext = $null
            $hadUiRunContext = $false

            try {
                $ctxVar = Get-Variable -Scope Script -Name UiAuditRunContext -ErrorAction SilentlyContinue
                if ($null -ne $ctxVar) { $uiRunContext = $ctxVar.Value }
            } catch { $uiRunContext = $null }
            try { $hadUiRunContext = ($null -ne $uiRunContext) } catch { $hadUiRunContext = $false }

            try {
                if ($null -ne $uiRunContext) {
                    if ($null -ne $uiRunContext.Timer) {
                        $uiRunContext.Timer.Stop()
                        $uiRunContext.Timer.Dispose()
                    }
                }
            } catch { }

            try {
                if ($null -ne $uiRunContext) {
                    if ($null -ne $uiRunContext.Process) {
                        if (-not $uiRunContext.Process.HasExited) {
                            $uiRunContext.Process.Kill($true)
                            $killed++
                        }
                    }
                }
            } catch { }

            try { $script:UiAuditRunContext = $null } catch { }

            try {
                $procs = @(Get-CimInstance Win32_Process -Filter "name = 'powershell.exe' OR name = 'pwsh.exe'" -ErrorAction Stop)
            } catch {
                $procs = @()
            }

            foreach ($proc in @($procs)) {
                $cmdLine = ""
                try { $cmdLine = ("" + $proc.CommandLine).Trim().ToLowerInvariant() } catch { $cmdLine = "" }
                if ($cmdLine -eq "") { continue }
                if ($coreNeedle -eq "") { continue }
                if ($cmdLine.Contains($coreNeedle)) {
                    try {
                        Stop-Process -Id ([int]$proc.ProcessId) -Force -ErrorAction Stop
                        $killed++
                    } catch { }
                }
            }

            if ($killed -gt 0 -or $hadUiRunContext) {
                try { $txt.Clear() } catch { }
                try { $txtFilter.Text = "" } catch { }
                try { $lblFilterStatus.Text = "" } catch { }
                try { $script:AuditOutputRaw = "" } catch { }
                try { $script:AuditOutputViewRaw = "" } catch { }
                try { $script:AuditSectionsByKey = @{} } catch { }
                try { $script:AuditSelectedKey = "" } catch { }
                try { Reset-AuditStatuses } catch { }
                try { $btnRun.Enabled = $true } catch { }
                try { $btnCopy.Enabled = $false } catch { }
                try { $lblDetailTitle.Text = "Detailansicht: Gesamtausgabe" } catch { }
                try { Sync-OutputPopupButtons } catch { }
                if ($killed -gt 0) {
                    $lblStatus.Text = ("Audit gestoppt ({0} Prozess(e) beendet)" -f $killed)
                } else {
                    $lblStatus.Text = "Audit gestoppt"
                }
            } else {
                $lblStatus.Text = "Kein laufender Audit-Prozess gefunden"
            }
        } catch {
            $lblStatus.Text = ('Stop fehlgeschlagen: ' + $_.Exception.Message)
        }
    })
    $chkFilterIgnoreCase.Add_CheckedChanged({ try { Set-OutputFilterView } catch { } })
    $chkFilterRegex.Add_CheckedChanged({ try { Set-OutputFilterView } catch { } })
    $tabs.Add_SelectedIndexChanged({
        try { Update-KsAuditStackLayout -Container $checksPage.LeftStack } catch { }
        try { Update-KsAuditStackLayout -Container $checksPage.RightStack } catch { }
        try { Update-KsAuditStackLayout -Container $securityPage.LeftStack } catch { }
        try { Update-KsAuditStackLayout -Container $securityPage.RightStack } catch { }
        try { Update-KsAuditStackLayout -Container $logsHost.Stack } catch { }
        try { Update-KsAuditTabStatuses } catch { }
    })
    $form.Add_Shown({
        try { Update-KsAuditStackLayout -Container $checksPage.LeftStack } catch { }
        try { Update-KsAuditStackLayout -Container $checksPage.RightStack } catch { }
        try { Update-KsAuditStackLayout -Container $securityPage.LeftStack } catch { }
        try { Update-KsAuditStackLayout -Container $securityPage.RightStack } catch { }
        try { Update-KsAuditStackLayout -Container $logsHost.Stack } catch { }
        try { Sync-OutputPopupButtons } catch { }
        try { Update-KsAuditTabStatuses } catch { }
    })

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
