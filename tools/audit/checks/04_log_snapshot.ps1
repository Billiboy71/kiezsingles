# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\04_log_snapshot.ps1
# Purpose: Audit check - Laravel log snapshot (tail; informative)
# Created: 21-02-2026 00:25 (Europe/Berlin)
# Changed: 23-02-2026 03:28 (Europe/Berlin)
# Version: 0.7
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_LogSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $new  = $Context.Helpers.NewAuditResult
    $root = $Context.ProjectRoot

    & $Context.Helpers.WriteSection "4) Laravel log snapshot"

    $logPath = Join-Path $root "storage\logs\laravel.log"
    $tailLines = 200

    # Deterministic default: snapshot is informational and should not turn the whole audit into WARN.
    # Optional override via Context.LogSnapshotWarnOnLocalError = $true
    $warnOnLocalError = $false
    try {
        if ($Context -and ($Context | Get-Member -Name "LogSnapshotWarnOnLocalError" -MemberType NoteProperty,Property -ErrorAction SilentlyContinue)) {
            $warnOnLocalError = [bool]$Context.LogSnapshotWarnOnLocalError
        }
    } catch { $warnOnLocalError = $false }

    # Optional: if provided by core, we classify "new since audit start"
    $auditStartedAt = $null
    try {
        if ($Context -and ($Context | Get-Member -Name "AuditStartedAt" -MemberType NoteProperty,Property -ErrorAction SilentlyContinue)) {
            $auditStartedAt = $Context.AuditStartedAt
        }
    } catch { $auditStartedAt = $null }

    if (-not (Test-Path $logPath)) {
        $sw.Stop()
        return & $new -Id "log_snapshot" -Title "4) Laravel log snapshot" -Status "WARN" -Summary "laravel.log not found." -Details @("Expected: " + $logPath) -Data @{ path = $logPath } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    try {
        $lines = Get-Content -LiteralPath $logPath -Tail $tailLines -ErrorAction Stop

        $errorCount = 0
        $newErrorCount = 0

        $newErrorLines = New-Object System.Collections.Generic.List[string]

        # Known historic noise classification (does NOT change status by default):
        # - route:list unsupported options (--columns / --format)
        # - bootstrap/cache access denied rename packages.php (Windows file lock)
        $knownLegacyCounts = @{
            route_list_columns = 0
            route_list_format = 0
            cache_rename_access_denied = 0
        }
        $knownLegacySinceAuditCounts = @{
            route_list_columns = 0
            route_list_format = 0
            cache_rename_access_denied = 0
        }

        # Laravel log lines typically start with:
        # [YYYY-MM-DD HH:MM:SS] local.ERROR: ...
        $rxTs = '^\[(?<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\]\s+local\.ERROR:'

        function Classify-KnownLegacyError {
            param(
                [Parameter(Mandatory = $true)][string]$Line
            )

            $l = $Line

            if ($l -match '(?i)The\s+"--columns"\s+option\s+does\s+not\s+exist') { return "route_list_columns" }
            if ($l -match '(?i)The\s+"--format"\s+option\s+does\s+not\s+exist') { return "route_list_format" }

            # Example:
            # rename(...bootstrap\cache\pacXXXX.tmp,...bootstrap\cache\packages.php): Zugriff verweigert (code: 5)
            if ($l -match '(?i)\brename\(' -and $l -match '(?i)bootstrap\\cache\\.*packages\.php' -and $l -match '(?i)Zugriff\s+verweigert\s+\(code:\s*5\)') {
                return "cache_rename_access_denied"
            }

            return ""
        }

        foreach ($l in @($lines)) {
            $line = ""
            try { $line = "" + $l } catch { $line = "" }
            if ($line -eq "") { continue }

            $isLocalError = $false
            if ($line -match 'local\.ERROR:') {
                $errorCount++
                $isLocalError = $true

                $k = Classify-KnownLegacyError -Line $line
                if ($k -ne "") {
                    try { $knownLegacyCounts[$k] = [int]$knownLegacyCounts[$k] + 1 } catch { }
                }
            }

            if ($null -ne $auditStartedAt) {
                if ($line -match $rxTs) {
                    $tsRaw = $Matches['ts']
                    $ts = $null
                    try { $ts = [datetime]::ParseExact($tsRaw, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) } catch { $ts = $null }

                    if ($null -ne $ts) {
                        $start = $null
                        try {
                            if ($auditStartedAt -is [datetime]) { $start = [datetime]$auditStartedAt }
                            else { $start = [datetime]$auditStartedAt }
                        } catch { $start = $null }

                        if ($null -ne $start) {
                            if ($ts -ge $start -and $isLocalError) {
                                $newErrorCount++
                                $newErrorLines.Add($line) | Out-Null

                                $k2 = Classify-KnownLegacyError -Line $line
                                if ($k2 -ne "") {
                                    try { $knownLegacySinceAuditCounts[$k2] = [int]$knownLegacySinceAuditCounts[$k2] + 1 } catch { }
                                }
                            }
                        }
                    }
                }
            }
        }

        $sw.Stop()

        $details = @()
        $details += ("=== Laravel Log Tail (last " + $tailLines + " lines) ===")
        $details += @($lines)

        if ($null -ne $auditStartedAt) {
            $details += ""
            $details += ("=== local.ERROR since AuditStartedAt (" + $auditStartedAt + ") ===")
            if ($newErrorLines.Count -gt 0) {
                $details += @($newErrorLines.ToArray())
            } else {
                $details += "(none)"
            }

            $details += ""
            $details += "=== Classification (informational) ==="
            $details += ("AuditStartedAt: " + $auditStartedAt)

            $details += ("Known legacy patterns in tail (overall): " +
                "route_list(--columns)=" + [int]$knownLegacyCounts["route_list_columns"] + " | " +
                "route_list(--format)=" + [int]$knownLegacyCounts["route_list_format"] + " | " +
                "bootstrap/cache access_denied(rename packages.php)=" + [int]$knownLegacyCounts["cache_rename_access_denied"]
            )

            $details += ("Known legacy patterns since AuditStartedAt: " +
                "route_list(--columns)=" + [int]$knownLegacySinceAuditCounts["route_list_columns"] + " | " +
                "route_list(--format)=" + [int]$knownLegacySinceAuditCounts["route_list_format"] + " | " +
                "bootstrap/cache access_denied(rename packages.php)=" + [int]$knownLegacySinceAuditCounts["cache_rename_access_denied"]
            )

            if ($newErrorCount -eq 0 -and $errorCount -gt 0) {
                $details += "INFO: local.ERROR lines exist in the tail, but none are newer than AuditStartedAt (likely historical noise)."
            }
        }

        $data = @{
            path = $logPath
            tail_lines = $tailLines
            local_error_count = $errorCount
            known_legacy_route_list_columns_count = [int]$knownLegacyCounts["route_list_columns"]
            known_legacy_route_list_format_count = [int]$knownLegacyCounts["route_list_format"]
            known_legacy_cache_rename_access_denied_count = [int]$knownLegacyCounts["cache_rename_access_denied"]
        }

        if ($null -ne $auditStartedAt) {
            $data["audit_started_at"] = $auditStartedAt
            $data["local_error_since_audit_start"] = $newErrorCount
            $data["known_legacy_route_list_columns_since_audit_start"] = [int]$knownLegacySinceAuditCounts["route_list_columns"]
            $data["known_legacy_route_list_format_since_audit_start"] = [int]$knownLegacySinceAuditCounts["route_list_format"]
            $data["known_legacy_cache_rename_access_denied_since_audit_start"] = [int]$knownLegacySinceAuditCounts["cache_rename_access_denied"]
        }

        if ($warnOnLocalError -and ($errorCount -gt 0)) {
            $summary = "Appended last " + $tailLines + " lines from laravel.log. Detected local.ERROR: " + $errorCount + "."
            if ($null -ne $auditStartedAt) {
                $summary += " Since audit start: " + $newErrorCount + "."
            }

            return & $new -Id "log_snapshot" -Title "4) Laravel log snapshot" -Status "WARN" -Summary $summary -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        # Default: OK (informational), even if local.ERROR lines exist.
        $summary = "Appended last " + $tailLines + " lines from laravel.log."
        if ($errorCount -gt 0) {
            $summary += " Detected local.ERROR: " + $errorCount + "."
        }
        if ($null -ne $auditStartedAt) {
            $summary += " Since audit start: " + $newErrorCount + "."

            if ($newErrorCount -eq 0 -and $errorCount -gt 0) {
                $summary += " (All local.ERROR in tail are older than AuditStartedAt.)"
            }
        }

        return & $new -Id "log_snapshot" -Title "4) Laravel log snapshot" -Status "OK" -Summary $summary -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    } catch {
        $sw.Stop()
        return & $new -Id "log_snapshot" -Title "4) Laravel log snapshot" -Status "WARN" -Summary ("Failed to read laravel.log: " + $_.Exception.Message) -Details @() -Data @{ path = $logPath } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }
}