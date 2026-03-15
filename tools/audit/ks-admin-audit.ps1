# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit.ps1
# Purpose: Deterministic CLI core for KiezSingles Admin Audit (no GUI)
# Created: 21-02-2026 00:29 (Europe/Berlin)
# Changed: 15-03-2026 20:49 (Europe/Berlin)
# Version: 5.6
# =============================================================================

[CmdletBinding()]
param(
    # Base URL for optional HTTP checks
    [string]$BaseUrl = "http://kiezsingles.test",

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
    
    # Compatibility only: accepted from wrapper/UI, not used by core logic.
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
    [string]$SecurityLoginAttempts = "8",

    # If set, runs optional IP ban enforcement probe
    [switch]$SecurityCheckIpBan,

    # If set, runs optional registration abuse probe
    [switch]$SecurityCheckRegister,

    # If set, security lockout probe expects explicit 429 status
    [switch]$SecurityExpect429,

    # Lockout keywords used by security probes
    [string[]]$SecurityLockoutKeywords = @("too many attempts","throttle","locked","lockout"),

    # If true, prints optional per-check details/evidence blocks below the status line.
    [string]$ShowCheckDetails = "true",

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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-SafeCount([object]$Value) {
    try {
        if ($null -eq $Value) { return 0 }

        if ($Value -is [string]) { return 1 }

        if ($Value -is [System.Collections.IDictionary]) {
            try { return [int]$Value.Count } catch { return 0 }
        }

        if ($Value -is [System.Collections.ICollection]) {
            try { return [int]$Value.Count } catch { return 0 }
        }

        try {
            $arr = @($Value)
            if ($null -eq $arr) { return 0 }
            try { return [int]$arr.Count } catch { return 0 }
        } catch {
            return 0
        }
    } catch {
        return 0
    }
}

function ConvertTo-SafeStringArray([object]$Value) {
    $out = New-Object System.Collections.Generic.List[string]
    try {
        if ($null -eq $Value) { return @() }

        if ($Value -is [string]) {
            $out.Add(("" + $Value)) | Out-Null
            return @($out.ToArray())
        }

        $items = @()
        try { $items = @($Value) } catch { $items = @() }

        foreach ($i in $items) {
            if ($null -eq $i) { continue }
            $out.Add(("" + $i)) | Out-Null
        }

        return @($out.ToArray())
    } catch {
        try { return @($out.ToArray()) } catch { return @() }
    }
}

function Mask-SensitiveValue([string]$Text) {
    if ($null -eq $Text) { return "" }

    $masked = "" + $Text

    try {
        $masked = [System.Text.RegularExpressions.Regex]::Replace(
            $masked,
            '(?im)^(\s*(?:Cookie|Set-Cookie)\s*:\s*)(.+)$',
            {
                param($m)
                $pairs = @()
                try { $pairs = @(([string]$m.Groups[2].Value) -split '\s*;\s*') } catch { $pairs = @() }
                $maskedPairs = New-Object System.Collections.Generic.List[string]

                foreach ($pair in @($pairs)) {
                    $entry = ("" + $pair).Trim()
                    if ($entry -eq "") { continue }

                    if ($entry -match '^([^=]+)=') {
                        $cookieName = ("" + $matches[1]).Trim()
                        $maskedPairs.Add(($cookieName + '=[masked]')) | Out-Null
                    } else {
                        $maskedPairs.Add($entry) | Out-Null
                    }
                }

                return ($m.Groups[1].Value + (($maskedPairs.ToArray()) -join '; '))
            }
        )
    } catch { }

    foreach ($pattern in @(
        '(?i)\b(laravel_session)\s*=\s*([^;\s,]+)',
        '(?i)\b(XSRF-TOKEN)\s*=\s*([^;\s,]+)',
        '(?i)\b(laravel_session)\s*:\s*([^\s,;]+)',
        '(?i)\b(XSRF-TOKEN)\s*:\s*([^\s,;]+)',
        '(?i)\b(session(?:[_-]?id)?)\s*:\s*([^\s,;]+)',
        '(?i)\b(session(?:[_-]?id)?)\s*=\s*([^\s,;]+)'
    )) {
        try {
            $masked = [System.Text.RegularExpressions.Regex]::Replace(
                $masked,
                $pattern,
                {
                    param($m)
                    return ($m.Groups[1].Value + $(if ($m.Value.Contains(':')) { ': ' } else { '=' }) + '[masked]')
                }
            )
        } catch { }
    }

    return $masked
}

function Write-Host {
    [CmdletBinding(DefaultParameterSetName = 'NoNewline')]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [object[]]$Object,

        [switch]$NoNewline,
        [object]$Separator = ' ',
        [System.ConsoleColor]$ForegroundColor,
        [System.ConsoleColor]$BackgroundColor
    )

    $sanitizedObjects = @()
    foreach ($item in @($Object)) {
        if ($item -is [string]) {
            $sanitizedObjects += (Mask-SensitiveValue ("" + $item))
        } else {
            $sanitizedObjects += $item
        }
    }

    $forward = @{}
    foreach ($entry in $PSBoundParameters.GetEnumerator()) {
        if ($entry.Key -eq 'Object') { continue }
        $forward[$entry.Key] = $entry.Value
    }
    $forward['Object'] = $sanitizedObjects

    Microsoft.PowerShell.Utility\Write-Host @forward
}

function Stop-Program([int]$Code) {
    if ($NoExit) { return $Code }
    exit $Code
}

# Ensure predictable UTF-8 output (no BOM)
try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }
try { [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false) } catch { }

# -----------------------------------------------------------------------------
# Robust parameter recovery (deterministic)
# Some runners accidentally break named binding so BaseUrl becomes "-BaseUrl"
# and/or ProbePaths absorbs tokens. If we detect that, re-parse a deterministic
# token stream and re-apply sane values.
# -----------------------------------------------------------------------------
function Get-ArgValueFromToken([string]$token) {
    if ($null -eq $token) { return $null }
    $t = ("" + $token).Trim()
    if ($t -match '^(?<name>-[A-Za-z][A-Za-z0-9_]*)\s*:\s*(?<val>.*)$') {
        return $Matches['val']
    }
    return $null
}

function Get-ArgNameFromToken([string]$token) {
    if ($null -eq $token) { return "" }
    $t = ("" + $token).Trim()
    if ($t -match '^(?<name>-[A-Za-z][A-Za-z0-9_]*)(\s*:\s*.*)?$') {
        return $Matches['name']
    }
    return ""
}

function Test-KnownSwitch([string]$name) {
    switch ($name) {
        "-HttpProbe" { return $true }
        "-TailLog" { return $true }
        "-RoutesVerbose" { return $true }
        "-RouteListFindstrAdmin" { return $true }
        "-SuperadminCount" { return $true }
        "-LoginCsrfProbe" { return $true }
        "-RoleSmokeTest" { return $true }
        "-SessionCsrfBaseline" { return $true }
        "-LogSnapshot" { return $true }
        "-LogClearBefore" { return $true }
        "-LogClearAfter" { return $true }
        "-RouteListOptionScanFullProject" { return $true }
        "-SecurityProbe" { return $true }
        "-SecurityCheckIpBan" { return $true }
        "-SecurityCheckRegister" { return $true }
        "-SecurityExpect429" { return $true }
        "-NoExit" { return $true }
        default { return $false }
    }
}

function Test-KnownValueParam([string]$name) {
    switch ($name) {
        "-BaseUrl" { return $true }
        "-PathsConfigFile" { return $true }
        "-ProbePaths" { return $true }
        "-SuperadminEmail" { return $true }
        "-SuperadminPassword" { return $true }
        "-AdminEmail" { return $true }
        "-AdminPassword" { return $true }
        "-ModeratorEmail" { return $true }
        "-ModeratorPassword" { return $true }
        "-RoleSmokePaths" { return $true }
        "-PathsConfigFile" { return $true }
        "-LogSnapshotLines" { return $true }
        "-SecurityLoginAttempts" { return $true }
        "-SecurityLockoutKeywords" { return $true }
        "-ShowCheckDetails" { return $true }
        "-ExportLogs" { return $true }
        "-ExportLogsLines" { return $true }
        "-ExportFolder" { return $true }
        "-AutoOpenExportFolder" { return $true }
        "-PerCheckDetails" { return $true }
        "-PerCheckExport" { return $true }
        "-Gui" { return $true }
        default { return $false }
    }
}

function Test-RecoverArgsNeeded {
    try {
        if ($BaseUrl -and (("" + $BaseUrl).Trim() -match '^-')) { return $true }

        foreach ($v in @($ProbePaths)) {
            if ($v -and (("" + $v).Trim() -match '^-')) { return $true }
        }

        foreach ($v in @($IgnoredArgs)) {
            if ($v -and (("" + $v).Trim() -match '^-')) { return $true }
        }

        return $false
    } catch {
        return $false
    }
}

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
    $recPathsConfigFile = ""
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
    $recShowCheckDetails = $true
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
        if ($name -eq "-PathsConfigFile") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal) {
                $i++
                continue
            }

            if (($i + 1) -lt $tokens.Count) {
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

        if ($name -eq "-PathsConfigFile") {
            $inlineVal = Get-ArgValueFromToken $t
            if ($null -ne $inlineVal -and (("" + $inlineVal).Trim() -ne "")) {
                $recPathsConfigFile = ("" + $inlineVal).Trim()
                $i++
                continue
            }

            if (($i + 1) -lt $tokens.Count) {
                $recPathsConfigFile = ("" + $tokens[$i + 1]).Trim()
                $i += 2
                continue
            }

            $i++
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

        if ($name -eq "-SuperadminEmail" -or $name -eq "-SuperadminPassword" -or $name -eq "-AdminEmail" -or $name -eq "-AdminPassword" -or $name -eq "-ModeratorEmail" -or $name -eq "-ModeratorPassword") {
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

        if ($name -eq "-ShowCheckDetails" -or $name -eq "-ExportLogs" -or $name -eq "-AutoOpenExportFolder") {
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
    if ($recPathsConfigFile -ne "") { $PathsConfigFile = $recPathsConfigFile }
    if ($recSessionCsrfBaseline) { $SessionCsrfBaseline = $true }
    if ($recLogSnapshot) { $LogSnapshot = $true }
    $LogSnapshotLines = [int]$recLogSnapshotLines
    if ($recLogClearBefore) { $LogClearBefore = $true }
    if ($recLogClearAfter) { $LogClearAfter = $true }
    if ($recRouteListOptionScanFullProject) { $RouteListOptionScanFullProject = $true }
    if ($recSecurityProbe) { $SecurityProbe = $true }
    $SecurityLoginAttempts = ("" + [int]$recSecurityLoginAttempts)
    if ($recSecurityCheckIpBan) { $SecurityCheckIpBan = $true }
    if ($recSecurityCheckRegister) { $SecurityCheckRegister = $true }
    if ($recSecurityExpect429) { $SecurityExpect429 = $true }
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
    if ($recRoleSmokePaths.Count -gt 0) { $RoleSmokePaths = @($recRoleSmokePaths.ToArray()) }
    if ($recSecurityLockoutKeywords.Count -gt 0) { $SecurityLockoutKeywords = @($recSecurityLockoutKeywords.ToArray()) }

    if ($null -ne $recGui) { $Gui = $recGui }

    $IgnoredArgs = @()
}

function Get-InvocationParameterValues {
    param(
        [Parameter(Mandatory = $true)][string]$ParamName
    )

    $out = New-Object System.Collections.Generic.List[string]
    $line = ""
    try { $line = ("" + $MyInvocation.Line) } catch { $line = "" }
    if ($line.Trim() -eq "") { return @() }

    $tokens = New-Object System.Collections.Generic.List[string]
    try {
        $rx = [regex]'("([^"\\]|\\.)*"|''[^'']*''|\S+)'
        foreach ($m in $rx.Matches($line)) {
            $t = ("" + $m.Value).Trim()
            if ($t -eq "") { continue }
            if (($t.StartsWith('"') -and $t.EndsWith('"')) -or ($t.StartsWith("'") -and $t.EndsWith("'"))) {
                if ($t.Length -ge 2) { $t = $t.Substring(1, $t.Length - 2) }
            }
            $tokens.Add($t) | Out-Null
        }
    } catch {
        return @()
    }

    if ($tokens.Count -le 0) { return @() }

    $nameNorm = ("-" + ("" + $ParamName).Trim().TrimStart("-"))
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $tok = ("" + $tokens[$i]).Trim()
        if ($tok -ne $nameNorm) { continue }

        $j = $i + 1
        while ($j -lt $tokens.Count) {
            $v = ("" + $tokens[$j]).Trim()
            if ($v -eq "") { $j++; continue }
            if ($v.StartsWith("-")) { break }
            $out.Add($v) | Out-Null
            $j++
        }
    }

    return @($out.ToArray())
}

function Get-ProcessArgParameterValues {
    param(
        [Parameter(Mandatory = $true)][string]$ParamName
    )

    $out = New-Object System.Collections.Generic.List[string]
    $argv = @()
    try { $argv = @([Environment]::GetCommandLineArgs()) } catch { $argv = @() }
    if ($argv.Count -le 0) { return @() }

    $nameNorm = ("-" + ("" + $ParamName).Trim().TrimStart("-"))
    for ($i = 0; $i -lt $argv.Count; $i++) {
        $tok = ("" + $argv[$i]).Trim()
        if ($tok -ne $nameNorm) { continue }

        $j = $i + 1
        while ($j -lt $argv.Count) {
            $v = ("" + $argv[$j]).Trim()
            if ($v -eq "") { $j++; continue }
            if ($v.StartsWith("-")) { break }
            $out.Add($v) | Out-Null
            $j++
        }
    }

    return @($out.ToArray())
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

function Test-ProjectRoot([string]$Root) {
    $artisan = Join-Path $Root "artisan"
    if (!(Test-Path $artisan)) {
        throw "Project root not detected. Expected artisan at: $artisan"
    }
}
Test-ProjectRoot $projectRoot
Set-Location $projectRoot

# Capture audit start (for log snapshot "since audit start" classification)
$auditStartedAt = $null
try { $auditStartedAt = Get-Date } catch { $auditStartedAt = $null }

# --- Normalize ProbePaths (some launchers accidentally pass them as a single string token)
function ConvertTo-NormalizedProbePaths([object]$Value) {
    $out = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    if ($null -eq $Value) {
        return @()
    }

    $vals = @()
    try { $vals = @($Value) } catch { $vals = @() }

    foreach ($v in $vals) {
        if ($null -eq $v) { continue }
        $s = ("" + $v).Trim()
        if ($s -eq "") { continue }

        $parts = @()
        if ($s -match "\r?\n" -or $s -match "\s" -or $s -match "[,;]") {
            try { $parts = @($s -split "[\s,;]+") } catch { $parts = @() }
        } else {
            $parts = @($s)
        }

        foreach ($part in @($parts)) {
            $x = ("" + $part).Trim()
            if ($x -eq "") { continue }

            if ($x -match '^(?i)https?://') {
                try {
                    $u = $null
                    $ok = $false
                    try { $ok = [System.Uri]::TryCreate($x, [System.UriKind]::Absolute, [ref]$u) } catch { $ok = $false }
                    if ($ok -and $u -and $u.AbsolutePath) { $x = ("" + $u.AbsolutePath).Trim() }
                } catch { }
            }

            if ($x -eq "") { continue }
            if (-not $x.StartsWith("/")) { $x = "/" + $x.TrimStart("/") }
            if ($x -eq "/") { continue }

            if ($seen.ContainsKey($x)) { continue }
            $seen[$x] = $true
            $out.Add($x) | Out-Null
        }
    }

    return @($out.ToArray())
}

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

# Recover string/bool value parameters from invocation if host binding shifted.
function Resolve-ParamValues([string]$Name) {
    $vals = @()
    try { $vals = @(Get-InvocationParameterValues -ParamName $Name) } catch { $vals = @() }
    if ($vals.Count -le 0) {
        try { $vals = @(Get-ProcessArgParameterValues -ParamName $Name) } catch { $vals = @() }
    }
    return @($vals)
}

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

$effectiveLoginCsrfProbe = [bool]$LoginCsrfProbe
$effectiveSessionCsrfBaseline = [bool]$SessionCsrfBaseline

# --- Helpers (kept minimal; no GUI logic)
function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 78)
    Write-Host $Title
    Write-Host ("=" * 78)
}

function ConvertTo-QuotedArgWindows([string]$s) {
    if ($null -eq $s) { return '""' }

    $t = "" + $s
    if ($t -eq "") { return '""' }

    if ($t -match '[\s"]') {
        $t = $t -replace '(\\*)"', '$1$1\"'
        $t = $t -replace '(\\+)$', '$1$1'
        return '"' + $t + '"'
    }

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

        $quotedArgs = @()
        foreach ($a in $ArgumentList) {
            $quotedArgs += (ConvertTo-QuotedArgWindows ("" + $a))
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

function Resolve-PHPExePath {
    try {
        $exe = $null

        try {
            $paths = ("" + $env:PATH).Split(";") | Where-Object { $_ -and ("" + $_).Trim() -ne "" }
            foreach ($p in $paths) {
                $candidate = Join-Path ($p.Trim()) "php.exe"
                if (Test-Path -LiteralPath $candidate) {
                    $exe = $candidate
                    break
                }
            }
        } catch { }

        if ($exe -and (("" + $exe).Trim() -ne "")) {
            return ("" + $exe).Trim()
        }

        try {
            $phpApp = Get-Command php -All -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandType -eq "Application" } |
                Select-Object -First 1

            if ($phpApp -and $phpApp.Source -and ("" + $phpApp.Source).Trim() -ne "") {
                return ("" + $phpApp.Source).Trim()
            }
        } catch { }

        return "php"
    } catch {
        return "php"
    }
}

function Invoke-PHPArtisan([string]$Root, [string[]]$ArgumentList, [int]$TimeoutSeconds = 120) {
    $php = Resolve-PHPExePath
    $artisan = Join-Path $Root "artisan"

    if ($null -eq $ArgumentList) { $ArgumentList = @() }

    $cmdArgs = @()
    $cmdArgs += $artisan
    $cmdArgs += $ArgumentList
    $cmdArgs = @($cmdArgs | Where-Object { $_ -ne $null })

    return Invoke-ProcessToFiles -File $php -ArgumentList $cmdArgs -TimeoutSeconds $TimeoutSeconds -WorkingDirectory $Root
}

function New-AuditResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][ValidateSet("OK","WARN","FAIL","CRITICAL")][string]$Status,
        [Parameter(Mandatory = $true)][string]$Summary,
        [string[]]$Details = @(),
        [hashtable]$Data = @{},
        [string]$DetailsText = "",
        [object[]]$Evidence = @(),
        [string[]]$LogSlice = @(),
        [string]$LogExportPath = "",
        [int]$DurationMs = 0
    )

    $effectiveDetailsText = $DetailsText
    if (($effectiveDetailsText -eq "") -and ((Get-SafeCount $Details) -gt 0)) {
        try { $effectiveDetailsText = ((@($Details) | ForEach-Object { "" + $_ }) -join "`n") } catch { $effectiveDetailsText = "" }
    }

    return [pscustomobject]@{
        id = $Id
        title = $Title
        status = $Status
        summary = $Summary
        details = @($Details)
        data = $Data
        details_text = $effectiveDetailsText
        evidence = @($Evidence)
        log_slice = @($LogSlice)
        log_export_path = ("" + $LogExportPath)
        duration_ms = $DurationMs
    }
}

function Get-StatusScore([string]$Status) {
    switch ($Status) {
        "OK" { return 0 }
        "WARN" { return 1 }
        "FAIL" { return 2 }
        "CRITICAL" { return 3 }
        default { return 3 }
    }
}

function Format-StatusTag([string]$Status) {
    switch ($Status) {
        "OK" { return "[OK]" }
        "WARN" { return "[WARN]" }
        "FAIL" { return "[FAIL]" }
        "CRITICAL" { return "[CRITICAL]" }
        default { return "[CRITICAL]" }
    }
}

function Get-CompactAuditTitle($Res) {
    $title = ""
    try { $title = ("" + $Res.title).Trim() } catch { $title = "" }
    if ($title -eq "") {
        try { $title = ("" + $Res.id).Trim() } catch { $title = "Check" }
    }

    $title = ($title -replace '^(?i:\s*[0-9x]+[a-z]?\)\s*)', '')

    if ($title -match '(?i)^HTTP exposure probe$') { return "HTTP-Probe" }
    if ($title -match '(?i)^Login CSRF probe$') { return "Login CSRF Probe" }
    if ($title -match '(?i)^Role access smoke test') { return "Role Smoke Test" }
    if ($title -match '(?i)^Session/CSRF baseline') { return "Session/CSRF Baseline" }
    if ($title -match '(?i)^route:list option scan') { return "route:list option scan" }

    return $title
}

function Test-IsNullRunResult($Res) {
    $id = ""
    try { $id = ("" + $Res.id).Trim().ToLowerInvariant() } catch { $id = "" }
    return ($id -eq "cache_clear")
}

function Get-PlanStepDebugName($Step) {
    $stepText = ""
    try { $stepText = ("" + $Step).Trim() } catch { $stepText = "" }
    if ($stepText -eq "") { return "unknown_step" }

    if ($stepText -match '(Invoke-KsAuditCheck_[A-Za-z0-9_]+)') {
        return $Matches[1]
    }

    if ($stepText -match '-Title\s+"([^"]+)"') {
        return $Matches[1]
    }

    return $stepText
}

function Get-AuditDisplayItems {
    $items = New-Object System.Collections.Generic.List[object]

    $items.Add([pscustomobject]@{ group = "null"; title = "Cache Clear" }) | Out-Null
    $items.Add([pscustomobject]@{ group = "test"; title = "Routes / collisions / admin scope" }) | Out-Null
    $items.Add([pscustomobject]@{ group = "test"; title = "route:list option scan (--columns / --format)" }) | Out-Null

    if ($HttpProbe) { $items.Add([pscustomobject]@{ group = "test"; title = "HTTP-Probe" }) | Out-Null }
    if ($LoginCsrfProbe) { $items.Add([pscustomobject]@{ group = "test"; title = "Login CSRF Probe" }) | Out-Null }
    if ($RoleSmokeTest) { $items.Add([pscustomobject]@{ group = "test"; title = "Role Smoke Test" }) | Out-Null }
    if ($SuperadminCount) { $items.Add([pscustomobject]@{ group = "test"; title = "Governance: Superadmin Fail-Safe" }) | Out-Null }
    if ($SessionCsrfBaseline) { $items.Add([pscustomobject]@{ group = "test"; title = "Session/CSRF Baseline" }) | Out-Null }
    if ($RoutesVerbose) { $items.Add([pscustomobject]@{ group = "test"; title = "Routes Verbose Inspection" }) | Out-Null }
    if ($RouteListFindstrAdmin) { $items.Add([pscustomobject]@{ group = "test"; title = "Route List Filter (admin-only)" }) | Out-Null }
    if ($LogSnapshot) { $items.Add([pscustomobject]@{ group = "test"; title = "Laravel Log Snapshot" }) | Out-Null }
    if ($TailLog) { $items.Add([pscustomobject]@{ group = "test"; title = "Tail Laravel Log" }) | Out-Null }
    $items.Add([pscustomobject]@{ group = "test"; title = "Security / Abuse Protection" }) | Out-Null

    return @($items.ToArray())
}

function Write-AuditDisplayPlan {
    $items = @(Get-AuditDisplayItems)
    $nullItems = @($items | Where-Object { $_.group -eq "null" })
    $testItems = @($items | Where-Object { $_.group -eq "test" })

    Write-Host ""
    Write-Host "Run Plan"
    Write-Host "--------"

    Write-Host "Null-Lauf:"
    if ($nullItems.Count -gt 0) {
        foreach ($item in $nullItems) {
            Write-Host ("- " + ("" + $item.title))
        }
    } else {
        Write-Host "(keine)"
    }

    Write-Host ""
    Write-Host "Ausgewaehlt:"
    if ($testItems.Count -gt 0) {
        $i = 0
        foreach ($item in $testItems) {
            $i++
            Write-Host ("Test {0} - {1}" -f $i, ("" + $item.title))
        }
    } else {
        Write-Host "(keine)"
    }
}

function Test-FunctionExists([string]$Name) {
    try {
        $c = Get-Command $Name -CommandType Function -ErrorAction SilentlyContinue
        return ($null -ne $c)
    } catch {
        return $false
    }
}

function Get-ResultScore($Res) {
    if ($null -eq $Res) { return 3 }

    try {
        if (("" + $Res.id) -eq "log_snapshot" -and ("" + $Res.status) -eq "WARN") {
            return 0
        }
    } catch { }

    return Get-StatusScore ("" + $Res.status)
}

function Get-DetailsForOutput($Res) {
    try {
        if ($null -eq $Res) { return @() }

        $detailsArr = ConvertTo-SafeStringArray $Res.details
        if ((Get-SafeCount $detailsArr) -le 0) { return @() }

        $title = ""
        try { $title = "" + $Res.title } catch { $title = "" }

        # Cosmetic: suppress Set-Cookie noise in unauthenticated HTTP probe output.
        if ($title -match 'HTTP exposure probe') {
            $filtered = New-Object System.Collections.Generic.List[string]
            foreach ($d in $detailsArr) {
                $line = ""
                try { $line = "" + $d } catch { $line = "" }
                if ($line -match '^(?i:Set-Cookie\s*:)') { continue }

                # Cosmetic: mark "follow" lines as INFO so "200 /login" doesn't look like exposure.
                if ($line -match '^(?i:FinalStatus\(follow\):)') { $line = "INFO: " + $line }
                elseif ($line -match '^(?i:FinalUri\(follow\):)') { $line = "INFO: " + $line }

                $filtered.Add($line) | Out-Null
            }
            return @($filtered.ToArray())
        }

        return @($detailsArr)
    } catch {
        try { return @(ConvertTo-SafeStringArray $Res.details) } catch { return @() }
    }
}

function Get-LaravelLogPath([string]$Root) {
    try {
        $logsDir = Join-Path $Root "storage\logs"
        if (-not (Test-Path -LiteralPath $logsDir -PathType Container)) { return "" }

        $single = Join-Path $logsDir "laravel.log"
        if (Test-Path -LiteralPath $single -PathType Leaf) { return $single }

        $daily = @()
        try {
            $daily = @(Get-ChildItem -LiteralPath $logsDir -File -Filter "laravel-*.log" -ErrorAction Stop | Sort-Object LastWriteTime -Descending)
        } catch { $daily = @() }
        if ($daily.Count -gt 0) { return ("" + $daily[0].FullName) }

        return ""
    } catch {
        return ""
    }
}

function Get-ResultLogCandidatePaths([string]$PrimaryLogPath, [int]$MaxCandidates = 2) {
    $out = New-Object System.Collections.Generic.List[string]
    try {
        $primary = ("" + $PrimaryLogPath).Trim()
        if ($primary -ne "") {
            $out.Add($primary) | Out-Null
        }
    } catch { }

    return @($out.ToArray())
}

function Build-CheckExportLines {
    param(
        [Parameter(Mandatory = $true)]$Res
    )

    $out = New-Object System.Collections.Generic.List[string]

    $resId = ""
    try { $resId = ("" + $Res.id).Trim() } catch { $resId = "" }
    $resTitle = ""
    try { $resTitle = ("" + $Res.title).Trim() } catch { $resTitle = "" }
    $resStatus = ""
    try { $resStatus = ("" + $Res.status).Trim() } catch { $resStatus = "" }
    $resSummary = ""
    try { $resSummary = ("" + $Res.summary).Trim() } catch { $resSummary = "" }

    $out.Add((Mask-SensitiveValue ("Check: " + $resId))) | Out-Null
    $out.Add((Mask-SensitiveValue ("Title: " + $resTitle))) | Out-Null
    $out.Add((Mask-SensitiveValue ("Status: " + $resStatus))) | Out-Null
    $out.Add((Mask-SensitiveValue ("Summary: " + $resSummary))) | Out-Null

    $evArr = @()
    try { $evArr = @(ConvertTo-SafeStringArray $Res.evidence) } catch { $evArr = @() }
    if ($evArr.Count -gt 0) {
        $out.Add("") | Out-Null
        $out.Add("Evidence:") | Out-Null
        foreach ($x in $evArr) {
            $out.Add((Mask-SensitiveValue ("- " + ("" + $x)))) | Out-Null
        }
    }

    $detailsArr = @()
    try { $detailsArr = @(ConvertTo-SafeStringArray $Res.details) } catch { $detailsArr = @() }
    if ($detailsArr.Count -gt 0) {
        $out.Add("") | Out-Null
        $out.Add("Details:") | Out-Null
        foreach ($d in $detailsArr) {
            $out.Add((Mask-SensitiveValue ("" + $d))) | Out-Null
        }
    }

    $detailsText = ""
    try { $detailsText = ("" + $Res.details_text) } catch { $detailsText = "" }
    $detailsTextArr = @()
    if ($detailsText.Trim() -ne "") {
        try { $detailsTextArr = @(ConvertTo-SafeStringArray ($detailsText -split "`r?`n")) } catch { $detailsTextArr = @() }
    }
    $detailsTextNormalized = ""
    $detailsArrNormalized = ""
    try { $detailsTextNormalized = (($detailsTextArr | ForEach-Object { ("" + $_).TrimEnd() }) -join "`n").Trim() } catch { $detailsTextNormalized = "" }
    try { $detailsArrNormalized = ((@($detailsArr) | ForEach-Object { ("" + $_).TrimEnd() }) -join "`n").Trim() } catch { $detailsArrNormalized = "" }
    if ($detailsTextNormalized -ne "" -and $detailsTextNormalized -ne $detailsArrNormalized) {
        $out.Add("") | Out-Null
        $out.Add("DetailsText:") | Out-Null
        foreach ($dt in $detailsTextArr) {
            $out.Add((Mask-SensitiveValue ("" + $dt))) | Out-Null
        }
    }

    $sliceArr = @()
    try { $sliceArr = @(ConvertTo-SafeStringArray $Res.log_slice) } catch { $sliceArr = @() }
    $out.Add("") | Out-Null
    if ($sliceArr.Count -gt 0) {
        $out.Add("LogSlice:") | Out-Null
        foreach ($line in $sliceArr) {
            $out.Add((Mask-SensitiveValue ("" + $line))) | Out-Null
        }
    } else {
        $out.Add("LogSlice: none") | Out-Null
    }

    return @($out.ToArray())
}

function Test-IsIgnoredAuditNoiseLogLine([string]$Line) {
    if ($null -eq $Line) { return $false }
    $l = ""
    try { $l = ("" + $Line).ToLowerInvariant() } catch { $l = "" }
    if ($l -eq "") { return $false }

    if ($l -match 'vendor/psy/psysh') { return $true }
    if ($l -match 'psy\\exception') { return $true }
    if ($l -match 'psy/shell') { return $true }
    if ($l -match 'laravel/tinker') { return $true }
    if ($l -match 'parseerrorexception') { return $true }
    if ($l -match 'codecleaner\.php') { return $true }
    if ($l -match '=config\(') { return $true }
    if ($l -match 'psy\\codecleaner') { return $true }
    if ($l -match 'psy/shell->') { return $true }

    return $false
}

function Convert-ToBooleanSafe([object]$Value, [bool]$Default = $false) {
    try {
        if ($null -eq $Value) { return $Default }
        if ($Value -is [bool]) { return [bool]$Value }
        $s = ("" + $Value).Trim()
        if ($s -eq "") { return $Default }
        if ($s -match '^(?i:1|true|\$true|yes|on)$') { return $true }
        if ($s -match '^(?i:0|false|\$false|no|off)$') { return $false }
        return [System.Convert]::ToBoolean($Value)
    } catch {
        return $Default
    }
}

function Convert-ToIntSafe([object]$Value, [int]$Default = 0) {
    try {
        if ($null -eq $Value) { return $Default }
        $n = [int]$Value
        return $n
    } catch {
        return $Default
    }
}

function Resolve-AuditExportFolder([string]$ProjectRoot, [string]$FolderValue) {
    try {
        $candidate = ("" + $FolderValue).Trim()
        if ($candidate -eq "") { $candidate = "tools/audit/output" }
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            return (Join-Path $ProjectRoot $candidate)
        }
        return $candidate
    } catch {
        return (Join-Path $ProjectRoot "tools/audit/output")
    }
}

function Convert-ToSafeFileSegment([string]$Value) {
    $s = ("" + $Value).Trim().ToLowerInvariant()
    if ($s -eq "") { $s = "check" }
    $s = $s -replace '[^a-z0-9\-_]+', '-'
    $s = $s.Trim('-')
    if ($s -eq "") { $s = "check" }
    return $s
}

function Convert-PerCheckSettingMap([string]$JsonText) {
    $out = @{}
    $raw = ""
    try { $raw = ("" + $JsonText).Trim() } catch { $raw = "" }
    if ($raw -eq "") { return $out }

    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $obj) { return $out }

        foreach ($p in @($obj.PSObject.Properties)) {
            $k = ""
            try { $k = ("" + $p.Name).Trim().ToLowerInvariant() } catch { $k = "" }
            if ($k -eq "") { continue }
            $out[$k] = (Convert-ToBooleanSafe $p.Value $false)
        }
    } catch { }

    return $out
}

function Get-PerCheckEnabled([hashtable]$Map, [string]$CheckId, [bool]$Default = $false) {
    if ($null -eq $Map) { return $Default }
    $k = ""
    try { $k = ("" + $CheckId).Trim().ToLowerInvariant() } catch { $k = "" }
    if ($k -eq "") { return $Default }
    try {
        if ($Map.Contains($k)) { return (Convert-ToBooleanSafe $Map[$k] $Default) }
    } catch { }
    return $Default
}

function Try-ParseLaravelLogTimestamp([string]$Line) {
    if ($null -eq $Line) { return $null }
    try {
        if ($Line -match '^\[(?<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\]') {
            return [datetime]::ParseExact($Matches['ts'], 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
        }
    } catch { }
    return $null
}

function Get-ValueFromResultData {
    param(
        [Parameter(Mandatory = $true)]$Data,
        [Parameter(Mandatory = $true)][string[]]$Keys
    )
    foreach ($k in @($Keys)) {
        try {
            if ($Data -is [System.Collections.IDictionary]) {
                if ($Data.Contains($k)) { return $Data[$k] }
            }
            if ($Data.PSObject -and ($Data.PSObject.Properties.Name -contains $k)) {
                return $Data.$k
            }
        } catch { }
    }
    return $null
}

function Get-ResultLogSlice {
    param(
        [Parameter(Mandatory = $true)][string]$LogPath,
        [Parameter(Mandatory = $true)]$Res,
        [Parameter(Mandatory = $true)][datetime]$CheckStartedAt,
        [Parameter(Mandatory = $true)][datetime]$CheckFinishedAt,
        [Parameter(Mandatory = $true)][int]$MaxLines
    )

    $evidence = New-Object System.Collections.Generic.List[string]
    $slice = New-Object System.Collections.Generic.List[string]

    if ($LogPath -eq "") {
        $evidence.Add("No Laravel log file found.") | Out-Null
        return [pscustomobject]@{
            lines = @()
            evidence = @($evidence.ToArray())
            mode = "missing"
        }
    }

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        $evidence.Add("No Laravel log file found.") | Out-Null
        return [pscustomobject]@{
            lines = @()
            evidence = @($evidence.ToArray())
            mode = "missing"
        }
    }

    $all = New-Object System.Collections.Generic.List[string]
    $readOk = $false
    $readErrors = New-Object System.Collections.Generic.List[string]
    $scanPaths = @(Get-ResultLogCandidatePaths -PrimaryLogPath $LogPath -MaxCandidates 2)
    if ($scanPaths.Count -le 0) { $scanPaths = @($LogPath) }
    foreach ($scanPath in $scanPaths) {
        if (-not (Test-Path -LiteralPath $scanPath -PathType Leaf)) { continue }
        try {
            $part = @(Get-Content -LiteralPath $scanPath -ErrorAction Stop)
            foreach ($line in $part) { $all.Add(("" + $line)) | Out-Null }
            $readOk = $true
        } catch {
            $readErrors.Add((("" + $scanPath) + ": " + $_.Exception.Message)) | Out-Null
        }
    }
    if (-not $readOk) {
        $msg = "LogSlice: failed to read log file."
        if ($readErrors.Count -gt 0) { $msg = ("LogSlice: failed to read log file (" + (($readErrors.ToArray() | Select-Object -First 1) -join "") + ").") }
        $evidence.Add($msg) | Out-Null
        return [pscustomobject]@{
            lines = @()
            evidence = @($evidence.ToArray())
            mode = "read_error"
        }
    }

    if ($all.Count -le 0) {
        $evidence.Add("Log file contains no entries during this run.") | Out-Null
        return [pscustomobject]@{
            lines = @()
            evidence = @($evidence.ToArray())
            mode = "empty"
        }
    }

    $data = $null
    try { $data = $Res.data } catch { $data = $null }

    $corr = ""
    if ($null -ne $data) {
        $corrRaw = Get-ValueFromResultData -Data $data -Keys @("correlation_id","correlationId","request_id","requestId","trace_id","traceId")
        if ($null -ne $corrRaw) { $corr = ("" + $corrRaw).Trim() }
    }

    $nonNoise = New-Object System.Collections.Generic.List[string]
    foreach ($line in $all) {
        $text = "" + $line
        if (Test-IsIgnoredAuditNoiseLogLine $text) { continue }
        $nonNoise.Add($text) | Out-Null
    }
    $allFiltered = @($nonNoise.ToArray())

    if ($allFiltered.Count -le 0) {
        $evidence.Add("Log file contains only Tinker/PsySH noise (ignored).") | Out-Null
        return [pscustomobject]@{
            lines = @()
            evidence = @($evidence.ToArray())
            mode = "empty_filtered"
        }
    }

    if ($corr -ne "") {
        foreach ($line in $allFiltered) {
            $text = "" + $line
            if ($text -like ("*" + $corr + "*")) { $slice.Add($text) | Out-Null }
        }
        if ($slice.Count -gt 0) {
            $evidence.Add("LogSlice mode: correlation_id ($corr)") | Out-Null
            if ($slice.Count -gt $MaxLines) { $slice = New-Object System.Collections.Generic.List[string] (@($slice.ToArray() | Select-Object -Last $MaxLines)) }
            return [pscustomobject]@{
                lines = @($slice.ToArray())
                evidence = @($evidence.ToArray())
                mode = "correlation"
            }
        }
    }

    $from = $CheckStartedAt
    $to = $CheckFinishedAt
    if ($to -lt $from) { $to = $from }
    $to = $to.AddSeconds(2)

    $hasParseableTimestamp = $false
    foreach ($line in $allFiltered) {
        $text = "" + $line
        $ts = Try-ParseLaravelLogTimestamp $text
        if ($null -eq $ts) { continue }
        $hasParseableTimestamp = $true
        if ($ts -ge $from -and $ts -le $to) { $slice.Add($text) | Out-Null }
    }

    if ($slice.Count -gt 0) {
        $evidence.Add("LogSlice mode: time_window ($($from.ToString('yyyy-MM-dd HH:mm:ss')) .. $($to.ToString('yyyy-MM-dd HH:mm:ss'))).") | Out-Null
        if ($slice.Count -gt $MaxLines) { $slice = New-Object System.Collections.Generic.List[string] (@($slice.ToArray() | Select-Object -Last $MaxLines)) }
        return [pscustomobject]@{
            lines = @($slice.ToArray())
            evidence = @($evidence.ToArray())
            mode = "time_window"
        }
    }

    if ($hasParseableTimestamp) {
        $nearSlice = New-Object System.Collections.Generic.List[string]
        $nearFrom = $from.AddMinutes(-2)
        $nearTo = $to.AddMinutes(2)
        foreach ($line in $allFiltered) {
            $text = "" + $line
            $ts = Try-ParseLaravelLogTimestamp $text
            if ($null -eq $ts) { continue }
            if ($ts -ge $nearFrom -and $ts -le $nearTo) { $nearSlice.Add($text) | Out-Null }
        }

        if ($nearSlice.Count -gt 0) {
            $evidence.Add("LogSlice mode: fallback near time window ($($nearFrom.ToString('yyyy-MM-dd HH:mm:ss')) .. $($nearTo.ToString('yyyy-MM-dd HH:mm:ss'))).") | Out-Null
            if ($nearSlice.Count -gt $MaxLines) { $nearSlice = New-Object System.Collections.Generic.List[string] (@($nearSlice.ToArray() | Select-Object -Last $MaxLines)) }
            return [pscustomobject]@{
                lines = @($nearSlice.ToArray())
                evidence = @($evidence.ToArray())
                mode = "time_window_fallback_near"
            }
        }

        $evidence.Add("LogSlice mode: fallback tail ($MaxLines lines) after empty check window.") | Out-Null
        $tailAfterWindowMiss = @($allFiltered | Select-Object -Last $MaxLines)
        return [pscustomobject]@{
            lines = @($tailAfterWindowMiss)
            evidence = @($evidence.ToArray())
            mode = "time_window_empty_tail"
        }
    }

    $evidence.Add("LogSlice mode: fallback tail ($MaxLines lines).") | Out-Null
    $tail = @($allFiltered | Select-Object -Last $MaxLines)
    return [pscustomobject]@{
        lines = @($tail)
        evidence = @($evidence.ToArray())
        mode = "tail"
    }
}

function Invoke-LaravelLogRotateIfExists([string]$Root, [string]$PhaseLabel) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $logPath = ""
    try { $logPath = Get-LaravelLogPath $Root } catch { $logPath = "" }

    if (-not $logPath -or ("" + $logPath).Trim() -eq "") {
        $sw.Stop()
        return (New-AuditResult -Id ("log_clear_" + $PhaseLabel) -Title ("Log cleanup (" + $PhaseLabel + ")") -Status "WARN" -Summary "Could not determine laravel.log path." -Details @() -Data @{} -DurationMs ([int]$sw.ElapsedMilliseconds))
    }

    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
        $sw.Stop()
        return (New-AuditResult -Id ("log_clear_" + $PhaseLabel) -Title ("Log cleanup (" + $PhaseLabel + ")") -Status "OK" -Summary "laravel.log not found; nothing to do." -Details @("Path: " + $logPath) -Data @{ path = $logPath; action = "none"; exists = $false } -DurationMs ([int]$sw.ElapsedMilliseconds))
    }

    $ts = ""
    try { $ts = (Get-Date).ToString("yyyyMMdd-HHmmss") } catch { $ts = "unknown" }

    $bakPath = ""
    try { $bakPath = ($logPath + ".bak-" + $ts) } catch { $bakPath = "" }

    try {
        Move-Item -LiteralPath $logPath -Destination $bakPath -Force -ErrorAction Stop | Out-Null

        # Recreate empty laravel.log (UTF-8, no BOM)
        try {
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($logPath, "", $utf8NoBom)
        } catch {
            # Fallback: create empty file
            try { New-Item -ItemType File -Path $logPath -Force | Out-Null } catch { }
        }

        $sw.Stop()
        return (New-AuditResult -Id ("log_clear_" + $PhaseLabel) -Title ("Log cleanup (" + $PhaseLabel + ")") -Status "OK" -Summary "Rotated laravel.log to backup and recreated empty log." -Details @("Path: " + $logPath, "Backup: " + $bakPath) -Data @{ path = $logPath; backup = $bakPath; action = "rotate" } -DurationMs ([int]$sw.ElapsedMilliseconds))
    } catch {
        $msg = ""
        try { $msg = $_.Exception.Message } catch { $msg = "unknown_error" }

        $sw.Stop()
        return (New-AuditResult -Id ("log_clear_" + $PhaseLabel) -Title ("Log cleanup (" + $PhaseLabel + ")") -Status "WARN" -Summary ("Failed to rotate laravel.log: " + $msg) -Details @("Path: " + $logPath, "Backup: " + $bakPath) -Data @{ path = $logPath; backup = $bakPath; action = "failed" } -DurationMs ([int]$sw.ElapsedMilliseconds))
    }
}

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

$effectiveSecurityLockoutKeywords = @("too many attempts","throttle","locked","lockout")
try {
    $kw = @($SecurityLockoutKeywords | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
    if ($kw.Count -gt 0) { $effectiveSecurityLockoutKeywords = @($kw) }
} catch { }

$effectiveShowCheckDetails = Convert-ToBooleanSafe $ShowCheckDetails $true
$effectiveExportLogs = Convert-ToBooleanSafe $ExportLogs $false
$effectiveExportLogsLines = Convert-ToIntSafe $ExportLogsLines 200
if ($effectiveExportLogsLines -lt 1) { $effectiveExportLogsLines = 200 }
$effectiveExportFolder = Resolve-AuditExportFolder -ProjectRoot $projectRoot -FolderValue $ExportFolder
$effectiveAutoOpenExportFolder = Convert-ToBooleanSafe $AutoOpenExportFolder $false
$effectivePerCheckDetailsMap = Convert-PerCheckSettingMap $PerCheckDetails
$effectivePerCheckExportMap = Convert-PerCheckSettingMap $PerCheckExport
$effectiveLogFilePath = Get-LaravelLogPath $projectRoot
$effectiveExportRunStamp = ""
$effectiveExportRunFolder = $effectiveExportFolder
if ($effectiveExportLogs) {
    try { $effectiveExportRunStamp = (Get-Date).ToString("dd-MM-yy HH-mm-ss") } catch { $effectiveExportRunStamp = "" }
    if ($effectiveExportRunStamp -ne "") {
        try { $effectiveExportRunFolder = Join-Path $effectiveExportFolder $effectiveExportRunStamp } catch { $effectiveExportRunFolder = $effectiveExportFolder }
    }
}

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
    SecurityProbe = [bool]$SecurityProbe
    SecurityLoginAttempts = [int]$effectiveSecurityLoginAttempts
    SecurityCheckIpBan = [bool]$SecurityCheckIpBan
    SecurityCheckRegister = [bool]$SecurityCheckRegister
    SecurityExpect429 = [bool]$SecurityExpect429
    SecurityLockoutKeywords = @($effectiveSecurityLockoutKeywords)
    ShowCheckDetails = [bool]$effectiveShowCheckDetails
    ExportLogs = [bool]$effectiveExportLogs
    ExportLogsLines = [int]$effectiveExportLogsLines
    ExportFolder = $effectiveExportFolder
    AutoOpenExportFolder = [bool]$effectiveAutoOpenExportFolder
    Helpers = [pscustomobject]@{
        WriteSection = ${function:Write-Section}
        RunPHPArtisan = ${function:Invoke-PHPArtisan}
        NewAuditResult = ${function:New-AuditResult}
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

if ($missingRequired.Count -gt 0) {
    Write-Section "KiezSingles Admin Audit (CLI Core)"
    Write-Host ("ProjectRoot: " + $projectRoot)
    Write-Host ("BaseUrl:     " + $BaseUrl)
    Write-Host ("HttpProbe:   " + [bool]$HttpProbe)
    Write-Host ("TailLog:     " + [bool]$TailLog)
    Write-Host ("RoutesVerbose: " + [bool]$RoutesVerbose)
    Write-Host ("RouteListFindstrAdmin: " + [bool]$RouteListFindstrAdmin)
    Write-Host ("SuperadminCount: " + [bool]$SuperadminCount)
    Write-Host ("LoginCsrfProbe: " + [bool]$LoginCsrfProbe)
    Write-Host ("RoleSmokeTest: " + [bool]$RoleSmokeTest)
    Write-Host ("SessionCsrfBaseline: " + [bool]$SessionCsrfBaseline)
    Write-Host ("LogSnapshot: " + [bool]$LogSnapshot)
    Write-Host ("LogSnapshotLines: " + $logSnapshotLinesHeader)
    Write-Host ("LogClearBefore: " + [bool]$LogClearBefore)
    Write-Host ("LogClearAfter: " + [bool]$LogClearAfter)
    if ([bool]$LogClearBefore -or [bool]$LogClearAfter) { Write-Host "Hinweis: laravel.log wird rotiert; .bak-* vorhanden" }
    Write-Host ("RouteListOptionScanFullProject: " + [bool]$RouteListOptionScanFullProject)
    Write-Host ("SecurityProbe: " + [bool]$SecurityProbe)
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

$plan.Add({ Invoke-KsAuditCheck_CacheClear -Context $context }) | Out-Null

if (Test-FunctionExists "Invoke-KsAuditCheck_Routes") {
    $plan.Add({ Invoke-KsAuditCheck_Routes -Context $context }) | Out-Null
} else {
    $plan.Add({
        New-AuditResult -Id "missing_check" -Title "1) Routes / collisions / admin scope" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_Routes" -Details @() -Data @{} -DurationMs 0
    }) | Out-Null
}

if (Test-FunctionExists "Invoke-KsAuditCheck_RouteListOptionScan") {
    $plan.Add({ Invoke-KsAuditCheck_RouteListOptionScan -Context $context }) | Out-Null
} else {
    $plan.Add({
        New-AuditResult -Id "missing_check" -Title "1x) route:list option scan (--columns / --format)" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_RouteListOptionScan" -Details @() -Data @{} -DurationMs 0
    }) | Out-Null
}

if ($HttpProbe) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_HttpProbe") {
        $plan.Add({ Invoke-KsAuditCheck_HttpProbe -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "2) HTTP exposure probe" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_HttpProbe" -Details @() -Data @{} -DurationMs 0
        }) | Out-Null
    }
}

if ($LoginCsrfProbe) {
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

if ($SessionCsrfBaseline) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_SessionCsrfBaseline") {
        $plan.Add({ Invoke-KsAuditCheck_SessionCsrfBaseline -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "3a) Session/CSRF baseline (read-only)" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_SessionCsrfBaseline" -Details @() -Data @{} -DurationMs 0
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

if (Test-FunctionExists "Invoke-KsAuditCheck_SecurityAbuseProtection") {
    $plan.Add({ Invoke-KsAuditCheck_SecurityAbuseProtection -Context $context }) | Out-Null
} else {
    $plan.Add({
        New-AuditResult -Id "missing_check" -Title "X) Security / Abuse Protection" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_SecurityAbuseProtection" -Details @() -Data @{} -DurationMs 0
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
Write-Host ("LoginCsrfProbe: " + [bool]$LoginCsrfProbe)
Write-Host ("RoleSmokeTest: " + [bool]$RoleSmokeTest)
Write-Host ("SessionCsrfBaseline: " + [bool]$SessionCsrfBaseline)
Write-Host ("LogSnapshot: " + [bool]$LogSnapshot)
Write-Host ("LogSnapshotLines: " + $logSnapshotLinesHeader)
Write-Host ("LogClearBefore: " + [bool]$LogClearBefore)
Write-Host ("LogClearAfter: " + [bool]$LogClearAfter)
if ([bool]$LogClearBefore -or [bool]$LogClearAfter) { Write-Host "Hinweis: laravel.log wird rotiert; .bak-* vorhanden" }
Write-Host ("RouteListOptionScanFullProject: " + [bool]$RouteListOptionScanFullProject)
Write-Host ("SecurityProbe: " + [bool]$SecurityProbe)
Write-Host ("SecurityLoginAttempts: " + [int]$effectiveSecurityLoginAttempts)
Write-Host ("SecurityCheckIpBan: " + [bool]$SecurityCheckIpBan)
Write-Host ("SecurityCheckRegister: " + [bool]$SecurityCheckRegister)
Write-Host ("SecurityExpect429: " + [bool]$SecurityExpect429)
Write-Host ("SecurityLockoutKeywords: " + (($effectiveSecurityLockoutKeywords | ForEach-Object { "" + $_ }) -join ", "))
Write-Host ("ShowCheckDetails: " + [bool]$effectiveShowCheckDetails)
Write-Host ("ExportLogs: " + [bool]$effectiveExportLogs)
Write-Host ("ExportLogsLines: " + [int]$effectiveExportLogsLines)
Write-Host ("ExportFolder: " + $effectiveExportFolder)
if ($effectiveExportRunFolder -ne $effectiveExportFolder) { Write-Host ("ExportRunFolder: " + $effectiveExportRunFolder) }
Write-Host ("AutoOpenExportFolder: " + [bool]$effectiveAutoOpenExportFolder)
Write-Host ("LogFile: " + $(if ($effectiveLogFilePath -and $effectiveLogFilePath.Trim() -ne "") { $effectiveLogFilePath } else { "(none)" }))
Write-Host ("ChecksSource: " + $checksSourceLabel + " (" + $checksRoot + ")")
Write-AuditDisplayPlan

$results = New-Object System.Collections.Generic.List[object]
$exports = New-Object System.Collections.Generic.List[string]
$maxScore = 0
$visibleTestIndex = 0
$summaryOkCount = 0
$summaryWarnCount = 0
$summaryFailCount = 0
$summaryCriticalCount = 0
$summarySkipCount = 0

if ($effectiveExportLogs) {
    try {
        New-Item -ItemType Directory -Path $effectiveExportRunFolder -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Host ("[WARN] ExportFolder could not be created: " + $effectiveExportRunFolder + " (" + $_.Exception.Message + ")")
    }
}

foreach ($step in $plan) {
    $res = $null
    $checkStartedAt = Get-Date
    $stepDebugName = Get-PlanStepDebugName $step
    $stepDebugSource = ""
    try { $stepDebugSource = ("" + $step).Trim() } catch { $stepDebugSource = "" }
    try {
        $res = & $step
    } catch {
        $exceptionMessage = ""
        $exceptionType = ""
        try { $exceptionMessage = ("" + $_.Exception.Message).Trim() } catch { $exceptionMessage = "unknown_exception" }
        try { $exceptionType = ("" + $_.Exception.GetType().FullName).Trim() } catch { $exceptionType = "unknown_exception_type" }
        $durationMs = 0
        try { $durationMs = [int]((Get-Date) - $checkStartedAt).TotalMilliseconds } catch { $durationMs = 0 }

        $res = New-AuditResult `
            -Id "core_exception" `
            -Title ("Core exception: " + $stepDebugName) `
            -Status "CRITICAL" `
            -Summary ("Unhandled exception while executing step '" + $stepDebugName + "': " + $exceptionMessage) `
            -Details @(
                "Step: " + $stepDebugName,
                "Exception type: " + $exceptionType,
                "Message: " + $exceptionMessage,
                "Step source: " + $stepDebugSource
            ) `
            -Data @{
                step = $stepDebugName
                step_source = $stepDebugSource
                exception_type = $exceptionType
                exception = $exceptionMessage
            } `
            -DurationMs $durationMs
    }
    $checkFinishedAt = Get-Date

    if ($null -ne $res) {
        $checkId = ""
        try { $checkId = ("" + $res.id).Trim().ToLowerInvariant() } catch { $checkId = "" }
        $detailsEnabledForThisCheck = [bool]$effectiveShowCheckDetails
        $exportEnabledForThisCheck = ([bool]$effectiveExportLogs -and (-not (Test-IsNullRunResult $res)))

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
                    $checkNameSource = ""
                    try { $checkNameSource = ("" + $res.title).Trim() } catch { $checkNameSource = "" }
                    if ($checkNameSource -eq "") {
                        try { $checkNameSource = ("" + $res.id).Trim() } catch { $checkNameSource = "check" }
                    }
                    # Remove common numbering prefixes like "1) ", "2a) ", "X) ".
                    $checkNameSource = ($checkNameSource -replace '^(?i:\s*[0-9x]+[a-z]?\)\s*)', '')
                    $checkName = Convert-ToSafeFileSegment $checkNameSource
                    $exportName = ("security-abuse_{0}.log" -f $checkName)
                    $exportPath = Join-Path $effectiveExportRunFolder $exportName
                    $exportLines = @()
                    try { $exportLines = @(Build-CheckExportLines -Res $res) } catch { $exportLines = @() }
                    if ($exportLines.Count -le 0) {
                        $exportLines = @(
                            "Check: " + ("" + $res.id),
                            "Title: " + ("" + $res.title),
                            "Status: " + ("" + $res.status),
                            "Summary: " + ("" + $res.summary),
                            "",
                            "LogSlice: none"
                        )
                    }
                    [System.IO.File]::WriteAllLines($exportPath, @($exportLines), [System.Text.UTF8Encoding]::new($false))
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

        switch (("" + $res.status).Trim().ToUpperInvariant()) {
            "OK" { $summaryOkCount++ }
            "WARN" { $summaryWarnCount++ }
            "FAIL" { $summaryFailCount++ }
            "CRITICAL" { $summaryCriticalCount++ }
        }
        try {
            $summaryText = ("" + $res.summary).Trim()
            if ($summaryText -match '^(?i:Skipped:)') { $summarySkipCount++ }
        } catch { }

        Write-Host ""
        $statusTag = Format-StatusTag $res.status
        $visibleTitle = Get-CompactAuditTitle $res
        $statusLine = ""
        if (Test-IsNullRunResult $res) {
            $statusLine = ("{0,-10} Null-Lauf - {1}" -f $statusTag, $visibleTitle)
        } else {
            $visibleTestIndex++
            $statusLine = ("{0,-10} Test {1} - {2}" -f $statusTag, $visibleTestIndex, $visibleTitle)
        }
        Write-Host $statusLine

        $shouldPrintDetailsForThisCheck = ($detailsEnabledForThisCheck -or (("" + $res.status).Trim().ToUpperInvariant() -ne "OK"))
        if ($shouldPrintDetailsForThisCheck) {
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
Write-Host ""
Write-Host "Audit Summary"
Write-Host "-------------"
Write-Host ("OK:   " + $summaryOkCount)
Write-Host ("WARN: " + $summaryWarnCount)
Write-Host ("FAIL: " + $summaryFailCount)
Write-Host ("CRITICAL: " + $summaryCriticalCount)
Write-Host ("SKIP: " + $summarySkipCount)

if ($exports.Count -gt 0) {
    Write-Section "Exports"
    foreach ($p in @($exports.ToArray())) {
        Write-Host ("Datei: " + $p)
    }

    if ($effectiveAutoOpenExportFolder) {
        try {
            Start-Process explorer.exe $effectiveExportRunFolder | Out-Null
            Write-Host ("Explorer: opened " + $effectiveExportRunFolder)
        } catch {
            Write-Host ("[WARN] Could not open export folder: " + $_.Exception.Message)
        }
    }
}

return (Stop-Program $exitCode)
