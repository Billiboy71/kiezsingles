# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit-ui.ps1
# Purpose: Repeatable admin/backend audit (routes, duplicates, inline HTML/Blade, role checks, DB sanity, optional HTTP traces)
# Created: 19-02-2026 17:25 (Europe/Berlin)
# Changed: 14-03-2026 19:00 (Europe/Berlin)
# Version: 8.3
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

    # If set, runs the security / abuse protection check suite.
    [switch]$SecurityProbe,

    # Login attempts used by the security / abuse protection suite.
    [string]$SecurityLoginAttempts = "8",

    # If set, includes IP-ban probe in the security suite.
    [switch]$SecurityCheckIpBan,

    # If set, includes register probe in the security suite.
    [switch]$SecurityCheckRegister,

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

    # Max line count per exported log slice.
    [int]$ExportLogsLines = 200,

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

$script:KsAuditUiScriptRoot = $PSScriptRoot
$script:KsAuditGuiVersion = "2.0"

function Get-GuiEnabledFlag {
    $enabled = $true
    if ($PSBoundParameters.ContainsKey('Gui')) {
        $s = ("" + $Gui).Trim()
        if ($s -eq "") {
            $enabled = $true
        } elseif ($s -match '^(?i:false|\$false|0|no|off|disable|disabled)$') {
            $enabled = $false
        } elseif ($s -match '^(?i:true|\$true|1|yes|on|enable|enabled)$') {
            $enabled = $true
        } else {
            $enabled = $true
        }
    }
    return $enabled
}

function Get-GuiRelaunchArgumentList {
    $argsList = New-Object System.Collections.Generic.List[string]

    foreach ($entry in $PSBoundParameters.GetEnumerator()) {
        $name = "" + $entry.Key
        $value = $entry.Value

        if ($name -eq "Gui") { continue }
        if ($name -eq "IgnoredArgs") { continue }

        if ($value -is [System.Management.Automation.SwitchParameter]) {
            if ([bool]$value.IsPresent) {
                $argsList.Add(("-" + $name)) | Out-Null
            }
            continue
        }

        if ($null -eq $value) {
            continue
        }

        if ($value -is [System.Array]) {
            $items = @($value | ForEach-Object { "" + $_ } | Where-Object { ("" + $_).Trim() -ne "" })
            if ($items.Count -gt 0) {
                $argsList.Add(("-" + $name)) | Out-Null
                foreach ($item in $items) {
                    $argsList.Add($item) | Out-Null
                }
            }
            continue
        }

        $argsList.Add(("-" + $name)) | Out-Null
        $argsList.Add(("" + $value)) | Out-Null
    }

    $argsList.Add("-Gui") | Out-Null
    $argsList.Add("true") | Out-Null

    if ($IgnoredArgs -and $IgnoredArgs.Count -gt 0) {
        foreach ($token in $IgnoredArgs) {
            if (("" + $token).Trim() -ne "") {
                $argsList.Add(("" + $token)) | Out-Null
            }
        }
    }

    return @($argsList.ToArray())
}

$GuiEnabled = Get-GuiEnabledFlag

if ($GuiEnabled -and $env:KS_AUDIT_GUI_HIDDEN_LAUNCH -ne "1") {
    try {
        $launcherExe = Join-Path $PSHOME "powershell.exe"
        if (-not (Test-Path $launcherExe)) {
            $launcherExe = "powershell.exe"
        }

        $relaunchArgs = New-Object System.Collections.Generic.List[string]
        $relaunchArgs.Add("-NoProfile") | Out-Null
        $relaunchArgs.Add("-ExecutionPolicy") | Out-Null
        $relaunchArgs.Add("Bypass") | Out-Null
        $relaunchArgs.Add("-File") | Out-Null
        $relaunchArgs.Add($PSCommandPath) | Out-Null

        foreach ($arg in @(Get-GuiRelaunchArgumentList)) {
            $relaunchArgs.Add(("" + $arg)) | Out-Null
        }

        $isWindowsPlatform = $false
        try { $isWindowsPlatform = ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) } catch { $isWindowsPlatform = $false }

        if ($isWindowsPlatform) {
            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = $launcherExe
            $psi.WorkingDirectory = (Get-Location).Path
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            $psi.RedirectStandardOutput = $false
            $psi.RedirectStandardError = $false
            $psi.RedirectStandardInput = $false
            $psi.EnvironmentVariables["KS_AUDIT_GUI_HIDDEN_LAUNCH"] = "1"
            $psi.Arguments = (($relaunchArgs.ToArray() | ForEach-Object {
                $t = "" + $_
                if ($t -match '[\s"]') {
                    '"' + (($t -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
                } else {
                    $t
                }
            }) -join " ")

            [void][System.Diagnostics.Process]::Start($psi)
            return
        }
    } catch {
    }
}

# Ensure predictable UTF-8 output (console + child processes consuming stdout)
try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

. (Join-Path $PSScriptRoot "ui\ks-admin-audit-ui-config.ps1")
. (Join-Path $PSScriptRoot "ui\ks-admin-audit-ui-popups.ps1")
. (Join-Path $PSScriptRoot "ui\ks-admin-audit-ui-runner.ps1")
. (Join-Path $PSScriptRoot "ui\ks-admin-audit-ui-status.ps1")
. (Join-Path $PSScriptRoot "ui\ks-admin-audit-ui-form.ps1")

if (Get-Command Show-AuditGui -CommandType Function -ErrorAction SilentlyContinue) {
    $script:KsAuditOriginalShowAuditGui = ${function:Show-AuditGui}

    function Show-AuditGui {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $titleTimer = New-Object System.Windows.Forms.Timer
        $titleTimer.Interval = 150

        $titleTimer.Add_Tick({
            try {
                $forms = [System.Windows.Forms.Application]::OpenForms
                if ($null -eq $forms -or $forms.Count -le 0) { return }

                $mainForm = $null
                foreach ($form in $forms) {
                    if ($form -is [System.Windows.Forms.Form]) {
                        $mainForm = $form
                        break
                    }
                }

                if ($null -eq $mainForm) { return }

                $targetTitle = "KiezSingles Admin Audit v$($script:KsAuditGuiVersion)"
                if (("" + $mainForm.Text) -ne $targetTitle) {
                    $mainForm.Text = $targetTitle
                }

                $versionLabel = $mainForm.Controls.Find("lblKsAuditGuiVersion", $true)
                if ($null -eq $versionLabel -or $versionLabel.Count -le 0) {
                    $dashboardGroup = $null
                    foreach ($control in $mainForm.Controls) {
                        if ($control -is [System.Windows.Forms.GroupBox] -and ("" + $control.Text).Trim() -eq "Audit Dashboard") {
                            $dashboardGroup = $control
                            break
                        }
                    }

                    if ($null -ne $dashboardGroup) {
                        $lblVersion = New-Object System.Windows.Forms.Label
                        $lblVersion.Name = "lblKsAuditGuiVersion"
                        $lblVersion.AutoSize = $true
                        $lblVersion.Text = ("Version " + $script:KsAuditGuiVersion)
                        $lblVersion.ForeColor = [System.Drawing.Color]::DimGray
                        $lblVersion.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
                        $lblVersion.Location = New-Object System.Drawing.Point(([Math]::Max(12, $dashboardGroup.ClientSize.Width - 100)), 18)
                        $dashboardGroup.Controls.Add($lblVersion)

                        $dashboardGroup.Add_Resize({
                            try {
                                $found = $this.Controls.Find("lblKsAuditGuiVersion", $false)
                                if ($found -and $found.Count -gt 0) {
                                    $found[0].Location = New-Object System.Drawing.Point(([Math]::Max(12, $this.ClientSize.Width - 100)), 18)
                                }
                            } catch { }
                        })
                    }
                }

                $titleTimer.Stop()
                $titleTimer.Dispose()
            } catch {
                try {
                    $titleTimer.Stop()
                    $titleTimer.Dispose()
                } catch { }
            }
        })

        $titleTimer.Start()
        & $script:KsAuditOriginalShowAuditGui
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
if ($SecurityProbe) { $argList.Add("-SecurityProbe") | Out-Null }
if ($SecurityCheckIpBan) { $argList.Add("-SecurityCheckIpBan") | Out-Null }
if ($SecurityCheckRegister) { $argList.Add("-SecurityCheckRegister") | Out-Null }
if (("" + $SecurityLoginAttempts).Trim() -ne "") {
    $argList.Add("-SecurityLoginAttempts") | Out-Null
    $argList.Add(("" + $SecurityLoginAttempts).Trim()) | Out-Null
}
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
$argList.Add("-ExportLogsLines") | Out-Null
$argList.Add(("" + [int]$ExportLogsLines)) | Out-Null
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
