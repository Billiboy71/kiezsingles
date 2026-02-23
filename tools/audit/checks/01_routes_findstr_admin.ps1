# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\01_routes_findstr_admin.ps1
# Purpose: Audit check - full route:list filter "admin" (informative)
# Created: 21-02-2026 00:12 (Europe/Berlin)
# Changed: 21-02-2026 02:50 (Europe/Berlin)
# Version: 0.2
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_RouteListFindstrAdmin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $root = $Context.ProjectRoot
    $run  = $Context.Helpers.RunPHPArtisan
    $new  = $Context.Helpers.NewAuditResult

    & $Context.Helpers.WriteSection "1f) Route list filter (php artisan route:list | findstr admin)"

    try {
        $r = & $run $root @("route:list", "--no-ansi", "--no-interaction") 120

        $out = ""
        $err = ""
        try { $out = ("" + $r.StdOut) } catch { $out = "" }
        try { $err = ("" + $r.StdErr).Trim() } catch { $err = "" }

        # Sanitize known Unicode symbols from Laravel output to keep Windows consoles / findstr-friendly output
        # (prevents "???" artifacts when codepage/font is not UTF-8 capable).
        $outSan = $out
        try {
            $outSan = $outSan -replace "›", ">"
            $outSan = $outSan -replace "⇂", "v"
        } catch {
            $outSan = $out
        }

        $hits = @()
        if ($outSan.Trim() -ne "") {
            $lines = $outSan -split "`r?`n"
            $hits = @($lines | Where-Object { $_ -match "admin" })
        }

        $details = @()
        if ($err -ne "") { $details += ("STDERR: " + $err) }

        if ($hits.Count -gt 0) {
            $details += "--- STDOUT FILTERED (lines containing 'admin') ---"
            $details += $hits
        } else {
            $details += "(no hits for 'admin' in route:list output)"
        }

        $ec = 0
        try { $ec = [int]$r.ExitCode } catch { $ec = 0 }

        $sw.Stop()

        if ($ec -ne 0) {
            return & $new -Id "routes_findstr_admin" -Title "1f) Route list filter (admin-only)" -Status "WARN" -Summary ("route:list exit code: " + $ec) -Details $details -Data @{ exit_code = $ec; hits = [int]$hits.Count } -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        return & $new -Id "routes_findstr_admin" -Title "1f) Route list filter (admin-only)" -Status "OK" -Summary ("Filtered " + $hits.Count + " lines containing 'admin'.") -Details $details -Data @{ exit_code = $ec; hits = [int]$hits.Count } -DurationMs ([int]$sw.ElapsedMilliseconds)
    } catch {
        $sw.Stop()
        return & $new -Id "routes_findstr_admin" -Title "1f) Route list filter (admin-only)" -Status "WARN" -Summary ("Route filter failed: " + $_.Exception.Message) -Details @() -Data @{} -DurationMs ([int]$sw.ElapsedMilliseconds)
    }
}