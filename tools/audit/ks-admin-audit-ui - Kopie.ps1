# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit-ui.ps1
# Purpose: Repeatable admin/backend audit (routes, duplicates, inline HTML/Blade, role checks, DB sanity, optional HTTP traces)
# Created: 19-02-2026 17:25 (Europe/Berlin)
# Changed: 20-02-2026 21:53 (Europe/Berlin)
# Version: 3.2
# =============================================================================

[CmdletBinding()]
param(
    # Base URL for optional HTTP checks
    [string]$BaseUrl = "http://127.0.0.1:8000",

    # Admin endpoints to probe (relative to BaseUrl) - only used if -HttpProbe is set
    [string[]]$ProbePaths = @("/admin", "/admin/status", "/admin/moderation", "/admin/maintenance", "/admin/debug"),

    # If set, performs HTTP probe checks (redirect chain + headers)
    [switch]$HttpProbe,

    # If set, tails laravel.log (CTRL+C to stop) (GUI mode: appends tail after audit)
    [switch]$TailLog,

    # If set, runs additional verbose admin route listing (-vv) to show more details like middleware.
    [switch]$RoutesVerbose,

    # If set, runs full route:list and filters lines containing "admin" (similar to `php artisan route:list | findstr admin`).
    [switch]$RouteListFindstrAdmin,

    # If set, attempts a non-interactive "superadmin count" check via tinker --execute (best effort).
    [switch]$SuperadminCount,

    # If set, writes the whole audit output to clipboard at the end (requires transcript).
    # NOTE: Console mode only. In GUI use the "Copy Output" button.
    [switch]$CopyToClipboard,

    # If set, shows a "press C to copy to clipboard" prompt at the end (requires transcript).
    # NOTE: Console mode only. In GUI use the "Copy Output" button.
    [switch]$ClipboardPrompt,

    # GUI toggle (robust: accept weird runner argument tokens without crashing)
    [object]$Gui,

    # INTERNAL: used by GUI runner to execute the audit in a child process without opening GUI again
    [switch]$RunAuditInternal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-Boolish([object]$v, [bool]$defaultValue) {
    if ($null -eq $v) { return $defaultValue }

    try {
        if ($v -is [System.Management.Automation.SwitchParameter]) { return [bool]$v }
    } catch { }

    if ($v -is [bool]) { return $v }
    if ($v -is [int]) { return ([bool]$v) }

    if ($v -is [string]) {
        $s = $v.Trim()
        if ($s -eq "") { return $defaultValue }
        if ($s -match '^(?i:true|\$true|1|yes|y|on)$') { return $true }
        if ($s -match '^(?i:false|\$false|0|no|n|off)$') { return $false }

        # Some runners pass "System.String" or other tokens to the parameter position.
        # Fail-open (treat as true) instead of crashing the whole tool.
        return $true
    }

    # Unknown type -> best effort
    try { return [bool]$v } catch { return $defaultValue }
}

# Default behavior: ALWAYS open UI unless explicitly disabled (-Gui:$false).
$guiEnabled = $true
if ($PSBoundParameters.ContainsKey('Gui')) {
    $guiEnabled = ConvertTo-Boolish -v $Gui -defaultValue $true
} else {
    $guiEnabled = $true
}

function Quote-Arg([string]$s) {
    if ($null -eq $s) { return '""' }
    $t = ("" + $s) -replace '"', '""'
    return ('"' + $t + '"')
}

function Get-ScriptPath() {
    if ($PSCommandPath -and ($PSCommandPath.Trim() -ne "")) { return $PSCommandPath }
    if ($MyInvocation -and $MyInvocation.MyCommand -and ($MyInvocation.MyCommand | Get-Member -Name Path -ErrorAction SilentlyContinue)) {
        try { return $MyInvocation.MyCommand.Path } catch { }
    }
    return (Join-Path (Get-Location) "ks-admin-audit-ui.ps1")
}

function Resolve-ProjectRootFromScript([string]$scriptPath) {
    $dir = Split-Path -Parent $scriptPath
    # tools\audit -> project root = ..\..
    $root = Resolve-Path (Join-Path $dir "..\..") | Select-Object -ExpandProperty Path
    return $root
}

function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 78)
    Write-Host $Title
    Write-Host ("=" * 78)
}

function Require-ProjectRoot([string]$Root) {
    $artisan = Join-Path $Root "artisan"
    if (!(Test-Path $artisan)) {
        throw "Project root not detected. Expected artisan at: $artisan"
    }
}

function Run-ProcessToFiles(
    [string]$File,
    [string[]]$ArgumentList,
    [int]$TimeoutSeconds = 120,
    [string]$WorkingDirectory = ""
) {
    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()
    $tmpIn  = [System.IO.Path]::GetTempFileName()

    try {
        if ($null -eq $ArgumentList) { $ArgumentList = @() }
        $ArgumentList = @($ArgumentList | Where-Object { $_ -ne $null })

        try { Set-Content -LiteralPath $tmpIn -Value "" -NoNewline -Encoding ASCII } catch { }

        $sp = @{
            FilePath               = $File
            NoNewWindow            = $true
            PassThru               = $true
            RedirectStandardInput  = $tmpIn
            RedirectStandardOutput = $tmpOut
            RedirectStandardError  = $tmpErr
        }

        if ($WorkingDirectory -and ($WorkingDirectory.Trim() -ne "")) {
            $sp.WorkingDirectory = $WorkingDirectory
        }

        if ($ArgumentList.Count -gt 0) {
            $sp.ArgumentList = $ArgumentList
        }

        $p = Start-Process @sp
        $exited = $p.WaitForExit($TimeoutSeconds * 1000)

        if (-not $exited) {
            try { $p.Kill($true) } catch { }

            $outTxt = ""
            $errTxt = ""
            try { $outTxt = Get-Content -LiteralPath $tmpOut -Raw -ErrorAction SilentlyContinue } catch { }
            try { $errTxt = Get-Content -LiteralPath $tmpErr -Raw -ErrorAction SilentlyContinue } catch { }

            $argString = ($ArgumentList -join " ")
            return [pscustomobject]@{
                ExitCode = -1
                StdOut   = $outTxt
                StdErr   = ("TIMEOUT after {0}s while running: {1} {2}" -f $TimeoutSeconds, $File, $argString) + "`n" + $errTxt
            }
        }

        $stdout = ""
        $stderr = ""
        try { $stdout = Get-Content -LiteralPath $tmpOut -Raw -ErrorAction SilentlyContinue } catch { $stdout = "" }
        try { $stderr = Get-Content -LiteralPath $tmpErr -Raw -ErrorAction SilentlyContinue } catch { $stderr = "" }

        $exitCode = 0
        try { $exitCode = $p.ExitCode } catch { $exitCode = 0 }
        if ($null -eq $exitCode) { $exitCode = 0 }

        return [pscustomobject]@{
            ExitCode = [int]$exitCode
            StdOut   = $stdout
            StdErr   = $stderr
        }
    }
    finally {
        try { Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue } catch { }
        try { Remove-Item -LiteralPath $tmpErr -Force -ErrorAction SilentlyContinue } catch { }
        try { Remove-Item -LiteralPath $tmpIn  -Force -ErrorAction SilentlyContinue } catch { }
    }
}

function Run-PHPArtisan([string]$Root, [string[]]$ArgumentList, [int]$TimeoutSeconds = 120) {
    $php = "php"
    $artisan = Join-Path $Root "artisan"

    if ($null -eq $ArgumentList) { $ArgumentList = @() }

    $cmdArgs = @()
    $cmdArgs += $artisan
    $cmdArgs += $ArgumentList
    $cmdArgs = @($cmdArgs | Where-Object { $_ -ne $null })

    return Run-ProcessToFiles -File $php -ArgumentList $cmdArgs -TimeoutSeconds $TimeoutSeconds -WorkingDirectory $Root
}

function Print-TableIfAny($Grouped, [string]$Label) {
    if ($null -eq $Grouped) { return }
    $items = $Grouped | Where-Object { $_.Count -gt 1 }
    if ($items) {
        Write-Host ""
        Write-Host $Label
        $items | Sort-Object Count -Descending | Format-Table Count, Name -AutoSize
    } else {
        Write-Host ""
        Write-Host $Label
        Write-Host "(none)"
    }
}

function Write-StdStreams($procResult) {
    if ($null -eq $procResult) { return }

    if ($procResult.StdErr -and ($procResult.StdErr.Trim() -ne "")) {
        $filtered = ($procResult.StdErr -split "`r?`n") | Where-Object { $_ -and ($_ -notmatch '^\[KS_ADMIN_ROUTES\]') }
        $filteredTxt = ($filtered -join "`n").Trim()
        if ($filteredTxt -ne "") {
            Write-Host ""
            Write-Host "--- STDERR ---"
            Write-Host $filteredTxt
        }
    }

    if ($procResult.StdOut -and ($procResult.StdOut.Trim() -ne "")) {
        Write-Host ""
        Write-Host "--- STDOUT ---"
        Write-Host $procResult.StdOut
    }
}

function Is-Completed($procResult) {
    if ($null -eq $procResult) { return $false }

    try { if ([int]$procResult.ExitCode -eq -1) { return $false } } catch { }

    $out = ""
    try { $out = ("" + $procResult.StdOut).Trim() } catch { $out = "" }

    try { if ([int]$procResult.ExitCode -eq 0) { return $true } } catch { }

    return ($out -ne "")
}

function Append-LaravelLogTail([string]$root, [int]$tailLines = 200) {
    if (-not $root -or ($root.Trim() -eq "")) { return "" }

    $logPath = Join-Path $root "storage\logs\laravel.log"
    if (!(Test-Path $logPath)) {
        return ("`r`n`r`n=== Laravel Log Tail ===`r`nlaravel.log not found at: " + $logPath + "`r`n")
    }

    try {
        $lines = Get-Content -LiteralPath $logPath -Tail $tailLines -ErrorAction Stop
        $txtTail = ($lines -join "`r`n")
        return ("`r`n`r`n=== Laravel Log Tail (last " + $tailLines + " lines) ===`r`n" + $txtTail + "`r`n")
    } catch {
        return ("`r`n`r`n=== Laravel Log Tail ===`r`nFailed to read log: " + $_.Exception.Message + "`r`n")
    }
}

function Normalize-ProbePaths([string[]]$paths) {
    if ($null -eq $paths) { return @() }
    $flat = @()

    foreach ($x in $paths) {
        if ($null -eq $x) { continue }
        $s = ("" + $x).Trim()
        if ($s -eq "") { continue }

        # If cmdline passed a single token like: "/admin","/admin/status"
        if ($s -match ',') {
            $parts = $s -split ','
            foreach ($p in $parts) {
                $t = ("" + $p).Trim()
                if ($t -eq "") { continue }

                # Strip surrounding quotes if present
                if (($t.StartsWith('"') -and $t.EndsWith('"')) -or ($t.StartsWith("'") -and $t.EndsWith("'"))) {
                    if ($t.Length -ge 2) { $t = $t.Substring(1, $t.Length - 2).Trim() }
                }

                if ($t -ne "") { $flat += $t }
            }
            continue
        }

        # Strip surrounding quotes if present
        if (($s.StartsWith('"') -and $s.EndsWith('"')) -or ($s.StartsWith("'") -and $s.EndsWith("'"))) {
            if ($s.Length -ge 2) { $s = $s.Substring(1, $s.Length - 2).Trim() }
        }

        if ($s -ne "") { $flat += $s }
    }

    return @($flat)
}

# Fail-safe normalization (helps with comma-separated cmdline tokens)
$ProbePaths = Normalize-ProbePaths $ProbePaths

function Invoke-AuditConsole([string]$projectRoot) {
    Require-ProjectRoot $projectRoot
    Set-Location $projectRoot

    # --- Root cache clear (Laravel caches) before running the audit, to avoid stale artifacts.
    Write-Section "0) Clear Laravel caches (php artisan optimize:clear)"
    try {
        $c = Run-PHPArtisan $projectRoot @("optimize:clear", "--no-ansi", "--no-interaction") 120
        Write-StdStreams $c
    } catch {
        Write-Host ""
        Write-Host ("Cache clear failed (continuing): " + $_.Exception.Message)
    }

    # --- Optional transcript for clipboard copy (CONSOLE MODE ONLY)
    $transcriptPath = $null
    $transcriptEnabled = $false
    if ($CopyToClipboard -or $ClipboardPrompt) {
        try {
            $ts = Get-Date -Format "yyyyMMdd-HHmmss"
            $transcriptPath = Join-Path $env:TEMP ("ks-admin-audit-" + $ts + ".log")
            Start-Transcript -Path $transcriptPath -Force | Out-Null
            $transcriptEnabled = $true
        } catch {
            $transcriptEnabled = $false
            $transcriptPath = $null
        }
    }

    Write-Section "KiezSingles Admin Audit (routes + patterns + DB sanity)"

    Write-Host "ProjectRoot: $projectRoot"
    Write-Host "BaseUrl:     $BaseUrl"
    Write-Host "HttpProbe:   $HttpProbe"
    Write-Host "TailLog:     $TailLog"
    Write-Host "RoutesVerbose: $RoutesVerbose"
    Write-Host "RouteListFindstrAdmin: $RouteListFindstrAdmin"
    Write-Host "SuperadminCount: $SuperadminCount"
    Write-Host "CopyToClipboard: $CopyToClipboard"
    Write-Host "ClipboardPrompt: $ClipboardPrompt"
    if ($transcriptEnabled -and $transcriptPath) {
        Write-Host "Transcript:  $transcriptPath"
    } elseif ($CopyToClipboard -or $ClipboardPrompt) {
        Write-Host "Transcript:  (failed to start transcript; clipboard feature unavailable)"
    }

    # -----------------------------------------------------------------------------
    # 1) Find admin-related route patterns in routes/*.php
    # -----------------------------------------------------------------------------
    Write-Section "1) Find admin route patterns in routes/*.php"

    Get-ChildItem -Recurse -Path .\routes -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern "Route::prefix\(\s*'admin'\s*\)|Route::get\(\s*'/admin|Route::post\(\s*'/admin|'/admin/" |
        ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } |
        ForEach-Object { Write-Host $_ }

    # -----------------------------------------------------------------------------
    # 1a) Hardcoded '/admin' in routes (single-quote)
    # -----------------------------------------------------------------------------
    Write-Section "1a) Hardcoded '/admin' in routes (single-quote)  [toolbox #2]"

    Get-ChildItem .\routes -Recurse -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern "'/admin" |
        ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } |
        ForEach-Object { Write-Host $_ }

    # -----------------------------------------------------------------------------
    # 1b) Hardcoded "/admin" in routes (double-quote)
    # -----------------------------------------------------------------------------
    Write-Section "1b) Hardcoded ""/admin"" in routes (double-quote)  [toolbox #2]"

    Get-ChildItem .\routes -Recurse -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern '"/admin' |
        ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } |
        ForEach-Object { Write-Host $_ }

    # -----------------------------------------------------------------------------
    # 1c) Hardcoded /admin in app (any quote / plain string)  [toolbox #2 optional]
    # -----------------------------------------------------------------------------
    Write-Section "1c) Hardcoded /admin in app  [toolbox #2 optional]"

    Get-ChildItem .\app -Recurse -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern "/admin" |
        ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } |
        ForEach-Object { Write-Host $_ }

    # -----------------------------------------------------------------------------
    # 2) Route list (admin path) + duplicate route names / duplicate URIs
    # -----------------------------------------------------------------------------
    Write-Section "2) php artisan route:list --path=admin (raw output)"

    $r = Run-PHPArtisan $projectRoot @("route:list", "--path=admin", "--no-ansi", "--no-interaction") 60
    Write-StdStreams $r

    $routeListCompleted = Is-Completed $r

    # -----------------------------------------------------------------------------
    # 2v) Verbose admin route list (-vv) to surface middleware details  [toolbox #1]
    # -----------------------------------------------------------------------------
    if ($RoutesVerbose) {
        Write-Section "2v) php artisan route:list --path=admin -vv (verbose; middleware/details)  [toolbox #1]"

        $rv = Run-PHPArtisan $projectRoot @("route:list", "--path=admin", "-vv", "--no-ansi", "--no-interaction") 120
        Write-StdStreams $rv
    }

    Write-Section "2a) Duplicate admin route names (from route:list output)"

    if ($routeListCompleted) {
        $txt2a = ("" + $r.StdOut)
        $names = ($txt2a -split "`n") | ForEach-Object {
            $line = ($_ -replace "\s+", " ").Trim()
            if ($line -match "\s(admin\.[A-Za-z0-9\._-]+)\s") { $Matches[1] }
        } | Where-Object { $_ }

        $grouped = $names | Group-Object
        Print-TableIfAny $grouped "Duplicate Names:"
    } else {
        Write-Host "(skipped - route:list did not complete)"
    }

    Write-Section "2b) Duplicate admin URIs (from route:list output)"

    if ($routeListCompleted) {
        $txt2b = ("" + $r.StdOut)
        $uris = ($txt2b -split "`n") | ForEach-Object {
            $line = ($_ -replace "\s+", " ").Trim()
            if ($line -match "^(GET\|HEAD|POST|PUT|PATCH|DELETE)\s+(admin[^\s]*)\s") { $Matches[2] }
        } | Where-Object { $_ }

        $grouped = $uris | Group-Object
        Print-TableIfAny $grouped "Duplicate URIs:"
    } else {
        Write-Host "(skipped - route:list did not complete)"
    }

    # -----------------------------------------------------------------------------
    # 3) Duplicate route names via static scan of routes/*.php (->name('admin.*'))
    # -----------------------------------------------------------------------------
    Write-Section "3) Duplicate admin.* names via static scan (routes/*.php)"

    $matches = Get-ChildItem -Recurse -Path .\routes -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern "->name\(\s*'admin\.[^']+'\s*\)"

    $namesStatic = $matches | ForEach-Object {
        if ($_.Line -match "->name\(\s*'(?<n>admin\.[^']+)'\s*\)") { $Matches.n }
    } | Where-Object { $_ }

    $groupedStatic = $namesStatic | Group-Object
    Print-TableIfAny $groupedStatic "Duplicate Names (static scan):"

    # -----------------------------------------------------------------------------
    # 3a) Role usage scan in app (role)  [toolbox #3]
    # -----------------------------------------------------------------------------
    Write-Section "3a) Scan app for role usage (""role"")  [toolbox #3]"

    Get-ChildItem .\app -Recurse -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern "role" |
        ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } |
        ForEach-Object { Write-Host $_ }

    # -----------------------------------------------------------------------------
    # 3b) Role usage scan in app (superadmin)  [toolbox #3]
    # -----------------------------------------------------------------------------
    Write-Section "3b) Scan app for ""superadmin"" occurrences  [toolbox #3]"

    Get-ChildItem .\app -Recurse -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern "superadmin" |
        ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } |
        ForEach-Object { Write-Host $_ }

    # -----------------------------------------------------------------------------
    # 3c) Role usage scan in routes (role)  [toolbox #3]
    # -----------------------------------------------------------------------------
    Write-Section "3c) Scan routes for role usage (""role"")  [toolbox #3]"

    Get-ChildItem .\routes -Recurse -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern "role" |
        ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } |
        ForEach-Object { Write-Host $_ }

    # -----------------------------------------------------------------------------
    # 4) Scan for inline HTML / Blade::render patterns in route files
    # -----------------------------------------------------------------------------
    Write-Section "4) Scan routes for inline HTML / Blade::render / heredoc patterns"

    Get-ChildItem .\routes -Recurse -File -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern 'Blade::render','<<<\s*[''"]?BLADE[''"]?','<!doctype\s+html','<html\b','<head\b','<body\b','return\s+response\(' -AllMatches |
        Select-Object Path, LineNumber, Line |
        Format-Table -AutoSize

    # -----------------------------------------------------------------------------
    # 4a) Section middleware usage scan (section:)  [toolbox #4]
    # -----------------------------------------------------------------------------
    Write-Section "4a) Scan routes for section middleware (""section:"")  [toolbox #4]"

    Get-ChildItem .\routes -Recurse -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern "section:" |
        ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } |
        ForEach-Object { Write-Host $_ }

    # -----------------------------------------------------------------------------
    # 5) Scan admin route files for role checks / abort_unless / role usage
    # -----------------------------------------------------------------------------
    Write-Section "5) Scan routes/web/admin for role checks / abort_unless patterns"

    Get-ChildItem .\routes\web\admin -Recurse -File -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern 'auth\(\)\-\>user\(\)\-\>role','\-\>role\b','isAdminRole','isStaffRole','isStaffLike','abort_unless\(.+role' |
        Select-Object Path, LineNumber, Line |
        Format-Table -AutoSize

    # -----------------------------------------------------------------------------
    # 5a) Admin prefix occurrences (Route::prefix('admin'))  [toolbox #5]
    # -----------------------------------------------------------------------------
    Write-Section "5a) Scan routes for Route::prefix('admin') occurrences  [toolbox #5]"

    $adminPrefixHits = Get-ChildItem .\routes -Recurse -Filter *.php -ErrorAction SilentlyContinue |
        Select-String -Pattern "Route::prefix\(\s*'admin'\s*\)"

    if ($adminPrefixHits) {
        $adminPrefixHits | ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } | ForEach-Object { Write-Host $_ }

        Write-Host ""
        Write-Host ("Total occurrences: " + ($adminPrefixHits | Measure-Object | Select-Object -ExpandProperty Count))
    } else {
        Write-Host "(none)"
    }

    # -----------------------------------------------------------------------------
    # 6) DB sanity checks (non-interactive artisan command; no tinker/psysh)
    # -----------------------------------------------------------------------------
    Write-Section "6) DB sanity via ks:audit:db (non-interactive)"

    $db = Run-PHPArtisan $projectRoot @("ks:audit:db", "--no-ansi", "--no-interaction") 60
    Write-StdStreams $db

    $dbCompleted = Is-Completed $db

    if (-not $dbCompleted) {
        Write-Host ""
        Write-Host "DB audit did not complete (no output)."
    } else {
        $ec = 0
        try { $ec = [int]$db.ExitCode } catch { $ec = 0 }
        if ($ec -ne 0) {
            Write-Host ""
            Write-Host "DB audit returned non-zero exit code: $ec"
        }
    }

    # -----------------------------------------------------------------------------
    # 6a) Full route list filtered by "admin" (findstr-like)  [toolbox #6]
    # -----------------------------------------------------------------------------
    if ($RouteListFindstrAdmin) {
        Write-Section "6a) php artisan route:list | findstr admin (PowerShell filter)  [toolbox #6]"

        $rf = Run-PHPArtisan $projectRoot @("route:list", "--no-ansi", "--no-interaction") 120
        if (Is-Completed $rf) {
            $lines = ("" + $rf.StdOut) -split "`r?`n"
            $lines | Select-String -Pattern "admin" | ForEach-Object { $_.Line } | ForEach-Object { Write-Host $_ }
        } else {
            Write-StdStreams $rf
            Write-Host "(skipped - route:list did not complete)"
        }
    }

    # -----------------------------------------------------------------------------
    # 6b) Superadmin count (best effort, non-interactive)  [toolbox #7]
    # -----------------------------------------------------------------------------
    if ($SuperadminCount) {
        Write-Section "6b) Superadmin count via tinker --execute (best effort)  [toolbox #7]"

        $t = Run-PHPArtisan $projectRoot @(
            "tinker",
            "--execute=\App\Models\User::where('role','superadmin')->count();",
            "--no-ansi",
            "--no-interaction"
        ) 60

        if (Is-Completed $t) {
            Write-StdStreams $t
        } else {
            Write-StdStreams $t
            Write-Host ""
            Write-Host "Superadmin count could not be executed non-interactively in this environment."
            Write-Host "Manual fallback:"
            Write-Host "  php artisan tinker"
            Write-Host "  \App\Models\User::where('role', 'superadmin')->count();"
        }
    }

    # -----------------------------------------------------------------------------
    # 7) Optional HTTP probe (redirect chains + interesting headers)
    # -----------------------------------------------------------------------------
    if ($HttpProbe) {
        Write-Section "7) HTTP probe (redirects + headers)"

        foreach ($p in $ProbePaths) {
            $u = ($BaseUrl.TrimEnd('/') + $p)

            Write-Host ""
            Write-Host ("--- " + $u + " ---")

            try {
                $r0 = Invoke-WebRequest $u -UseBasicParsing -MaximumRedirection 0
                Write-Host ("Status: " + $r0.StatusCode)
                Write-Host ("Location: " + $r0.Headers.Location)
                Write-Host ("Set-Cookie: " + $r0.Headers.'Set-Cookie')
                Write-Host ("X-KS-Role: " + $r0.Headers.'X-KS-Role')
                Write-Host ("X-KS-Section: " + $r0.Headers.'X-KS-Section')
            } catch {
                $resp = $_.Exception.Response
                if ($resp) {
                    Write-Host ("Status: " + [int]$resp.StatusCode)
                    Write-Host ("Location: " + $resp.Headers['Location'])
                    Write-Host ("Set-Cookie: " + $resp.Headers['Set-Cookie'])
                    Write-Host ("X-KS-Role: " + $resp.Headers['X-KS-Role'])
                    Write-Host ("X-KS-Section: " + $resp.Headers['X-KS-Section'])
                } else {
                    Write-Host $_.Exception.Message
                }
            }

            try {
                $r1 = Invoke-WebRequest $u -UseBasicParsing -MaximumRedirection 20
                Write-Host ("FinalStatus: " + $r1.StatusCode)
                Write-Host ("FinalUri: " + $r1.BaseResponse.ResponseUri.AbsoluteUri)
            } catch {
                $resp = $_.Exception.Response
                if ($resp) {
                    Write-Host ("FinalStatus: " + [int]$resp.StatusCode)
                } else {
                    Write-Host $_.Exception.Message
                }
            }
        }

        Write-Host ""
        Write-Host "Hint: for full verbose redirect chain, run:"
        Write-Host ("  curl.exe -v -L --max-redirs 20 """ + ($BaseUrl.TrimEnd('/') + "/admin") + """")
    }

    Write-Section "Audit completed"
    Write-Host "Done."

    # -----------------------------------------------------------------------------
    # 9) Optional clipboard actions (requires transcript) - CONSOLE MODE ONLY
    # -----------------------------------------------------------------------------
    if ($transcriptEnabled) {
        try { Stop-Transcript | Out-Null } catch { }

        if ($transcriptPath -and (Test-Path $transcriptPath)) {
            $doCopy = $false

            if ($CopyToClipboard) {
                $doCopy = $true
            } elseif ($ClipboardPrompt) {
                Write-Host ""
                Write-Host "Press C to copy the full audit output to clipboard, any other key to skip..."
                try {
                    $k = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    if ($k -and $k.Character -and (($k.Character -eq 'c') -or ($k.Character -eq 'C'))) {
                        $doCopy = $true
                    }
                } catch {
                    $doCopy = $false
                }
            }

            if ($doCopy) {
                try {
                    $txt9 = Get-Content -LiteralPath $transcriptPath -Raw -ErrorAction Stop
                    Set-Clipboard -Value $txt9
                    Write-Host "Copied audit output to clipboard."
                } catch {
                    Write-Host "Clipboard copy failed: $($_.Exception.Message)"
                    Write-Host "Transcript file: $transcriptPath"
                }
            }
        }
    }
}

function Show-AuditGui() {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

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

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = "Fill"
    $split.Orientation = "Vertical"
    $form.Controls.Add($split)

    $form.Add_Shown({
        try {
            $desired = 380
            $w = 0
            try { $w = [int]$split.Width } catch { $w = 0 }
            if ($w -le 0) {
                try { $w = [int]$form.ClientSize.Width } catch { $w = 0 }
            }

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

            if ($w -le 0) {
                try { $split.SplitterDistance = [int]$min1 } catch { }
                return
            }

            $min = [int]$split.Panel1MinSize
            $max = $w - [int]$split.Panel2MinSize
            if ($max -lt $min) {
                try { $split.SplitterDistance = [int]$min } catch { }
                return
            }

            $dist = $desired
            if ($dist -lt $min) { $dist = $min }
            if ($dist -gt $max) { $dist = $max }
            try { $split.SplitterDistance = [int]$dist } catch { }
        } catch {
            try { $split.SplitterDistance = 300 } catch { }
        }
    })

    $panelLeft = $split.Panel1
    $panelLeft.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.AutoSize = $true
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Text = "Audit-Optionen"
    $lblTitle.Left = 10
    $lblTitle.Top = 10
    $panelLeft.Controls.Add($lblTitle)

    $lblBaseUrl = New-Object System.Windows.Forms.Label
    $lblBaseUrl.AutoSize = $true
    $lblBaseUrl.Text = "Base-URL (nur fuer HTTP-Probe)"
    $lblBaseUrl.Left = 10
    $lblBaseUrl.Top = 44
    $panelLeft.Controls.Add($lblBaseUrl)

    $txtBaseUrl = New-Object System.Windows.Forms.TextBox
    $txtBaseUrl.Left = 10
    $txtBaseUrl.Top = 64
    $txtBaseUrl.Width = 340
    $txtBaseUrl.Text = ("" + $BaseUrl)
    $panelLeft.Controls.Add($txtBaseUrl)

    $lblProbePaths = New-Object System.Windows.Forms.Label
    $lblProbePaths.AutoSize = $true
    $lblProbePaths.Text = "Probe-Pfade (je Zeile ein relativer Pfad; nur fuer HTTP-Probe)"
    $lblProbePaths.Left = 10
    $lblProbePaths.Top = 98
    $panelLeft.Controls.Add($lblProbePaths)

    $txtProbePaths = New-Object System.Windows.Forms.TextBox
    $txtProbePaths.Left = 10
    $txtProbePaths.Top = 118
    $txtProbePaths.Width = 340
    $txtProbePaths.Height = 90
    $txtProbePaths.Multiline = $true
    $txtProbePaths.ScrollBars = "Vertical"
    $txtProbePaths.WordWrap = $false
    $txtProbePaths.Text = (($ProbePaths | ForEach-Object { "" + $_ }) -join "`r`n")
    $panelLeft.Controls.Add($txtProbePaths)

    $lblSwitches = New-Object System.Windows.Forms.Label
    $lblSwitches.AutoSize = $true
    $lblSwitches.Text = "Auswahl (was soll laufen)"
    $lblSwitches.Left = 10
    $lblSwitches.Top = 220
    $panelLeft.Controls.Add($lblSwitches)

    $chkHttpProbe = New-Object System.Windows.Forms.CheckBox
    $chkHttpProbe.Left = 10
    $chkHttpProbe.Top = 242
    $chkHttpProbe.Width = 340
    $chkHttpProbe.Text = "HTTP-Probe (Status/Redirects/Headers ohne Browser)"
    $chkHttpProbe.Checked = [bool]$HttpProbe
    $panelLeft.Controls.Add($chkHttpProbe)

    $chkRoutesVerbose = New-Object System.Windows.Forms.CheckBox
    $chkRoutesVerbose.Left = 10
    $chkRoutesVerbose.Top = 266
    $chkRoutesVerbose.Width = 340
    $chkRoutesVerbose.Text = "Routen (verbose) - admin: route:list --path=admin -vv"
    $chkRoutesVerbose.Checked = [bool]$RoutesVerbose
    $panelLeft.Controls.Add($chkRoutesVerbose)

    $chkRouteListFindstrAdmin = New-Object System.Windows.Forms.CheckBox
    $chkRouteListFindstrAdmin.Left = 10
    $chkRouteListFindstrAdmin.Top = 290
    $chkRouteListFindstrAdmin.Width = 340
    $chkRouteListFindstrAdmin.Text = "Routen (gesamt) - route:list gefiltert nach 'admin'"
    $chkRouteListFindstrAdmin.Checked = [bool]$RouteListFindstrAdmin
    $panelLeft.Controls.Add($chkRouteListFindstrAdmin)

    $chkSuperadminCount = New-Object System.Windows.Forms.CheckBox
    $chkSuperadminCount.Left = 10
    $chkSuperadminCount.Top = 314
    $chkSuperadminCount.Width = 340
    $chkSuperadminCount.Text = "Superadmin-Anzahl (best effort via tinker --execute)"
    $chkSuperadminCount.Checked = [bool]$SuperadminCount
    $panelLeft.Controls.Add($chkSuperadminCount)

    $chkTailLog = New-Object System.Windows.Forms.CheckBox
    $chkTailLog.Left = 10
    $chkTailLog.Top = 338
    $chkTailLog.Width = 340
    $chkTailLog.Text = "Laravel-Log anhaengen (tail storage/logs/laravel.log)"
    $chkTailLog.Checked = [bool]$TailLog
    $panelLeft.Controls.Add($chkTailLog)

    $lblInfoBox = New-Object System.Windows.Forms.Label
    $lblInfoBox.AutoSize = $false
    $lblInfoBox.Left = 10
    $lblInfoBox.Top = 388
    $lblInfoBox.Width = 340
    $lblInfoBox.Height = 230
    $lblInfoBox.BorderStyle = "FixedSingle"
    $lblInfoBox.Padding = New-Object System.Windows.Forms.Padding(8, 8, 8, 8)
    $lblInfoBox.Text =
        "Kurz erklaert:`r`n" +
        "- 'Run' startet das Audit und zeigt die Ausgabe rechts.`r`n" +
        "- 'Copy Output' kopiert den Inhalt des rechten Fensters.`r`n" +
        "- HTTP-Probe nutzt Base-URL/Probe-Pfade.`r`n" +
        "- Full-Audit: HTTP-Probe + Log anhaken.`r`n" +
        "- Hinweis: Log-Anhaengen in GUI fuegt nur den Tail ans Ende (kein Endlos-Wait)."
    $panelLeft.Controls.Add($lblInfoBox)

    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = "Run"
    $btnRun.Width = 120
    $btnRun.Height = 32
    $btnRun.Left = 10
    $btnRun.Top = 630
    $panelLeft.Controls.Add($btnRun)

    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "Copy Output"
    $btnCopy.Width = 120
    $btnCopy.Height = 32
    $btnCopy.Left = 140
    $btnCopy.Top = 630
    $btnCopy.Enabled = $false
    $panelLeft.Controls.Add($btnCopy)

    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = "Clear"
    $btnClear.Width = 80
    $btnClear.Height = 32
    $btnClear.Left = 270
    $btnClear.Top = 630
    $panelLeft.Controls.Add($btnClear)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.AutoSize = $true
    $lblStatus.Left = 10
    $lblStatus.Top = 672
    $lblStatus.Width = 340
    $lblStatus.Text = ""
    $panelLeft.Controls.Add($lblStatus)

    $panelRight = $split.Panel2
    $panelRight.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Multiline = $true
    $txt.ScrollBars = "Both"
    $txt.Dock = "Fill"
    $txt.Font = New-Object System.Drawing.Font("Consolas", 9)
    $txt.WordWrap = $false
    $panelRight.Controls.Add($txt)

    $uiScriptPath = Get-ScriptPath
    $projectRoot = $null
    try { $projectRoot = Resolve-ProjectRootFromScript $uiScriptPath } catch { $projectRoot = $null }

    function Get-UiArgs() {
        $argsList = New-Object System.Collections.Generic.List[string]

        # Always run this same script in child mode (no external dependency).
        $argsList.Add("-RunAuditInternal") | Out-Null
        $argsList.Add("-Gui:$false") | Out-Null

        if ($chkHttpProbe.Checked) {
            $bu = ("" + $txtBaseUrl.Text).Trim()
            if ($bu -ne "") {
                $argsList.Add("-BaseUrl") | Out-Null
                $argsList.Add((Quote-Arg $bu)) | Out-Null
            }

            $ppLines = @()
            try { $ppLines = ("" + $txtProbePaths.Text) -split "`r?`n" } catch { $ppLines = @() }

            $ppLines = @($ppLines | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
            if ($ppLines.Count -gt 0) {
                $argsList.Add("-ProbePaths") | Out-Null
                foreach ($p in $ppLines) {
                    $argsList.Add((Quote-Arg $p)) | Out-Null
                }
            }
        }

        if ($chkHttpProbe.Checked) { $argsList.Add("-HttpProbe") | Out-Null }
        if ($chkRoutesVerbose.Checked) { $argsList.Add("-RoutesVerbose") | Out-Null }
        if ($chkRouteListFindstrAdmin.Checked) { $argsList.Add("-RouteListFindstrAdmin") | Out-Null }
        if ($chkSuperadminCount.Checked) { $argsList.Add("-SuperadminCount") | Out-Null }

        # TailLog in GUI is appended AFTER the audit completes to avoid hanging
        if ($chkTailLog.Checked) { $argsList.Add("-TailLog") | Out-Null }

        return $argsList
    }

    $btnRun.Add_Click({
        $btnRun.Enabled = $false
        $btnCopy.Enabled = $false
        $txt.Clear()
        $lblStatus.Text = "Laeuft..."

        $psi = $null
        try {
            $argsList = Get-UiArgs

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell.exe"
            $psi.Arguments = ("-STA -NoProfile -ExecutionPolicy Bypass -File " + (Quote-Arg $uiScriptPath) + " " + ($argsList -join " "))
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true

            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $psi

            [void]$p.Start()

            $out = $p.StandardOutput.ReadToEnd()
            $err = $p.StandardError.ReadToEnd()

            $p.WaitForExit()

            $combined = ""
            if ($err -and ($err.Trim() -ne "")) { $combined += $err.TrimEnd() + "`r`n" }
            if ($out -and ($out.Trim() -ne "")) { $combined += $out.TrimEnd() + "`r`n" }
            if ($combined.Trim() -eq "") { $combined = "(keine Ausgabe)`r`n" }

            # Append log tail in GUI (if checkbox checked)
            if ($chkTailLog.Checked) {
                $combined += (Append-LaravelLogTail -root $projectRoot -tailLines 200)
            }

            $txt.Text = $combined
            $btnCopy.Enabled = $true
            $lblStatus.Text = ("Fertig (ExitCode: " + $p.ExitCode + ")")
        } catch {
            $argDump = ""
            try {
                if ($psi -and $psi.Arguments) {
                    $argDump = "`r`n`r`nChild-Command:`r`n" + $psi.FileName + " " + $psi.Arguments
                }
            } catch { }

            $txt.Text = ("GUI-Fehler:`r`n" + ($_ | Out-String).TrimEnd() + $argDump)
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
            $btnCopy.Enabled = $false
            $lblStatus.Text = ""
        } catch { }
    })

    [void]$form.ShowDialog()
}

# =============================================================================
# ENTRYPOINT
# =============================================================================

# If started by GUI-runner child process: run audit in console mode and exit.
if ($RunAuditInternal) {
    $scriptPath = Get-ScriptPath
    $projectRoot = Resolve-ProjectRootFromScript $scriptPath

    Invoke-AuditConsole -projectRoot $projectRoot

    # In child mode, DO NOT tail-follow; just output audit. GUI appends tail itself.
    # If someone runs child mode manually with -TailLog, we still output a snapshot tail at the end:
    if ($TailLog) {
        Write-Host (Append-LaravelLogTail -root $projectRoot -tailLines 200)
    }

    exit 0
}

# Normal mode: GUI by default unless explicitly disabled.
if ($guiEnabled) {
    try {
        Show-AuditGui
    } catch {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show(($_ | Out-String), "Audit UI Crash", "OK", "Error") | Out-Null
        } catch { }
    }
    exit 0
}

# GUI disabled and not internal runner -> run audit in console mode directly.
$scriptPath = Get-ScriptPath
$projectRoot = Resolve-ProjectRootFromScript $scriptPath
Invoke-AuditConsole -projectRoot $projectRoot

if ($TailLog) {
    Write-Host (Append-LaravelLogTail -root $projectRoot -tailLines 200)
}