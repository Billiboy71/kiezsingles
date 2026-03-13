# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit.ps1
# Purpose: Repeatable admin/backend audit (routes, duplicates, inline HTML/Blade, role checks, DB sanity, optional HTTP traces)
# Created: 19-02-2026 17:25 (Europe/Berlin)
# Changed: 19-02-2026 19:39 (Europe/Berlin)
# Version: 1.1
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
    [switch]$TailLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
        if ($null -eq $ArgumentList) {
            $ArgumentList = @()
        }

        # Remove NULL elements to satisfy Start-Process parameter validation.
        $ArgumentList = @($ArgumentList | Where-Object { $_ -ne $null })

        # IMPORTANT:
        # Always provide an empty stdin file to prevent edge cases where the child process waits for input.
        try {
            Set-Content -LiteralPath $tmpIn -Value "" -NoNewline -Encoding ASCII
        } catch {
            # ignore; still try to run without stdin content
        }

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

        # IMPORTANT: -ArgumentList must NOT be empty; omit it when no args exist.
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

        # Defensive: ExitCode can end up $null in some Start-Process edge cases.
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

    if ($null -eq $ArgumentList) {
        $ArgumentList = @()
    }

    # Build cmd args as array and remove NULLs.
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
        # Reduce noise: filter internal admin-route tracing lines
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

    try {
        if ([int]$procResult.ExitCode -eq -1) { return $false } # our timeout marker
    } catch {
        # ignore
    }

    $out = ""
    try { $out = ("" + $procResult.StdOut).Trim() } catch { $out = "" }

    # Consider "completed" if we have any output OR exitcode is 0.
    try {
        if ([int]$procResult.ExitCode -eq 0) { return $true }
    } catch {
        # ignore
    }

    return ($out -ne "")
}

# --- Determine project root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir "..\..") | Select-Object -ExpandProperty Path
Require-ProjectRoot $projectRoot
Set-Location $projectRoot

Write-Section "KiezSingles Admin Audit (routes + patterns + DB sanity)"

Write-Host "ProjectRoot: $projectRoot"
Write-Host "BaseUrl:     $BaseUrl"
Write-Host "HttpProbe:   $HttpProbe"
Write-Host "TailLog:     $TailLog"

# -----------------------------------------------------------------------------
# 1) Find admin-related route patterns in routes/*.php
# -----------------------------------------------------------------------------
Write-Section "1) Find admin route patterns in routes/*.php"

Get-ChildItem -Recurse -Path .\routes -Filter *.php -ErrorAction SilentlyContinue |
    Select-String -Pattern "Route::prefix\(\s*'admin'\s*\)|Route::get\(\s*'/admin|Route::post\(\s*'/admin|'/admin/" |
    ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } |
    ForEach-Object { Write-Host $_ }

# -----------------------------------------------------------------------------
# 2) Route list (admin path) + duplicate route names / duplicate URIs
# -----------------------------------------------------------------------------
Write-Section "2) php artisan route:list --path=admin (raw output)"

$r = Run-PHPArtisan $projectRoot @("route:list", "--path=admin", "--no-ansi", "--no-interaction") 60
Write-StdStreams $r

$routeListCompleted = Is-Completed $r

Write-Section "2a) Duplicate admin route names (from route:list output)"

if ($routeListCompleted) {
    $txt = ("" + $r.StdOut)
    $names = ($txt -split "`n") | ForEach-Object {
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
    $txt = ("" + $r.StdOut)
    $uris = ($txt -split "`n") | ForEach-Object {
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
# 4) Scan for inline HTML / Blade::render patterns in route files
# -----------------------------------------------------------------------------
Write-Section "4) Scan routes for inline HTML / Blade::render / heredoc patterns"

Get-ChildItem .\routes -Recurse -File -Filter *.php -ErrorAction SilentlyContinue |
    Select-String -Pattern 'Blade::render','<<<\s*[''"]?BLADE[''"]?','<!doctype\s+html','<html\b','<head\b','<body\b','return\s+response\(' -AllMatches |
    Select-Object Path, LineNumber, Line |
    Format-Table -AutoSize

# -----------------------------------------------------------------------------
# 5) Scan admin route files for role checks / abort_unless / role usage
# -----------------------------------------------------------------------------
Write-Section "5) Scan routes/web/admin for role checks / abort_unless patterns"

Get-ChildItem .\routes\web\admin -Recurse -File -Filter *.php -ErrorAction SilentlyContinue |
    Select-String -Pattern 'auth\(\)\-\>user\(\)\-\>role','\-\>role\b','isAdminRole','isStaffRole','isStaffLike','abort_unless\(.+role' |
    Select-Object Path, LineNumber, Line |
    Format-Table -AutoSize

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
    # Only warn if we got a reliable non-zero exit code AND we had output.
    $ec = 0
    try { $ec = [int]$db.ExitCode } catch { $ec = 0 }
    if ($ec -ne 0) {
        Write-Host ""
        Write-Host "DB audit returned non-zero exit code: $ec"
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

        # Status + Location (no redirects)
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

        # Follow redirects (up to 20), show final status + final uri
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

# -----------------------------------------------------------------------------
# 8) Optional log tail
# -----------------------------------------------------------------------------
if ($TailLog) {
    Write-Section "8) Tail storage/logs/laravel.log (CTRL+C to stop)"
    $logPath = Join-Path $projectRoot "storage\logs\laravel.log"
    if (Test-Path $logPath) {
        Get-Content -Path $logPath -Tail 200 -Wait
    } else {
        Write-Host "laravel.log not found at: $logPath"
    }
}

Write-Section "Audit completed"
Write-Host "Done."
