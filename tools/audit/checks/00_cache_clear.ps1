# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\00_cache_clear.ps1
# Purpose: Audit check - clear Laravel caches (best effort; non-fatal)
# Created: 21-02-2026 00:02 (Europe/Berlin)
# Changed: 21-02-2026 19:25 (Europe/Berlin)
# Version: 0.3
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_CacheClear {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $root = $Context.ProjectRoot
    $run  = $Context.Helpers.RunPHPArtisan
    $new  = $Context.Helpers.NewAuditResult

    try {
        & $Context.Helpers.WriteSection "0) Cache clear (php artisan optimize:clear)"

        $r = & $run $root @("optimize:clear", "--no-ansi", "--no-interaction") 120

        $out = ""
        $err = ""
        try { $out = ("" + $r.StdOut).Trim() } catch { $out = "" }
        try { $err = ("" + $r.StdErr).Trim() } catch { $err = "" }

        $ec = 0
        try { $ec = [int]$r.ExitCode } catch { $ec = 0 }

        $sw.Stop()

        # Keep output clean on success: do NOT echo verbose artisan stdout/stderr.
        # Only include details when something is off (non-zero exit code).
        $details = @()

        if ($ec -ne 0) {
            if ($err -ne "") {
                $details += "--- STDERR ---"
                $details += $err
            }
            if ($out -ne "") {
                $details += "--- STDOUT ---"
                $details += $out
            }

            return & $new -Id "cache_clear" -Title "0) Cache clear" -Status "WARN" -Summary ("optimize:clear exit code: " + $ec + " (continuing)") -Details $details -Data @{ exit_code = $ec } -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        return & $new -Id "cache_clear" -Title "0) Cache clear" -Status "OK" -Summary "Caches cleared." -Details @() -Data @{ exit_code = $ec } -DurationMs ([int]$sw.ElapsedMilliseconds)
    } catch {
        $sw.Stop()
        return & $new -Id "cache_clear" -Title "0) Cache clear" -Status "WARN" -Summary ("Cache clear failed (continuing): " + $_.Exception.Message) -Details @() -Data @{} -DurationMs ([int]$sw.ElapsedMilliseconds)
    }
}