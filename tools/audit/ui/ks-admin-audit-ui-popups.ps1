# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ui\ks-admin-audit-ui-popups.ps1
# Purpose: Popup/viewer helper functions for ks-admin-audit-ui
# Created: 14-03-2026 02:31 (Europe/Berlin)
# Changed: 14-03-2026 03:55 (Europe/Berlin)
# Version: 0.2
# =============================================================================

function Show-AuditTextPopup([string]$Title, [string]$Body) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $popup = New-Object System.Windows.Forms.Form
    $popup.Text = $Title
    $popup.Width = 1040
    $popup.Height = 760
    $popup.StartPosition = "CenterParent"
    $popup.MinimumSize = New-Object System.Drawing.Size(760, 520)

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = "Fill"
    $layout.ColumnCount = 1
    $layout.RowCount = 2
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 44)))
    $popup.Controls.Add($layout)

    $viewer = New-Object System.Windows.Forms.RichTextBox
    $viewer.Dock = "Fill"
    $viewer.ReadOnly = $true
    $viewer.WordWrap = $false
    $viewer.ScrollBars = "Both"
    $viewer.Font = New-Object System.Drawing.Font("Consolas", 9)
    $viewer.Text = (Add-TopPaddingLine (ConvertTo-NormalizedText $Body))
    $layout.Controls.Add($viewer, 0, 0)

    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Dock = "Fill"
    $layout.Controls.Add($buttonPanel, 0, 1)

    $btnClosePopup = New-Object System.Windows.Forms.Button
    $btnClosePopup.Text = "Close"
    $btnClosePopup.Width = 90
    $btnClosePopup.Height = 28
    $btnClosePopup.Top = 8
    $buttonPanel.Controls.Add($btnClosePopup)

    $btnCopyPopup = New-Object System.Windows.Forms.Button
    $btnCopyPopup.Text = "Copy"
    $btnCopyPopup.Width = 90
    $btnCopyPopup.Height = 28
    $btnCopyPopup.Top = 8
    $buttonPanel.Controls.Add($btnCopyPopup)

    $buttonPanel.Add_Resize({
        try {
            $btnClosePopup.Left = $this.ClientSize.Width - $btnClosePopup.Width - 8
            $btnCopyPopup.Left = $btnClosePopup.Left - $btnCopyPopup.Width - 8
        } catch { }
    })
    try { $btnClosePopup.Left = $buttonPanel.ClientSize.Width - $btnClosePopup.Width - 8 } catch { }
    try { $btnCopyPopup.Left = $btnClosePopup.Left - $btnCopyPopup.Width - 8 } catch { }

    $btnCopyPopup.Add_Click({
        try { Set-Clipboard -Value $viewer.Text } catch { }
    })
    $btnClosePopup.Add_Click({ $popup.Close() })

    [void]$popup.ShowDialog($form)
}

function Sync-OutputPopupButtons {
    $hasAnyOutput = $false
    $hasDetailOutput = $false

    try { $hasAnyOutput = (("" + $script:AuditOutputRaw).Trim() -ne "") } catch { $hasAnyOutput = $false }
    try { $hasDetailOutput = (("" + $script:AuditOutputViewRaw).Trim() -ne "") } catch { $hasDetailOutput = $false }

    try { if ($btnOpenDetails) { $btnOpenDetails.Enabled = $hasDetailOutput } } catch { }
    try { if ($btnShowFullOutput) { $btnShowFullOutput.Enabled = $hasAnyOutput } } catch { }
}

function Open-AuditDetailPopup {
    $title = "Audit Details"
    $body = ""

    try { $title = ("" + $lblDetailTitle.Text).Trim() } catch { $title = "Audit Details" }
    try { $body = "" + $script:AuditOutputViewRaw } catch { $body = "" }
    if ($body.Trim() -eq "") {
        try { $body = "" + $script:AuditOutputRaw } catch { $body = "" }
    }
    if ($body.Trim() -eq "") { return }

    Show-AuditTextPopup -Title $title -Body $body
}

function Open-AuditFullOutputPopup {
    $body = ""
    try { $body = "" + $script:AuditOutputRaw } catch { $body = "" }
    if ($body.Trim() -eq "") { return }

    Show-AuditTextPopup -Title "Audit Full Output" -Body $body
}

function Select-AuditDetail([string]$Key) {
    $targetKey = ""
    try { $targetKey = ("" + $Key).Trim() } catch { $targetKey = "" }
    if ($targetKey -ne "" -and $script:AuditSectionsByKey.ContainsKey($targetKey)) {
        $script:AuditSelectedKey = $targetKey
        $script:AuditOutputViewRaw = "" + $script:AuditSectionsByKey[$targetKey]
        $detailName = $targetKey
        try {
            if ($checkMap.ContainsKey($targetKey)) {
                $detailName = ("" + $checkMap[$targetKey].Text).Trim()
            }
        } catch { $detailName = $targetKey }
        $lblDetailTitle.Text = ("Detailansicht: " + $detailName)
    } else {
        $script:AuditSelectedKey = ""
        $script:AuditOutputViewRaw = "" + $script:AuditOutputRaw
        $lblDetailTitle.Text = "Detailansicht: Gesamtausgabe"
    }
    Set-OutputFilterView
    Sync-OutputPopupButtons
}

function Add-TopPaddingLine([string]$s) {
    try {
        if ($null -eq $s) { return "" }
        $t = "" + $s
        if ($t -eq "") { return "" }
        if ($t.StartsWith("`r`n")) { return $t }
        return ("`r`n" + $t)
    } catch {
        try { return ("`r`n" + ("" + $s)) } catch { return "" }
    }
}

function Reset-Highlighting {
    try {
        $txt.SuspendLayout()
        $txt.SelectAll()
        $txt.SelectionBackColor = $txt.BackColor
        $txt.SelectionColor = $txt.ForeColor
        $txt.Select(0, 0)
        $txt.ScrollToCaret()
    } catch {
        # ignore
    } finally {
        try { $txt.ResumeLayout() } catch { }
    }
}

function Set-MatchHighlighting([string]$query, [bool]$ignoreCase, [bool]$useRegex) {
    try {
        if ($null -eq $query) { return }
        $q = ("" + $query).Trim()
        if ($q -eq "") { return }

        if ($useRegex -and $q.Contains("|")) { return }
        if ($useRegex -and $q.Contains(",")) {
            $parts = @($q -split "\s*,\s*" | Where-Object { ("" + $_).Trim() -ne "" })
            if ($parts.Count -gt 0) { $q = ($parts -join "|") }
        }

        $text = ""
        try { $text = "" + $txt.Text } catch { $text = "" }
        if ($text -eq "") { return }

        $txt.SuspendLayout()
        Reset-Highlighting

        if ($useRegex) {
            $opts = [System.Text.RegularExpressions.RegexOptions]::None
            if ($ignoreCase) { $opts = $opts -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }

            $rx = $null
            try { $rx = [System.Text.RegularExpressions.Regex]::new($q, $opts) } catch { return }

            $rxMatches = $null
            try { $rxMatches = $rx.Matches($text) } catch { $rxMatches = $null }
            if ($null -eq $rxMatches) { return }

            foreach ($m in $rxMatches) {
                if ($null -eq $m) { continue }
                $idx = 0
                $len = 0
                try { $idx = [int]$m.Index } catch { $idx = 0 }
                try { $len = [int]$m.Length } catch { $len = 0 }
                if ($len -le 0) { continue }

                try {
                    $txt.Select($idx, $len)
                    $txt.SelectionBackColor = [System.Drawing.SystemColors]::Highlight
                    $txt.SelectionColor = [System.Drawing.SystemColors]::HighlightText
                } catch { }
            }
        } else {
            $comparison = [System.StringComparison]::Ordinal
            if ($ignoreCase) { $comparison = [System.StringComparison]::OrdinalIgnoreCase }

            $start = 0
            while ($true) {
                $pos = -1
                try { $pos = $text.IndexOf($q, $start, $comparison) } catch { $pos = -1 }
                if ($pos -lt 0) { break }

                try {
                    $txt.Select($pos, $q.Length)
                    $txt.SelectionBackColor = [System.Drawing.SystemColors]::Highlight
                    $txt.SelectionColor = [System.Drawing.SystemColors]::HighlightText
                } catch { }

                $start = $pos + [Math]::Max(1, $q.Length)
                if ($start -ge $text.Length) { break }
            }
        }

        $txt.Select(0, 0)
        $txt.ScrollToCaret()
    } catch {
        # ignore
    } finally {
        try { $txt.ResumeLayout() } catch { }
    }
}

function Set-OutputFilterView {
    try {
        $raw = ""
        try { $raw = "" + $script:AuditOutputViewRaw } catch { $raw = "" }

        $q = ""
        try { $q = ("" + $txtFilter.Text).Trim() } catch { $q = "" }

        if ($raw -eq "") {
            $txt.Text = ""
            $lblFilterStatus.Text = ""
            Sync-OutputPopupButtons
            return
        }

        $raw = Add-TopPaddingLine $raw

        if ($q -eq "") {
            $txt.Text = $raw
            $lblFilterStatus.Text = ""
            Reset-Highlighting
            Sync-OutputPopupButtons
            return
        }

        $ignoreCase = $true
        try { $ignoreCase = [bool]$chkFilterIgnoreCase.Checked } catch { $ignoreCase = $true }

        $useRegex = $false
        try { $useRegex = [bool]$chkFilterRegex.Checked } catch { $useRegex = $false }

        if ($useRegex -and $q.Contains("|")) {
            $txt.Text = $raw
            $lblFilterStatus.Text = "Bitte Komma statt | verwenden (z.B. fail,error,419)"
            Reset-Highlighting
            return
        }

        if ($useRegex -and $q.Contains(",")) {
            $parts = @($q -split "\s*,\s*" | Where-Object { ("" + $_).Trim() -ne "" })
            if ($parts.Count -gt 0) { $q = ($parts -join "|") }
        }

        $matched = 0
        $total = 0
        try {
            $allText = "" + $raw
            if ($allText -ne "") {
                $total = [int](($allText -split "`r`n").Count)
            }
        } catch { $total = 0 }

        $txt.Text = $raw

        if ($useRegex) {
            $opts = [System.Text.RegularExpressions.RegexOptions]::None
            if ($ignoreCase) { $opts = $opts -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }

            $rx = $null
            try {
                $rx = [System.Text.RegularExpressions.Regex]::new($q, $opts)
            } catch {
                $lblFilterStatus.Text = "Ungueltiger Regex"
                Reset-Highlighting
                return
            }

            try { $matched = [int]$rx.Matches($raw).Count } catch { $matched = 0 }
        } else {
            $comparison = [System.StringComparison]::Ordinal
            if ($ignoreCase) { $comparison = [System.StringComparison]::OrdinalIgnoreCase }

            $start = 0
            while ($true) {
                $pos = -1
                try { $pos = $raw.IndexOf($q, $start, $comparison) } catch { $pos = -1 }
                if ($pos -lt 0) { break }
                $matched++
                $start = $pos + [Math]::Max(1, $q.Length)
                if ($start -ge $raw.Length) { break }
            }
        }

        if ($matched -le 0) {
            $lblFilterStatus.Text = ("Treffer: 0 / " + $total + " (keine Treffer)")
            Reset-Highlighting
            return
        }

        $lblFilterStatus.Text = ("Treffer: " + $matched + " / " + $total)

        Set-MatchHighlighting -query $q -ignoreCase $ignoreCase -useRegex $useRegex
    } catch {
        try { $txt.Text = Add-TopPaddingLine ("" + $script:AuditOutputViewRaw) } catch { }
        try { $lblFilterStatus.Text = "" } catch { }
        try { Reset-Highlighting } catch { }
        try { Sync-OutputPopupButtons } catch { }
    }
}

function Copy-AuditViewerOutput {
    try {
        Set-Clipboard -Value $txt.Text
        $lblStatus.Text = "Ausgabe kopiert"
    } catch {
        $lblStatus.Text = ("Kopieren fehlgeschlagen: " + $_.Exception.Message)
    }
}

function Clear-AuditViewerOutput {
    try {
        $txt.Clear()
        $txtFilter.Text = ""
        $lblFilterStatus.Text = ""
        $script:AuditOutputRaw = ""
        $script:AuditOutputViewRaw = ""
        $script:AuditSectionsByKey = @{}
        $script:AuditSelectedKey = ""
        Reset-AuditStatuses
        $btnCopy.Enabled = $false
        $lblStatus.Text = ""
        $lblDetailTitle.Text = "Detailansicht: Gesamtausgabe"
        Sync-OutputPopupButtons
    } catch {
        # ignore
    }
}
