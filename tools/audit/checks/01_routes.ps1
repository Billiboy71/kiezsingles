# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\01_routes.ps1
# Purpose: Audit check - routes / collisions / admin scope (deterministic)
# Created: 21-02-2026 00:06 (Europe/Berlin)
# Changed: 21-02-2026 01:07 (Europe/Berlin)
# Version: 0.2
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_Routes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $root = $Context.ProjectRoot
    $run  = $Context.Helpers.RunPHPArtisan
    $new  = $Context.Helpers.NewAuditResult

    & $Context.Helpers.WriteSection "1) Routes / collisions / admin scope"

    $r = $null
    try {
        $r = & $run $root @("route:list", "--path=admin", "--no-ansi", "--no-interaction") 90
    } catch {
        $sw.Stop()
        return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "CRITICAL" -Summary ("route:list failed: " + $_.Exception.Message) -Details @() -Data @{} -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $stdout = ""
    $stderr = ""
    try { $stdout = ("" + $r.StdOut) } catch { $stdout = "" }
    try { $stderr = ("" + $r.StdErr) } catch { $stderr = "" }

    $exitCode = 0
    try { $exitCode = [int]$r.ExitCode } catch { $exitCode = 0 }

    $completed = $false
    try {
        $completed = ($exitCode -eq 0 -or ($stdout.Trim() -ne ""))
    } catch {
        $completed = ($stdout.Trim() -ne "")
    }

    if (-not $completed) {
        $sw.Stop()
        $details = @()
        if ($stderr.Trim() -ne "") { $details += ("STDERR: " + $stderr.Trim()) }
        return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "CRITICAL" -Summary "route:list produced no output / did not complete." -Details $details -Data @{ exit_code = $exitCode } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    # --- Parse route:list output
    $lines = @()
    try { $lines = $stdout -split "`r?`n" } catch { $lines = @() }

    # Collect route names and admin URIs from table lines.
    $names = New-Object System.Collections.Generic.List[string]
    $uris  = New-Object System.Collections.Generic.List[string]
    $nonAdminUris = New-Object System.Collections.Generic.List[string]

    foreach ($raw in $lines) {
        $line = ("" + $raw)
        if ($line.Trim() -eq "") { continue }

        $flat = ($line -replace "\s+", " ").Trim()

        # Name: " admin.something " anywhere in the line (typical route:list table)
        if ($flat -match "\s(admin\.[A-Za-z0-9\._-]+)\s") {
            $names.Add($Matches[1]) | Out-Null
        }

        # URI: line starts with methods then whitespace then "admin..."
        if ($flat -match "^(GET\|HEAD|POST|PUT|PATCH|DELETE|OPTIONS)\s+(?<uri>\S+)\s") {
            $u = $Matches["uri"]
            if ($u) {
                $uris.Add($u) | Out-Null
                if (-not ($u -like "admin*")) {
                    $nonAdminUris.Add($u) | Out-Null
                }
            }
        }
    }

    # Grouping helpers (robust: handle scalar / missing Count)
    function Get-DupGroups($Items) {
        $arr = @()
        try { $arr = @($Items) } catch { $arr = @() }

        if ($arr.Count -le 0) { return @() }

        return @(
            $arr |
                Group-Object |
                Where-Object { $_.Count -gt 1 } |
                Sort-Object Count -Descending
        )
    }

    $dupNames = Get-DupGroups ($names.ToArray())
    $dupUris  = Get-DupGroups ($uris.ToArray())

    $details = @()
    $data = @{
        route_list_exit_code = $exitCode
        admin_routes_parsed  = [int]($uris.Count)
        admin_names_parsed   = [int]($names.Count)
        dup_name_count       = [int](@($dupNames).Count)
        dup_uri_count        = [int](@($dupUris).Count)
        non_admin_uri_count  = [int]($nonAdminUris.Count)
    }

    # Include stderr if present (but avoid noise explosion)
    if ($stderr -and $stderr.Trim() -ne "") {
        $details += ("STDERR: " + $stderr.Trim())
    }

    if ($nonAdminUris.Count -gt 0) {
        $details += ("Non-admin URIs in --path=admin output (unexpected): " + ($nonAdminUris.ToArray() -join ", "))
    }

    if (@($dupNames).Count -gt 0) {
        $details += "Duplicate route names detected:"
        foreach ($g in (@($dupNames) | Select-Object -First 12)) {
            $details += ("  " + $g.Name + " (x" + $g.Count + ")")
        }
        if (@($dupNames).Count -gt 12) { $details += ("  ... (" + (@($dupNames).Count - 12) + " more)") }
    }

    if (@($dupUris).Count -gt 0) {
        $details += "Duplicate URIs detected:"
        foreach ($g in (@($dupUris) | Select-Object -First 12)) {
            $details += ("  " + $g.Name + " (x" + $g.Count + ")")
        }
        if (@($dupUris).Count -gt 12) { $details += ("  ... (" + (@($dupUris).Count - 12) + " more)") }
    }

    $sw.Stop()

    # Decide status
    if ($nonAdminUris.Count -gt 0) {
        return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "FAIL" -Summary "Admin route scope mismatch detected." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if (@($dupNames).Count -gt 0 -or @($dupUris).Count -gt 0) {
        return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "FAIL" -Summary "Route collisions detected (duplicate names and/or URIs)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($uris.Count -le 0) {
        return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "WARN" -Summary "No admin routes found via route:list --path=admin." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "OK" -Summary ("Parsed " + $uris.Count + " admin routes; no collisions.") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
}