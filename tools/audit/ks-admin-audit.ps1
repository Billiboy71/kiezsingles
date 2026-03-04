# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit.ps1
# Purpose: Deterministic CLI core for KiezSingles Admin Audit (no GUI)
# Created: 21-02-2026 00:29 (Europe/Berlin)
# Changed: 04-03-2026 01:59 (Europe/Berlin)
# Version: 5.3
# =============================================================================

[CmdletBinding()]
param(
    # Base URL for optional HTTP checks
    [string]$BaseUrl = "http://127.0.0.1:8000",

    # Admin endpoints to probe (relative to BaseUrl) - only used if -HttpProbe is set
    [string[]]$ProbePaths = @("/admin", "/admin/status", "/admin/moderation", "/admin/maintenance", "/admin/debug"),

    # If set, performs HTTP probe checks (deterministic interpretation)
    [switch]$HttpProbe,

    # If set, tails laravel.log (CTRL+C to stop)
    [switch]$TailLog,

    # If set, runs additional verbose admin route listing (-vv)
    [switch]$RoutesVerbose,

    # If set, runs full route:list and filters lines containing "admin"
    [switch]$RouteListFindstrAdmin,

    # If set, runs governance check: superadmin count (deterministic; via artisan command)
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

    # Optional path config file (compatibility with GUI wrapper)
    [string]$PathsConfigFile = "",

    # If set, prints session/CSRF baseline (read-only)
    [switch]$SessionCsrfBaseline,

    # If set, appends Laravel log snapshot (tail) to output
    [switch]$LogSnapshot,

    # Line count for Laravel log snapshot (used when -LogSnapshot is set)
    [string]$LogSnapshotLines = "200",

    # If set, clears/rotates laravel.log BEFORE the audit (only if file exists).
    [switch]$LogClearBefore,

    # If set, clears/rotates laravel.log AFTER the audit (only if file exists).
    [switch]$LogClearAfter,

    # If set, scans the full project for route:list invocations using --columns/--format
    # (still excludes tools/audit/* and large dirs like vendor/node_modules/storage/bootstrap/cache)
    [switch]$RouteListOptionScanFullProject,

    # If set, enables active security abuse probes (login/register/IP behavior checks)
    [switch]$SecurityProbe,

    # Failed login attempts used by security lockout probe
    [int]$SecurityLoginAttempts = 8,

    # If set, runs optional IP ban enforcement probe
    [switch]$SecurityCheckIpBan,

    # If set, runs optional registration abuse probe
    [switch]$SecurityCheckRegister,

    # If set, security lockout probe expects explicit 429 status
    [switch]$SecurityExpect429,

    # Lockout keywords used by security probes
    [string[]]$SecurityLockoutKeywords = @("too many attempts","throttle","locked","lockout","zu viele","versuche"),

    # If set, runs full end-to-end security test flow over HTTP.
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
    [string]$SecurityE2ECleanup = "true",
    [string]$SecurityE2EDryRun = "false",
    [string]$SecurityE2EEnvGate = "true",

    # If true, prints optional per-check details/evidence blocks below the status line.
    [string]$ShowCheckDetails = "false",

    # If true, exports per-check log slices to files in ExportFolder.
    [string]$ExportLogs = "false",

    # Max lines for per-check log slice and export.
    [int]$ExportLogsLines = 200,

    # Output folder for per-check exported log slices.
    [string]$ExportFolder = "tools/audit/output",

    # If true, opens ExportFolder in Explorer after the run (when exports exist).
    [string]$AutoOpenExportFolder = "false",

    # Optional JSON map of per-check detail toggles, keyed by check id.
    [string]$PerCheckDetails = "",

    # Optional JSON map of per-check export toggles, keyed by check id.
    [string]$PerCheckExport = "",

    # If set, core will NOT call 'exit'. Instead it returns the exit code as an integer.
    # This is required for running the core in-process from the GUI without terminating the GUI host.
    [switch]$NoExit,

    # GUI flag ignored by core (compatibility with wrapper)
    [string]$Gui = "",

    # Compatibility: Some launchers pass extra stray tokens after parameters.
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$IgnoredArgs
)

# Ensure predictable UTF-8 output (no BOM) - must run BEFORE Import-Module to avoid mojibake in module import warnings
try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }
try { [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false) } catch { }

# Suppress non-approved verb warning from Import-Module (cosmetic; restore afterwards)
$__origWarningPreference = $WarningPreference
try {
    $WarningPreference = "SilentlyContinue"
    Import-Module "$PSScriptRoot\ks-admin-audit-core.psm1" -Force
} finally {
    $WarningPreference = $__origWarningPreference
    Remove-Variable -Name "__origWarningPreference" -ErrorAction SilentlyContinue
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"


# -----------------------------------------------------------------------------
# Robust parameter recovery (deterministic)
# Some runners accidentally break named binding so BaseUrl becomes "-BaseUrl"
# and/or ProbePaths absorbs tokens. If we detect that, re-parse a deterministic
# token stream and re-apply sane values.
# -----------------------------------------------------------------------------


if (Test-RecoverArgsNeeded) {
    $tokens = @()
    try { if ($null -ne $BaseUrl) { $tokens += @("" + $BaseUrl) } } catch { }
    try { if ($null -ne $ProbePaths) { $tokens += @($ProbePaths | ForEach-Object { "" + $_ }) } } catch { }
    try { if ($null -ne $IgnoredArgs) { $tokens += @($IgnoredArgs | ForEach-Object { "" + $_ }) } } catch { }

    $recBaseUrl = ""
    $recBaseUrlSet = $false
    $recProbePaths = New-Object System.Collections.Generic.List[string]
    $recHttpProbe = $false
    $recTailLog = $false
    $recRoutesVerbose = $false
    $recRouteListFindstrAdmin = $false
    $recSuperadminCount = $false
    $recLoginCsrfProbe = $false
    $recRoleSmokeTest = $false
    $recSessionCsrfBaseline = $false
    $recLogSnapshot = $false
    $recLogSnapshotLines = 200
    $recLogClearBefore = $false
    $recLogClearAfter = $false
    $recRouteListOptionScanFullProject = $false
    $recSecurityProbe = $false
    $recSecurityLoginAttempts = 8
    $recSecurityCheckIpBan = $false
    $recSecurityCheckRegister = $false
    $recSecurityExpect429 = $false
    $recSecurityLockoutKeywords = New-Object System.Collections.Generic.List[string]
    $recSecurityE2E = $false
    $recSecurityE2ELockout = $false
    $recSecurityE2EIpAutoban = $false
    $recSecurityE2EDeviceAutoban = $false
    $recSecurityE2EIdentityBan = $false
    $recSecurityE2ESupportRef = $false
    $recSecurityE2EEventsCheck = $false
    $recSecurityE2EAttempts = 10
    $recSecurityE2EThreshold = 3
    $recSecurityE2ESeconds = 300
    $recSecurityE2ELogin = "audit-test@kiezsingles.local"
    $recSecurityE2EPassword = "random"
    $recSecurityE2ECleanup = $true
    $recSecurityE2EDryRun = $false
    $recSecurityE2EEnvGate = $true
    $recShowCheckDetails = $false
    $recExportLogs = $false
    $recExportLogsLines = 200
    $recExportFolder = "tools/audit/output"
    $recAutoOpenExportFolder = $false
    $recPerCheckDetails = ""
    $recPerCheckExport = ""
    $recNoExit = $false
    $recSuperadminEmail = ""
    $recSuperadminPassword = ""
    $recAdminEmail = ""
    $recAdminPassword = ""
    $recModeratorEmail = ""
    $recModeratorPassword = ""
    $recRoleSmokePaths = New-Object System.Collections.Generic.List[string]
    $recGui = ""
    $recPathsConfigFile = ""

    $i = 0
    while ($i -lt $tokens.Count) {
        $raw = $tokens[$i]
        $t = ("" + $raw).Trim()
        if ($t -eq "") { $i++; continue }

        $name = Get-ArgNameFromToken $t

        if ($name -eq "-BaseUrl") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                $recBaseUrl = ("" + $inlineVal).Trim()
                $recBaseUrlSet = $true
                $i++
                continue
            }

            if (($i + 1) -lt $tokens.Count) {
                $recBaseUrl = ("" + $tokens[$i + 1]).Trim()
                $recBaseUrlSet = $true
                $i += 2
                continue
            }

            $i++
            continue
        }

        if ($name -eq "-ProbePaths") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                $recProbePaths.Add((("" + $inlineVal).Trim())) | Out-Null
                $i++
                continue
            }

            $i++
            while ($i -lt $tokens.Count) {
                $p = ("" + $tokens[$i]).Trim()
                if ($p -eq "") { $i++; continue }

                $pName = Get-ArgNameFromToken $p
                if ($p -match '^-') {
                    if (Test-KnownSwitch $pName -or Test-KnownValueParam $pName) { break }
                    break
                }

                $recProbePaths.Add($p) | Out-Null
                $i++
            }
            continue
        }

        if ($name -eq "-RoleSmokePaths") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                $recRoleSmokePaths.Add((("" + $inlineVal).Trim())) | Out-Null
                $i++
                continue
            }

            $i++
            while ($i -lt $tokens.Count) {
                $p = ("" + $tokens[$i]).Trim()
                if ($p -eq "") { $i++; continue }

                $pName = Get-ArgNameFromToken $p
                if ($p -match '^-') {
                    if (Test-KnownSwitch $pName -or Test-KnownValueParam $pName) { break }
                    break
                }

                $recRoleSmokePaths.Add($p) | Out-Null
                $i++
            }
            continue
        }

        if ($name -eq "-SecurityLockoutKeywords") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                $recSecurityLockoutKeywords.Add((("" + $inlineVal).Trim())) | Out-Null
                $i++
                continue
            }

            $i++
            while ($i -lt $tokens.Count) {
                $p = ("" + $tokens[$i]).Trim()
                if ($p -eq "") { $i++; continue }

                $pName = Get-ArgNameFromToken $p
                if ($p -match '^-') {
                    if (Test-KnownSwitch $pName -or Test-KnownValueParam $pName) { break }
                    break
                }

                $recSecurityLockoutKeywords.Add($p) | Out-Null
                $i++
            }
            continue
        }

        if ($name -eq "-SuperadminEmail" -or $name -eq "-SuperadminPassword" -or $name -eq "-AdminEmail" -or $name -eq "-AdminPassword" -or $name -eq "-ModeratorEmail" -or $name -eq "-ModeratorPassword" -or $name -eq "-SecurityE2ELogin" -or $name -eq "-SecurityE2EPassword" -or $name -eq "-PathsConfigFile") {
            $val = Get-ArgValueFromToken $t
            if ($null -eq $val -or (("" + $val).Trim() -eq "")) {
                if (($i + 1) -lt $tokens.Count) {
                    $n = ("" + $tokens[$i + 1]).Trim()
                    if ($n -notmatch '^-') { $val = $n; $i += 2 } else { $val = ""; $i++ }
                } else {
                    $val = ""
                    $i++
                }
            } else {
                $i++
            }

            switch ($name) {
                "-SuperadminEmail" { $recSuperadminEmail = ("" + $val) }
                "-SuperadminPassword" { $recSuperadminPassword = ("" + $val) }
                "-AdminEmail" { $recAdminEmail = ("" + $val) }
                "-AdminPassword" { $recAdminPassword = ("" + $val) }
                "-ModeratorEmail" { $recModeratorEmail = ("" + $val) }
                "-ModeratorPassword" { $recModeratorPassword = ("" + $val) }
                "-SecurityE2ELogin" { $recSecurityE2ELogin = ("" + $val) }
                "-SecurityE2EPassword" { $recSecurityE2EPassword = ("" + $val) }
                "-PathsConfigFile" { $recPathsConfigFile = ("" + $val) }
            }
            continue
        }

        if ($name -eq "-ExportFolder") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                $recExportFolder = ("" + $inlineVal).Trim()
                $i++
                continue
            }

            if (($i + 1) -lt $tokens.Count) {
                $nv = ("" + $tokens[$i + 1]).Trim()
                if ($nv -notmatch '^-') {
                    $recExportFolder = $nv
                    $i += 2
                    continue
                }
            }

            $i++
            continue
        }

        if ($name -eq "-PerCheckDetails" -or $name -eq "-PerCheckExport") {
            $inlineVal = Get-ArgValueFromToken $t
            $val = ""
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                $val = ("" + $inlineVal).Trim()
                $i++
            } else {
                if (($i + 1) -lt $tokens.Count) {
                    $nv = ("" + $tokens[$i + 1]).Trim()
                    if ($nv -notmatch '^-') {
                        $val = $nv
                        $i += 2
                    } else {
                        $i++
                    }
                } else {
                    $i++
                }
            }

            if ($name -eq "-PerCheckDetails") { $recPerCheckDetails = $val }
            if ($name -eq "-PerCheckExport") { $recPerCheckExport = $val }
            continue
        }

        if ($name -eq "-LogSnapshotLines") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                try {
                    $n = [int](("" + $inlineVal).Trim())
                    if ($n -gt 0) { $recLogSnapshotLines = $n }
                } catch { }
                $i++
                continue
            }

            if (($i + 1) -lt $tokens.Count) {
                $nv = ("" + $tokens[$i + 1]).Trim()
                if ($nv -notmatch '^-') {
                    try {
                        $n = [int]$nv
                        if ($n -gt 0) { $recLogSnapshotLines = $n }
                    } catch { }
                    $i += 2
                    continue
                }
            }

            $i++
            continue
        }

        if ($name -eq "-SecurityLoginAttempts") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                try {
                    $n = [int](("" + $inlineVal).Trim())
                    if ($n -gt 0) { $recSecurityLoginAttempts = $n }
                } catch { }
                $i++
                continue
            }

            if (($i + 1) -lt $tokens.Count) {
                $nv = ("" + $tokens[$i + 1]).Trim()
                if ($nv -notmatch '^-') {
                    try {
                        $n = [int]$nv
                        if ($n -gt 0) { $recSecurityLoginAttempts = $n }
                    } catch { }
                    $i += 2
                    continue
                }
            }

            $i++
            continue
        }

        if ($name -eq "-SecurityE2EAttempts" -or $name -eq "-SecurityE2EThreshold" -or $name -eq "-SecurityE2ESeconds") {
            $inlineVal = Get-ArgValueFromToken $t
            $val = ""
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                $val = ("" + $inlineVal).Trim()
                $i++
            } else {
                if (($i + 1) -lt $tokens.Count) {
                    $nv = ("" + $tokens[$i + 1]).Trim()
                    if ($nv -notmatch '^-') {
                        $val = $nv
                        $i += 2
                    } else {
                        $i++
                    }
                } else {
                    $i++
                }
            }

            if ($val -ne "") {
                try {
                    $n = [int]$val
                    if ($n -gt 0) {
                        switch ($name) {
                            "-SecurityE2EAttempts" { $recSecurityE2EAttempts = $n }
                            "-SecurityE2EThreshold" { $recSecurityE2EThreshold = $n }
                            "-SecurityE2ESeconds" { $recSecurityE2ESeconds = $n }
                        }
                    }
                } catch { }
            }
            continue
        }

        if ($name -eq "-ExportLogsLines") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                try {
                    $n = [int](("" + $inlineVal).Trim())
                    if ($n -gt 0) { $recExportLogsLines = $n }
                } catch { }
                $i++
                continue
            }

            if (($i + 1) -lt $tokens.Count) {
                $nv = ("" + $tokens[$i + 1]).Trim()
                if ($nv -notmatch '^-') {
                    try {
                        $n = [int]$nv
                        if ($n -gt 0) { $recExportLogsLines = $n }
                    } catch { }
                    $i += 2
                    continue
                }
            }

            $i++
            continue
        }

        if ($name -eq "-ShowCheckDetails" -or $name -eq "-ExportLogs" -or $name -eq "-AutoOpenExportFolder" -or $name -eq "-SecurityE2ECleanup" -or $name -eq "-SecurityE2EDryRun" -or $name -eq "-SecurityE2EEnvGate") {
            $inlineVal = Get-ArgValueFromToken $t
            $val = $null
            if ($null -ne $inlineVal) {
                $val = ("" + $inlineVal).Trim()
                $i++
            } else {
                if (($i + 1) -lt $tokens.Count) {
                    $nv = ("" + $tokens[$i + 1]).Trim()
                    if ($nv -notmatch '^-') {
                        $val = $nv
                        $i += 2
                    } else {
                        $val = "true"
                        $i++
                    }
                } else {
                    $val = "true"
                    $i++
                }
            }

            $parsed = $true
            try { $parsed = [System.Convert]::ToBoolean($val) } catch {
                if (("" + $val) -match '^(?i:0|no|off|false|\$false)$') { $parsed = $false } else { $parsed = $true }
            }

            switch ($name) {
                "-ShowCheckDetails" { $recShowCheckDetails = [bool]$parsed }
                "-ExportLogs" { $recExportLogs = [bool]$parsed }
                "-AutoOpenExportFolder" { $recAutoOpenExportFolder = [bool]$parsed }
                "-SecurityE2ECleanup" { $recSecurityE2ECleanup = [bool]$parsed }
                "-SecurityE2EDryRun" { $recSecurityE2EDryRun = [bool]$parsed }
                "-SecurityE2EEnvGate" { $recSecurityE2EEnvGate = [bool]$parsed }
            }
            continue
        }

        if (Test-KnownSwitch $name) {
            switch ($name) {
                "-HttpProbe" { $recHttpProbe = $true }
                "-TailLog" { $recTailLog = $true }
                "-RoutesVerbose" { $recRoutesVerbose = $true }
                "-RouteListFindstrAdmin" { $recRouteListFindstrAdmin = $true }
                "-SuperadminCount" { $recSuperadminCount = $true }
                "-LoginCsrfProbe" { $recLoginCsrfProbe = $true }
                "-RoleSmokeTest" { $recRoleSmokeTest = $true }
                "-SessionCsrfBaseline" { $recSessionCsrfBaseline = $true }
                "-LogSnapshot" { $recLogSnapshot = $true }
                "-LogClearBefore" { $recLogClearBefore = $true }
                "-LogClearAfter" { $recLogClearAfter = $true }
                "-RouteListOptionScanFullProject" { $recRouteListOptionScanFullProject = $true }
                "-SecurityProbe" { $recSecurityProbe = $true }
                "-SecurityCheckIpBan" { $recSecurityCheckIpBan = $true }
                "-SecurityCheckRegister" { $recSecurityCheckRegister = $true }
                "-SecurityExpect429" { $recSecurityExpect429 = $true }
                "-SecurityE2E" { $recSecurityE2E = $true }
                "-SecurityE2ELockout" { $recSecurityE2ELockout = $true }
                "-SecurityE2EIpAutoban" { $recSecurityE2EIpAutoban = $true }
                "-SecurityE2EDeviceAutoban" { $recSecurityE2EDeviceAutoban = $true }
                "-SecurityE2EIdentityBan" { $recSecurityE2EIdentityBan = $true }
                "-SecurityE2ESupportRef" { $recSecurityE2ESupportRef = $true }
                "-SecurityE2EEventsCheck" { $recSecurityE2EEventsCheck = $true }
                "-NoExit" { $recNoExit = $true }
            }
            $i++
            continue
        }

        if ($name -eq "-Gui") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal) {
                $recGui = ("" + $inlineVal).Trim()
                $i++
                continue
            }

            if (($i + 1) -lt $tokens.Count) {
                $n = ("" + $tokens[$i + 1]).Trim()
                if ($n -notmatch '^-') {
                    $recGui = $n
                    $i += 2
                    continue
                }
            }

            $recGui = ""
            $i++
            continue
        }

        $i++
    }

    if ($recBaseUrlSet -and $recBaseUrl -and ($recBaseUrl.Trim() -ne "") -and ($recBaseUrl.Trim() -notmatch '^-')) {
        $BaseUrl = $recBaseUrl
    }

    if ($recProbePaths.Count -gt 0) {
        $ProbePaths = @($recProbePaths.ToArray())
    }

    if ($recHttpProbe) { $HttpProbe = $true }
    if ($recTailLog) { $TailLog = $true }
    if ($recRoutesVerbose) { $RoutesVerbose = $true }
    if ($recRouteListFindstrAdmin) { $RouteListFindstrAdmin = $true }
    if ($recSuperadminCount) { $SuperadminCount = $true }
    if ($recLoginCsrfProbe) { $LoginCsrfProbe = $true }
    if ($recRoleSmokeTest) { $RoleSmokeTest = $true }
    if ($recSessionCsrfBaseline) { $SessionCsrfBaseline = $true }
    if ($recLogSnapshot) { $LogSnapshot = $true }
    $LogSnapshotLines = [int]$recLogSnapshotLines
    if ($recLogClearBefore) { $LogClearBefore = $true }
    if ($recLogClearAfter) { $LogClearAfter = $true }
    if ($recRouteListOptionScanFullProject) { $RouteListOptionScanFullProject = $true }
    if ($recSecurityProbe) { $SecurityProbe = $true }
    $SecurityLoginAttempts = [int]$recSecurityLoginAttempts
    if ($recSecurityCheckIpBan) { $SecurityCheckIpBan = $true }
    if ($recSecurityCheckRegister) { $SecurityCheckRegister = $true }
    if ($recSecurityExpect429) { $SecurityExpect429 = $true }
    if ($recSecurityE2E) { $SecurityE2E = $true }
    if ($recSecurityE2ELockout) { $SecurityE2ELockout = $true }
    if ($recSecurityE2EIpAutoban) { $SecurityE2EIpAutoban = $true }
    if ($recSecurityE2EDeviceAutoban) { $SecurityE2EDeviceAutoban = $true }
    if ($recSecurityE2EIdentityBan) { $SecurityE2EIdentityBan = $true }
    if ($recSecurityE2ESupportRef) { $SecurityE2ESupportRef = $true }
    if ($recSecurityE2EEventsCheck) { $SecurityE2EEventsCheck = $true }
    $SecurityE2EAttempts = [int]$recSecurityE2EAttempts
    $SecurityE2EThreshold = [int]$recSecurityE2EThreshold
    $SecurityE2ESeconds = [int]$recSecurityE2ESeconds
    if ($recSecurityE2ELogin -ne "") { $SecurityE2ELogin = $recSecurityE2ELogin }
    if ($recSecurityE2EPassword -ne "") { $SecurityE2EPassword = $recSecurityE2EPassword }
    $SecurityE2ECleanup = ("" + [bool]$recSecurityE2ECleanup).ToLowerInvariant()
    $SecurityE2EDryRun = ("" + [bool]$recSecurityE2EDryRun).ToLowerInvariant()
    $SecurityE2EEnvGate = ("" + [bool]$recSecurityE2EEnvGate).ToLowerInvariant()
    $ShowCheckDetails = [bool]$recShowCheckDetails
    $ExportLogs = [bool]$recExportLogs
    $ExportLogsLines = [int]$recExportLogsLines
    if ($recExportFolder -ne "") { $ExportFolder = $recExportFolder }
    $AutoOpenExportFolder = [bool]$recAutoOpenExportFolder
    if ($recPerCheckDetails -ne "") { $PerCheckDetails = $recPerCheckDetails }
    if ($recPerCheckExport -ne "") { $PerCheckExport = $recPerCheckExport }
    if ($recNoExit) { $NoExit = $true }
    if ($recSuperadminEmail -ne "") { $SuperadminEmail = $recSuperadminEmail }
    if ($recSuperadminPassword -ne "") { $SuperadminPassword = $recSuperadminPassword }
    if ($recAdminEmail -ne "") { $AdminEmail = $recAdminEmail }
    if ($recAdminPassword -ne "") { $AdminPassword = $recAdminPassword }
    if ($recModeratorEmail -ne "") { $ModeratorEmail = $recModeratorEmail }
    if ($recModeratorPassword -ne "") { $ModeratorPassword = $recModeratorPassword }
    if ($recPathsConfigFile -ne "") { $PathsConfigFile = $recPathsConfigFile }
    if ($recRoleSmokePaths.Count -gt 0) { $RoleSmokePaths = @($recRoleSmokePaths.ToArray()) }
    if ($recSecurityLockoutKeywords.Count -gt 0) { $SecurityLockoutKeywords = @($recSecurityLockoutKeywords.ToArray()) }

    if ($null -ne $recGui) { $Gui = $recGui }

    $IgnoredArgs = @()
}

# Deterministic HTTP stack preflight
try { $ProgressPreference = "SilentlyContinue" } catch { }

try {
    try { Add-Type -AssemblyName "System.Net.Http" -ErrorAction Stop | Out-Null } catch { }

    $useBasicParsingSupported = $false
    try {
        $cmd = Get-Command Invoke-WebRequest -ErrorAction Stop
        if ($cmd -and $cmd.Parameters -and $cmd.Parameters.ContainsKey("UseBasicParsing")) {
            $useBasicParsingSupported = $true
        }
    } catch { $useBasicParsingSupported = $false }

    if ($useBasicParsingSupported) {
        try { $PSDefaultParameterValues["Invoke-WebRequest:UseBasicParsing"] = $true } catch { }
    }
} catch {
    # ignore
}

# -----------------------------------------------------------------------------
# Deterministic HTTP helper (no redirect; cookie container; stable Status/Location)
# Used by checks to avoid Invoke-WebRequest edge-cases ("invalid state of object").
# -----------------------------------------------------------------------------


# --- Determine project root (this script lives in tools/audit)
$scriptDir = $null
if ($PSScriptRoot -and ($PSScriptRoot.Trim() -ne "")) {
    $scriptDir = $PSScriptRoot
} elseif ($PSCommandPath -and ($PSCommandPath.Trim() -ne "")) {
    $scriptDir = Split-Path -Parent $PSCommandPath
} else {
    $scriptDir = (Get-Location).Path
}

$projectRoot = Resolve-Path (Join-Path $scriptDir "..\..") | Select-Object -ExpandProperty Path


Test-ProjectRoot $projectRoot
Set-Location $projectRoot

# Capture audit start (for log snapshot "since audit start" classification)
$auditStartedAt = $null
try { $auditStartedAt = Get-Date } catch { $auditStartedAt = $null }

# --- Normalize ProbePaths (some launchers accidentally pass them as a single string token)


$ProbePaths = ConvertTo-NormalizedProbePaths $ProbePaths

if (@($ProbePaths).Count -le 1) {
    $invProbe = @()
    try { $invProbe = @(Get-InvocationParameterValues -ParamName "ProbePaths") } catch { $invProbe = @() }
    if ($invProbe.Count -le 1) {
        try { $invProbe = @(Get-ProcessArgParameterValues -ParamName "ProbePaths") } catch { $invProbe = @() }
    }
    if ($invProbe.Count -gt 1) {
        $ProbePaths = ConvertTo-NormalizedProbePaths $invProbe
    }
}

# --- Recovery: some hosts bind only the first ProbePaths element; extra "/admin/..." tokens land in RemainingArguments.
# Keep this deterministic: append only tokens that look like probe paths (start with "/").
if ($null -ne $IgnoredArgs -and @($IgnoredArgs).Count -gt 0) {
    $extra = New-Object System.Collections.Generic.List[string]
    foreach ($ia in @($IgnoredArgs)) {
        if ($null -eq $ia) { continue }
        $t = ("" + $ia).Trim()
        if ($t -eq "") { continue }

        # If it contains multiple tokens (space/newline/comma/semicolon), split conservatively.
        $parts = @()
        if ($t -match "\r?\n" -or $t -match "\s" -or $t -match "[,;]") {
            try { $parts = @($t -split "[\s,;]+") } catch { $parts = @() }
        } else {
            $parts = @($t)
        }

        foreach ($p in @($parts)) {
            $x = ("" + $p).Trim()
            if ($x -eq "") { continue }
            if (-not $x.StartsWith("/")) { continue }
            $extra.Add($x) | Out-Null
        }
    }

    if ($extra.Count -gt 0) {
        $ProbePaths = ConvertTo-NormalizedProbePaths (@($ProbePaths) + @($extra.ToArray()))
    }

    # Do not treat consumed leftovers as generic ignored args afterwards.
    $IgnoredArgs = @()
}

# De-dup ProbePaths deterministically (preserve first occurrence order)
if ($null -ne $ProbePaths -and @($ProbePaths).Count -gt 0) {
    $seen = @{}
    $dedup = New-Object System.Collections.Generic.List[string]
    foreach ($p in @($ProbePaths)) {
        $s = ("" + $p).Trim()
        if ($s -eq "") { continue }
        if ($seen.ContainsKey($s)) { continue }
        $seen[$s] = $true
        $dedup.Add($s) | Out-Null
    }
    $ProbePaths = @($dedup.ToArray())
}

$RoleSmokePaths = ConvertTo-NormalizedProbePaths $RoleSmokePaths
if (@($RoleSmokePaths).Count -le 1) {
    $invRole = @()
    try { $invRole = @(Get-InvocationParameterValues -ParamName "RoleSmokePaths") } catch { $invRole = @() }
    if ($invRole.Count -le 1) {
        try { $invRole = @(Get-ProcessArgParameterValues -ParamName "RoleSmokePaths") } catch { $invRole = @() }
    }
    if ($invRole.Count -gt 1) {
        $RoleSmokePaths = ConvertTo-NormalizedProbePaths $invRole
    }
}
if ($null -ne $RoleSmokePaths -and @($RoleSmokePaths).Count -gt 0) {
    $seenRole = @{}
    $dedupRole = New-Object System.Collections.Generic.List[string]
    foreach ($p in @($RoleSmokePaths)) {
        $s = ("" + $p).Trim()
        if ($s -eq "") { continue }
        if ($seenRole.ContainsKey($s)) { continue }
        $seenRole[$s] = $true
        $dedupRole.Add($s) | Out-Null
    }
    $RoleSmokePaths = @($dedupRole.ToArray())
}

# --- FIX 1/2: Recover SecurityLockoutKeywords when runner binds only the first element.
# Strategy:
# 1) Try invocation/process arg readers (same as other multi-value params).
# 2) If still only 0/1 keyword: harvest leftover RemainingArguments tokens that look like keywords.
try {
    $SecurityLockoutKeywords = @($SecurityLockoutKeywords | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
} catch { }

if (@($SecurityLockoutKeywords).Count -le 1) {
    $invKw = @()
    try { $invKw = @(Get-InvocationParameterValues -ParamName "SecurityLockoutKeywords") } catch { $invKw = @() }
    if ($invKw.Count -le 1) {
        try { $invKw = @(Get-ProcessArgParameterValues -ParamName "SecurityLockoutKeywords") } catch { $invKw = @() }
    }
    if ($invKw.Count -gt 1) {
        try { $SecurityLockoutKeywords = @($invKw | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" }) } catch { }
    }
}

if (@($SecurityLockoutKeywords).Count -le 1 -and $null -ne $IgnoredArgs -and @($IgnoredArgs).Count -gt 0) {
    $defaultKw = @("too many attempts","throttle","locked","lockout","zu viele","versuche")
    $extraKw = New-Object System.Collections.Generic.List[string]

    foreach ($ia in @($IgnoredArgs)) {
        if ($null -eq $ia) { continue }
        $t = ("" + $ia).Trim()
        if ($t -eq "") { continue }

        $parts = @()
        if ($t -match "\r?\n" -or $t -match "\s" -or $t -match "[,;]") {
            try { $parts = @($t -split "[\s,;]+") } catch { $parts = @() }
        } else {
            $parts = @($t)
        }

        foreach ($p in @($parts)) {
            $x = ("" + $p).Trim()
            if ($x -eq "") { continue }
            if ($x.StartsWith("-")) { continue }
            if ($x.StartsWith("/")) { continue }

            $isKnown = $false
            foreach ($dk in $defaultKw) {
                if ($x.Equals($dk, [System.StringComparison]::OrdinalIgnoreCase)) { $isKnown = $true; break }
            }

            if (-not $isKnown) { continue }
            $extraKw.Add($x) | Out-Null
        }
    }

    if ($extraKw.Count -gt 0) {
        $merged = New-Object System.Collections.Generic.List[string]
        foreach ($k in @($SecurityLockoutKeywords)) { if (("" + $k).Trim() -ne "") { $merged.Add((("" + $k).Trim())) | Out-Null } }
        foreach ($k in @($extraKw.ToArray())) { if (("" + $k).Trim() -ne "") { $merged.Add((("" + $k).Trim())) | Out-Null } }

        # de-dup preserve order
        $seenKw = @{}
        $dedupKw = New-Object System.Collections.Generic.List[string]
        foreach ($k in @($merged.ToArray())) {
            $s = ("" + $k).Trim()
            if ($s -eq "") { continue }
            if ($seenKw.ContainsKey($s.ToLowerInvariant())) { continue }
            $seenKw[$s.ToLowerInvariant()] = $true
            $dedupKw.Add($s) | Out-Null
        }
        $SecurityLockoutKeywords = @($dedupKw.ToArray())
    }
}

# Recover string/bool value parameters from invocation if host binding shifted.


$showVals = @(Resolve-ParamValues "ShowCheckDetails")
if ($showVals.Count -gt 0) { $ShowCheckDetails = ("" + $showVals[$showVals.Count - 1]).Trim() }

$expVals = @(Resolve-ParamValues "ExportLogs")
if ($expVals.Count -gt 0) { $ExportLogs = ("" + $expVals[$expVals.Count - 1]).Trim() }

$expLinesVals = @(Resolve-ParamValues "ExportLogsLines")
if ($expLinesVals.Count -gt 0) {
    $v = ("" + $expLinesVals[$expLinesVals.Count - 1]).Trim()
    if ($v -ne "") { $ExportLogsLines = $v }
}

$expFolderVals = @(Resolve-ParamValues "ExportFolder")
if ($expFolderVals.Count -gt 0) {
    $v = ("" + $expFolderVals[$expFolderVals.Count - 1]).Trim()
    if ($v -ne "") { $ExportFolder = $v }
}

$autoOpenVals = @(Resolve-ParamValues "AutoOpenExportFolder")
if ($autoOpenVals.Count -gt 0) { $AutoOpenExportFolder = ("" + $autoOpenVals[$autoOpenVals.Count - 1]).Trim() }

$securityE2ECleanupVals = @(Resolve-ParamValues "SecurityE2ECleanup")
if ($securityE2ECleanupVals.Count -gt 0) { $SecurityE2ECleanup = ("" + $securityE2ECleanupVals[$securityE2ECleanupVals.Count - 1]).Trim() }

$securityE2EDryRunVals = @(Resolve-ParamValues "SecurityE2EDryRun")
if ($securityE2EDryRunVals.Count -gt 0) { $SecurityE2EDryRun = ("" + $securityE2EDryRunVals[$securityE2EDryRunVals.Count - 1]).Trim() }

$securityE2EEnvGateVals = @(Resolve-ParamValues "SecurityE2EEnvGate")
if ($securityE2EEnvGateVals.Count -gt 0) { $SecurityE2EEnvGate = ("" + $securityE2EEnvGateVals[$securityE2EEnvGateVals.Count - 1]).Trim() }

$effectiveLoginCsrfProbe = ([bool]$LoginCsrfProbe -or [bool]$RoleSmokeTest)
$effectiveSessionCsrfBaseline = ([bool]$SessionCsrfBaseline -or [bool]$RoleSmokeTest)
$loginCsrfProbeEffectiveReason = $(if ([bool]$LoginCsrfProbe) { "as requested" } elseif ([bool]$RoleSmokeTest) { "forced by dependency: RoleSmokeTest=true" } else { "as requested" })
$sessionCsrfBaselineEffectiveReason = $(if ([bool]$SessionCsrfBaseline) { "as requested" } elseif ([bool]$RoleSmokeTest) { "forced by dependency: RoleSmokeTest=true" } else { "as requested" })

$effectiveSecurityProbe = [bool]$SecurityProbe
$allowSecurityE2EWithoutProbe = $false
try { $allowSecurityE2EWithoutProbe = Convert-ToBooleanSafe $env:KS_AUDIT_ALLOW_SECURITY_E2E_WITHOUT_PROBE $false } catch { $allowSecurityE2EWithoutProbe = $false }

$effectiveSecurityE2E = [bool]$SecurityE2E
$securityE2EEffectiveReason = "as requested"
if ($effectiveSecurityE2E -and (-not $effectiveSecurityProbe)) {
    if ($allowSecurityE2EWithoutProbe) {
        $securityE2EEffectiveReason = "explicitly allowed without SecurityProbe (env:KS_AUDIT_ALLOW_SECURITY_E2E_WITHOUT_PROBE=true)"
    } else {
        $effectiveSecurityE2E = $false
        $securityE2EEffectiveReason = "overridden by dependency: SecurityProbe=false"
    }
}

$effectiveSecurityE2ELockout = ([bool]$SecurityE2ELockout -and $effectiveSecurityE2E)
$effectiveSecurityE2EIpAutoban = ([bool]$SecurityE2EIpAutoban -and $effectiveSecurityE2E)
$effectiveSecurityE2EDeviceAutoban = ([bool]$SecurityE2EDeviceAutoban -and $effectiveSecurityE2E)
$effectiveSecurityE2EIdentityBan = ([bool]$SecurityE2EIdentityBan -and $effectiveSecurityE2E)
$effectiveSecurityE2ESupportRef = ([bool]$SecurityE2ESupportRef -and $effectiveSecurityE2E)
$effectiveSecurityE2EEventsCheck = ([bool]$SecurityE2EEventsCheck -and $effectiveSecurityE2E)

# --- Helpers (kept minimal; no GUI logic)


# Tail-only mode:
$tailOnly = [bool]$TailLog `
    -and (-not [bool]$HttpProbe) `
    -and (-not [bool]$RoutesVerbose) `
    -and (-not [bool]$RouteListFindstrAdmin) `
    -and (-not [bool]$SuperadminCount) `
    -and (-not [bool]$LoginCsrfProbe) `
    -and (-not [bool]$RoleSmokeTest) `
    -and (-not [bool]$SessionCsrfBaseline) `
    -and (-not [bool]$SecurityProbe) `
    -and (-not [bool]$SecurityE2E) `
    -and (-not [bool]$SecurityCheckIpBan) `
    -and (-not [bool]$SecurityCheckRegister) `
    -and (-not [bool]$SecurityExpect429) `
    -and (-not [bool]$LogSnapshot)

$effectiveLogSnapshotLines = 200
try {
    $n = [int]$LogSnapshotLines
    if ($n -gt 0) { $effectiveLogSnapshotLines = $n }
} catch { $effectiveLogSnapshotLines = 200 }

$logSnapshotLinesHeader = "-"
if ([bool]$LogSnapshot) { $logSnapshotLinesHeader = ("" + [int]$effectiveLogSnapshotLines) }

$effectiveSecurityLoginAttempts = 8
try {
    $n = [int]$SecurityLoginAttempts
    if ($n -gt 0) { $effectiveSecurityLoginAttempts = $n }
} catch { $effectiveSecurityLoginAttempts = 8 }
if ($effectiveSecurityLoginAttempts -gt 10) { $effectiveSecurityLoginAttempts = 10 }
if ($effectiveSecurityLoginAttempts -lt 1) { $effectiveSecurityLoginAttempts = 1 }

$effectiveSecurityLockoutKeywords = @("too many attempts","throttle","locked","lockout","zu viele","versuche")
try {
    $kw = @($SecurityLockoutKeywords | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
    if ($kw.Count -gt 0) { $effectiveSecurityLockoutKeywords = @($kw) }
} catch { }

$effectiveSecurityE2EAttempts = 10
try {
    $n = [int]$SecurityE2EAttempts
    if ($n -gt 0) { $effectiveSecurityE2EAttempts = $n }
} catch { $effectiveSecurityE2EAttempts = 10 }

$effectiveSecurityE2EThreshold = 3
try {
    $n = [int]$SecurityE2EThreshold
    if ($n -gt 0) { $effectiveSecurityE2EThreshold = $n }
} catch { $effectiveSecurityE2EThreshold = 3 }

$effectiveSecurityE2ESeconds = 300
try {
    $n = [int]$SecurityE2ESeconds
    if ($n -gt 0) { $effectiveSecurityE2ESeconds = $n }
} catch { $effectiveSecurityE2ESeconds = 300 }

$effectiveSecurityE2ELogin = "audit-test@kiezsingles.local"
try {
    $v = ("" + $SecurityE2ELogin).Trim()
    if ($v -ne "") { $effectiveSecurityE2ELogin = $v }
} catch { $effectiveSecurityE2ELogin = "audit-test@kiezsingles.local" }

$effectiveSecurityE2EPassword = "random"
try {
    $v = ("" + $SecurityE2EPassword)
    if ($v -ne "") { $effectiveSecurityE2EPassword = $v }
} catch { $effectiveSecurityE2EPassword = "random" }

$effectiveSecurityE2ECleanup = Convert-ToBooleanSafe $SecurityE2ECleanup $true
$effectiveSecurityE2EDryRun = Convert-ToBooleanSafe $SecurityE2EDryRun $false
$effectiveSecurityE2EEnvGate = Convert-ToBooleanSafe $SecurityE2EEnvGate $true

$effectiveShowCheckDetails = Convert-ToBooleanSafe $ShowCheckDetails $false
$effectiveExportLogs = Convert-ToBooleanSafe $ExportLogs $false
$effectiveExportLogsLines = Convert-ToIntSafe $ExportLogsLines 200
if ($effectiveExportLogsLines -lt 1) { $effectiveExportLogsLines = 200 }
$effectiveExportFolder = Resolve-AuditExportFolder -ProjectRoot $projectRoot -FolderValue $ExportFolder
$effectiveAutoOpenExportFolder = Convert-ToBooleanSafe $AutoOpenExportFolder $false
$effectivePerCheckDetailsMap = Convert-PerCheckSettingMap $PerCheckDetails
$effectivePerCheckExportMap = Convert-PerCheckSettingMap $PerCheckExport
$effectiveLogFilePath = Get-LaravelLogPath $projectRoot

$hasPerCheckDetailsOverrides = $false
try { $hasPerCheckDetailsOverrides = ($null -ne $effectivePerCheckDetailsMap -and [int]$effectivePerCheckDetailsMap.Count -gt 0) } catch { $hasPerCheckDetailsOverrides = $false }

$hasPerCheckExportOverrides = $false
try { $hasPerCheckExportOverrides = ($null -ne $effectivePerCheckExportMap -and [int]$effectivePerCheckExportMap.Count -gt 0) } catch { $hasPerCheckExportOverrides = $false }

# Resolve TailLogMode for checks (prefer env var)
$tailMode = "history"
try {
    if ($null -ne $env:KS_TAILLOG_MODE -and ("" + $env:KS_TAILLOG_MODE).Trim() -ne "") {
        $tailMode = ("" + $env:KS_TAILLOG_MODE).Trim().ToLower()
    }
} catch { $tailMode = "history" }

# --- Build Context shared to checks
$context = [pscustomobject]@{
    ProjectRoot = $projectRoot
    BaseUrl = $BaseUrl
    ProbePaths = $ProbePaths
    RoleSmokePaths = $RoleSmokePaths
    RoleSmokeExpectations = @{}
    SuperadminEmail = $SuperadminEmail
    SuperadminPassword = $SuperadminPassword
    AdminEmail = $AdminEmail
    AdminPassword = $AdminPassword
    ModeratorEmail = $ModeratorEmail
    ModeratorPassword = $ModeratorPassword
    ExpectedUnauthedHttpCodes = @(302, 401, 403)
    HttpTimeoutSec = 12
    TailLogMode = $tailMode
    AuditStartedAt = $auditStartedAt
    LogSnapshotLines = [int]$effectiveLogSnapshotLines
    LogClearBefore = [bool]$LogClearBefore
    LogClearAfter = [bool]$LogClearAfter
    LogCleanupBeforeBackupCreated = $false
    LogCleanupBeforeBackupPath = "-"
    RouteListOptionScanFullProject = [bool]$RouteListOptionScanFullProject
    SecurityProbe = [bool]$effectiveSecurityProbe
    SecurityLoginAttempts = [int]$effectiveSecurityLoginAttempts
    SecurityCheckIpBan = [bool]$SecurityCheckIpBan
    SecurityCheckRegister = [bool]$SecurityCheckRegister
    SecurityExpect429 = [bool]$SecurityExpect429
    SecurityLockoutKeywords = @($effectiveSecurityLockoutKeywords)
    SecurityE2E = [bool]$effectiveSecurityE2E
    SecurityE2ELockout = [bool]$effectiveSecurityE2ELockout
    SecurityE2EIpAutoban = [bool]$effectiveSecurityE2EIpAutoban
    SecurityE2EDeviceAutoban = [bool]$effectiveSecurityE2EDeviceAutoban
    SecurityE2EIdentityBan = [bool]$effectiveSecurityE2EIdentityBan
    SecurityE2ESupportRef = [bool]$effectiveSecurityE2ESupportRef
    SecurityE2EEventsCheck = [bool]$effectiveSecurityE2EEventsCheck
    SecurityE2EAttempts = [int]$effectiveSecurityE2EAttempts
    SecurityE2EThreshold = [int]$effectiveSecurityE2EThreshold
    SecurityE2ESeconds = [int]$effectiveSecurityE2ESeconds
    SecurityE2ELogin = $effectiveSecurityE2ELogin
    SecurityE2EPassword = $effectiveSecurityE2EPassword
    SecurityE2ECleanup = [bool]$effectiveSecurityE2ECleanup
    SecurityE2EDryRun = [bool]$effectiveSecurityE2EDryRun
    SecurityE2EEnvGate = [bool]$effectiveSecurityE2EEnvGate
    ShowCheckDetails = [bool]$effectiveShowCheckDetails
    ExportLogs = [bool]$effectiveExportLogs
    ExportLogsLines = [int]$effectiveExportLogsLines
    ExportFolder = $effectiveExportFolder
    AutoOpenExportFolder = [bool]$effectiveAutoOpenExportFolder
    Helpers = [pscustomobject]@{
        WriteSection = ${function:Write-Section}
        RunPHPArtisan = ${function:Invoke-PHPArtisan}
        NewAuditResult = ${function:New-AuditResult}
        HttpNoRedirect = ${function:Invoke-KsHttpNoRedirect}
    }
}

# --- Load checks (prefer .\checks, fallback to script directory)
$checksDir = Join-Path $scriptDir "checks"
$checksRoot = $checksDir
$checksSourceLabel = "checks"

if (-not (Test-Path $checksDir)) {
    $checksRoot = $scriptDir
    $checksSourceLabel = "flat"
}

Get-ChildItem -LiteralPath $checksRoot -File -Filter "*.ps1" |
    Where-Object { $_.Name -match '^\d{2}_.+\.ps1$' } |
    Sort-Object Name |
    ForEach-Object {
        . $_.FullName
    }

if ($tailOnly) {
    if (-not (Test-FunctionExists "Invoke-KsAuditCheck_TailLog")) {
        return (Stop-Program 1)
    }

    try {
        if ($LogClearBefore) {
            & $context.Helpers.WriteSection "Log cleanup (before)"
            $beforeRes = Invoke-LaravelLogRotateIfExists -Root $projectRoot -PhaseLabel "before"
            Write-Host ""
            Write-Host ((Format-StatusTag $beforeRes.status) + " " + $beforeRes.title + " - " + $beforeRes.summary + " (" + $beforeRes.duration_ms + "ms)")
            $d = Get-DetailsForOutput $beforeRes
            $dd = ConvertTo-SafeStringArray $d
            if ((Get-SafeCount $dd) -gt 0) { Write-Host ""; foreach ($x in $dd) { Write-Host $x } }
        }

        $null = Invoke-KsAuditCheck_TailLog -Context $context

        if ($LogClearAfter) {
            & $context.Helpers.WriteSection "Log cleanup (after)"
            $afterRes = Invoke-LaravelLogRotateIfExists -Root $projectRoot -PhaseLabel "after"
            Write-Host ""
            Write-Host ((Format-StatusTag $afterRes.status) + " " + $afterRes.title + " - " + $afterRes.summary + " (" + $afterRes.duration_ms + "ms)")
            $d = Get-DetailsForOutput $afterRes
            $dd = ConvertTo-SafeStringArray $d
            if ((Get-SafeCount $dd) -gt 0) { Write-Host ""; foreach ($x in $dd) { Write-Host $x } }
        }

        return (Stop-Program 0)
    } catch {
        return (Stop-Program 1)
    }
}

# --- Check registry (deterministic order)
$plan = New-Object System.Collections.Generic.List[scriptblock]

$missingRequired = New-Object System.Collections.Generic.List[string]
if (-not (Test-FunctionExists "Invoke-KsAuditCheck_CacheClear")) { $missingRequired.Add("Invoke-KsAuditCheck_CacheClear") | Out-Null }
if (-not (Test-FunctionExists "Invoke-KsAuditCheck_Routes"))     { $missingRequired.Add("Invoke-KsAuditCheck_Routes") | Out-Null }

if ($missingRequired.Count -gt 0) {
    Write-Section "KiezSingles Admin Audit (CLI Core)"
    Write-Host ("ProjectRoot: " + $projectRoot)
    Write-Host ("BaseUrl:     " + $BaseUrl)
    Write-Host ("HttpProbe:   " + [bool]$HttpProbe)
    Write-Host ("TailLog:     " + [bool]$TailLog)
    Write-Host ("RoutesVerbose: " + [bool]$RoutesVerbose)
    Write-Host ("RouteListFindstrAdmin: " + [bool]$RouteListFindstrAdmin)
    Write-Host ("SuperadminCount: " + [bool]$SuperadminCount)
    Write-Host ("LoginCsrfProbe: " + [bool]$LoginCsrfProbe + " (effective: " + [bool]$effectiveLoginCsrfProbe + "; " + $loginCsrfProbeEffectiveReason + ")")
    Write-Host ("RoleSmokeTest: " + [bool]$RoleSmokeTest)
    Write-Host ("SessionCsrfBaseline: " + [bool]$SessionCsrfBaseline + " (effective: " + [bool]$effectiveSessionCsrfBaseline + "; " + $sessionCsrfBaselineEffectiveReason + ")")
    Write-Host ("LogSnapshot: " + [bool]$LogSnapshot)
    Write-Host ("LogSnapshotLines: " + $logSnapshotLinesHeader)
    Write-Host ("LogClearBefore: " + [bool]$LogClearBefore)
    Write-Host ("LogClearAfter: " + [bool]$LogClearAfter)
    if ([bool]$LogClearBefore -or [bool]$LogClearAfter) { Write-Host "Hinweis: laravel.log wird rotiert; .bak-* vorhanden" }
    Write-Host ("RouteListOptionScanFullProject: " + [bool]$RouteListOptionScanFullProject)
    Write-Host ("SecurityProbe: " + [bool]$SecurityProbe + " (effective: " + [bool]$effectiveSecurityProbe + "; as requested)")
    Write-Host ("SecurityLoginAttempts: " + [int]$effectiveSecurityLoginAttempts)
    Write-Host ("SecurityCheckIpBan: " + [bool]$SecurityCheckIpBan)
    Write-Host ("SecurityCheckRegister: " + [bool]$SecurityCheckRegister)
    Write-Host ("SecurityExpect429: " + [bool]$SecurityExpect429)
    Write-Host ("SecurityLockoutKeywords: " + (($effectiveSecurityLockoutKeywords | ForEach-Object { "" + $_ }) -join ", "))
    Write-Host ("ChecksSource: " + $checksSourceLabel + " (" + $checksRoot + ")")

    Write-Host ""
    $msg = "Required check function(s) missing: " + (($missingRequired | ForEach-Object { "" + $_ }) -join ", ")
    Write-Host ("[CRITICAL] Core exception - " + $msg + " (0ms)")

    Write-Section "Audit result"
    Write-Host "FinalStatus: CRITICAL"
    Write-Host "ExitCode: 30"
    return (Stop-Program 30)
}

# Log cleanup BEFORE (optional; only when flag is set)
if ($LogClearBefore) {
    $plan.Add({
        & $context.Helpers.WriteSection "Log cleanup (before)"
        return (Invoke-LaravelLogRotateIfExists -Root $context.ProjectRoot -PhaseLabel "before")
    }) | Out-Null
}

$plan.Add({ Invoke-KsAuditCheck_CacheClear -Context $context }) | Out-Null
$plan.Add({ Invoke-KsAuditCheck_Routes -Context $context }) | Out-Null

# 1x) route:list unsupported options scan (identify external callers)
$plan.Add({
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $context.Helpers.WriteSection "1x) route:list option scan (--columns / --format)"

    $details = @()

    try {
        $roots = New-Object System.Collections.Generic.List[string]

        $candidates = @()
        if ([bool]$context.RouteListOptionScanFullProject) {
            $candidates = @(
                ("" + $context.ProjectRoot)
            )
        } else {
            $candidates = @(
                (Join-Path $context.ProjectRoot ".vscode"),
                (Join-Path $context.ProjectRoot "tools"),
                (Join-Path $context.ProjectRoot "scripts"),
                (Join-Path $context.ProjectRoot "package.json"),
                (Join-Path $context.ProjectRoot "composer.json")
            )
        }

        foreach ($c in $candidates) {
            try {
                if ($c -and (Test-Path -LiteralPath $c)) {
                    $roots.Add(("" + $c)) | Out-Null
                }
            } catch { }
        }

        $files = New-Object System.Collections.Generic.List[string]

        $auditToolsRoot = ""
        $auditCoreFile = ""
        $auditChecksRoot = ""
        try { $auditToolsRoot = (Join-Path $context.ProjectRoot "tools\audit") } catch { $auditToolsRoot = "" }
        try { $auditCoreFile = (Join-Path $context.ProjectRoot "tools\audit\ks-admin-audit.ps1") } catch { $auditCoreFile = "" }
        try { $auditChecksRoot = (Join-Path $context.ProjectRoot "tools\audit\checks") } catch { $auditChecksRoot = "" }

        $vendorRoot = ""
        $nodeModulesRoot = ""
        $storageRoot = ""
        $bootstrapCacheRoot = ""
        try { $vendorRoot = (Join-Path $context.ProjectRoot "vendor") } catch { $vendorRoot = "" }
        try { $nodeModulesRoot = (Join-Path $context.ProjectRoot "node_modules") } catch { $nodeModulesRoot = "" }
        try { $storageRoot = (Join-Path $context.ProjectRoot "storage") } catch { $storageRoot = "" }
        try { $bootstrapCacheRoot = (Join-Path $context.ProjectRoot "bootstrap\cache") } catch { $bootstrapCacheRoot = "" }

        foreach ($r in $roots) {
            try {
                if (Test-Path -LiteralPath $r -PathType Container) {
                    $g = Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue |
                        Where-Object {
                            $_.Extension -in @(".ps1",".php",".json",".yml",".yaml",".cmd",".bat",".sh",".txt")
                        } |
                        Where-Object {
                            $p = ""
                            try { $p = "" + $_.FullName } catch { $p = "" }
                            if ($p -eq "") { return $false }

                            # Exclude this core audit file and checks directory to avoid self-matches/noise.
                            if ($auditCoreFile -and ($p -ieq $auditCoreFile)) { return $false }
                            if ($auditChecksRoot -and ($p -like ($auditChecksRoot + "*"))) { return $false }

                            # If scanning full project, exclude large/irrelevant dirs for speed/noise.
                            if ([bool]$context.RouteListOptionScanFullProject) {
                                if ($vendorRoot -and ($p -like ($vendorRoot + "*"))) { return $false }
                                if ($nodeModulesRoot -and ($p -like ($nodeModulesRoot + "*"))) { return $false }
                                if ($storageRoot -and ($p -like ($storageRoot + "*"))) { return $false }
                                if ($bootstrapCacheRoot -and ($p -like ($bootstrapCacheRoot + "*"))) { return $false }
                            }

                            return $true
                        } |
                        Select-Object -ExpandProperty FullName

                    foreach ($f in @($g)) {
                        if (-not $f) { continue }

                        if (("" + $f).Trim() -ne "") { $files.Add(("" + $f)) | Out-Null }
                    }
                } elseif (Test-Path -LiteralPath $r -PathType Leaf) {
                    $f = "" + $r

                    if ($auditCoreFile -and ($f -ieq $auditCoreFile)) { }
                    elseif ($auditChecksRoot -and ($f -like ($auditChecksRoot + "*"))) { }
                    else { $files.Add($f) | Out-Null }
                }
            } catch { }
        }

        # Detect real invocations:
        # - a line containing route:list AND (--columns or --format)
        # - or a nearby window (+/- 5 lines) combining route:list + (--columns/--format) (common in PS arrays)
        $relevant = New-Object System.Collections.Generic.List[string]
        $hitMap = @{} # file -> list of lines (limited excerpts)

        foreach ($f in @($files.ToArray())) {
            if (-not $f) { continue }

            $lines = @()
            try {
                $lines = Get-Content -LiteralPath $f -ErrorAction SilentlyContinue
                $lines = @($lines)
            } catch { $lines = @() }

            if (@($lines).Count -le 0) { continue }

            $hitsOut = New-Object System.Collections.Generic.List[string]
            $found = $false

            for ($idx = 0; $idx -lt $lines.Count; $idx++) {
                $line = ""
                try { $line = "" + $lines[$idx] } catch { $line = "" }
                if ($line.Trim() -eq "") { continue }

                $hasRoute = ($line -match '(?i)\broute:list\b')
                $hasColumns = ($line -match '(?i)--columns\b')
                $hasFormat = ($line -match '(?i)--format\b')

                if ($hasRoute -and ($hasColumns -or $hasFormat)) {
                    $hitsOut.Add(("L{0}: {1}" -f ($idx + 1), $line.Trim())) | Out-Null
                    $found = $true
                    continue
                }

                if (-not ($hasColumns -or $hasFormat)) { continue }

                $wStart = [Math]::Max(0, $idx - 5)
                $wEnd = [Math]::Min($lines.Count - 1, $idx + 5)

                $winHasRoute = $false
                for ($j = $wStart; $j -le $wEnd; $j++) {
                    $wLine = ""
                    try { $wLine = "" + $lines[$j] } catch { $wLine = "" }
                    if ($wLine -match '(?i)\broute:list\b') { $winHasRoute = $true; break }
                }

                if (-not $winHasRoute) { continue }

                for ($j = $wStart; $j -le $wEnd; $j++) {
                    $wLine = ""
                    try { $wLine = "" + $lines[$j] } catch { $wLine = "" }
                    $t = $wLine.Trim()
                    if ($t -eq "") { continue }
                    $hitsOut.Add(("L{0}: {1}" -f ($j + 1), $t)) | Out-Null
                }

                $found = $true
            }

            if (-not $found) { continue }

            # De-duplicate and cap
            $dedup = New-Object System.Collections.Generic.List[string]
            $seen = @{}
            foreach ($h in @($hitsOut.ToArray())) {
                if (-not $h) { continue }
                if ($seen.ContainsKey($h)) { continue }
                $seen[$h] = $true
                $dedup.Add($h) | Out-Null
                if ($dedup.Count -ge 30) { break }
            }

            if ($dedup.Count -gt 0) {
                $hitMap[$f] = @($dedup.ToArray())
                $relevant.Add($f) | Out-Null
            }
        }

        if ($relevant.Count -le 0) {
            $sw.Stop()

            $mode = "scanned roots (.vscode/tools/scripts + composer.json + package.json), excluding tools/audit/ks-admin-audit.ps1 and tools/audit/checks/*."
            if ([bool]$context.RouteListOptionScanFullProject) {
                $mode = "scanned full project (excluding tools/audit/ks-admin-audit.ps1 and tools/audit/checks/* and vendor/node_modules/storage/bootstrap/cache)."
            }

            return & $context.Helpers.NewAuditResult -Id "route_list_option_scan" -Title "1x) route:list option scan" -Status "OK" -Summary ("No route:list invocation using '--columns' / '--format' found; " + $mode) -Details @() -Data @{ scanned_files = [int]$files.Count; hits_files = 0 } -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        if ([bool]$context.RouteListOptionScanFullProject) {
            $details += "Found potential callers (scan root: PROJECT ROOT; excludes tools/audit/ks-admin-audit.ps1, tools/audit/checks/* and vendor/node_modules/storage/bootstrap/cache)."
        } else {
            $details += "Found potential callers (scan roots: .vscode/, tools/, scripts/, composer.json, package.json; excludes tools/audit/ks-admin-audit.ps1 and tools/audit/checks/*)."
        }

        $details += "Only showing likely invocations (route:list with --columns/--format on same line or within +/- 5 lines)."
        $details += ""

        foreach ($ff in @($relevant.ToArray() | Sort-Object)) {
            $details += ("File: " + $ff)
            $ls = @()
            try { $ls = @($hitMap[$ff]) } catch { $ls = @() }

            $printed = 0
            foreach ($l in $ls) {
                if ($printed -ge 30) { break }
                $details += ("  " + $l)
                $printed++
            }
            if ($ls.Count -gt 30) {
                $details += ("  ... (" + ($ls.Count - 30) + " more)")
            }
            $details += ""
        }

        $sw.Stop()
        return & $context.Helpers.NewAuditResult -Id "route_list_option_scan" -Title "1x) route:list option scan" -Status "WARN" -Summary ("Found " + $relevant.Count + " potential caller file(s) using route:list with '--columns'/'--format'.") -Details $details -Data @{ scanned_files = [int]$files.Count; hits_files = [int]$relevant.Count } -DurationMs ([int]$sw.ElapsedMilliseconds)
    } catch {
        $sw.Stop()
        return & $context.Helpers.NewAuditResult -Id "route_list_option_scan" -Title "1x) route:list option scan" -Status "WARN" -Summary ("Scan failed: " + $_.Exception.Message) -Details @() -Data @{} -DurationMs ([int]$sw.ElapsedMilliseconds)
    }
}) | Out-Null

# Desired output/plan order:
# (optional) LogClearBefore -> 0 -> 1 -> 2 -> 3 -> 1v -> 1f -> 4 -> (optional) LogClearAfter
# LogClearBefore -> CacheClear -> Routes -> HTTP Probe -> Governance -> RoutesVerbose -> RouteListFindstrAdmin -> LogSnapshot -> TailLog -> LogClearAfter

if ($HttpProbe) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_HttpProbe") {
        $plan.Add({ Invoke-KsAuditCheck_HttpProbe -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "2) HTTP exposure probe" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_HttpProbe" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

if ($effectiveLoginCsrfProbe) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_LoginCsrfProbe") {
        $plan.Add({ Invoke-KsAuditCheck_LoginCsrfProbe -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "2a) Login CSRF probe" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_LoginCsrfProbe" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

if ($RoleSmokeTest) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_RoleSmokeTest") {
        $plan.Add({ Invoke-KsAuditCheck_RoleSmokeTest -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "2b) Role access smoke test (GET-only)" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_RoleSmokeTest" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

if ($SuperadminCount) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_GovernanceSuperadmin") {
        $plan.Add({ Invoke-KsAuditCheck_GovernanceSuperadmin -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "3) Governance: superadmin fail-safe (deterministic)" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_GovernanceSuperadmin" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

if ($effectiveSessionCsrfBaseline) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_SessionCsrfBaseline") {
        $plan.Add({ Invoke-KsAuditCheck_SessionCsrfBaseline -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "3a) Session/CSRF baseline (read-only)" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_SessionCsrfBaseline" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

if (Test-FunctionExists "Invoke-KsAuditCheck_SecurityAbuseProtection") {
    $plan.Add({ Invoke-KsAuditCheck_SecurityAbuseProtection -Context $context }) | Out-Null
} else {
    $plan.Add({
        New-AuditResult -Id "missing_check" -Title "X) Security / Abuse Protection" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_SecurityAbuseProtection" -Details @() -Data @{} -DurationMs 0
    }) | Out-Null
}

if ($effectiveSecurityE2E) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_SecurityE2E") {
        $plan.Add({ Invoke-KsAuditCheck_SecurityE2E -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "X+) Security E2E Test" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_SecurityE2E" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

if ($RoutesVerbose) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_RoutesVerbose") {
        $plan.Add({ Invoke-KsAuditCheck_RoutesVerbose -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "RoutesVerbose" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_RoutesVerbose" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

if ($RouteListFindstrAdmin) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_RouteListFindstrAdmin") {
        $plan.Add({ Invoke-KsAuditCheck_RouteListFindstrAdmin -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "RouteListFindstrAdmin" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_RouteListFindstrAdmin" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

if ($LogSnapshot) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_LogSnapshot") {
        $plan.Add({ Invoke-KsAuditCheck_LogSnapshot -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "Laravel log snapshot" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_LogSnapshot" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

if ($TailLog) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_TailLog") {
        $plan.Add({ Invoke-KsAuditCheck_TailLog -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "Tail laravel.log" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_TailLog" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

# Log cleanup AFTER (optional; only when flag is set)
if ($LogClearAfter) {
    $plan.Add({
        & $context.Helpers.WriteSection "Log cleanup (after)"
        return (Invoke-LaravelLogRotateIfExists -Root $context.ProjectRoot -PhaseLabel "after")
    }) | Out-Null
}

Write-Section "KiezSingles Admin Audit (CLI Core)"
Write-Host ("ProjectRoot: " + $projectRoot)
Write-Host ("BaseUrl:     " + $BaseUrl)
Write-Host ("HttpProbe:   " + [bool]$HttpProbe)
Write-Host ("TailLog:     " + [bool]$TailLog)
Write-Host ("RoutesVerbose: " + [bool]$RoutesVerbose)
Write-Host ("RouteListFindstrAdmin: " + [bool]$RouteListFindstrAdmin)
Write-Host ("SuperadminCount: " + [bool]$SuperadminCount)
Write-Host ("LoginCsrfProbe: " + [bool]$LoginCsrfProbe + " (effective: " + [bool]$effectiveLoginCsrfProbe + "; " + $loginCsrfProbeEffectiveReason + ")")
Write-Host ("RoleSmokeTest: " + [bool]$RoleSmokeTest)
Write-Host ("SessionCsrfBaseline: " + [bool]$SessionCsrfBaseline + " (effective: " + [bool]$effectiveSessionCsrfBaseline + "; " + $sessionCsrfBaselineEffectiveReason + ")")
Write-Host ("LogSnapshot: " + [bool]$LogSnapshot)
Write-Host ("LogSnapshotLines: " + $logSnapshotLinesHeader)
Write-Host ("LogClearBefore: " + [bool]$LogClearBefore)
Write-Host ("LogClearAfter: " + [bool]$LogClearAfter)
if ([bool]$LogClearBefore -or [bool]$LogClearAfter) { Write-Host "Hinweis: laravel.log wird rotiert; .bak-* vorhanden" }
Write-Host ("RouteListOptionScanFullProject: " + [bool]$RouteListOptionScanFullProject)
Write-Host ("SecurityProbe: " + [bool]$SecurityProbe + " (effective: " + [bool]$effectiveSecurityProbe + "; as requested)")
Write-Host ("SecurityLoginAttempts: " + [int]$effectiveSecurityLoginAttempts)
Write-Host ("SecurityCheckIpBan: " + [bool]$SecurityCheckIpBan)
Write-Host ("SecurityCheckRegister: " + [bool]$SecurityCheckRegister)
Write-Host ("SecurityExpect429: " + [bool]$SecurityExpect429)
Write-Host ("SecurityLockoutKeywords: " + (($effectiveSecurityLockoutKeywords | ForEach-Object { "" + $_ }) -join ", "))
Write-Host ("SecurityE2E: " + [bool]$SecurityE2E + " (effective: " + [bool]$effectiveSecurityE2E + "; " + $securityE2EEffectiveReason + ")")
Write-Host ("SecurityE2ELockout: " + [bool]$SecurityE2ELockout + " (effective: " + [bool]$effectiveSecurityE2ELockout + $(if ([bool]$SecurityE2ELockout -and -not [bool]$effectiveSecurityE2E) { "; overridden by dependency: SecurityE2E=false" } else { "; as requested" }) + ")")
Write-Host ("SecurityE2EIpAutoban: " + [bool]$SecurityE2EIpAutoban + " (effective: " + [bool]$effectiveSecurityE2EIpAutoban + $(if ([bool]$SecurityE2EIpAutoban -and -not [bool]$effectiveSecurityE2E) { "; overridden by dependency: SecurityE2E=false" } else { "; as requested" }) + ")")
Write-Host ("SecurityE2EDeviceAutoban: " + [bool]$SecurityE2EDeviceAutoban + " (effective: " + [bool]$effectiveSecurityE2EDeviceAutoban + $(if ([bool]$SecurityE2EDeviceAutoban -and -not [bool]$effectiveSecurityE2E) { "; overridden by dependency: SecurityE2E=false" } else { "; as requested" }) + ")")
Write-Host ("SecurityE2EIdentityBan: " + [bool]$SecurityE2EIdentityBan + " (effective: " + [bool]$effectiveSecurityE2EIdentityBan + $(if ([bool]$SecurityE2EIdentityBan -and -not [bool]$effectiveSecurityE2E) { "; overridden by dependency: SecurityE2E=false" } else { "; as requested" }) + ")")
Write-Host ("SecurityE2ESupportRef: " + [bool]$SecurityE2ESupportRef + " (effective: " + [bool]$effectiveSecurityE2ESupportRef + $(if ([bool]$SecurityE2ESupportRef -and -not [bool]$effectiveSecurityE2E) { "; overridden by dependency: SecurityE2E=false" } else { "; as requested" }) + ")")
Write-Host ("SecurityE2EEventsCheck: " + [bool]$SecurityE2EEventsCheck + " (effective: " + [bool]$effectiveSecurityE2EEventsCheck + $(if ([bool]$SecurityE2EEventsCheck -and -not [bool]$effectiveSecurityE2E) { "; overridden by dependency: SecurityE2E=false" } else { "; as requested" }) + ")")
Write-Host ("SecurityE2EAttempts: " + [int]$effectiveSecurityE2EAttempts)
Write-Host ("SecurityE2EThreshold: " + [int]$effectiveSecurityE2EThreshold)
Write-Host ("SecurityE2ESeconds: " + [int]$effectiveSecurityE2ESeconds)
Write-Host ("SecurityE2ELogin: " + $effectiveSecurityE2ELogin)
Write-Host ("SecurityE2EPassword: <redacted>")
Write-Host ("SecurityE2ECleanup: " + [bool]$effectiveSecurityE2ECleanup)
Write-Host ("SecurityE2EDryRun: " + [bool]$effectiveSecurityE2EDryRun)
Write-Host ("SecurityE2EEnvGate: " + [bool]$effectiveSecurityE2EEnvGate)
Write-Host ("ShowCheckDetails: " + [bool]$effectiveShowCheckDetails)
Write-Host ("ExportLogs: " + [bool]$effectiveExportLogs)
Write-Host ("ExportLogsLines: " + [int]$effectiveExportLogsLines)
Write-Host ("ExportFolder: " + $effectiveExportFolder)
Write-Host ("AutoOpenExportFolder: " + [bool]$effectiveAutoOpenExportFolder)
Write-Host ("LogFile: " + $(if ($effectiveLogFilePath -and $effectiveLogFilePath.Trim() -ne "") { $effectiveLogFilePath } else { "(none)" }))
Write-Host ("ChecksSource: " + $checksSourceLabel + " (" + $checksRoot + ")")

$results = New-Object System.Collections.Generic.List[object]
$exports = New-Object System.Collections.Generic.List[string]
$maxScore = 0

if ($effectiveExportLogs) {
    try {
        New-Item -ItemType Directory -Path $effectiveExportFolder -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Host ("[WARN] ExportFolder could not be created: " + $effectiveExportFolder + " (" + $_.Exception.Message + ")")
    }
}

foreach ($step in $plan) {
    $res = $null
    $checkStartedAt = Get-Date
    try {
        $res = & $step
    } catch {
        $res = New-AuditResult -Id "core_exception" -Title "Core exception" -Status "CRITICAL" -Summary $_.Exception.Message -Details @() -Data @{} -DurationMs 0
    }
    $checkFinishedAt = Get-Date

    if ($null -ne $res) {
        $checkId = ""
        try { $checkId = ("" + $res.id).Trim().ToLowerInvariant() } catch { $checkId = "" }

        $detailsEnabledForThisCheck = $false
        if ($effectiveShowCheckDetails) {
            if (-not $hasPerCheckDetailsOverrides) {
                $detailsEnabledForThisCheck = $true
            } else {
                $detailsEnabledForThisCheck = (Get-PerCheckEnabled -Map $effectivePerCheckDetailsMap -CheckId $checkId -Default $false)
            }
        }

        $exportEnabledForThisCheck = $false
        if ($effectiveExportLogs) {
            if (-not $hasPerCheckExportOverrides) {
                $exportEnabledForThisCheck = $true
            } else {
                $exportEnabledForThisCheck = (Get-PerCheckEnabled -Map $effectivePerCheckExportMap -CheckId $checkId -Default $false)
            }
        }

        if ($null -eq $res.data) { $res.data = @{} }
        try { $res.data["check_started_at"] = $checkStartedAt.ToString("yyyy-MM-dd HH:mm:ss") } catch { }
        try { $res.data["check_finished_at"] = $checkFinishedAt.ToString("yyyy-MM-dd HH:mm:ss") } catch { }

        if ($detailsEnabledForThisCheck -or $exportEnabledForThisCheck) {
            $computedDetailsText = ""
            try { $computedDetailsText = ("" + $res.details_text) } catch { $computedDetailsText = "" }
            if ($computedDetailsText.Trim() -eq "") {
                try {
                    $detailsRaw = ConvertTo-SafeStringArray $res.details
                    if ((Get-SafeCount $detailsRaw) -gt 0) { $computedDetailsText = (($detailsRaw | ForEach-Object { "" + $_ }) -join "`n") }
                } catch { $computedDetailsText = "" }
            }
            try { $res.details_text = $computedDetailsText } catch { }

            $logSliceArr = @()
            $sliceEvidenceArr = @()
            try {
                $sliceObj = Get-ResultLogSlice -LogPath $effectiveLogFilePath -Res $res -CheckStartedAt $checkStartedAt -CheckFinishedAt $checkFinishedAt -MaxLines $effectiveExportLogsLines
                if ($null -ne $sliceObj) {
                    try { $logSliceArr = @(ConvertTo-SafeStringArray $sliceObj.lines) } catch { $logSliceArr = @() }
                    try { $sliceEvidenceArr = @(ConvertTo-SafeStringArray $sliceObj.evidence) } catch { $sliceEvidenceArr = @() }
                    try { $res.data["log_slice_mode"] = ("" + $sliceObj.mode) } catch { }
                }
            } catch {
                $sliceEvidenceArr = @("LogSlice: generation failed (" + $_.Exception.Message + ").")
                $logSliceArr = @()
            }
            try { $res.log_slice = @($logSliceArr) } catch { }

            $resEvidence = @()
            try { $resEvidence = @(ConvertTo-SafeStringArray $res.evidence) } catch { $resEvidence = @() }
            $evidenceCombined = New-Object System.Collections.Generic.List[string]
            foreach ($e in $resEvidence) { $evidenceCombined.Add(("" + $e)) | Out-Null }
            foreach ($e in $sliceEvidenceArr) { $evidenceCombined.Add(("" + $e)) | Out-Null }
            try { $res.evidence = @($evidenceCombined.ToArray()) } catch { }

            if ($exportEnabledForThisCheck) {
                try {
                    $runStamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
                    $checkNameSource = ""
                    try { $checkNameSource = ("" + $res.title).Trim() } catch { $checkNameSource = "" }
                    if ($checkNameSource -eq "") {
                        try { $checkNameSource = ("" + $res.id).Trim() } catch { $checkNameSource = "check" }
                    }
                    # Remove common numbering prefixes like "1) ", "2a) ", "X) ".
                    $checkNameSource = ($checkNameSource -replace '^(?i:\s*[0-9x]+[a-z]?\)\s*)', '')
                    $checkName = Convert-ToSafeFileSegment $checkNameSource
                    $exportName = ("{0}_audit_{1}.log" -f $runStamp, $checkName)
                    $exportPath = Join-Path $effectiveExportFolder $exportName

                    $modeHint = ""
                    try { $modeHint = ("" + $res.data["log_slice_mode"]).Trim() } catch { $modeHint = "" }

                    $exportLinesList = New-Object System.Collections.Generic.List[string]
                    $exportLinesList.Add("# KiezSingles Admin Audit - Per-Check Report") | Out-Null
                    $exportLinesList.Add("# CheckId: " + ("" + $res.id)) | Out-Null
                    $exportLinesList.Add("# Title: " + ("" + $res.title)) | Out-Null
                    $exportLinesList.Add("# Status: " + ("" + $res.status)) | Out-Null
                    $exportLinesList.Add("# Summary: " + ("" + $res.summary)) | Out-Null
                    $exportLinesList.Add("# StartedAt: " + $checkStartedAt.ToString("yyyy-MM-dd HH:mm:ss")) | Out-Null
                    $exportLinesList.Add("# FinishedAt: " + $checkFinishedAt.ToString("yyyy-MM-dd HH:mm:ss")) | Out-Null
                    if ($modeHint -ne "") { $exportLinesList.Add("# LogSliceMode: " + $modeHint) | Out-Null }

                    $exportLinesList.Add("") | Out-Null
                    $exportLinesList.Add("Evidence:") | Out-Null
                    $evExport = @()
                    try { $evExport = @(ConvertTo-SafeStringArray $res.evidence) } catch { $evExport = @() }
                    if ($evExport.Count -le 0) {
                        $exportLinesList.Add("  (none)") | Out-Null
                    } else {
                        foreach ($ev in $evExport) { $exportLinesList.Add("  - " + ("" + $ev)) | Out-Null }
                    }

                    $exportLinesList.Add("") | Out-Null
                    $exportLinesList.Add("Details:") | Out-Null
                    $detExport = @()
                    try { $detExport = @(ConvertTo-SafeStringArray (Get-DetailsForOutput $res)) } catch { $detExport = @() }
                    if ($detExport.Count -le 0) {
                        $exportLinesList.Add("  (none)") | Out-Null
                    } else {
                        foreach ($d in $detExport) { $exportLinesList.Add("  " + ("" + $d)) | Out-Null }
                    }

                    $exportLinesList.Add("") | Out-Null
                    $exportLinesList.Add(("LogSlice (max {0} lines):" -f [int]$effectiveExportLogsLines)) | Out-Null
                    if ($logSliceArr.Count -le 0) {
                        $exportLinesList.Add("  (no lines)") | Out-Null
                    } else {
                        foreach ($l in $logSliceArr) { $exportLinesList.Add("  " + ("" + $l)) | Out-Null }
                    }

                    [System.IO.File]::WriteAllLines($exportPath, @($exportLinesList.ToArray()), [System.Text.UTF8Encoding]::new($false))
                    $exports.Add($exportPath) | Out-Null
                    try { $res.log_export_path = $exportPath } catch { }
                    try { $res.data["log_export_path"] = $exportPath } catch { }
                } catch {
                    try { $res.data["log_export_error"] = ("" + $_.Exception.Message) } catch { }
                }
            }
        }

        $results.Add($res) | Out-Null
        $score = Get-ResultScore $res
        if ($score -gt $maxScore) { $maxScore = $score }

        Write-Host ""
        Write-Host ((Format-StatusTag $res.status) + " " + $res.title + " - " + $res.summary + " (" + $res.duration_ms + "ms)")

        if ($detailsEnabledForThisCheck) {
            $detailsToPrint = Get-DetailsForOutput $res
            $detailsToPrintArr = ConvertTo-SafeStringArray $detailsToPrint
            $evToPrint = @()
            try { $evToPrint = @(ConvertTo-SafeStringArray $res.evidence) } catch { $evToPrint = @() }
            $sliceToPrint = @()
            try { $sliceToPrint = @(ConvertTo-SafeStringArray $res.log_slice) } catch { $sliceToPrint = @() }
            $exportPathPrint = ""
            try { $exportPathPrint = ("" + $res.log_export_path).Trim() } catch { $exportPathPrint = "" }

            if ((Get-SafeCount $detailsToPrintArr) -gt 0 -or (Get-SafeCount $evToPrint) -gt 0 -or (Get-SafeCount $sliceToPrint) -gt 0 -or $exportPathPrint -ne "") {
                Write-Host ""

                if ((Get-SafeCount $evToPrint) -gt 0) {
                    Write-Host "  Evidence:"
                    foreach ($x in $evToPrint) { Write-Host ("    - " + $x) }
                }

                if ((Get-SafeCount $detailsToPrintArr) -gt 0) {
                    Write-Host "  Details:"
                    foreach ($d in $detailsToPrintArr) { Write-Host ("    " + $d) }
                }

                if ($exportPathPrint -ne "") {
                    Write-Host ("  Log: exported -> " + $exportPathPrint)
                } elseif ((Get-SafeCount $sliceToPrint) -gt 0) {
                    Write-Host ("  Log: log slice shown below (max " + [int]$effectiveExportLogsLines + " lines)")
                }

                if ((Get-SafeCount $sliceToPrint) -gt 0) {
                    Write-Host "  LogSlice:"
                    foreach ($line in $sliceToPrint) { Write-Host ("    " + $line) }
                }
            }
        }
    }
}

$finalStatus = "OK"
switch ($maxScore) {
    0 { $finalStatus = "OK" }
    1 { $finalStatus = "WARN" }
    2 { $finalStatus = "FAIL" }
    default { $finalStatus = "CRITICAL" }
}

$exitCode = 0
switch ($finalStatus) {
    "OK" { $exitCode = 0 }
    "WARN" { $exitCode = 10 }
    "FAIL" { $exitCode = 20 }
    default { $exitCode = 30 }
}

Write-Section "Audit result"
Write-Host ("FinalStatus: " + $finalStatus)
Write-Host ("ExitCode: " + $exitCode)

if ($exports.Count -gt 0) {
    Write-Section "Exports"
    foreach ($p in @($exports.ToArray())) {
        Write-Host ("Datei: " + $p)
    }

    if ($effectiveAutoOpenExportFolder) {
        try {
            Start-Process explorer.exe $effectiveExportFolder | Out-Null
            Write-Host ("Explorer: opened " + $effectiveExportFolder)
        } catch {
            Write-Host ("[WARN] Could not open export folder: " + $_.Exception.Message)
        }
    }
}

return (Stop-Program $exitCode)
