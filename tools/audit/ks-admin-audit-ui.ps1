# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit-ui.ps1
# Purpose: Repeatable admin/backend audit (routes, duplicates, inline HTML/Blade, role checks, DB sanity, optional HTTP traces)
# Created: 19-02-2026 17:25 (Europe/Berlin)
# Changed: 23-02-2026 03:38 (Europe/Berlin)
# Version: 6.6
# =============================================================================

[CmdletBinding()]
param(
    # Base URL for optional HTTP checks
    [string]$BaseUrl = "http://127.0.0.1:8000",

    # Admin endpoints to probe (relative to BaseUrl) - only used if -HttpProbe is set
    [string[]]$ProbePaths = @("/admin", "/admin/status", "/admin/moderation", "/admin/maintenance", "/admin/debug"),

    # If set, performs HTTP probe checks (redirect chain + headers)
    [switch]$HttpProbe,

    # If set, tails laravel.log (CTRL+C to stop)
    [switch]$TailLog,

    # Tail mode selection (applies to TailLog window):
    # - live: follow only new lines (default)
    # - history: show last N lines (no follow)
    [ValidateSet("live","history")]
    [string]$TailLogMode = "live",

    # If set, runs additional verbose admin route listing (-vv) to show more details like middleware.
    [switch]$RoutesVerbose,

    # If set, runs full route:list and filters lines containing "admin" (similar to php artisan route:list | findstr admin).
    [switch]$RouteListFindstrAdmin,

    # If set, runs governance check: superadmin count (deterministic; requires ks:audit:superadmin artisan cmd).
    [switch]$SuperadminCount,

    # If set, appends Laravel log snapshot (tail) to output (handled by CLI core).
    [switch]$LogSnapshot,

    # If set, clears/rotates laravel.log before running the core audit (handled by CLI core).
    [switch]$LogClearBefore,

    # If set, clears/rotates laravel.log after running the core audit (handled by CLI core).
    [switch]$LogClearAfter,

    # If set, writes the whole audit output to clipboard at the end (wrapper-only).
    # NOTE: Console mode only. In GUI use the "Copy Output" button.
    [switch]$CopyToClipboard,

    # If set, shows a "press C to copy to clipboard" prompt at the end (wrapper-only).
    # NOTE: Console mode only. In GUI use the "Copy Output" button.
    [switch]$ClipboardPrompt,

    # GUI toggle.
    # IMPORTANT:
    # Some runners pass "-Gui:System.String" or similar garbage. SwitchParameter chokes on that.
    # Therefore Gui is a string and we parse it to bool.
    [string]$Gui = "",

    # Compatibility: Some launchers pass extra stray tokens after parameters.
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$IgnoredArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Ensure predictable UTF-8 output (console + child processes consuming stdout)
try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

# Default behavior: ALWAYS open UI unless explicitly disabled (-Gui:false / -Gui:0 / -Gui:$false).
$GuiEnabled = $true
if ($PSBoundParameters.ContainsKey('Gui')) {
    $s = ("" + $Gui).Trim()
    if ($s -eq "") {
        $GuiEnabled = $true
    } elseif ($s -match '^(?i:false|\$false|0|no|off|disable|disabled)$') {
        $GuiEnabled = $false
    } elseif ($s -match '^(?i:true|\$true|1|yes|on|enable|enabled)$') {
        $GuiEnabled = $true
    } else {
        # Unknown tokens (e.g. "System.String") -> treat as enabled to avoid hard crash.
        $GuiEnabled = $true
    }
}

function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 78)
    Write-Host $Title
    Write-Host ("=" * 78)
}

function Confirm-ProjectRoot([string]$Root) {
    $artisan = Join-Path $Root "artisan"
    if (!(Test-Path $artisan)) {
        throw "Project root not detected. Expected artisan at: $artisan"
    }
}

function ConvertTo-NormalizedText([string]$s) {
    if ($null -eq $s) { return "" }
    $t = "" + $s

    # Strip common ANSI escape sequences (color/cursor control) that can destroy readable line breaks.
    # Examples: ESC[...m, ESC[...K, ESC[...G, etc.
    try { $t = [System.Text.RegularExpressions.Regex]::Replace($t, "\x1B\[[0-9;?]*[ -/]*[@-~]", "") } catch { }

    # Normalize line endings to CRLF:
    # - convert lone LF to CRLF
    # - convert lone CR to CRLF
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
    # IMPORTANT:
    # Use System.Diagnostics.Process to avoid visible console window flashing (CreateNoWindow=true).
    # Keep deterministic stdout/stderr capture.
    $stdout = ""
    $stderr = ""

    try {
        if ($null -eq $ArgumentList) { $ArgumentList = @() }
        $ArgumentList = @($ArgumentList | Where-Object { $_ -ne $null })

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = ("" + $File)

        # Quote each argument deterministically for Windows command line parsing.
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

        # Ensure consistent encoding where possible.
        try { $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
        try { $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8 } catch { }

        $p = [System.Diagnostics.Process]::new()
        $p.StartInfo = $psi

        $null = $p.Start()

        # Provide empty stdin to avoid interactive hangs.
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

        # Make sure async readers completed.
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

function ConvertTo-QuotedArg([string]$s) {
    if ($null -eq $s) { return '""' }
    $t = ("" + $s) -replace '"', '""'
    return ('"' + $t + '"')
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
        # History-only: last 200 lines, no follow.
        $cmd += "Get-Content -LiteralPath " + (ConvertTo-QuotedArg $logPath) + " -Tail 200"
    } else {
        # Live-only: follow only new lines, no history.
        $cmd += "Get-Content -LiteralPath " + (ConvertTo-QuotedArg $logPath) + " -Tail 0 -Wait"
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

function Show-AuditGui() {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Determine project root for GUI (needed for WorkingDirectory)
    $uiScriptDir = $null
    if ($PSScriptRoot -and ($PSScriptRoot.Trim() -ne "")) {
        $uiScriptDir = $PSScriptRoot
    } elseif ($PSCommandPath -and ($PSCommandPath.Trim() -ne "")) {
        $uiScriptDir = Split-Path -Parent $PSCommandPath
    } elseif ($MyInvocation -and $MyInvocation.MyCommand -and ($MyInvocation.MyCommand -is [object]) -and ($MyInvocation.MyCommand | Get-Member -Name Path -ErrorAction SilentlyContinue)) {
        $uiScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $uiScriptDir = (Get-Location).Path
    }

    $uiProjectRoot = Resolve-Path (Join-Path $uiScriptDir "..\..") | Select-Object -ExpandProperty Path
    Confirm-ProjectRoot $uiProjectRoot

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "KiezSingles Admin Audit"
    $form.Width = 1180
    $form.Height = 820
    $form.StartPosition = "CenterScreen"
    $form.MinimumSize = New-Object System.Drawing.Size(980, 720)

    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.AutoPopDelay = 12000
    $toolTip.InitialDelay = 400
    $toolTip.ReshowDelay = 150
    $toolTip.ShowAlways = $true

    # Keep full output to allow filtering without losing original
    $script:AuditOutputRaw = ""

    # --- Layout: left settings / right output
    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = "Fill"
    $split.Orientation = "Vertical"
    $form.Controls.Add($split)

    $form.Add_Shown({
        try {
            $desired = 380
            $w = 0
            try { $w = [int]$split.Width } catch { $w = 0 }
            if ($w -le 0) { try { $w = [int]$form.ClientSize.Width } catch { $w = 0 } }

            $min1 = 340
            $min2 = 600
            if ($w -gt 0) {
                if (($min1 + $min2) -ge $w) {
                    $min2 = $w - $min1 - 20
                    if ($min2 -lt 260) { $min2 = 260 }
                    if (($min1 + $min2) -ge $w) {
                        $min1 = $w - $min2 - 20
                        if ($min1 -lt 240) { $min1 = 240 }
                    }
                }
            }

            try { $split.Panel1MinSize = [int]$min1 } catch { }
            try { $split.Panel2MinSize = [int]$min2 } catch { }

            if ($w -le 0) { try { $split.SplitterDistance = [int]$min1 } catch { }; return }

            $min = [int]$split.Panel1MinSize
            $max = $w - [int]$split.Panel2MinSize
            if ($max -lt $min) { try { $split.SplitterDistance = [int]$min } catch { }; return }

            $dist = $desired
            if ($dist -lt $min) { $dist = $min }
            if ($dist -gt $max) { $dist = $max }
            try { $split.SplitterDistance = [int]$dist } catch { }
        } catch {
            try { $split.SplitterDistance = 300 } catch { }
        }
    })

    # --- Left panel: settings
    $panelLeft = $split.Panel1
    $panelLeft.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.AutoSize = $true
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Text = "Audit-Optionen"
    $lblTitle.Left = 10
    $lblTitle.Top = 10
    $panelLeft.Controls.Add($lblTitle)

    $lblSwitches = New-Object System.Windows.Forms.Label
    $lblSwitches.AutoSize = $true
    $lblSwitches.Text = "Auswahl"
    $lblSwitches.Left = 10
    $lblSwitches.Top = 44
    $panelLeft.Controls.Add($lblSwitches)

    # 1) HTTP-Probe
    $chkHttpProbe = New-Object System.Windows.Forms.CheckBox
    $chkHttpProbe.Left = 10
    $chkHttpProbe.Top = 66
    $chkHttpProbe.Width = 340
    $chkHttpProbe.Text = "1) HTTP-Probe (inkl. ProbePaths)"
    $chkHttpProbe.Checked = [bool]$HttpProbe
    $panelLeft.Controls.Add($chkHttpProbe)

    # ProbePaths (unter 1)
    $lblProbePaths = New-Object System.Windows.Forms.Label
    $lblProbePaths.AutoSize = $true
    $lblProbePaths.Text = "Probe-Pfade (je Zeile ein relativer Pfad)"
    $lblProbePaths.Left = 10
    $lblProbePaths.Top = 92
    $panelLeft.Controls.Add($lblProbePaths)

    $txtProbePaths = New-Object System.Windows.Forms.TextBox
    $txtProbePaths.Left = 10
    $txtProbePaths.Top = 112
    $txtProbePaths.Width = 340
    $txtProbePaths.Height = 78
    $txtProbePaths.Multiline = $true
    $txtProbePaths.ScrollBars = "Vertical"
    $txtProbePaths.WordWrap = $false
    $txtProbePaths.Text = (($ProbePaths | ForEach-Object { "" + $_ }) -join "`r`n")
    $panelLeft.Controls.Add($txtProbePaths)

    # 2) Custom Base URL
    $chkCustomBaseUrl = New-Object System.Windows.Forms.CheckBox
    $chkCustomBaseUrl.Left = 10
    $chkCustomBaseUrl.Top = 198
    $chkCustomBaseUrl.Width = 340
    $chkCustomBaseUrl.Text = "2) Custom Base URL"
    $chkCustomBaseUrl.Checked = $false
    $panelLeft.Controls.Add($chkCustomBaseUrl)

    # BaseUrl (unter 2)
    $lblBaseUrl = New-Object System.Windows.Forms.Label
    $lblBaseUrl.AutoSize = $true
    $lblBaseUrl.Text = "Base-URL (z.B. http://localhost:8000)"
    $lblBaseUrl.Left = 10
    $lblBaseUrl.Top = 224
    $panelLeft.Controls.Add($lblBaseUrl)

    $txtBaseUrl = New-Object System.Windows.Forms.TextBox
    $txtBaseUrl.Left = 10
    $txtBaseUrl.Top = 244
    $txtBaseUrl.Width = 340
    $txtBaseUrl.Text = ("" + $BaseUrl)
    $panelLeft.Controls.Add($txtBaseUrl)

    # 3) TailLog (Konsole -Wait) -> separate Konsole, blockiert GUI nicht
    $chkTailLog = New-Object System.Windows.Forms.CheckBox
    $chkTailLog.Left = 10
    $chkTailLog.Top = 276
    $chkTailLog.Width = 340
    $chkTailLog.Text = "3) TailLog (separates Fenster)"
    $chkTailLog.Checked = [bool]$TailLog
    $panelLeft.Controls.Add($chkTailLog)

    # TailLogMode (unter 3)
    $lblTailMode = New-Object System.Windows.Forms.Label
    $lblTailMode.AutoSize = $true
    $lblTailMode.Text = "Tail-Modus"
    $lblTailMode.Left = 10
    $lblTailMode.Top = 300
    $panelLeft.Controls.Add($lblTailMode)

    $cmbTailMode = New-Object System.Windows.Forms.ComboBox
    $cmbTailMode.Left = 10
    $cmbTailMode.Top = 320
    $cmbTailMode.Width = 340
    $cmbTailMode.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$cmbTailMode.Items.Add("live (nur neue Zeilen)")
    [void]$cmbTailMode.Items.Add("history (letzte 200 Zeilen)")

    $initialMode = "live"
    try { $initialMode = ("" + $TailLogMode).Trim().ToLower() } catch { $initialMode = "live" }
    if ($initialMode -eq "history") { $cmbTailMode.SelectedIndex = 1 } else { $cmbTailMode.SelectedIndex = 0 }
    $panelLeft.Controls.Add($cmbTailMode)

    # 4) RoutesVerbose
    $chkRoutesVerbose = New-Object System.Windows.Forms.CheckBox
    $chkRoutesVerbose.Left = 10
    $chkRoutesVerbose.Top = 352
    $chkRoutesVerbose.Width = 340
    $chkRoutesVerbose.Text = "4) RoutesVerbose"
    $chkRoutesVerbose.Checked = [bool]$RoutesVerbose
    $panelLeft.Controls.Add($chkRoutesVerbose)

    # 5) RouteListFindstrAdmin
    $chkRouteListFindstrAdmin = New-Object System.Windows.Forms.CheckBox
    $chkRouteListFindstrAdmin.Left = 10
    $chkRouteListFindstrAdmin.Top = 376
    $chkRouteListFindstrAdmin.Width = 340
    $chkRouteListFindstrAdmin.Text = "5) RouteListFindstrAdmin"
    $chkRouteListFindstrAdmin.Checked = [bool]$RouteListFindstrAdmin
    $panelLeft.Controls.Add($chkRouteListFindstrAdmin)

    # 6) SuperadminCount
    $chkSuperadminCount = New-Object System.Windows.Forms.CheckBox
    $chkSuperadminCount.Left = 10
    $chkSuperadminCount.Top = 400
    $chkSuperadminCount.Width = 340
    $chkSuperadminCount.Text = "6) SuperadminCount (deterministisch; ks:audit:superadmin)"
    $chkSuperadminCount.Checked = [bool]$SuperadminCount
    $panelLeft.Controls.Add($chkSuperadminCount)

    # 7) Laravel log snapshot
    $chkLaravelLog = New-Object System.Windows.Forms.CheckBox
    $chkLaravelLog.Left = 10
    $chkLaravelLog.Top = 424
    $chkLaravelLog.Width = 340
    $chkLaravelLog.Text = "7) Laravel log (Snapshot im Core)"
    $chkLaravelLog.Checked = [bool]$LogSnapshot
    $panelLeft.Controls.Add($chkLaravelLog)

    # 8) Log clear before
    $chkLogClearBefore = New-Object System.Windows.Forms.CheckBox
    $chkLogClearBefore.Left = 10
    $chkLogClearBefore.Top = 448
    $chkLogClearBefore.Width = 340
    $chkLogClearBefore.Text = "8) LogClearBefore (laravel.log rotieren/neu vor Audit)"
    $chkLogClearBefore.Checked = [bool]$LogClearBefore
    $panelLeft.Controls.Add($chkLogClearBefore)

    # 9) Log clear after
    $chkLogClearAfter = New-Object System.Windows.Forms.CheckBox
    $chkLogClearAfter.Left = 10
    $chkLogClearAfter.Top = 472
    $chkLogClearAfter.Width = 340
    $chkLogClearAfter.Text = "9) LogClearAfter (laravel.log rotieren/neu nach Audit)"
    $chkLogClearAfter.Checked = [bool]$LogClearAfter
    $panelLeft.Controls.Add($chkLogClearAfter)

    # --- Bottom buttons (left)
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = "Run"
    $btnRun.Width = 120
    $btnRun.Height = 32
    $btnRun.Left = 10
    $btnRun.Top = 606
    $panelLeft.Controls.Add($btnRun)

    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "Copy Output"
    $btnCopy.Width = 120
    $btnCopy.Height = 32
    $btnCopy.Left = 140
    $btnCopy.Top = 606
    $btnCopy.Enabled = $false
    $panelLeft.Controls.Add($btnCopy)

    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = "Clear"
    $btnClear.Width = 80
    $btnClear.Height = 32
    $btnClear.Left = 270
    $btnClear.Top = 606
    $panelLeft.Controls.Add($btnClear)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.AutoSize = $true
    $lblStatus.Left = 10
    $lblStatus.Top = 648
    $lblStatus.Width = 340
    $lblStatus.Text = ""
    $panelLeft.Controls.Add($lblStatus)

    # --- Right panel: output
    $panelRight = $split.Panel2
    $panelRight.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)

    # Filter bar (top)
    $panelFilter = New-Object System.Windows.Forms.Panel
    $panelFilter.Dock = "Top"
    $panelFilter.Height = 34
    $panelRight.Controls.Add($panelFilter)

    $lblFilter = New-Object System.Windows.Forms.Label
    $lblFilter.AutoSize = $true
    $lblFilter.Text = "Filter:"
    $lblFilter.Left = 0
    $lblFilter.Top = 8
    $panelFilter.Controls.Add($lblFilter)

    $txtFilter = New-Object System.Windows.Forms.TextBox
    $txtFilter.Left = 46
    $txtFilter.Top = 4
    $txtFilter.Width = 420
    $panelFilter.Controls.Add($txtFilter)

    $chkFilterIgnoreCase = New-Object System.Windows.Forms.CheckBox
    $chkFilterIgnoreCase.Left = 476
    $chkFilterIgnoreCase.Top = 6
    $chkFilterIgnoreCase.Width = 130
    $chkFilterIgnoreCase.Text = "Ignore case"
    $chkFilterIgnoreCase.Checked = $true
    $panelFilter.Controls.Add($chkFilterIgnoreCase)

    $chkFilterRegex = New-Object System.Windows.Forms.CheckBox
    $chkFilterRegex.Left = 612
    $chkFilterRegex.Top = 6
    $chkFilterRegex.Width = 95
    $chkFilterRegex.Text = "Regex"
    $chkFilterRegex.Checked = $false
    $panelFilter.Controls.Add($chkFilterRegex)

    $btnApplyFilter = New-Object System.Windows.Forms.Button
    $btnApplyFilter.Text = "Apply"
    $btnApplyFilter.Width = 70
    $btnApplyFilter.Height = 24
    $btnApplyFilter.Left = 714
    $btnApplyFilter.Top = 4
    $panelFilter.Controls.Add($btnApplyFilter)

    $btnClearFilter = New-Object System.Windows.Forms.Button
    $btnClearFilter.Text = "Clear"
    $btnClearFilter.Width = 70
    $btnClearFilter.Height = 24
    $btnClearFilter.Left = 790
    $btnClearFilter.Top = 4
    $panelFilter.Controls.Add($btnClearFilter)

    $lblFilterStatus = New-Object System.Windows.Forms.Label
    $lblFilterStatus.AutoSize = $true
    $lblFilterStatus.Left = 868
    $lblFilterStatus.Top = 8
    $lblFilterStatus.Width = 260
    $lblFilterStatus.Text = ""
    $panelFilter.Controls.Add($lblFilterStatus)

    function Update-FilterBarLayout {
        try {
            $w = 0
            try { $w = [int]$panelFilter.ClientSize.Width } catch { $w = 0 }
            if ($w -le 0) { return }

            $marginL = 0
            $marginR = 0
            $gap = 8

            $lblFilter.Left = $marginL
            $lblFilter.Top = 8

            $btnClearFilter.Width = 70
            $btnApplyFilter.Width = 70
            $chkFilterRegex.Width = 95
            $chkFilterIgnoreCase.Width = 130
            $lblFilterStatus.Width = 260

            $right = $w - $marginR

            $lblFilterStatus.Left = [Math]::Max($marginL, $right - $lblFilterStatus.Width)
            $lblFilterStatus.Top = 8
            $right = $lblFilterStatus.Left - $gap

            $btnClearFilter.Left = [Math]::Max($marginL, $right - $btnClearFilter.Width)
            $btnClearFilter.Top = 4
            $right = $btnClearFilter.Left - $gap

            $btnApplyFilter.Left = [Math]::Max($marginL, $right - $btnApplyFilter.Width)
            $btnApplyFilter.Top = 4
            $right = $btnApplyFilter.Left - $gap

            $chkFilterRegex.Left = [Math]::Max($marginL, $right - $chkFilterRegex.Width)
            $chkFilterRegex.Top = 6
            $right = $chkFilterRegex.Left - $gap

            $chkFilterIgnoreCase.Left = [Math]::Max($marginL, $right - $chkFilterIgnoreCase.Width)
            $chkFilterIgnoreCase.Top = 6
            $right = $chkFilterIgnoreCase.Left - $gap

            $txtFilter.Top = 4
            $txtFilter.Left = 46
            $minFilterWidth = 140
            $calcWidth = $right - $txtFilter.Left
            if ($calcWidth -lt $minFilterWidth) { $calcWidth = $minFilterWidth }
            $txtFilter.Width = [int]$calcWidth
        } catch {
            # ignore
        }
    }

    $panelFilter.Add_Resize({ Update-FilterBarLayout })
    Update-FilterBarLayout

    # Use RichTextBox to allow highlight for matches
    $txt = New-Object System.Windows.Forms.RichTextBox
    $txt.Multiline = $true
    $txt.ScrollBars = "Both"
    $txt.Dock = "Fill"
    $txt.Font = New-Object System.Drawing.Font("Consolas", 9)
    $txt.WordWrap = $false
    $txt.HideSelection = $false
    $txt.ReadOnly = $true
    $panelRight.Controls.Add($txt)

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
            try { $raw = "" + $script:AuditOutputRaw } catch { $raw = "" }

            $q = ""
            try { $q = ("" + $txtFilter.Text).Trim() } catch { $q = "" }

            if ($raw -eq "") {
                $txt.Text = ""
                $lblFilterStatus.Text = ""
                return
            }

            # Always add a small top padding line for readability
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

            $lines = @()
            try { $lines = $raw -split "`r`n" } catch { $lines = @() }

            $filtered = New-Object System.Collections.Generic.List[string]
            $matched = 0
            $total = 0
            try { $total = [int]$lines.Count } catch { $total = 0 }

            if ($useRegex) {
                $opts = [System.Text.RegularExpressions.RegexOptions]::None
                if ($ignoreCase) { $opts = $opts -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }

                $rx = $null
                try {
                    $rx = [System.Text.RegularExpressions.Regex]::new($q, $opts)
                } catch {
                    $txt.Text = $raw
                    $lblFilterStatus.Text = "Ungueltiger Regex"
                    Reset-Highlighting
                    return
                }

                foreach ($line in $lines) {
                    if ($null -eq $line) { continue }
                    $s = "" + $line
                    if ($rx.IsMatch($s)) {
                        $filtered.Add($s) | Out-Null
                        $matched++
                    }
                }
            } else {
                foreach ($line in $lines) {
                    if ($null -eq $line) { continue }
                    $s = "" + $line

                    $ok = $false
                    if ($ignoreCase) {
                        try { $ok = ($s.IndexOf($q, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) } catch { $ok = $false }
                    } else {
                        try { $ok = ($s.IndexOf($q, [System.StringComparison]::Ordinal) -ge 0) } catch { $ok = $false }
                    }

                    if ($ok) {
                        $filtered.Add($s) | Out-Null
                        $matched++
                    }
                }
            }

            if ($matched -le 0) {
                # Do NOT blank the view; show full raw output and only update status.
                $txt.Text = $raw
                $lblFilterStatus.Text = ("Treffer: 0 / " + $total + " (keine Treffer)")
                Reset-Highlighting
                return
            }

            $txt.Text = (($filtered.ToArray()) -join "`r`n")
            $lblFilterStatus.Text = ("Treffer: " + $matched + " / " + $total)

            Set-MatchHighlighting -query $q -ignoreCase $ignoreCase -useRegex $useRegex
        } catch {
            try { $txt.Text = Add-TopPaddingLine ("" + $script:AuditOutputRaw) } catch { }
            try { $lblFilterStatus.Text = "" } catch { }
            try { Reset-Highlighting } catch { }
        }
    }

    $btnApplyFilter.Add_Click({ Set-OutputFilterView })
    $btnClearFilter.Add_Click({
        try {
            $txtFilter.Text = ""
            $lblFilterStatus.Text = ""
            Set-OutputFilterView
        } catch {
            # ignore
        }
    })

    $txtFilter.Add_KeyDown({
        try {
            if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
                $_.SuppressKeyPress = $true
                Set-OutputFilterView
            }
        } catch {
            # ignore
        }
    })

    # Tooltips (DE)
    try {
        $toolTip.SetToolTip($chkHttpProbe, "Fuehrt unauthentifizierte HTTP-Checks auf die Probe-Pfade aus (Redirect-Kette / Header).")
        $toolTip.SetToolTip($txtProbePaths, "Probe-Pfade fuer die HTTP-Probe. Je Zeile ein relativer Pfad, z.B. /admin/debug.")
        $toolTip.SetToolTip($chkCustomBaseUrl, "Wenn aktiv, wird fuer die HTTP-Probe die Base-URL aus dem Feld darunter verwendet.")
        $toolTip.SetToolTip($txtBaseUrl, "Absolute Base-URL fuer HTTP-Probe, z.B. http://localhost:8000")
        $toolTip.SetToolTip($chkTailLog, "Oeffnet ein separates PowerShell-Fenster zum Anzeigen von storage/logs/laravel.log.")
        $toolTip.SetToolTip($cmbTailMode, "Tail-Modus: live = nur neue Zeilen (Follow), history = letzte 200 Zeilen (kein Follow).")
        $toolTip.SetToolTip($chkRoutesVerbose, "Fuehrt: php artisan route:list --path=admin -vv")
        $toolTip.SetToolTip($chkRouteListFindstrAdmin, "Fuehrt: php artisan route:list | findstr admin")
        $toolTip.SetToolTip($chkSuperadminCount, "Prueft Governance: mindestens 1 Superadmin (via ks:audit:superadmin).")
        $toolTip.SetToolTip($chkLaravelLog, "Fuegt einen Laravel-Log Snapshot (Tail) in die Core-Ausgabe ein.")
        $toolTip.SetToolTip($chkLogClearBefore, "Rotiert/cleart storage/logs/laravel.log VOR dem Audit (nur wenn aktiviert).")
        $toolTip.SetToolTip($chkLogClearAfter, "Rotiert/cleart storage/logs/laravel.log NACH dem Audit (nur wenn aktiviert).")
        $toolTip.SetToolTip($btnRun, "Startet den Audit (Core wird als versteckter Subprozess ausgefuehrt).")
        $toolTip.SetToolTip($btnCopy, "Kopiert die aktuelle Ausgabe (inkl. Filter) in die Zwischenablage.")
        $toolTip.SetToolTip($btnClear, "Leert die Ausgabe und setzt Filter zurueck.")

        $toolTip.SetToolTip($txtFilter, "Filtertext. ENTER = Apply.")
        $toolTip.SetToolTip($chkFilterIgnoreCase, "Gross-/Kleinschreibung ignorieren.")
        $toolTip.SetToolTip($chkFilterRegex, "Filter als regulaeren Ausdruck (Regex) interpretieren.")
        $toolTip.SetToolTip($btnApplyFilter, "Wendet den Filter auf die gespeicherte Roh-Ausgabe an (ohne erneuten Run).")
        $toolTip.SetToolTip($btnClearFilter, "Setzt den Filter zurueck und zeigt wieder die volle Ausgabe.")
    } catch {
        # ignore
    }

    # --- Determine core script path deterministically (MUST be ks-admin-audit.ps1 next to this UI file)
    $uiPath = $null
    if ($PSCommandPath -and ($PSCommandPath.Trim() -ne "")) {
        $uiPath = $PSCommandPath
    } elseif ($MyInvocation -and ($MyInvocation.MyCommand | Get-Member -Name Path -ErrorAction SilentlyContinue)) {
        $uiPath = $MyInvocation.MyCommand.Path
    } else {
        $uiPath = $null
    }

    $corePath = $null
    try {
        $uiDir = $uiScriptDir
        if (-not $uiDir -or ("" + $uiDir).Trim() -eq "") {
            if ($uiPath -and ("" + $uiPath).Trim() -ne "") {
                $uiDir = Split-Path -Parent $uiPath
            } else {
                $uiDir = (Get-Location).Path
            }
        }

        $candidate = Join-Path $uiDir "ks-admin-audit.ps1"
        if (Test-Path -LiteralPath $candidate) {
            $corePath = $candidate
        } else {
            throw ("CLI core not found next to UI: " + $candidate)
        }
    } catch {
        throw
    }

    function Sync-HttpFieldsEnabled() {
        $httpOn = [bool]$chkHttpProbe.Checked
        $customOn = [bool]$chkCustomBaseUrl.Checked

        $txtProbePaths.Enabled = $httpOn
        $lblProbePaths.Enabled = $httpOn
        $chkCustomBaseUrl.Enabled = $httpOn
        $txtBaseUrl.Enabled = ($httpOn -and $customOn)
        $lblBaseUrl.Enabled = ($httpOn -and $customOn)

        if (-not $httpOn) { try { $chkCustomBaseUrl.Checked = $false } catch { } }
    }

    function Sync-TailFieldsEnabled() {
        $tailOn = [bool]$chkTailLog.Checked
        $cmbTailMode.Enabled = $tailOn
        $lblTailMode.Enabled = $tailOn
        if (-not $tailOn) { }
    }

    $chkHttpProbe.add_CheckedChanged({ Sync-HttpFieldsEnabled })
    $chkCustomBaseUrl.add_CheckedChanged({ Sync-HttpFieldsEnabled })
    Sync-HttpFieldsEnabled

    $chkTailLog.add_CheckedChanged({ Sync-TailFieldsEnabled })
    Sync-TailFieldsEnabled

    function Get-UiArgs() {
        $argsList = New-Object System.Collections.Generic.List[string]

        # Always pass BaseUrl deterministically.
        $effectiveBaseUrl = ("" + $BaseUrl).Trim()

        if ($chkHttpProbe.Checked -and $chkCustomBaseUrl.Checked) {
            $bu = ("" + $txtBaseUrl.Text).Trim()
            if ($bu -ne "") {
                $u = $null
                $ok = $false
                try { $ok = [System.Uri]::TryCreate($bu, [System.UriKind]::Absolute, [ref]$u) } catch { $ok = $false }
                if (-not $ok) { throw ("Custom Base URL is not a valid absolute URL: " + $bu) }
                $effectiveBaseUrl = $bu
            } else {
                throw "Custom Base URL is enabled, but Base-URL field is empty."
            }
        }

        $argsList.Add("-BaseUrl") | Out-Null
        $argsList.Add($effectiveBaseUrl) | Out-Null

        # ProbePaths: pass as proper string[] tokens (NOT newline payload)
        $ppLines = @()
        try { $ppLines = ("" + $txtProbePaths.Text) -split "`r?`n" } catch { $ppLines = @() }
        $ppLines = @($ppLines | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })

        if ($ppLines.Count -gt 0) {
            $argsList.Add("-ProbePaths") | Out-Null
            foreach ($p in $ppLines) {
                $argsList.Add(("" + $p)) | Out-Null
            }
        }

        if ($chkHttpProbe.Checked) { $argsList.Add("-HttpProbe") | Out-Null }
        if ($chkRoutesVerbose.Checked) { $argsList.Add("-RoutesVerbose") | Out-Null }
        if ($chkRouteListFindstrAdmin.Checked) { $argsList.Add("-RouteListFindstrAdmin") | Out-Null }
        if ($chkSuperadminCount.Checked) { $argsList.Add("-SuperadminCount") | Out-Null }
        if ($chkLaravelLog.Checked) { $argsList.Add("-LogSnapshot") | Out-Null }

        if ($chkLogClearBefore.Checked) { $argsList.Add("-LogClearBefore") | Out-Null }
        if ($chkLogClearAfter.Checked) { $argsList.Add("-LogClearAfter") | Out-Null }

        # IMPORTANT: TailLog is handled by GUI (separate tail window), NOT by core.
        return @($argsList.ToArray())
    }

    $btnRun.Add_Click({
        $btnRun.Enabled = $false
        $btnCopy.Enabled = $false
        $txt.Clear()
        $lblFilterStatus.Text = ""
        $script:AuditOutputRaw = ""
        $lblStatus.Text = "Laeuft..."

        $argsList = $null
        $childCmdLine = ""

        try {
            # TailLog (separates Fenster)
            if ($chkTailLog.Checked) {
                $mode = "live"
                try { if ($cmbTailMode.SelectedIndex -eq 1) { $mode = "history" } else { $mode = "live" } } catch { $mode = "live" }
                try { Start-LaravelTailWindow -ProjectRoot $uiProjectRoot -Mode $mode } catch { }
            }

            $argsList = @(Get-UiArgs)

            # Run core as a separate hidden process to avoid in-process binding shifts against UI parameters (TailLogMode etc.).
            $psArgs = New-Object System.Collections.Generic.List[string]
            $psArgs.Add("-NoProfile") | Out-Null
            $psArgs.Add("-ExecutionPolicy") | Out-Null
            $psArgs.Add("Bypass") | Out-Null
            $psArgs.Add("-File") | Out-Null
            $psArgs.Add($corePath) | Out-Null
            foreach ($a in $argsList) { $psArgs.Add(("" + $a)) | Out-Null }

            $childCmdLine = ("powershell.exe " + (($psArgs | ForEach-Object { ConvertTo-QuotedArg $_ }) -join " ")).Trim()

            $proc = Invoke-ProcessToFiles -File "powershell.exe" -ArgumentList @($psArgs.ToArray()) -TimeoutSeconds 600 -WorkingDirectory $uiProjectRoot

            $out = ""
            $err = ""
            try { $out = "" + $proc.StdOut } catch { $out = "" }
            try { $err = "" + $proc.StdErr } catch { $err = "" }

            $out = ConvertTo-NormalizedText $out
            $err = ConvertTo-NormalizedText $err

            $combined = ""
            if ($err -and ($err.Trim() -ne "")) { $combined += $err.TrimEnd() + "`r`n" }
            if ($out -and ($out.Trim() -ne "")) { $combined += $out.TrimEnd() + "`r`n" }

            if ($combined.Trim() -eq "") {
                $combined = "(keine Ausgabe)`r`n"
                $combined += "Hinweis: Der Prozess hat nichts auf STDOUT/STDERR geschrieben.`r`n"
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
            Set-OutputFilterView

            $btnCopy.Enabled = $true

            $ec = 0
            try { $ec = [int]$proc.ExitCode } catch { $ec = 0 }
            if ($ec -eq 0) { $lblStatus.Text = "Fertig" } else { $lblStatus.Text = ("Fertig (ExitCode " + $ec + ")") }
        } catch {
            $argDump = ""
            try {
                if ($childCmdLine -and ($childCmdLine.Trim() -ne "")) {
                    $argDump = "`r`n`r`nCore-Command:`r`n" + $childCmdLine
                }
            } catch { }

            $combinedErr = ConvertTo-NormalizedText ("GUI-Fehler:`r`n" + ($_ | Out-String).TrimEnd() + $argDump)
            $script:AuditOutputRaw = $combinedErr
            Set-OutputFilterView

            $lblStatus.Text = "Fehler"
        } finally {
            $btnRun.Enabled = $true
        }
    })

    $btnCopy.Add_Click({
        try {
            Set-Clipboard -Value $txt.Text
            $lblStatus.Text = "Ausgabe kopiert"
        } catch {
            $lblStatus.Text = ("Kopieren fehlgeschlagen: " + $_.Exception.Message)
        }
    })

    $btnClear.Add_Click({
        try {
            $txt.Clear()
            $txtFilter.Text = ""
            $lblFilterStatus.Text = ""
            $script:AuditOutputRaw = ""
            $btnCopy.Enabled = $false
            $lblStatus.Text = ""
        } catch {
            # ignore
        }
    })

    [void]$form.ShowDialog()
}

# --- Determine project root
$scriptDir = $null
if ($PSScriptRoot -and ($PSScriptRoot.Trim() -ne "")) {
    $scriptDir = $PSScriptRoot
} elseif ($PSCommandPath -and ($PSCommandPath.Trim() -ne "")) {
    $scriptDir = Split-Path -Parent $PSCommandPath
} elseif ($MyInvocation -and ($MyInvocation.MyCommand -and ($MyInvocation.MyCommand -is [object]) -and ($MyInvocation.MyCommand | Get-Member -Name Path -ErrorAction SilentlyContinue))) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $scriptDir = (Get-Location).Path
}

$projectRoot = Resolve-Path (Join-Path $scriptDir "..\..") | Select-Object -ExpandProperty Path
Confirm-ProjectRoot $projectRoot
Set-Location $projectRoot

# --- GUI mode (must happen BEFORE any console output)
if ($GuiEnabled) {
    Show-AuditGui
    return
}

# --- Console wrapper mode: delegate to deterministic CLI core
$corePath = Join-Path $scriptDir "ks-admin-audit.ps1"
if (-not (Test-Path $corePath)) {
    throw "CLI core not found: $corePath"
}

Write-Section "KiezSingles Admin Audit (Console Wrapper -> CLI Core)"
Write-Host "Core: $corePath"
Write-Host "ProjectRoot:$projectRoot"

$argList = New-Object System.Collections.Generic.List[string]
$argList.Add("-NoProfile") | Out-Null
$argList.Add("-ExecutionPolicy") | Out-Null
$argList.Add("Bypass") | Out-Null
$argList.Add("-File") | Out-Null
$argList.Add($corePath) | Out-Null

# Always pass BaseUrl + ProbePaths explicitly
$argList.Add("-BaseUrl") | Out-Null
$argList.Add($BaseUrl) | Out-Null

if ($ProbePaths -and $ProbePaths.Count -gt 0) {
    # Pass as proper string[] tokens (NOT newline payload)
    $argList.Add("-ProbePaths") | Out-Null
    foreach ($p in @($ProbePaths | ForEach-Object { "" + $_ })) {
        $t = ("" + $p).Trim()
        if ($t -ne "") { $argList.Add($t) | Out-Null }
    }
}

if ($HttpProbe) { $argList.Add("-HttpProbe") | Out-Null }
if ($RoutesVerbose) { $argList.Add("-RoutesVerbose") | Out-Null }
if ($RouteListFindstrAdmin) { $argList.Add("-RouteListFindstrAdmin") | Out-Null }
if ($SuperadminCount) { $argList.Add("-SuperadminCount") | Out-Null }
if ($LogSnapshot) { $argList.Add("-LogSnapshot") | Out-Null }

if ($LogClearBefore) { $argList.Add("-LogClearBefore") | Out-Null }
if ($LogClearAfter) { $argList.Add("-LogClearAfter") | Out-Null }

if ($TailLog) { $argList.Add("-TailLog") | Out-Null }

$cmdShown = ("powershell.exe " + ($argList -join " "))
Write-Host ""
Write-Host "Child-Command:"
Write-Host $cmdShown

$prevTailMode = $null
$hasPrevTailMode = $false
try {
    $prevTailMode = $env:KS_TAILLOG_MODE
    $hasPrevTailMode = $true
} catch { $hasPrevTailMode = $false }

try {
    if ($TailLog) {
        try { $env:KS_TAILLOG_MODE = ("" + $TailLogMode).Trim().ToLower() } catch { }
    }

    $proc = Invoke-ProcessToFiles -File "powershell.exe" -ArgumentList @($argList.ToArray()) -TimeoutSeconds 600 -WorkingDirectory $projectRoot
} finally {
    if ($hasPrevTailMode) {
        try { $env:KS_TAILLOG_MODE = $prevTailMode } catch { }
    }
}

Write-StdStreams $proc

$exitCode = 0
try { $exitCode = [int]$proc.ExitCode } catch { $exitCode = 0 }

Write-Host ""
Write-Host ("ExitCode: " + $exitCode)

# Clipboard helper for wrapper mode
if ($CopyToClipboard -or $ClipboardPrompt) {
    $doCopy = $false
    if ($CopyToClipboard) {
        $doCopy = $true
    } elseif ($ClipboardPrompt) {
        Write-Host ""
        Write-Host "Press C to copy the full audit output to clipboard, any other key to skip..."
        try {
            $k = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($k -and ($k.Character -eq 'c' -or $k.Character -eq 'C')) { $doCopy = $true }
        } catch { $doCopy = $false }
    }

    if ($doCopy) {
        try {
            $combined = ""
            if ($proc.StdErr -and ($proc.StdErr.Trim() -ne "")) { $combined += (ConvertTo-NormalizedText $proc.StdErr).TrimEnd() + "`r`n" }
            if ($proc.StdOut -and ($proc.StdOut.Trim() -ne "")) { $combined += (ConvertTo-NormalizedText $proc.StdOut).TrimEnd() + "`r`n" }
            if ($combined.Trim() -eq "") { $combined = "(keine Ausgabe)" }
            Set-Clipboard -Value $combined
            Write-Host "Copied audit output to clipboard."
        } catch {
            Write-Host ("Clipboard copy failed: " + $_.Exception.Message)
        }
    }
}

exit $exitCode