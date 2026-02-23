# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit.ps1
# Purpose: Deterministic CLI core for KiezSingles Admin Audit (no GUI)
# Created: 21-02-2026 00:29 (Europe/Berlin)
# Changed: 23-02-2026 03:40 (Europe/Berlin)
# Version: 3.1
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

    # If set, appends Laravel log snapshot (tail) to output
    [switch]$LogSnapshot,

    # If set, clears/rotates laravel.log BEFORE the audit (only if file exists).
    [switch]$LogClearBefore,

    # If set, clears/rotates laravel.log AFTER the audit (only if file exists).
    [switch]$LogClearAfter,

    # If set, scans the full project for route:list invocations using --columns/--format
    # (still excludes tools/audit/* and large dirs like vendor/node_modules/storage/bootstrap/cache)
    [switch]$RouteListOptionScanFullProject,

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
        "-LogSnapshot" { return $true }
        "-LogClearBefore" { return $true }
        "-LogClearAfter" { return $true }
        "-RouteListOptionScanFullProject" { return $true }
        "-NoExit" { return $true }
        default { return $false }
    }
}

function Test-KnownValueParam([string]$name) {
    switch ($name) {
        "-BaseUrl" { return $true }
        "-ProbePaths" { return $true }
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

    $recBaseUrl = "http://127.0.0.1:8000"
    $recProbePaths = New-Object System.Collections.Generic.List[string]
    $recHttpProbe = $false
    $recTailLog = $false
    $recRoutesVerbose = $false
    $recRouteListFindstrAdmin = $false
    $recSuperadminCount = $false
    $recLogSnapshot = $false
    $recLogClearBefore = $false
    $recLogClearAfter = $false
    $recRouteListOptionScanFullProject = $false
    $recNoExit = $false
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
                $i++
                continue
            }

            if (($i + 1) -lt $tokens.Count) {
                $recBaseUrl = ("" + $tokens[$i + 1]).Trim()
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

        if (Test-KnownSwitch $name) {
            switch ($name) {
                "-HttpProbe" { $recHttpProbe = $true }
                "-TailLog" { $recTailLog = $true }
                "-RoutesVerbose" { $recRoutesVerbose = $true }
                "-RouteListFindstrAdmin" { $recRouteListFindstrAdmin = $true }
                "-SuperadminCount" { $recSuperadminCount = $true }
                "-LogSnapshot" { $recLogSnapshot = $true }
                "-LogClearBefore" { $recLogClearBefore = $true }
                "-LogClearAfter" { $recLogClearAfter = $true }
                "-RouteListOptionScanFullProject" { $recRouteListOptionScanFullProject = $true }
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

    if ($recBaseUrl -and ($recBaseUrl.Trim() -ne "") -and ($recBaseUrl.Trim() -notmatch '^-')) {
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
    if ($recLogSnapshot) { $LogSnapshot = $true }
    if ($recLogClearBefore) { $LogClearBefore = $true }
    if ($recLogClearAfter) { $LogClearAfter = $true }
    if ($recRouteListOptionScanFullProject) { $RouteListOptionScanFullProject = $true }
    if ($recNoExit) { $NoExit = $true }

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

    if ($null -eq $Value) {
        return @()
    }

    $vals = @()
    try { $vals = @($Value) } catch { $vals = @() }

    foreach ($v in $vals) {
        if ($null -eq $v) { continue }
        $s = ("" + $v).Trim()
        if ($s -eq "") { continue }

        if ($s -match '\s') {
            ($s -split '\s+') | ForEach-Object {
                $x = ("" + $_).Trim()
                if ($x -ne "") { $out.Add($x) | Out-Null }
            }
            continue
        }

        if ($s -match ',') {
            ($s -split ',') | ForEach-Object {
                $x = ("" + $_).Trim()
                if ($x -ne "") { $out.Add($x) | Out-Null }
            }
            continue
        }

        $out.Add($s) | Out-Null
    }

    return @($out.ToArray())
}

$ProbePaths = ConvertTo-NormalizedProbePaths $ProbePaths

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
        [int]$DurationMs = 0
    )

    return [pscustomobject]@{
        id = $Id
        title = $Title
        status = $Status
        summary = $Summary
        details = @($Details)
        data = $Data
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
        return (Join-Path $Root "storage\logs\laravel.log")
    } catch {
        return ""
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
    -and (-not [bool]$LogSnapshot)

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
    ExpectedUnauthedHttpCodes = @(302, 401, 403)
    HttpTimeoutSec = 12
    TailLogMode = $tailMode
    AuditStartedAt = $auditStartedAt
    RouteListOptionScanFullProject = [bool]$RouteListOptionScanFullProject
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
    Write-Host ("LogSnapshot: " + [bool]$LogSnapshot)
    Write-Host ("LogClearBefore: " + [bool]$LogClearBefore)
    Write-Host ("LogClearAfter: " + [bool]$LogClearAfter)
    Write-Host ("RouteListOptionScanFullProject: " + [bool]$RouteListOptionScanFullProject)
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

if ($SuperadminCount) {
    if (Test-FunctionExists "Invoke-KsAuditCheck_GovernanceSuperadmin") {
        $plan.Add({ Invoke-KsAuditCheck_GovernanceSuperadmin -Context $context }) | Out-Null
    } else {
        $plan.Add({
            New-AuditResult -Id "missing_check" -Title "3) Governance: superadmin fail-safe (deterministic)" -Status "WARN" -Summary "Check module not loaded: Invoke-KsAuditCheck_GovernanceSuperadmin" -Details @() -Data @{} -DurationMs 0
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
Write-Host ("LogSnapshot: " + [bool]$LogSnapshot)
Write-Host ("LogClearBefore: " + [bool]$LogClearBefore)
Write-Host ("LogClearAfter: " + [bool]$LogClearAfter)
Write-Host ("RouteListOptionScanFullProject: " + [bool]$RouteListOptionScanFullProject)
Write-Host ("ChecksSource: " + $checksSourceLabel + " (" + $checksRoot + ")")

$results = New-Object System.Collections.Generic.List[object]
$maxScore = 0

foreach ($step in $plan) {
    $res = $null
    try {
        $res = & $step
    } catch {
        $res = New-AuditResult -Id "core_exception" -Title "Core exception" -Status "CRITICAL" -Summary $_.Exception.Message -Details @() -Data @{} -DurationMs 0
    }

    if ($null -ne $res) {
        $results.Add($res) | Out-Null
        $score = Get-ResultScore $res
        if ($score -gt $maxScore) { $maxScore = $score }

        Write-Host ""
        Write-Host ((Format-StatusTag $res.status) + " " + $res.title + " - " + $res.summary + " (" + $res.duration_ms + "ms)")

        $detailsToPrint = Get-DetailsForOutput $res
        $detailsToPrintArr = ConvertTo-SafeStringArray $detailsToPrint
        if ((Get-SafeCount $detailsToPrintArr) -gt 0) {
            Write-Host ""
            foreach ($d in $detailsToPrintArr) { Write-Host $d }
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

return (Stop-Program $exitCode)