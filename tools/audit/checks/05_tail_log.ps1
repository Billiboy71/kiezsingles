# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\05_tail_log.ps1
# Purpose: Audit check - tail laravel.log (blocks; interactive)
# Created: 21-02-2026 00:27 (Europe/Berlin)
# Changed: 21-02-2026 13:38 (Europe/Berlin)
# Version: 0.5
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_TailLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $new  = $Context.Helpers.NewAuditResult
    $root = $Context.ProjectRoot

    # IMPORTANT: In TailLog mode this check must NOT emit any header/section output.
    # The dedicated TailLog window must show ONLY the live tail stream.

    $logPath = Join-Path $root "storage\logs\laravel.log"

    if (-not (Test-Path $logPath)) {
        $sw.Stop()
        return & $new -Id "tail_log" -Title "5) Tail laravel.log" -Status "WARN" -Summary "laravel.log not found." -Details @("Expected: " + $logPath) -Data @{ path = $logPath } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    # Tail mode selection:
    # - history: show last N lines, then follow (default)
    # - live: show only new lines from now on, then follow
    $mode = "history"
    try {
        if ($null -ne $Context -and ($Context.PSObject.Properties.Name -contains "TailLogMode")) {
            $m = ("" + $Context.TailLogMode).Trim().ToLower()
            if ($m -ne "") { $mode = $m }
        } elseif ($null -ne $env:KS_TAILLOG_MODE -and ("" + $env:KS_TAILLOG_MODE).Trim() -ne "") {
            $mode = ("" + $env:KS_TAILLOG_MODE).Trim().ToLower()
        }
    } catch { }

    $tailLines = 200
    if ($mode -eq "live") { $tailLines = 0 }

    try {
        # Open dedicated window that shows ONLY the live tail stream.
        # Keep the command free of any other output (suppress chcp output).
        $escapedPath = ($logPath -replace "'", "''")

        if ($mode -eq "live") {
            # Live-only follow: start at EOF and print only newly appended lines (deterministic).
            $tailCmd = @"
`$ErrorActionPreference = 'Stop';
try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(`$false) } catch { }
try { [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new(`$false) } catch { }

`$path = '$escapedPath';

`$fs = [System.IO.File]::Open(`$path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite);
try {
    [void]`$fs.Seek(0, [System.IO.SeekOrigin]::End);
    `$sr = [System.IO.StreamReader]::new(`$fs, [System.Text.UTF8Encoding]::UTF8, `$true, 4096, `$true);
    try {
        while (`$true) {
            `$line = `$sr.ReadLine();
            if (`$null -ne `$line) {
                Write-Output `$line;
            } else {
                Start-Sleep -Milliseconds 200;
            }
        }
    } finally {
        try { `$sr.Dispose() } catch { }
    }
} finally {
    try { `$fs.Dispose() } catch { }
}
"@
        } else {
            # History + follow (default).
            $tailCmd = @"
`$ErrorActionPreference = 'Stop';
try { chcp 65001 | Out-Null } catch { }
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(`$false) } catch { }
try { [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new(`$false) } catch { }
Get-Content -LiteralPath '$escapedPath' -Tail $tailLines -Wait
"@
        }

        $p = Start-Process -FilePath "pwsh" -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-NoLogo",
            "-NoExit",
            "-Command", $tailCmd
        ) -PassThru

        # Block until the tail window is closed.
        $p.WaitForExit() | Out-Null

        $sw.Stop()
        return & $new -Id "tail_log" -Title "5) Tail laravel.log" -Status "OK" -Summary "Tail stopped." -Details @() -Data @{ path = $logPath; mode = $mode; tail = [int]$tailLines } -DurationMs ([int]$sw.ElapsedMilliseconds)
    } catch {
        $exType = ""
        try { $exType = ("" + $_.Exception.GetType().FullName) } catch { $exType = "" }

        # CTRL+C / pipeline stop should not be treated as a failure.
        if ($exType -match 'PipelineStoppedException' -or $exType -match 'OperationCanceledException') {
            $sw.Stop()
            return & $new -Id "tail_log" -Title "5) Tail laravel.log" -Status "OK" -Summary "Tail stopped." -Details @() -Data @{ path = $logPath; mode = $mode; tail = [int]$tailLines } -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        $sw.Stop()
        return & $new -Id "tail_log" -Title "5) Tail laravel.log" -Status "WARN" -Summary ("Tail failed: " + $_.Exception.Message) -Details @() -Data @{ path = $logPath; mode = $mode; tail = [int]$tailLines } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }
}