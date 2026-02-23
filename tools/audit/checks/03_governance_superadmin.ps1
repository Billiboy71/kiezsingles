# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\03_governance_superadmin.ps1
# Purpose: Audit check - Governance: Superadmin fail-safe (deterministic, no tinker)
# Created: 21-02-2026 00:22 (Europe/Berlin)
# Changed: 22-02-2026 01:24 (Europe/Berlin)
# Version: 0.6
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_GovernanceSuperadmin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $root = $Context.ProjectRoot
    $run  = $Context.Helpers.RunPHPArtisan
    $new  = $Context.Helpers.NewAuditResult

    & $Context.Helpers.WriteSection "3) Governance: superadmin fail-safe (deterministic)"

    # Deterministic strategy (strict):
    # - Require an artisan command that returns JSON:
    #   php artisan ks:audit:superadmin --json --no-ansi --no-interaction
    # - JSON must be parseable and schema validated deterministically.
    # - Exit code must match the JSON state:
    #   0 => OK (>=1 superadmin)
    #   3 => CRITICAL (0 superadmins)
    #   2 => FAIL (command error/exception)
    #
    # JSON schema:
    #   { ok: <bool>, superadmins: <int>, admins: <int>, moderators: <int>, error?: <string>, error_class?: <string> }
    $cmd = "ks:audit:superadmin"

    try {
        $r = & $run $root @($cmd, "--json", "--no-ansi", "--no-interaction") 60

        $out = ""
        $err = ""
        try { $out = ("" + $r.StdOut).Trim() } catch { $out = "" }
        try { $err = ("" + $r.StdErr).Trim() } catch { $err = "" }

        $ec = 0
        try { $ec = [int]$r.ExitCode } catch { $ec = 0 }

        if ($out -eq "") {
            $sw.Stop()
            $details = @()
            if ($err -ne "") { $details += ("STDERR: " + $err) }
            $details += "No JSON output received."
            $details += "Expected deterministic command output."
            $details += ("Tried: php artisan {0} --json --no-ansi --no-interaction" -f $cmd)

            $data = @{ command = $cmd; exit_code = $ec }

            return & $new -Id "governance_superadmin" -Title "3) Governance: superadmin fail-safe" -Status "CRITICAL" -Summary "Deterministic superadmin check unavailable (no output)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        $payload = $null
        try {
            $payload = $out | ConvertFrom-Json -ErrorAction Stop
        } catch {
            $sw.Stop()
            $details = @()
            if ($err -ne "") { $details += ("STDERR: " + $err) }
            $details += "Failed to parse JSON from command output."
            $details += "Raw STDOUT:"
            $details += $out

            return & $new -Id "governance_superadmin" -Title "3) Governance: superadmin fail-safe" -Status "CRITICAL" -Summary "Deterministic superadmin check returned invalid JSON." -Details $details -Data @{ command = $cmd; exit_code = $ec } -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        $okRaw = $null
        $ok = $null
        try { $okRaw = $payload.ok } catch { $okRaw = $null }
        if ($null -ne $okRaw) {
            try { $ok = [bool]$okRaw } catch { $ok = $null }
        }

        $countRaw = $null
        $count = $null
        try { $countRaw = $payload.superadmins } catch { $countRaw = $null }
        if ($null -ne $countRaw) {
            try { $count = [int]$countRaw } catch { $count = $null }
        }

        $adminsRaw = $null
        $admins = $null
        try { $adminsRaw = $payload.admins } catch { $adminsRaw = $null }
        if ($null -ne $adminsRaw) {
            try { $admins = [int]$adminsRaw } catch { $admins = $null }
        }

        $moderatorsRaw = $null
        $moderators = $null
        try { $moderatorsRaw = $payload.moderators } catch { $moderatorsRaw = $null }
        if ($null -ne $moderatorsRaw) {
            try { $moderators = [int]$moderatorsRaw } catch { $moderators = $null }
        }

        $payloadError = ""
        try { $payloadError = ("" + $payload.error).Trim() } catch { $payloadError = "" }

        $payloadErrorClass = ""
        try { $payloadErrorClass = ("" + $payload.error_class).Trim() } catch { $payloadErrorClass = "" }

        $sw.Stop()

        $data = @{
            command = $cmd
            exit_code = $ec
            ok = $ok
            superadmins = $count
            admins = $admins
            moderators = $moderators
        }
        if ($payloadError -ne "") { $data["error"] = $payloadError }
        if ($payloadErrorClass -ne "") { $data["error_class"] = $payloadErrorClass }

        # Strict determinism: JSON schema must match, and exit code must match the state.

        if ($payloadError -ne "") {
            $details = @()
            if ($err -ne "") { $details += ("STDERR: " + $err) }
            $details += ("Command error: " + $payloadError)
            if ($payloadErrorClass -ne "") { $details += ("Error class: " + $payloadErrorClass) }
            if ($ec -ne 2) {
                $details += ("Exit code mismatch: JSON contains error but exit code is {0} (expected 2)." -f $ec)
            }

            return & $new -Id "governance_superadmin" -Title "3) Governance: superadmin fail-safe" -Status "CRITICAL" -Summary "Superadmin audit command reported an error." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        if ($null -eq $ok -or $null -eq $count -or $null -eq $admins -or $null -eq $moderators) {
            $details = @()
            if ($err -ne "") { $details += ("STDERR: " + $err) }
            $details += "JSON schema mismatch. Expected fields: ok(bool), superadmins(int), admins(int), moderators(int)."
            $details += "Parsed JSON:"
            $details += ($payload | ConvertTo-Json -Depth 6)

            return & $new -Id "governance_superadmin" -Title "3) Governance: superadmin fail-safe" -Status "CRITICAL" -Summary "Deterministic superadmin check schema mismatch." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        if ($ok -ne $true) {
            $details = @()
            if ($err -ne "") { $details += ("STDERR: " + $err) }
            $details += "Command returned ok=false without an explicit error field."
            $details += "Parsed JSON:"
            $details += ($payload | ConvertTo-Json -Depth 6)

            if ($ec -ne 2) {
                $details += ("Exit code mismatch: ok=false but exit code is {0} (expected 2)." -f $ec)
            }

            return & $new -Id "governance_superadmin" -Title "3) Governance: superadmin fail-safe" -Status "CRITICAL" -Summary "Superadmin audit command reported failure (ok=false)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        if ($count -le 0) {
            $details = @()
            if ($err -ne "") { $details += ("STDERR: " + $err) }
            if ($ec -ne 3) {
                $details += ("Exit code mismatch: JSON superadmins={0} but exit code is {1} (expected 3)." -f $count, $ec)
            }

            return & $new -Id "governance_superadmin" -Title "3) Governance: superadmin fail-safe" -Status "CRITICAL" -Summary "0 superadmins detected (forbidden)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        # count >= 1 => must be ExitCode 0
        if ($ec -ne 0) {
            $details = @()
            if ($err -ne "") { $details += ("STDERR: " + $err) }
            $details += ("Exit code mismatch: JSON superadmins={0} but exit code is {1} (expected 0)." -f $count, $ec)

            return & $new -Id "governance_superadmin" -Title "3) Governance: superadmin fail-safe" -Status "CRITICAL" -Summary ("Superadmins: " + $count + " (exit code mismatch)") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        return & $new -Id "governance_superadmin" -Title "3) Governance: superadmin fail-safe" -Status "OK" -Summary ("Superadmins: " + $count + " | Admins: " + $admins + " | Moderators: " + $moderators) -Details @() -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    } catch {
        $sw.Stop()
        $details = @()
        $details += ("Command missing or failed: php artisan " + $cmd + " --json --no-ansi --no-interaction")
        $details += ("Error: " + $_.Exception.Message)
        $details += ""
        $details += "Deterministic requirement: artisan command 'ks:audit:superadmin' must output JSON { ok: <bool>, superadmins: <int>, admins: <int>, moderators: <int> } and return exit codes 0/3/2."

        return & $new -Id "governance_superadmin" -Title "3) Governance: superadmin fail-safe" -Status "CRITICAL" -Summary "Deterministic superadmin check failed to execute." -Details $details -Data @{ command = $cmd } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }
}