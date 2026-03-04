# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit-ui.ps1
# Purpose: Repeatable admin/backend audit (routes, duplicates, inline HTML/Blade, role checks, DB sanity, optional HTTP traces)
# Created: 19-02-2026 17:25 (Europe/Berlin)
# Changed: 04-03-2026 02:20 (Europe/Berlin)
# Version: 9.5
# =============================================================================

[CmdletBinding()]
param(
    # Base URL for optional HTTP checks
    [string]$BaseUrl = "http://kiezsingles.test",

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

    # If set, enables active security abuse probes in the CLI core.
    [switch]$SecurityProbe,

    # Failed login attempts used by security lockout probe.
    [int]$SecurityLoginAttempts = 8,

    # If set, runs optional IP ban enforcement probe.
    [switch]$SecurityCheckIpBan,

    # If set, runs optional registration abuse probe.
    [switch]$SecurityCheckRegister,

    # If set, security lockout probe expects explicit 429 status.
    [switch]$SecurityExpect429,

    # Lockout keywords used by security probes.
    [string[]]$SecurityLockoutKeywords = @("too many attempts","throttle","locked","lockout","zu viele","versuche"),

    # If set, runs full end-to-end security flow over HTTP (login abuse / bans / events).
    [switch]$SecurityE2E,
    [switch]$SecurityE2ELockout,
    [switch]$SecurityE2EIpAutoban,
    [switch]$SecurityE2EDeviceAutoban,
    [switch]$SecurityE2EIdentityBan,
    [switch]$SecurityE2ESupportRef,
    [switch]$SecurityE2EEventsCheck,
    [int]$SecurityE2EAttempts = 10,
    [int]$SecurityE2EThreshold = 3,
    [int]$SecurityE2ESeconds = 300,
    [string]$SecurityE2ELogin = "audit-test@kiezsingles.local",
    [string]$SecurityE2EPassword = "random",
    [bool]$SecurityE2ECleanup = $true,
    [bool]$SecurityE2EDryRun = $false,
    [bool]$SecurityE2EEnvGate = $true,

    # If true, show per-check detail/evidence blocks in audit output.
    # IMPORTANT: Some runners pass "-ShowCheckDetails:System.String" or similar garbage.
    # Therefore ShowCheckDetails is a string and we parse it to bool.
    [string]$ShowCheckDetails = "",

    # If true, export per-check log slices.
    # IMPORTANT: Some runners pass "-ExportLogs:System.String" or similar garbage.
    # Therefore ExportLogs is a string and we parse it to bool.
    [string]$ExportLogs = "",

    # Max lines for per-check log slice/export.
    [ValidateSet(50,200,500,1000)]
    [int]$ExportLogsLines = 200,

    # Folder for exported per-check logs.
    [string]$ExportFolder = "tools/audit/output",

    # If true, open export folder after run (if exports exist).
    # IMPORTANT: Some runners pass "-AutoOpenExportFolder:System.String" or similar garbage.
    # Therefore AutoOpenExportFolder is a string and we parse it to bool.
    [string]$AutoOpenExportFolder = "",

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

function ConvertTo-ParsedBoolOrDefault {
    param(
        [Parameter(Mandatory = $false)]$Value,
        [Parameter(Mandatory = $true)][bool]$Default
    )
    try {
        $s = ("" + $Value).Trim()
        if ($s -eq "") { return $Default }
        if ($s -match '^(?i:false|\$false|0|no|off|disable|disabled)$') { return $false }
        if ($s -match '^(?i:true|\$true|1|yes|on|enable|enabled)$') { return $true }
        return $Default
    } catch {
        return $Default
    }
}

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

$ShowCheckDetailsEnabled = $false
try {
    if ($PSBoundParameters.ContainsKey('ShowCheckDetails')) {
        $ShowCheckDetailsEnabled = ConvertTo-ParsedBoolOrDefault -Value $ShowCheckDetails -Default $false
    } else {
        $ShowCheckDetailsEnabled = $false
    }
} catch { $ShowCheckDetailsEnabled = $false }

$ExportLogsEnabled = $false
try {
    if ($PSBoundParameters.ContainsKey('ExportLogs')) {
        $ExportLogsEnabled = ConvertTo-ParsedBoolOrDefault -Value $ExportLogs -Default $false
    } else {
        $ExportLogsEnabled = $false
    }
} catch { $ExportLogsEnabled = $false }

$AutoOpenExportFolderEnabled = $false
try {
    if ($PSBoundParameters.ContainsKey('AutoOpenExportFolder')) {
        $AutoOpenExportFolderEnabled = ConvertTo-ParsedBoolOrDefault -Value $AutoOpenExportFolder -Default $false
    } else {
        $AutoOpenExportFolderEnabled = $false
    }
} catch { $AutoOpenExportFolderEnabled = $false }


# --- UI core module import (deterministic relative path)
$uiCoreImportScriptDir = $null
if ($PSScriptRoot -and ($PSScriptRoot.Trim() -ne "")) {
    $uiCoreImportScriptDir = $PSScriptRoot
} elseif ($PSCommandPath -and ($PSCommandPath.Trim() -ne "")) {
    $uiCoreImportScriptDir = Split-Path -Parent $PSCommandPath
} elseif ($MyInvocation -and ($MyInvocation.MyCommand -and ($MyInvocation.MyCommand -is [object]) -and ($MyInvocation.MyCommand | Get-Member -Name Path -ErrorAction SilentlyContinue))) {
    $uiCoreImportScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $uiCoreImportScriptDir = (Get-Location).Path
}
$uiCoreModulePath = Join-Path $uiCoreImportScriptDir "ks-admin-audit-ui-core.psm1"
try {
    Import-Module $uiCoreModulePath -Force -ErrorAction Stop
} catch {
    throw ("UI core module import failed: " + $uiCoreModulePath + " (" + $_.Exception.Message + ")")
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

# --- Regression guard: detect which Login CSRF check file exists (02 vs 02a)
try {
    $checksDir = Join-Path $projectRoot "tools\audit\checks"
    $probe02 = Join-Path $checksDir "02_login_csrf_probe.ps1"
    $probe02a = Join-Path $checksDir "02a_login_csrf_probe.ps1"

    $found = @()
    if (Test-Path -LiteralPath $probe02 -PathType Leaf) { $found += $probe02 }
    if (Test-Path -LiteralPath $probe02a -PathType Leaf) { $found += $probe02a }

    if ($found.Count -eq 1) {
        Write-Host ("LoginCsrfProbe check file: " + $found[0])
    } elseif ($found.Count -gt 1) {
        Write-Host ("LoginCsrfProbe check files (multiple found): " + ($found -join " | "))
    } else {
        Write-Host ("LoginCsrfProbe check file: NOT FOUND (expected " + $probe02 + " or " + $probe02a + ")")
    }
} catch { }

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
if ($LoginCsrfProbe) { $argList.Add("-LoginCsrfProbe") | Out-Null }
if ($RoleSmokeTest) { $argList.Add("-RoleSmokeTest") | Out-Null }
if ($SessionCsrfBaseline) { $argList.Add("-SessionCsrfBaseline") | Out-Null }
if ($SecurityProbe) { $argList.Add("-SecurityProbe") | Out-Null }
if ($SecurityProbe -and $SecurityCheckIpBan) { $argList.Add("-SecurityCheckIpBan") | Out-Null }
if ($SecurityProbe -and $SecurityCheckRegister) { $argList.Add("-SecurityCheckRegister") | Out-Null }
if ($SecurityProbe -and $SecurityExpect429) { $argList.Add("-SecurityExpect429") | Out-Null }
if ($SecurityE2E) { $argList.Add("-SecurityE2E") | Out-Null }
if ($SecurityE2E -and $SecurityE2ELockout) { $argList.Add("-SecurityE2ELockout") | Out-Null }
if ($SecurityE2E -and $SecurityE2EIpAutoban) { $argList.Add("-SecurityE2EIpAutoban") | Out-Null }
if ($SecurityE2E -and $SecurityE2EDeviceAutoban) { $argList.Add("-SecurityE2EDeviceAutoban") | Out-Null }
if ($SecurityE2E -and $SecurityE2EIdentityBan) { $argList.Add("-SecurityE2EIdentityBan") | Out-Null }
if ($SecurityE2E -and $SecurityE2ESupportRef) { $argList.Add("-SecurityE2ESupportRef") | Out-Null }
if ($SecurityE2E -and $SecurityE2EEventsCheck) { $argList.Add("-SecurityE2EEventsCheck") | Out-Null }
if ($SecurityLoginAttempts -gt 0) {
    if ($SecurityLoginAttempts -gt 10) { $SecurityLoginAttempts = 10 }
    if ($SecurityLoginAttempts -lt 1) { $SecurityLoginAttempts = 1 }
    $argList.Add("-SecurityLoginAttempts") | Out-Null
    $argList.Add(("" + $SecurityLoginAttempts)) | Out-Null
}
if ($SecurityE2E -and $SecurityE2EAttempts -gt 0) {
    $argList.Add("-SecurityE2EAttempts") | Out-Null
    $argList.Add(("" + $SecurityE2EAttempts)) | Out-Null
}
if ($SecurityE2E -and $SecurityE2EThreshold -gt 0) {
    $argList.Add("-SecurityE2EThreshold") | Out-Null
    $argList.Add(("" + $SecurityE2EThreshold)) | Out-Null
}
if ($SecurityE2E -and $SecurityE2ESeconds -gt 0) {
    $argList.Add("-SecurityE2ESeconds") | Out-Null
    $argList.Add(("" + $SecurityE2ESeconds)) | Out-Null
}
if ($SecurityE2E -and $SecurityE2ELogin -and ("" + $SecurityE2ELogin).Trim() -ne "") {
    $argList.Add("-SecurityE2ELogin") | Out-Null
    $argList.Add(("" + $SecurityE2ELogin).Trim()) | Out-Null
}
if ($SecurityE2E -and $SecurityE2EPassword -and ("" + $SecurityE2EPassword) -ne "") {
    $argList.Add("-SecurityE2EPassword") | Out-Null
    $argList.Add("" + $SecurityE2EPassword) | Out-Null
}
if ($SecurityE2E -and $PSBoundParameters.ContainsKey("SecurityE2ECleanup")) {
    $argList.Add("-SecurityE2ECleanup") | Out-Null
    $argList.Add(("" + [bool]$SecurityE2ECleanup).ToLowerInvariant()) | Out-Null
}
if ($SecurityE2E -and $PSBoundParameters.ContainsKey("SecurityE2EDryRun")) {
    $argList.Add("-SecurityE2EDryRun") | Out-Null
    $argList.Add(("" + [bool]$SecurityE2EDryRun).ToLowerInvariant()) | Out-Null
}
if ($SecurityE2E -and $PSBoundParameters.ContainsKey("SecurityE2EEnvGate")) {
    $argList.Add("-SecurityE2EEnvGate") | Out-Null
    $argList.Add(("" + [bool]$SecurityE2EEnvGate).ToLowerInvariant()) | Out-Null
}
if ($SecurityLockoutKeywords -and $SecurityLockoutKeywords.Count -gt 0) {
    $kw = @($SecurityLockoutKeywords | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
    if ($kw.Count -gt 0) {
        $argList.Add("-SecurityLockoutKeywords") | Out-Null
        foreach ($k in $kw) { $argList.Add($k) | Out-Null }
    }
}

$argList.Add("-ShowCheckDetails") | Out-Null
$argList.Add(("" + [bool]$ShowCheckDetailsEnabled).ToLowerInvariant()) | Out-Null

$argList.Add("-ExportLogs") | Out-Null
$argList.Add(("" + [bool]$ExportLogsEnabled).ToLowerInvariant()) | Out-Null

$expLines = 200
try {
    $nExp = [int]$ExportLogsLines
    if ($nExp -in @(50,200,500,1000)) { $expLines = $nExp }
} catch { $expLines = 200 }
$argList.Add("-ExportLogsLines") | Out-Null
$argList.Add(("" + $expLines)) | Out-Null

$expFolder = ""
try { $expFolder = ("" + $ExportFolder).Trim() } catch { $expFolder = "" }
$expFolder = Resolve-ExportFolderAbsolute -ProjectRoot $projectRoot -FolderValue $expFolder
try { $script:ExportFolder = $expFolder } catch { }
$argList.Add("-ExportFolder") | Out-Null
$argList.Add($expFolder) | Out-Null

$argList.Add("-AutoOpenExportFolder") | Out-Null
$argList.Add(("" + [bool]$AutoOpenExportFolderEnabled).ToLowerInvariant()) | Out-Null

$defaultPerCheckIds = @(
    "cache_clear","routes","route_list_option_scan","http_probe","login_csrf_probe","role_smoke_test",
    "governance_superadmin","session_csrf_baseline","security_abuse","security_e2e","routes_verbose","routes_findstr_admin",
    "log_snapshot","tail_log","log_clear_before","log_clear_after"
)
$consoleDetailsMap = [ordered]@{}
$consoleExportMap = [ordered]@{}
foreach ($id in $defaultPerCheckIds) {
    if ($id -eq "tail_log") {
        if ($TailLog) {
            $consoleDetailsMap[$id] = [bool]$ShowCheckDetailsEnabled
            $consoleExportMap[$id] = [bool]$ExportLogsEnabled
        } else {
            $consoleDetailsMap[$id] = $false
            $consoleExportMap[$id] = $false
        }
    } else {
        $consoleDetailsMap[$id] = [bool]$ShowCheckDetailsEnabled
        $consoleExportMap[$id] = [bool]$ExportLogsEnabled
    }
}
$consolePerCheckDetailsJson = "{}"
$consolePerCheckExportJson = "{}"
try { $consolePerCheckDetailsJson = ($consoleDetailsMap | ConvertTo-Json -Compress) } catch { $consolePerCheckDetailsJson = "{}" }
try { $consolePerCheckExportJson = ($consoleExportMap | ConvertTo-Json -Compress) } catch { $consolePerCheckExportJson = "{}" }
$argList.Add("-PerCheckDetails") | Out-Null
$argList.Add($consolePerCheckDetailsJson) | Out-Null
$argList.Add("-PerCheckExport") | Out-Null
$argList.Add($consolePerCheckExportJson) | Out-Null

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

if ($TailLog) { $argList.Add("-TailLog") | Out-Null }

if ($RoleSmokeTest -and $RoleSmokePaths -and $RoleSmokePaths.Count -gt 0) {
    $argList.Add("-RoleSmokePaths") | Out-Null
    $rs = @($RoleSmokePaths | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
    if ($rs.Count -gt 0) {
        foreach ($rp in $rs) {
            $argList.Add(("" + $rp)) | Out-Null
        }
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