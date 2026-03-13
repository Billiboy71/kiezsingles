# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit-ui.ps1
# Purpose: Repeatable admin/backend audit (routes, duplicates, inline HTML/Blade, role checks, DB sanity, optional HTTP traces)
# Created: 19-02-2026 17:25 (Europe/Berlin)
# Changed: 14-03-2026 00:10 (Europe/Berlin)
# Version: 7.3
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

    # If set, runs login CSRF/session probe (GET /login + POST /login)
    [switch]$LoginCsrfProbe,

    # If set, runs role access smoke test (GET-only, role credentials required)
    [switch]$RoleSmokeTest,

    # Role smoke credentials
    [string]$SuperadminEmail = "",
    [string]$SuperadminPassword = "",
    [string]$AdminEmail = "",
    [string]$AdminPassword = "",
    [string]$ModeratorEmail = "",
    [string]$ModeratorPassword = "",

    # Role smoke paths (used by -RoleSmokeTest)
    [string[]]$RoleSmokePaths = @("/admin", "/admin/users", "/admin/moderation", "/admin/tickets", "/admin/maintenance", "/admin/debug", "/admin/develop", "/admin/status"),

    # Optional central path config file (JSON). If not set, tools/audit/ks-admin-audit-paths.json is used.
    [string]$PathsConfigFile = "",

    # If set, prints session/CSRF baseline (read-only)
    [switch]$SessionCsrfBaseline,

    # If set, appends Laravel log snapshot (tail) to output (handled by CLI core).
    [switch]$LogSnapshot,

    # Line count for Laravel log snapshot (only used when -LogSnapshot is set).
    [int]$LogSnapshotLines = 200,

    # If set, clears/rotates laravel.log before running the core audit (handled by CLI core).
    [switch]$LogClearBefore,

    # If set, clears/rotates laravel.log after running the core audit (handled by CLI core).
    [switch]$LogClearAfter,

    # If true, prints details/evidence blocks for all checks in the core output.
    [string]$ShowCheckDetails = "true",

    # If true, exports per-check log slices in the core.
    [string]$ExportLogs = "false",

    # If true, opens the export folder after the core run when exports exist.
    [string]$AutoOpenExportFolder = "false",

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

function Get-MaskedArgumentList([string[]]$InputArgs) {
    $out = New-Object System.Collections.Generic.List[string]
    if ($null -eq $InputArgs) { return @() }

    $sensitiveNames = @(
        "-SuperadminPassword",
        "-AdminPassword",
        "-ModeratorPassword"
    )

    $i = 0
    while ($i -lt $InputArgs.Count) {
        $cur = "" + $InputArgs[$i]
        $out.Add($cur) | Out-Null

        $isSensitiveName = $false
        foreach ($sn in $sensitiveNames) {
            if ($cur -ieq $sn) { $isSensitiveName = $true; break }
        }

        if ($isSensitiveName -and (($i + 1) -lt $InputArgs.Count)) {
            $out.Add("<redacted>") | Out-Null
            $i += 2
            continue
        }

        $i++
    }

    return @($out.ToArray())
}

function Get-KsAuditPathsConfig([string]$ConfigPath) {
    if (-not $ConfigPath -or ("" + $ConfigPath).Trim() -eq "") { return $null }
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $null }

    try {
        $raw = [string](Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop)
        if ($raw.Trim() -eq "") { return $null }
        $cfg = $raw | ConvertFrom-Json -ErrorAction Stop
        return $cfg
    } catch {
        return $null
    }
}

function Save-KsAuditPathsConfig([string]$ConfigPath, [string[]]$ProbePathsToSave, [string[]]$RoleSmokePathsToSave) {
    $dir = Split-Path -Parent $ConfigPath
    if ($dir -and (-not (Test-Path -LiteralPath $dir -PathType Container))) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $payload = [ordered]@{
        probe_paths = @($ProbePathsToSave | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
        role_smoke_paths = @($RoleSmokePathsToSave | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
    }

    $json = $payload | ConvertTo-Json -Depth 5
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ConfigPath, $json, $utf8NoBom)
}

function Get-KsAuditCredentialsConfig([string]$ConfigPath) {
    if (-not $ConfigPath -or ("" + $ConfigPath).Trim() -eq "") { return $null }
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $null }

    try {
        $raw = [string](Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop)
        if ($raw.Trim() -eq "") { return $null }
        return ($raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        return $null
    }
}

function Save-KsAuditCredential([string]$ConfigPath, [string]$Role, [string]$Email, [string]$Password, [bool]$ClearRole = $false) {
    $dir = Split-Path -Parent $ConfigPath
    if ($dir -and (-not (Test-Path -LiteralPath $dir -PathType Container))) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $payload = [ordered]@{
        superadmin = [ordered]@{ email = ""; password = "" }
        admin = [ordered]@{ email = ""; password = "" }
        moderator = [ordered]@{ email = ""; password = "" }
    }

    $existing = Get-KsAuditCredentialsConfig -ConfigPath $ConfigPath
    if ($null -ne $existing) {
        foreach ($rk in @("superadmin","admin","moderator")) {
            try {
                if ($existing.PSObject.Properties.Name -contains $rk) {
                    $r = $existing.$rk
                    if ($null -ne $r) {
                        $payload[$rk]["email"] = ("" + $r.email)
                        $payload[$rk]["password"] = ("" + $r.password)
                    }
                }
            } catch { }
        }
    }

    $k = ("" + $Role).Trim().ToLower()
    if (@("superadmin","admin","moderator") -contains $k) {
        if ($ClearRole) {
            $payload[$k]["email"] = ""
            $payload[$k]["password"] = ""
        } else {
            $payload[$k]["email"] = ("" + $Email)
            $payload[$k]["password"] = ("" + $Password)
        }
    }

    $json = $payload | ConvertTo-Json -Depth 6
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ConfigPath, $json, $utf8NoBom)
}

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

    $uiPathsConfigFile = ""
    try {
        if ($PathsConfigFile -and ("" + $PathsConfigFile).Trim() -ne "") {
            $uiPathsConfigFile = ("" + $PathsConfigFile).Trim()
            if (-not [System.IO.Path]::IsPathRooted($uiPathsConfigFile)) {
                $uiPathsConfigFile = Join-Path $uiProjectRoot $uiPathsConfigFile
            }
        } else {
            $uiPathsConfigFile = Join-Path $uiProjectRoot "tools\audit\ks-admin-audit-paths.json"
        }
    } catch {
        $uiPathsConfigFile = Join-Path $uiProjectRoot "tools\audit\ks-admin-audit-paths.json"
    }

    $cfgObj = Get-KsAuditPathsConfig -ConfigPath $uiPathsConfigFile
    if ($null -ne $cfgObj) {
        if (-not $PSBoundParameters.ContainsKey("ProbePaths")) {
            try {
                if ($cfgObj.PSObject.Properties.Name -contains "probe_paths") {
                    $pp = @($cfgObj.probe_paths | ForEach-Object { "" + $_ } | Where-Object { ("" + $_).Trim() -ne "" })
                    if ($pp.Count -gt 0) { $ProbePaths = @($pp) }
                }
            } catch { }
        }

        if (-not $PSBoundParameters.ContainsKey("RoleSmokePaths")) {
            try {
                if ($cfgObj.PSObject.Properties.Name -contains "role_smoke_paths") {
                    $rp = @($cfgObj.role_smoke_paths | ForEach-Object { "" + $_ } | Where-Object { ("" + $_).Trim() -ne "" })
                    if ($rp.Count -gt 0) { $RoleSmokePaths = @($rp) }
                }
            } catch { }
        }
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
    $form.Width = 1180
    $form.Height = 1200
    $form.StartPosition = "CenterScreen"
    $form.MinimumSize = New-Object System.Drawing.Size(980, 1040)

    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.AutoPopDelay = 12000
    $toolTip.InitialDelay = 400
    $toolTip.ReshowDelay = 150
    $toolTip.ShowAlways = $true

    # Keep full output to allow filtering without losing original
    $script:AuditOutputRaw = ""
    $script:AuditOutputViewRaw = ""
    $script:AuditSectionsByKey = @{}
    $script:AuditStatusByKey = @{}
    $script:AuditSelectedKey = ""

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
    $panelLeft.AutoScroll = $true

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

    # Global Base URL (applies to all checks that use BaseUrl)
    $lblBaseUrlGlobal = New-Object System.Windows.Forms.Label
    $lblBaseUrlGlobal.AutoSize = $true
    $lblBaseUrlGlobal.Text = "Base-URL (global)"
    $lblBaseUrlGlobal.Left = 10
    $lblBaseUrlGlobal.Top = 66
    $panelLeft.Controls.Add($lblBaseUrlGlobal)

    $cmbBaseUrl = New-Object System.Windows.Forms.ComboBox
    $cmbBaseUrl.Left = 10
    $cmbBaseUrl.Top = 86
    $cmbBaseUrl.Width = 340
    $cmbBaseUrl.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$cmbBaseUrl.Items.Add("http://kiezsingles.test")
    [void]$cmbBaseUrl.Items.Add("http://127.0.0.1:8000")
    [void]$cmbBaseUrl.Items.Add("localhost:8000")
    $panelLeft.Controls.Add($cmbBaseUrl)

    $initialBaseUrl = ("" + $BaseUrl).Trim()
    if (-not $PSBoundParameters.ContainsKey("BaseUrl")) {
        $initialBaseUrl = "http://kiezsingles.test"
    }
    if ($initialBaseUrl -eq "") { $initialBaseUrl = "http://kiezsingles.test" }
    $idxBase = $cmbBaseUrl.Items.IndexOf($initialBaseUrl)
    if ($idxBase -ge 0) {
        $cmbBaseUrl.SelectedIndex = $idxBase
    } else {
        [void]$cmbBaseUrl.Items.Add($initialBaseUrl)
        $cmbBaseUrl.SelectedIndex = ($cmbBaseUrl.Items.Count - 1)
    }

    # Shared Paths (for 1 + 11) - positioned above check list
    $lblProbePaths = New-Object System.Windows.Forms.Label
    $lblProbePaths.AutoSize = $true
    $lblProbePaths.Text = "Pfade (fuer 1 + 11; je Zeile ein relativer Pfad)"
    $lblProbePaths.Left = 10
    $lblProbePaths.Top = 122
    $panelLeft.Controls.Add($lblProbePaths)

    $sharedPaths = New-Object System.Collections.Generic.List[string]
    $sharedSeen = @{}
    foreach ($p in @($ProbePaths) + @($RoleSmokePaths)) {
        $x = ("" + $p).Trim()
        if ($x -eq "") { continue }
        if ($sharedSeen.ContainsKey($x)) { continue }
        $sharedSeen[$x] = $true
        $sharedPaths.Add($x) | Out-Null
    }
    if ($sharedPaths.Count -le 0) {
        $sharedPaths.Add("/admin") | Out-Null
        $sharedPaths.Add("/admin/status") | Out-Null
        $sharedPaths.Add("/admin/moderation") | Out-Null
        $sharedPaths.Add("/admin/maintenance") | Out-Null
        $sharedPaths.Add("/admin/debug") | Out-Null
        $sharedPaths.Add("/admin/users") | Out-Null
        $sharedPaths.Add("/admin/tickets") | Out-Null
        $sharedPaths.Add("/admin/develop") | Out-Null
    }

    $txtProbePaths = New-Object System.Windows.Forms.TextBox
    $txtProbePaths.Left = 10
    $txtProbePaths.Top = 142
    $txtProbePaths.Width = 340
    $txtProbePaths.Height = 116
    $txtProbePaths.Multiline = $true
    $txtProbePaths.ScrollBars = "Vertical"
    $txtProbePaths.WordWrap = $false
    $txtProbePaths.Text = (($sharedPaths | ForEach-Object { "" + $_ }) -join "`r`n")
    $panelLeft.Controls.Add($txtProbePaths)

    $btnSavePaths = New-Object System.Windows.Forms.Button
    $btnSavePaths.Text = "Save Paths"
    $btnSavePaths.Width = 340
    $btnSavePaths.Height = 28
    $btnSavePaths.Left = 10
    $btnSavePaths.Top = 262
    $panelLeft.Controls.Add($btnSavePaths)

    # 1) HTTP-Probe
    $chkHttpProbe = New-Object System.Windows.Forms.CheckBox
    $chkHttpProbe.Left = 10
    $chkHttpProbe.Top = 302
    $chkHttpProbe.Width = 340
    $chkHttpProbe.Text = "1) HTTP-Probe (nutzt Pfade oben)"
    $chkHttpProbe.Checked = [bool]$HttpProbe
    $panelLeft.Controls.Add($chkHttpProbe)

    # 2) TailLog (Konsole -Wait) -> separate Konsole, blockiert GUI nicht
    $chkTailLog = New-Object System.Windows.Forms.CheckBox
    $chkTailLog.Left = 10
    $chkTailLog.Top = 332
    $chkTailLog.Width = 340
    $chkTailLog.Text = "2) TailLog (separates Fenster)"
    $chkTailLog.Checked = [bool]$TailLog
    $panelLeft.Controls.Add($chkTailLog)

    # TailLogMode (unter 2)
    $lblTailMode = New-Object System.Windows.Forms.Label
    $lblTailMode.AutoSize = $true
    $lblTailMode.Text = "Tail-Modus"
    $lblTailMode.Left = 10
    $lblTailMode.Top = 356
    $panelLeft.Controls.Add($lblTailMode)

    $cmbTailMode = New-Object System.Windows.Forms.ComboBox
    $cmbTailMode.Left = 10
    $cmbTailMode.Top = 376
    $cmbTailMode.Width = 340
    $cmbTailMode.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$cmbTailMode.Items.Add("live (nur neue Zeilen)")
    [void]$cmbTailMode.Items.Add("history (letzte 200 Zeilen)")

    $initialMode = "live"
    try { $initialMode = ("" + $TailLogMode).Trim().ToLower() } catch { $initialMode = "live" }
    if ($initialMode -eq "history") { $cmbTailMode.SelectedIndex = 1 } else { $cmbTailMode.SelectedIndex = 0 }
    $panelLeft.Controls.Add($cmbTailMode)

    # 3) RoutesVerbose
    $chkRoutesVerbose = New-Object System.Windows.Forms.CheckBox
    $chkRoutesVerbose.Left = 10
    $chkRoutesVerbose.Top = 408
    $chkRoutesVerbose.Width = 340
    $chkRoutesVerbose.Text = "3) RoutesVerbose"
    $chkRoutesVerbose.Checked = [bool]$RoutesVerbose
    $panelLeft.Controls.Add($chkRoutesVerbose)

    # 4) RouteListFindstrAdmin
    $chkRouteListFindstrAdmin = New-Object System.Windows.Forms.CheckBox
    $chkRouteListFindstrAdmin.Left = 10
    $chkRouteListFindstrAdmin.Top = 432
    $chkRouteListFindstrAdmin.Width = 340
    $chkRouteListFindstrAdmin.Text = "4) RouteListFindstrAdmin"
    $chkRouteListFindstrAdmin.Checked = [bool]$RouteListFindstrAdmin
    $panelLeft.Controls.Add($chkRouteListFindstrAdmin)

    # 5) SuperadminCount
    $chkSuperadminCount = New-Object System.Windows.Forms.CheckBox
    $chkSuperadminCount.Left = 10
    $chkSuperadminCount.Top = 456
    $chkSuperadminCount.Width = 340
    $chkSuperadminCount.Text = "5) SuperadminCount (deterministisch; ks:audit:superadmin)"
    $chkSuperadminCount.Checked = [bool]$SuperadminCount
    $panelLeft.Controls.Add($chkSuperadminCount)

    # 6) Laravel log snapshot history
    $lblLaravelLogHistory = New-Object System.Windows.Forms.Label
    $lblLaravelLogHistory.AutoSize = $true
    $lblLaravelLogHistory.Text = "6) Laravel-Log-History (Snapshot im Core)"
    $lblLaravelLogHistory.Left = 10
    $lblLaravelLogHistory.Top = 480
    $panelLeft.Controls.Add($lblLaravelLogHistory)

    $cmbLaravelLogHistory = New-Object System.Windows.Forms.ComboBox
    $cmbLaravelLogHistory.Left = 10
    $cmbLaravelLogHistory.Top = 500
    $cmbLaravelLogHistory.Width = 340
    $cmbLaravelLogHistory.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$cmbLaravelLogHistory.Items.Add("OFF")
    [void]$cmbLaravelLogHistory.Items.Add("200")
    [void]$cmbLaravelLogHistory.Items.Add("500")
    [void]$cmbLaravelLogHistory.Items.Add("1000")

    $initialSnapshotSelection = "OFF"
    try {
        if ([bool]$LogSnapshot) {
            $snapLines = [int]$LogSnapshotLines
            if ($snapLines -eq 500) { $initialSnapshotSelection = "500" }
            elseif ($snapLines -eq 1000) { $initialSnapshotSelection = "1000" }
            else { $initialSnapshotSelection = "200" }
        }
    } catch {
        $initialSnapshotSelection = $(if ([bool]$LogSnapshot) { "200" } else { "OFF" })
    }
    $cmbLaravelLogHistory.SelectedItem = $initialSnapshotSelection
    if ($null -eq $cmbLaravelLogHistory.SelectedItem) { $cmbLaravelLogHistory.SelectedItem = "200" }
    $panelLeft.Controls.Add($cmbLaravelLogHistory)

    # 7) Log clear before
    $chkLogClearBefore = New-Object System.Windows.Forms.CheckBox
    $chkLogClearBefore.Left = 10
    $chkLogClearBefore.Top = 528
    $chkLogClearBefore.Width = 340
    $chkLogClearBefore.Text = "7) LogClearBefore (laravel.log rotieren/neu vor Audit)"
    $chkLogClearBefore.Checked = [bool]$LogClearBefore
    $panelLeft.Controls.Add($chkLogClearBefore)

    # 8) Log clear after
    $chkLogClearAfter = New-Object System.Windows.Forms.CheckBox
    $chkLogClearAfter.Left = 10
    $chkLogClearAfter.Top = 552
    $chkLogClearAfter.Width = 340
    $chkLogClearAfter.Text = "8) LogClearAfter (laravel.log rotieren/neu nach Audit)"
    $chkLogClearAfter.Checked = [bool]$LogClearAfter
    $panelLeft.Controls.Add($chkLogClearAfter)

    # 9) Login CSRF Probe
    $chkLoginCsrfProbe = New-Object System.Windows.Forms.CheckBox
    $chkLoginCsrfProbe.Left = 10
    $chkLoginCsrfProbe.Top = 576
    $chkLoginCsrfProbe.Width = 340
    $chkLoginCsrfProbe.Text = "9) LoginCsrfProbe (GET/POST /login)"
    $chkLoginCsrfProbe.Checked = [bool]$LoginCsrfProbe
    $panelLeft.Controls.Add($chkLoginCsrfProbe)

    # 10) Role Smoke Test
    $chkRoleSmokeTest = New-Object System.Windows.Forms.CheckBox
    $chkRoleSmokeTest.Left = 10
    $chkRoleSmokeTest.Top = 600
    $chkRoleSmokeTest.Width = 340
    $chkRoleSmokeTest.Text = "10) RoleSmokeTest (GET-only)"
    $chkRoleSmokeTest.Checked = [bool]$RoleSmokeTest
    $panelLeft.Controls.Add($chkRoleSmokeTest)

    # Credentials grid
    $lblRoleCreds = New-Object System.Windows.Forms.Label
    $lblRoleCreds.AutoSize = $true
    $lblRoleCreds.Text = "RoleSmoke Credentials (nur fuer 10)"
    $lblRoleCreds.Left = 10
    $lblRoleCreds.Top = 644
    $panelLeft.Controls.Add($lblRoleCreds)

    $lblSuperadminEmail = New-Object System.Windows.Forms.Label
    $lblSuperadminEmail.AutoSize = $true
    $lblSuperadminEmail.Text = "Superadmin E-Mail"
    $lblSuperadminEmail.Left = 10
    $lblSuperadminEmail.Top = 666
    $panelLeft.Controls.Add($lblSuperadminEmail)

    $txtSuperadminEmail = New-Object System.Windows.Forms.TextBox
    $txtSuperadminEmail.Left = 10
    $txtSuperadminEmail.Top = 684
    $txtSuperadminEmail.Width = 140
    $txtSuperadminEmail.Text = ("" + $SuperadminEmail)
    $panelLeft.Controls.Add($txtSuperadminEmail)

    $txtSuperadminPassword = New-Object System.Windows.Forms.TextBox
    $txtSuperadminPassword.Left = 156
    $txtSuperadminPassword.Top = 684
    $txtSuperadminPassword.Width = 140
    $txtSuperadminPassword.UseSystemPasswordChar = $true
    $txtSuperadminPassword.Text = ("" + $SuperadminPassword)
    $panelLeft.Controls.Add($txtSuperadminPassword)

    $btnSaveSuperadmin = New-Object System.Windows.Forms.Button
    $btnSaveSuperadmin.Left = 302
    $btnSaveSuperadmin.Top = 684
    $btnSaveSuperadmin.Text = "S"
    Set-RoundButtonShape -Button $btnSaveSuperadmin
    $panelLeft.Controls.Add($btnSaveSuperadmin)

    $btnClearSuperadmin = New-Object System.Windows.Forms.Button
    $btnClearSuperadmin.Left = 326
    $btnClearSuperadmin.Top = 684
    $btnClearSuperadmin.Text = "C"
    Set-RoundButtonShape -Button $btnClearSuperadmin
    $panelLeft.Controls.Add($btnClearSuperadmin)

    $lblAdminEmail = New-Object System.Windows.Forms.Label
    $lblAdminEmail.AutoSize = $true
    $lblAdminEmail.Text = "Admin E-Mail"
    $lblAdminEmail.Left = 10
    $lblAdminEmail.Top = 710
    $panelLeft.Controls.Add($lblAdminEmail)

    $txtAdminEmail = New-Object System.Windows.Forms.TextBox
    $txtAdminEmail.Left = 10
    $txtAdminEmail.Top = 728
    $txtAdminEmail.Width = 140
    $txtAdminEmail.Text = ("" + $AdminEmail)
    $panelLeft.Controls.Add($txtAdminEmail)

    $txtAdminPassword = New-Object System.Windows.Forms.TextBox
    $txtAdminPassword.Left = 156
    $txtAdminPassword.Top = 728
    $txtAdminPassword.Width = 140
    $txtAdminPassword.UseSystemPasswordChar = $true
    $txtAdminPassword.Text = ("" + $AdminPassword)
    $panelLeft.Controls.Add($txtAdminPassword)

    $btnSaveAdmin = New-Object System.Windows.Forms.Button
    $btnSaveAdmin.Left = 302
    $btnSaveAdmin.Top = 728
    $btnSaveAdmin.Text = "S"
    Set-RoundButtonShape -Button $btnSaveAdmin
    $panelLeft.Controls.Add($btnSaveAdmin)

    $btnClearAdmin = New-Object System.Windows.Forms.Button
    $btnClearAdmin.Left = 326
    $btnClearAdmin.Top = 728
    $btnClearAdmin.Text = "C"
    Set-RoundButtonShape -Button $btnClearAdmin
    $panelLeft.Controls.Add($btnClearAdmin)

    $lblModeratorEmail = New-Object System.Windows.Forms.Label
    $lblModeratorEmail.AutoSize = $true
    $lblModeratorEmail.Text = "Moderator E-Mail"
    $lblModeratorEmail.Left = 10
    $lblModeratorEmail.Top = 754
    $panelLeft.Controls.Add($lblModeratorEmail)

    $txtModeratorEmail = New-Object System.Windows.Forms.TextBox
    $txtModeratorEmail.Left = 10
    $txtModeratorEmail.Top = 772
    $txtModeratorEmail.Width = 140
    $txtModeratorEmail.Text = ("" + $ModeratorEmail)
    $panelLeft.Controls.Add($txtModeratorEmail)

    $txtModeratorPassword = New-Object System.Windows.Forms.TextBox
    $txtModeratorPassword.Left = 156
    $txtModeratorPassword.Top = 772
    $txtModeratorPassword.Width = 140
    $txtModeratorPassword.UseSystemPasswordChar = $true
    $txtModeratorPassword.Text = ("" + $ModeratorPassword)
    $panelLeft.Controls.Add($txtModeratorPassword)

    $btnSaveModerator = New-Object System.Windows.Forms.Button
    $btnSaveModerator.Left = 302
    $btnSaveModerator.Top = 772
    $btnSaveModerator.Text = "S"
    Set-RoundButtonShape -Button $btnSaveModerator
    $panelLeft.Controls.Add($btnSaveModerator)

    $btnClearModerator = New-Object System.Windows.Forms.Button
    $btnClearModerator.Left = 326
    $btnClearModerator.Top = 772
    $btnClearModerator.Text = "C"
    Set-RoundButtonShape -Button $btnClearModerator
    $panelLeft.Controls.Add($btnClearModerator)

    # 11) Session/CSRF baseline (under role credentials)
    $chkSessionCsrfBaseline = New-Object System.Windows.Forms.CheckBox
    $chkSessionCsrfBaseline.Left = 10
    $chkSessionCsrfBaseline.Top = 806
    $chkSessionCsrfBaseline.Width = 340
    $chkSessionCsrfBaseline.Text = "11) SessionCsrfBaseline (read-only)"
    $chkSessionCsrfBaseline.Checked = [bool]$SessionCsrfBaseline
    $panelLeft.Controls.Add($chkSessionCsrfBaseline)

    # 12) Show check details
    $chkShowCheckDetails = New-Object System.Windows.Forms.CheckBox
    $chkShowCheckDetails.Left = 10
    $chkShowCheckDetails.Top = 830
    $chkShowCheckDetails.Width = 340
    $chkShowCheckDetails.Text = "12) Check-Details anzeigen"
    $chkShowCheckDetails.Checked = [bool](("" + $ShowCheckDetails).Trim() -notmatch '^(?i:0|false|\$false|no|off)$')
    $panelLeft.Controls.Add($chkShowCheckDetails)

    # 13) Export log slices
    $chkExportLogs = New-Object System.Windows.Forms.CheckBox
    $chkExportLogs.Left = 10
    $chkExportLogs.Top = 854
    $chkExportLogs.Width = 340
    $chkExportLogs.Text = "13) Log-Slices exportieren"
    $chkExportLogs.Checked = [bool](("" + $ExportLogs).Trim() -match '^(?i:1|true|\$true|yes|on)$')
    $panelLeft.Controls.Add($chkExportLogs)

    # 14) Auto-open export folder
    $chkAutoOpenExportFolder = New-Object System.Windows.Forms.CheckBox
    $chkAutoOpenExportFolder.Left = 10
    $chkAutoOpenExportFolder.Top = 878
    $chkAutoOpenExportFolder.Width = 340
    $chkAutoOpenExportFolder.Text = "14) Export-Ordner danach oeffnen"
    $chkAutoOpenExportFolder.Checked = [bool](("" + $AutoOpenExportFolder).Trim() -match '^(?i:1|true|\$true|yes|on)$')
    $panelLeft.Controls.Add($chkAutoOpenExportFolder)

    # --- Bottom buttons (left)
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = "Run"
    $btnRun.Width = 82
    $btnRun.Height = 32
    $btnRun.Left = 10
    $btnRun.Top = 910
    $panelLeft.Controls.Add($btnRun)

    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "Copy Output"
    $btnCopy.Width = 90
    $btnCopy.Height = 32
    $btnCopy.Left = 98
    $btnCopy.Top = 910
    $btnCopy.Enabled = $false
    $panelLeft.Controls.Add($btnCopy)

    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = "Clear"
    $btnClear.Width = 60
    $btnClear.Height = 32
    $btnClear.Left = 192
    $btnClear.Top = 910
    $panelLeft.Controls.Add($btnClear)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.AutoSize = $true
    $lblStatus.Left = 10
    $lblStatus.Top = 950
    $lblStatus.Width = 340
    $lblStatus.Text = ""
    $panelLeft.Controls.Add($lblStatus)

    # --- Right panel: output / details
    $panelRight = $split.Panel2
    $panelRight.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)

    $panelInfo = New-Object System.Windows.Forms.Panel
    $panelInfo.Dock = "Fill"
    $panelRight.Controls.Add($panelInfo)

    $lblInfoTitle = New-Object System.Windows.Forms.Label
    $lblInfoTitle.AutoSize = $true
    $lblInfoTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblInfoTitle.Text = "Status / Detail"
    $lblInfoTitle.Left = 0
    $lblInfoTitle.Top = 0
    $panelInfo.Controls.Add($lblInfoTitle)

    $lblInfoHint = New-Object System.Windows.Forms.Label
    $lblInfoHint.AutoSize = $false
    $lblInfoHint.Left = 0
    $lblInfoHint.Top = 28
    $lblInfoHint.Width = 720
    $lblInfoHint.Height = 60
    $lblInfoHint.Text = "Das Logfenster dient jetzt als Detailansicht. Klick auf einen Check oder sein Statuslabel, um den zugehoerigen Abschnitt anzuzeigen."
    $panelInfo.Controls.Add($lblInfoHint)

    $panelDetail = New-Object System.Windows.Forms.Panel
    $panelDetail.Dock = "Bottom"
    $panelDetail.Height = 340
    $panelRight.Controls.Add($panelDetail)

    $panelDetailHeader = New-Object System.Windows.Forms.Panel
    $panelDetailHeader.Dock = "Top"
    $panelDetailHeader.Height = 28
    $panelDetail.Controls.Add($panelDetailHeader)

    $lblDetailTitle = New-Object System.Windows.Forms.Label
    $lblDetailTitle.AutoSize = $false
    $lblDetailTitle.Left = 0
    $lblDetailTitle.Top = 4
    $lblDetailTitle.Width = 540
    $lblDetailTitle.Height = 20
    $lblDetailTitle.Text = "Detailansicht: Gesamtausgabe"
    $panelDetailHeader.Controls.Add($lblDetailTitle)

    $btnShowFullOutput = New-Object System.Windows.Forms.Button
    $btnShowFullOutput.Text = "Gesamtausgabe"
    $btnShowFullOutput.Width = 116
    $btnShowFullOutput.Height = 24
    $btnShowFullOutput.Top = 2
    $panelDetailHeader.Controls.Add($btnShowFullOutput)

    # Filter bar (top)
    $panelFilter = New-Object System.Windows.Forms.Panel
    $panelFilter.Dock = "Top"
    $panelFilter.Height = 34
    $panelDetail.Controls.Add($panelFilter)

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
    $btnApplyFilter.Text = "Search"
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
    $panelLeft.Add_Resize({ Update-UiLayout })
    $panelRight.Add_Resize({ Update-UiLayout })
    $panelDetailHeader.Add_Resize({ Update-UiLayout })


    # Use RichTextBox to allow highlight for matches
    $txt = New-Object System.Windows.Forms.RichTextBox
    $txt.Multiline = $true
    $txt.ScrollBars = "Both"
    $txt.Dock = "Fill"
    $txt.Font = New-Object System.Drawing.Font("Consolas", 9)
    $txt.WordWrap = $false
    $txt.HideSelection = $false
    $txt.ReadOnly = $true
    $panelDetail.Controls.Add($txt)

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

    $chkCoreRoutes = New-Object System.Windows.Forms.CheckBox
    $chkCoreRoutes.Text = "Routes"
    $chkCoreRoutes.Checked = $true
    $chkCoreRoutes.AutoCheck = $false
    $panelLeft.Controls.Add($chkCoreRoutes)

    $chkCoreRouteOptionScan = New-Object System.Windows.Forms.CheckBox
    $chkCoreRouteOptionScan.Text = "Route option scan"
    $chkCoreRouteOptionScan.Checked = $true
    $chkCoreRouteOptionScan.AutoCheck = $false
    $panelLeft.Controls.Add($chkCoreRouteOptionScan)

    $chkCoreSecurityBaseline = New-Object System.Windows.Forms.CheckBox
    $chkCoreSecurityBaseline.Text = "Security baseline"
    $chkCoreSecurityBaseline.Checked = $true
    $chkCoreSecurityBaseline.AutoCheck = $false
    $panelLeft.Controls.Add($chkCoreSecurityBaseline)

    $statusLabels = @{
        core_routes = (New-AuditStatusLabel "core_routes")
        core_route_option_scan = (New-AuditStatusLabel "core_route_option_scan")
        core_security_baseline = (New-AuditStatusLabel "core_security_baseline")
        http_probe = (New-AuditStatusLabel "http_probe")
        tail_log = (New-AuditStatusLabel "tail_log")
        routes_verbose = (New-AuditStatusLabel "routes_verbose")
        route_list_findstr_admin = (New-AuditStatusLabel "route_list_findstr_admin")
        superadmin_count = (New-AuditStatusLabel "superadmin_count")
        log_snapshot = (New-AuditStatusLabel "log_snapshot")
        login_csrf_probe = (New-AuditStatusLabel "login_csrf_probe")
        role_smoke_test = (New-AuditStatusLabel "role_smoke_test")
        session_csrf_baseline = (New-AuditStatusLabel "session_csrf_baseline")
        show_check_details = (New-AuditStatusLabel "show_check_details")
        export_logs = (New-AuditStatusLabel "export_logs")
        auto_open_export_folder = (New-AuditStatusLabel "auto_open_export_folder")
        log_clear_before = (New-AuditStatusLabel "log_clear_before")
        log_clear_after = (New-AuditStatusLabel "log_clear_after")
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
        show_check_details = $chkShowCheckDetails
        export_logs = $chkExportLogs
        auto_open_export_folder = $chkAutoOpenExportFolder
        log_clear_before = $chkLogClearBefore
        log_clear_after = $chkLogClearAfter
    }

    $grpCoreChecks = New-Object System.Windows.Forms.GroupBox
    $grpCoreChecks.Text = "Core Checks"
    $panelLeft.Controls.Add($grpCoreChecks)

    $grpPassiveChecks = New-Object System.Windows.Forms.GroupBox
    $grpPassiveChecks.Text = "Passive Checks"
    $panelLeft.Controls.Add($grpPassiveChecks)

    $grpSecurityProbes = New-Object System.Windows.Forms.GroupBox
    $grpSecurityProbes.Text = "Security Probes"
    $panelLeft.Controls.Add($grpSecurityProbes)

    $grpToolsExport = New-Object System.Windows.Forms.GroupBox
    $grpToolsExport.Text = "Tools / Export"
    $panelLeft.Controls.Add($grpToolsExport)

    $lblTitle.Visible = $false
    $lblSwitches.Visible = $false

    foreach ($ctrl in @($chkCoreRoutes, $chkCoreRouteOptionScan, $chkCoreSecurityBaseline)) { $grpCoreChecks.Controls.Add($ctrl) }
    foreach ($lbl in @($statusLabels["core_routes"], $statusLabels["core_route_option_scan"], $statusLabels["core_security_baseline"])) { $grpCoreChecks.Controls.Add($lbl) }
    foreach ($ctrl in @($chkHttpProbe, $chkTailLog, $lblTailMode, $cmbTailMode, $chkRoutesVerbose, $chkRouteListFindstrAdmin, $chkSuperadminCount, $lblLaravelLogHistory, $cmbLaravelLogHistory)) { $grpPassiveChecks.Controls.Add($ctrl) }
    foreach ($lbl in @($statusLabels["http_probe"], $statusLabels["tail_log"], $statusLabels["routes_verbose"], $statusLabels["route_list_findstr_admin"], $statusLabels["superadmin_count"], $statusLabels["log_snapshot"])) { $grpPassiveChecks.Controls.Add($lbl) }
    foreach ($ctrl in @($chkLoginCsrfProbe, $chkRoleSmokeTest, $lblRoleCreds, $lblSuperadminEmail, $txtSuperadminEmail, $txtSuperadminPassword, $btnSaveSuperadmin, $btnClearSuperadmin, $lblAdminEmail, $txtAdminEmail, $txtAdminPassword, $btnSaveAdmin, $btnClearAdmin, $lblModeratorEmail, $txtModeratorEmail, $txtModeratorPassword, $btnSaveModerator, $btnClearModerator, $chkSessionCsrfBaseline)) { $grpSecurityProbes.Controls.Add($ctrl) }
    foreach ($lbl in @($statusLabels["login_csrf_probe"], $statusLabels["role_smoke_test"], $statusLabels["session_csrf_baseline"])) { $grpSecurityProbes.Controls.Add($lbl) }
    foreach ($ctrl in @($chkLogClearBefore, $chkLogClearAfter, $chkShowCheckDetails, $chkExportLogs, $chkAutoOpenExportFolder)) { $grpToolsExport.Controls.Add($ctrl) }
    foreach ($lbl in @($statusLabels["log_clear_before"], $statusLabels["log_clear_after"], $statusLabels["show_check_details"], $statusLabels["export_logs"], $statusLabels["auto_open_export_folder"])) { $grpToolsExport.Controls.Add($lbl) }

    function Layout-GroupRow([System.Windows.Forms.Control]$CheckControl, [System.Windows.Forms.Label]$StatusLabel, [int]$Top, [int]$Width) {
        $CheckControl.Left = 12
        $CheckControl.Top = $Top
        $CheckControl.Width = $Width - 86
        $StatusLabel.Left = $Width - 62
        $StatusLabel.Top = $Top
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

    function Update-UiLayout {
        try {
            $leftWidth = [Math]::Max(340, $panelLeft.ClientSize.Width - 24)
            $statusLeft = $leftWidth - 72

            $cmbBaseUrl.Width = $leftWidth
            $txtProbePaths.Width = $leftWidth
            $btnSavePaths.Width = $leftWidth

            $grpCoreChecks.Left = 10
            $grpCoreChecks.Top = 302
            $grpCoreChecks.Width = $leftWidth + 12
            $grpCoreChecks.Height = 108
            Layout-GroupRow $chkCoreRoutes $statusLabels["core_routes"] 24 $leftWidth
            Layout-GroupRow $chkCoreRouteOptionScan $statusLabels["core_route_option_scan"] 48 $leftWidth
            Layout-GroupRow $chkCoreSecurityBaseline $statusLabels["core_security_baseline"] 72 $leftWidth

            $grpPassiveChecks.Left = 10
            $grpPassiveChecks.Top = 420
            $grpPassiveChecks.Width = $leftWidth + 12
            $grpPassiveChecks.Height = 250
            Layout-GroupRow $chkHttpProbe $statusLabels["http_probe"] 24 $leftWidth
            Layout-GroupRow $chkTailLog $statusLabels["tail_log"] 48 $leftWidth
            $lblTailMode.Left = 12
            $lblTailMode.Top = 74
            $cmbTailMode.Left = 12
            $cmbTailMode.Top = 92
            $cmbTailMode.Width = $leftWidth
            Layout-GroupRow $chkRoutesVerbose $statusLabels["routes_verbose"] 126 $leftWidth
            Layout-GroupRow $chkRouteListFindstrAdmin $statusLabels["route_list_findstr_admin"] 150 $leftWidth
            Layout-GroupRow $chkSuperadminCount $statusLabels["superadmin_count"] 174 $leftWidth
            $lblLaravelLogHistory.Left = 12
            $lblLaravelLogHistory.Top = 198
            $cmbLaravelLogHistory.Left = 12
            $cmbLaravelLogHistory.Top = 216
            $cmbLaravelLogHistory.Width = $leftWidth - 74
            $statusLabels["log_snapshot"].Left = $statusLeft
            $statusLabels["log_snapshot"].Top = 216

            $grpSecurityProbes.Left = 10
            $grpSecurityProbes.Top = 680
            $grpSecurityProbes.Width = $leftWidth + 12
            $grpSecurityProbes.Height = 270
            Layout-GroupRow $chkLoginCsrfProbe $statusLabels["login_csrf_probe"] 24 $leftWidth
            Layout-GroupRow $chkRoleSmokeTest $statusLabels["role_smoke_test"] 48 $leftWidth
            $lblRoleCreds.Left = 12
            $lblRoleCreds.Top = 78
            $lblSuperadminEmail.Left = 12
            $lblSuperadminEmail.Top = 100
            $txtSuperadminEmail.Left = 12
            $txtSuperadminEmail.Top = 118
            $txtSuperadminEmail.Width = 140
            $txtSuperadminPassword.Left = 156
            $txtSuperadminPassword.Top = 118
            $txtSuperadminPassword.Width = [Math]::Max(120, $leftWidth - 240)
            $btnSaveSuperadmin.Left = $leftWidth - 34
            $btnSaveSuperadmin.Top = 118
            $btnClearSuperadmin.Left = $leftWidth - 10
            $btnClearSuperadmin.Top = 118
            $lblAdminEmail.Left = 12
            $lblAdminEmail.Top = 144
            $txtAdminEmail.Left = 12
            $txtAdminEmail.Top = 162
            $txtAdminEmail.Width = 140
            $txtAdminPassword.Left = 156
            $txtAdminPassword.Top = 162
            $txtAdminPassword.Width = [Math]::Max(120, $leftWidth - 240)
            $btnSaveAdmin.Left = $leftWidth - 34
            $btnSaveAdmin.Top = 162
            $btnClearAdmin.Left = $leftWidth - 10
            $btnClearAdmin.Top = 162
            $lblModeratorEmail.Left = 12
            $lblModeratorEmail.Top = 188
            $txtModeratorEmail.Left = 12
            $txtModeratorEmail.Top = 206
            $txtModeratorEmail.Width = 140
            $txtModeratorPassword.Left = 156
            $txtModeratorPassword.Top = 206
            $txtModeratorPassword.Width = [Math]::Max(120, $leftWidth - 240)
            $btnSaveModerator.Left = $leftWidth - 34
            $btnSaveModerator.Top = 206
            $btnClearModerator.Left = $leftWidth - 10
            $btnClearModerator.Top = 206
            Layout-GroupRow $chkSessionCsrfBaseline $statusLabels["session_csrf_baseline"] 236 $leftWidth

            $grpToolsExport.Left = 10
            $grpToolsExport.Top = 960
            $grpToolsExport.Width = $leftWidth + 12
            $grpToolsExport.Height = 158
            Layout-GroupRow $chkLogClearBefore $statusLabels["log_clear_before"] 24 $leftWidth
            Layout-GroupRow $chkLogClearAfter $statusLabels["log_clear_after"] 48 $leftWidth
            Layout-GroupRow $chkShowCheckDetails $statusLabels["show_check_details"] 72 $leftWidth
            Layout-GroupRow $chkExportLogs $statusLabels["export_logs"] 96 $leftWidth
            Layout-GroupRow $chkAutoOpenExportFolder $statusLabels["auto_open_export_folder"] 120 $leftWidth

            $btnRun.Top = 1132
            $btnCopy.Top = 1132
            $btnClear.Top = 1132
            $lblStatus.Top = 1170

            $btnShowFullOutput.Left = [Math]::Max(540, $panelDetailHeader.ClientSize.Width - $btnShowFullOutput.Width)
            $lblInfoHint.Width = [Math]::Max(240, $panelInfo.ClientSize.Width - 10)
            $lblDetailTitle.Width = [Math]::Max(260, $btnShowFullOutput.Left - 10)
            $panelDetail.Height = [Math]::Max(240, [Math]::Floor($panelRight.ClientSize.Height * 0.38))
        } catch { }
    }

    Update-UiLayout

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

            # Always show full output; search only highlights matches.
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
        $toolTip.SetToolTip($txtProbePaths, "Gemeinsame Pfadliste fuer 1) HTTP-Probe und 11) RoleSmokeTest. Je Zeile ein relativer Pfad.")
        $toolTip.SetToolTip($cmbBaseUrl, "Globale Base-URL fuer alle Checks, die HTTP nutzen.")
        $toolTip.SetToolTip($chkTailLog, "Oeffnet ein separates PowerShell-Fenster zum Anzeigen von storage/logs/laravel.log.")
        $toolTip.SetToolTip($cmbTailMode, "Tail-Modus: live = nur neue Zeilen (Follow), history = letzte 200 Zeilen (kein Follow).")
        $toolTip.SetToolTip($chkRoutesVerbose, "Fuehrt: php artisan route:list --path=admin -vv")
        $toolTip.SetToolTip($chkRouteListFindstrAdmin, "Fuehrt: php artisan route:list | findstr admin")
        $toolTip.SetToolTip($chkSuperadminCount, "Prueft Governance: mindestens 1 Superadmin (via ks:audit:superadmin).")
        $toolTip.SetToolTip($cmbLaravelLogHistory, "Laravel-Log-History (Snapshot im Core): OFF oder letzte 200/500/1000 Zeilen.")
        $toolTip.SetToolTip($chkLogClearBefore, "Rotiert/cleart storage/logs/laravel.log VOR dem Audit (nur wenn aktiviert).")
        $toolTip.SetToolTip($chkLogClearAfter, "Rotiert/cleart storage/logs/laravel.log NACH dem Audit (nur wenn aktiviert).")
        $toolTip.SetToolTip($chkLoginCsrfProbe, "Fuehrt Login-CSRF-Preflight aus (GET /login, POST /login no-redirect).")
        $toolTip.SetToolTip($chkRoleSmokeTest, "Fuehrt GET-only RoleSmokeTest aus (inkl. Login-Preflight, falls aktiviert).")
        $toolTip.SetToolTip($chkSessionCsrfBaseline, "Liest Session-/CSRF-Baseline aus .env/config (read-only).")
        $toolTip.SetToolTip($chkShowCheckDetails, "Wenn aktiv, gibt der Core die Details/Evidence unter allen Checks aus.")
        $toolTip.SetToolTip($chkExportLogs, "Wenn aktiv, exportiert der Core pro Check die Log-Slices in tools/audit/output.")
        $toolTip.SetToolTip($chkAutoOpenExportFolder, "Wenn aktiv, oeffnet der Core nach vorhandenen Exporten den Export-Ordner.")
        $toolTip.SetToolTip($txtSuperadminEmail, "Superadmin E-Mail fuer Login/RoleSmoke.")
        $toolTip.SetToolTip($txtSuperadminPassword, "Superadmin Passwort fuer Login/RoleSmoke.")
        $toolTip.SetToolTip($btnSaveSuperadmin, "Superadmin Credentials speichern")
        $toolTip.SetToolTip($btnClearSuperadmin, "Superadmin Credentials loeschen")
        $toolTip.SetToolTip($txtAdminEmail, "Admin E-Mail fuer RoleSmoke.")
        $toolTip.SetToolTip($txtAdminPassword, "Admin Passwort fuer RoleSmoke.")
        $toolTip.SetToolTip($btnSaveAdmin, "Admin Credentials speichern")
        $toolTip.SetToolTip($btnClearAdmin, "Admin Credentials loeschen")
        $toolTip.SetToolTip($txtModeratorEmail, "Moderator E-Mail fuer RoleSmoke.")
        $toolTip.SetToolTip($txtModeratorPassword, "Moderator Passwort fuer RoleSmoke.")
        $toolTip.SetToolTip($btnSaveModerator, "Moderator Credentials speichern")
        $toolTip.SetToolTip($btnClearModerator, "Moderator Credentials loeschen")
        $toolTip.SetToolTip($btnRun, "Startet den Audit (Core wird als versteckter Subprozess ausgefuehrt).")
        $toolTip.SetToolTip($btnCopy, "Kopiert die aktuelle Ausgabe (inkl. Filter) in die Zwischenablage.")
        $toolTip.SetToolTip($btnSavePaths, "Speichert die gemeinsame Pfadliste dauerhaft in tools/audit/ks-admin-audit-paths.json.")
        $toolTip.SetToolTip($btnClear, "Leert die Ausgabe und setzt Filter zurueck.")

        $toolTip.SetToolTip($txtFilter, "Suchtext. Ohne Regex = normaler Text. Mit Regex: Mehrere Suchbegriffe mit Komma trennen, z.B. fail,error,419. ENTER = Search.")
        $toolTip.SetToolTip($chkFilterIgnoreCase, "Gross-/Kleinschreibung ignorieren.")
        $toolTip.SetToolTip($chkFilterRegex, "Mehrere Suchbegriffe mit Komma trennen.")
        $toolTip.SetToolTip($btnApplyFilter, "Sucht im Output mit dem gesetzten Filter (ohne erneuten Run).")
        $toolTip.SetToolTip($btnClearFilter, "Setzt den Filter zurueck und zeigt wieder die volle Ausgabe.")
        $toolTip.SetToolTip($btnShowFullOutput, "Zeigt wieder die komplette Audit-Ausgabe.")
        $toolTip.SetToolTip($chkCoreRoutes, "Wird vom Core immer ausgefuehrt.")
        $toolTip.SetToolTip($chkCoreRouteOptionScan, "Wird vom Core immer ausgefuehrt.")
        $toolTip.SetToolTip($chkCoreSecurityBaseline, "Wird vom Core immer ausgefuehrt.")
    } catch {
        # ignore
    }

    foreach ($key in $statusLabels.Keys) {
        if (-not $checkMap.ContainsKey($key)) { continue }
        $statusLabel = $statusLabels[$key]
        $control = $checkMap[$key]
        $statusLabel.Add_Click({
            try { Select-AuditDetail ([string]$this.Tag) } catch { }
        })
        $control.Tag = $key
        if ($control -is [System.Windows.Forms.CheckBox]) {
            $control.Add_Click({
                try { Select-AuditDetail ([string]$this.Tag) } catch { }
            })
        }
    }

    $btnShowFullOutput.Add_Click({
        try { Select-AuditDetail "" } catch { }
    })

    Reset-AuditStatuses

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

    $chkHttpProbe.add_CheckedChanged({ Sync-HttpFieldsEnabled })
    Sync-HttpFieldsEnabled

    $chkTailLog.add_CheckedChanged({ Sync-TailFieldsEnabled })
    Sync-TailFieldsEnabled

    $chkRoleSmokeTest.add_CheckedChanged({ Sync-RoleSmokeFieldsEnabled })
    $chkLoginCsrfProbe.add_CheckedChanged({ Sync-RoleSmokeFieldsEnabled })
    Sync-RoleSmokeFieldsEnabled

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

    function Get-UiArgs() {
        $argsList = New-Object System.Collections.Generic.List[string]

        # Always pass BaseUrl deterministically from global dropdown.
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

        # ProbePaths: pass as proper string[] tokens (NOT newline payload)
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
        $argsList.Add("-AutoOpenExportFolder") | Out-Null
        $argsList.Add($(if ($chkAutoOpenExportFolder.Checked) { "true" } else { "false" })) | Out-Null
        if ($chkLoginCsrfProbe.Checked) { $argsList.Add("-LoginCsrfProbe") | Out-Null }
        if ($chkRoleSmokeTest.Checked) { $argsList.Add("-RoleSmokeTest") | Out-Null }
        if ($chkSessionCsrfBaseline.Checked) { $argsList.Add("-SessionCsrfBaseline") | Out-Null }

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

        # IMPORTANT: TailLog is handled by GUI (separate tail window), NOT by core.
        return @($argsList.ToArray())
    }

    $btnRun.Add_Click({
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
        $preRunNotice = ""

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

            $snapshotSelectionNow = "OFF"
            try { $snapshotSelectionNow = ("" + $cmbLaravelLogHistory.Text).Trim().ToUpper() } catch { $snapshotSelectionNow = "OFF" }
            $preRunNotice = Build-UiRunPlanNotice
            if ($snapshotSelectionNow -ne "OFF" -and [bool]$chkLogClearBefore.Checked) {
                $preRunNotice += "`r`n`r`nHinweis: LogClearBefore ist aktiv. Wenn waehrend des Audits keine neuen Logzeilen entstehen, kann der Snapshot leer sein."
            }

            # Run core as a separate hidden process to avoid in-process binding shifts against UI parameters (TailLogMode etc.).
            $psArgs = New-Object System.Collections.Generic.List[string]
            $psArgs.Add("-NoProfile") | Out-Null
            $psArgs.Add("-ExecutionPolicy") | Out-Null
            $psArgs.Add("Bypass") | Out-Null
            $psArgs.Add("-File") | Out-Null
            $psArgs.Add($corePath) | Out-Null
            foreach ($a in $argsList) { $psArgs.Add(("" + $a)) | Out-Null }

            $maskedPsArgs = @(Get-MaskedArgumentList -InputArgs @($psArgs.ToArray()))
            $childCmdLine = ("powershell.exe " + (($maskedPsArgs | ForEach-Object { ConvertTo-QuotedArg $_ }) -join " ")).Trim()

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
            $script:AuditOutputViewRaw = $combinedErr
            Parse-AuditOutput
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

    $chkFilterIgnoreCase.Add_CheckedChanged({
        try { Set-OutputFilterView } catch { }
    })

    $chkFilterRegex.Add_CheckedChanged({
        try { Set-OutputFilterView } catch { }
    })

    $btnSavePaths.Add_Click({
        try {
            $ppLines = @()
            try { $ppLines = ("" + $txtProbePaths.Text) -split "`r?`n" } catch { $ppLines = @() }
            $ppLines = @($ppLines | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })

            $rsLines = @($ppLines)

            Save-KsAuditPathsConfig -ConfigPath $uiPathsConfigFile -ProbePathsToSave @($ppLines) -RoleSmokePathsToSave @($rsLines)
            $lblStatus.Text = ("Pfade gespeichert: " + $uiPathsConfigFile)
        } catch {
            $lblStatus.Text = ("Save Paths fehlgeschlagen: " + $_.Exception.Message)
        }
    })

    $btnSaveSuperadmin.Add_Click({
        try {
            Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role "superadmin" -Email ("" + $txtSuperadminEmail.Text).Trim() -Password ("" + $txtSuperadminPassword.Text)
            $lblStatus.Text = "Superadmin gespeichert"
        } catch {
            $lblStatus.Text = ("Save Superadmin fehlgeschlagen: " + $_.Exception.Message)
        }
    })

    $btnClearSuperadmin.Add_Click({
        try {
            $txtSuperadminEmail.Text = ""
            $txtSuperadminPassword.Text = ""
            Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role "superadmin" -Email "" -Password "" -ClearRole:$true
            $lblStatus.Text = "Superadmin geloescht"
        } catch {
            $lblStatus.Text = ("Clear Superadmin fehlgeschlagen: " + $_.Exception.Message)
        }
    })

    $btnSaveAdmin.Add_Click({
        try {
            Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role "admin" -Email ("" + $txtAdminEmail.Text).Trim() -Password ("" + $txtAdminPassword.Text)
            $lblStatus.Text = "Admin gespeichert"
        } catch {
            $lblStatus.Text = ("Save Admin fehlgeschlagen: " + $_.Exception.Message)
        }
    })

    $btnClearAdmin.Add_Click({
        try {
            $txtAdminEmail.Text = ""
            $txtAdminPassword.Text = ""
            Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role "admin" -Email "" -Password "" -ClearRole:$true
            $lblStatus.Text = "Admin geloescht"
        } catch {
            $lblStatus.Text = ("Clear Admin fehlgeschlagen: " + $_.Exception.Message)
        }
    })

    $btnSaveModerator.Add_Click({
        try {
            Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role "moderator" -Email ("" + $txtModeratorEmail.Text).Trim() -Password ("" + $txtModeratorPassword.Text)
            $lblStatus.Text = "Moderator gespeichert"
        } catch {
            $lblStatus.Text = ("Save Moderator fehlgeschlagen: " + $_.Exception.Message)
        }
    })

    $btnClearModerator.Add_Click({
        try {
            $txtModeratorEmail.Text = ""
            $txtModeratorPassword.Text = ""
            Save-KsAuditCredential -ConfigPath $uiCredsConfigFile -Role "moderator" -Email "" -Password "" -ClearRole:$true
            $lblStatus.Text = "Moderator geloescht"
        } catch {
            $lblStatus.Text = ("Clear Moderator fehlgeschlagen: " + $_.Exception.Message)
        }
    })

    $btnClear.Add_Click({
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

$consolePathsConfig = ""
try {
    if ($PathsConfigFile -and ("" + $PathsConfigFile).Trim() -ne "") {
        $consolePathsConfig = ("" + $PathsConfigFile).Trim()
        if (-not [System.IO.Path]::IsPathRooted($consolePathsConfig)) {
            $consolePathsConfig = Join-Path $projectRoot $consolePathsConfig
        }
    } else {
        $consolePathsConfig = Join-Path $projectRoot "tools\audit\ks-admin-audit-paths.json"
    }
} catch {
    $consolePathsConfig = Join-Path $projectRoot "tools\audit\ks-admin-audit-paths.json"
}
if ($consolePathsConfig -and ("" + $consolePathsConfig).Trim() -ne "") {
    $argList.Add("-PathsConfigFile") | Out-Null
    $argList.Add($consolePathsConfig) | Out-Null
}

if ($ProbePaths -and $ProbePaths.Count -gt 0) {
    $argList.Add("-ProbePaths") | Out-Null
    $pp = @($ProbePaths | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
    if ($pp.Count -gt 0) { $argList.Add(($pp -join " ")) | Out-Null }
}

if ($HttpProbe) { $argList.Add("-HttpProbe") | Out-Null }
if ($RoutesVerbose) { $argList.Add("-RoutesVerbose") | Out-Null }
if ($RouteListFindstrAdmin) { $argList.Add("-RouteListFindstrAdmin") | Out-Null }
if ($SuperadminCount) { $argList.Add("-SuperadminCount") | Out-Null }
if ($LoginCsrfProbe) { $argList.Add("-LoginCsrfProbe") | Out-Null }
if ($RoleSmokeTest) { $argList.Add("-RoleSmokeTest") | Out-Null }
if ($SessionCsrfBaseline) { $argList.Add("-SessionCsrfBaseline") | Out-Null }
if ($LogSnapshot) {
    $argList.Add("-LogSnapshot") | Out-Null
    $snapLines = 200
    try {
        $n = [int]$LogSnapshotLines
        if ($n -gt 0) { $snapLines = $n }
    } catch { $snapLines = 200 }
    $argList.Add("-LogSnapshotLines") | Out-Null
    $argList.Add(("" + $snapLines)) | Out-Null
}

if ($LogClearBefore) { $argList.Add("-LogClearBefore") | Out-Null }
if ($LogClearAfter) { $argList.Add("-LogClearAfter") | Out-Null }
$argList.Add("-ShowCheckDetails") | Out-Null
$argList.Add(("" + $ShowCheckDetails)) | Out-Null
$argList.Add("-ExportLogs") | Out-Null
$argList.Add(("" + $ExportLogs)) | Out-Null
$argList.Add("-AutoOpenExportFolder") | Out-Null
$argList.Add(("" + $AutoOpenExportFolder)) | Out-Null

if ($TailLog) { $argList.Add("-TailLog") | Out-Null }

if ($RoleSmokeTest -and $RoleSmokePaths -and $RoleSmokePaths.Count -gt 0) {
    $argList.Add("-RoleSmokePaths") | Out-Null
    $rs = @($RoleSmokePaths | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
    foreach ($rp in $rs) {
        $argList.Add($rp) | Out-Null
    }
}

if ($RoleSmokeTest -or $LoginCsrfProbe) {
    if ($SuperadminEmail -and ("" + $SuperadminEmail).Trim() -ne "") { $argList.Add("-SuperadminEmail") | Out-Null; $argList.Add(("" + $SuperadminEmail).Trim()) | Out-Null }
    if ($SuperadminPassword -and ("" + $SuperadminPassword) -ne "") { $argList.Add("-SuperadminPassword") | Out-Null; $argList.Add("" + $SuperadminPassword) | Out-Null }
}
if ($RoleSmokeTest) {
    if ($AdminEmail -and ("" + $AdminEmail).Trim() -ne "") { $argList.Add("-AdminEmail") | Out-Null; $argList.Add(("" + $AdminEmail).Trim()) | Out-Null }
    if ($AdminPassword -and ("" + $AdminPassword) -ne "") { $argList.Add("-AdminPassword") | Out-Null; $argList.Add("" + $AdminPassword) | Out-Null }
    if ($ModeratorEmail -and ("" + $ModeratorEmail).Trim() -ne "") { $argList.Add("-ModeratorEmail") | Out-Null; $argList.Add(("" + $ModeratorEmail).Trim()) | Out-Null }
    if ($ModeratorPassword -and ("" + $ModeratorPassword) -ne "") { $argList.Add("-ModeratorPassword") | Out-Null; $argList.Add("" + $ModeratorPassword) | Out-Null }
}

$maskedArgList = @(Get-MaskedArgumentList -InputArgs @($argList.ToArray()))
$cmdShown = ("powershell.exe " + ($maskedArgList -join " "))
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
