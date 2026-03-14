# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ui\ks-admin-audit-ui-popups.ps1
# Purpose: Popup/viewer helper functions for ks-admin-audit-ui
# Created: 14-03-2026 02:31 (Europe/Berlin)
# Changed: 14-03-2026 02:31 (Europe/Berlin)
# Version: 0.1
# =============================================================================

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
            return
        }

        $raw = Add-TopPaddingLine $raw

        if ($q -eq "") {
            $txt.Text = $raw
            $lblFilterStatus.Text = ""
            Reset-Highlighting
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
    } catch {
        # ignore
    }
}
