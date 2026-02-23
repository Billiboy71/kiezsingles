# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\01_routes_verbose.ps1
# Purpose: Audit check - verbose route inspection (informative)
# Created: 21-02-2026 00:10 (Europe/Berlin)
# Changed: 23-02-2026 01:11 (Europe/Berlin)
# Version: 0.5
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_RoutesVerbose {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $root = $Context.ProjectRoot
    $run  = $Context.Helpers.RunPHPArtisan
    $new  = $Context.Helpers.NewAuditResult

    & $Context.Helpers.WriteSection "1v) Routes verbose inspection (route:list --path=admin -vv)"

    try {
        $r = & $run $root @("route:list", "--path=admin", "-vv", "--no-ansi", "--no-interaction") 120

        $out = ""
        $err = ""
        try { $out = ("" + $r.StdOut).Trim() } catch { $out = "" }
        try { $err = ("" + $r.StdErr).Trim() } catch { $err = "" }

        $details = @()
        if ($err -ne "") {
            $details += ("STDERR: " + $err)
        }

        if ($out -ne "") {
            # Keep full output as details (informative mode)
            $details += "--- STDOUT (route:list --path=admin -vv) ---"
            $details += $out
        } else {
            $details += "No STDOUT received from route:list -vv."
        }

        $ec = 0
        try { $ec = [int]$r.ExitCode } catch { $ec = 0 }

        # ---------------------------------------------------------------------
        # STRICT VALIDATION (SSOT via middleware)
        # Parse verbose output and validate:
        # - Authenticate present
        # - MaintenanceMode present
        # - EnsureSectionAccess:<section> present
        # - EnsureStaff for sections: overview, tickets
        # - EnsureSuperadmin for all other sections
        #
        # NOTE:
        # We intentionally do NOT match the leading arrow symbol (encoding can be
        # mangled). We detect middleware lines by taking the last whitespace-
        # separated token and checking if it starts with Illuminate\ or App\.
        # ---------------------------------------------------------------------
        $issues = @()

        if ($out -ne "") {
            $lines = $out -split "`r?`n"

            $routes = New-Object System.Collections.Generic.List[object]
            $current = $null

            foreach ($line in $lines) {
                $l = ("" + $line)

                # Route header line (e.g. "GET|HEAD   admin .... admin.home")
                if ($l -match '^\s*[A-Z\|]+\s+admin(\S*)\s+\.+') {

                    if ($null -ne $current) {
                        $routes.Add($current)
                    }

                    $routeName = ""
                    $uri = ""

                    try {
                        # URI
                        if ($l -match '^\s*[A-Z\|]+\s+(admin[^\s]*)\s+\.+') {
                            $uri = $Matches[1]
                        }

                        # Route name: take substring starting at 'admin.' and cut at ' › ' if present
                        $idx = $l.IndexOf("admin.")
                        if ($idx -ge 0) {
                            $tail = $l.Substring($idx).Trim()
                            $cut = $tail.IndexOf(" › ")
                            if ($cut -ge 0) {
                                $tail = $tail.Substring(0, $cut).Trim()
                            }
                            $parts = $tail -split '\s+'
                            if ($parts.Count -gt 0) {
                                $routeName = ("" + $parts[0]).Trim()
                            }
                        }
                    } catch {
                        $routeName = ""
                        $uri = ""
                    }

                    $current = [pscustomobject]@{
                        Uri = $uri
                        Name = $routeName
                        Middleware = New-Object System.Collections.Generic.List[string]
                    }

                    continue
                }

                # Middleware line (encoding-safe): last token should be the class name
                if ($null -ne $current) {
                    $trim = ("" + $l).Trim()
                    if ($trim -ne "") {
                        $tokens = $trim -split '\s+'
                        if ($tokens.Count -gt 0) {
                            $last = ("" + $tokens[$tokens.Count - 1]).Trim()
                            if ($last -like "Illuminate\*" -or $last -like "App\*") {
                                $current.Middleware.Add($last)
                                continue
                            }
                        }
                    }
                }
            }

            if ($null -ne $current) {
                $routes.Add($current)
            }

            foreach ($rt in $routes) {
                $name = ("" + $rt.Name).Trim()
                $uri  = ("" + $rt.Uri).Trim()

                $mw = @()
                try { $mw = @($rt.Middleware) } catch { $mw = @() }

                if ($uri -eq "") { continue }

                $hasAuth = $false
                $hasMaintenance = $false
                $section = ""
                $hasEnsureStaff = $false
                $hasEnsureSuperadmin = $false

                foreach ($m in $mw) {
                    if ($m -like "*Illuminate\Auth\Middleware\Authenticate*") { $hasAuth = $true }
                    if ($m -like "*App\Http\Middleware\MaintenanceMode*") { $hasMaintenance = $true }
                    if ($m -like "*App\Http\Middleware\EnsureStaff*") { $hasEnsureStaff = $true }
                    if ($m -like "*App\Http\Middleware\EnsureSuperadmin*") { $hasEnsureSuperadmin = $true }

                    if ($m -match 'EnsureSectionAccess:(?<sec>[a-z0-9_]+)') {
                        $section = ("" + $Matches["sec"]).Trim()
                    }
                }

                $missing = @()

                if (-not $hasAuth) { $missing += "missing: Authenticate" }
                if (-not $hasMaintenance) { $missing += "missing: MaintenanceMode" }
                if ($section -eq "") { $missing += "missing: EnsureSectionAccess:<section>" }

                if ($section -ne "") {
                    if ($section -eq "overview" -or $section -eq "tickets") {
                        if (-not $hasEnsureStaff) { $missing += ("missing: EnsureStaff (expected for section:" + $section + ")") }
                        if ($hasEnsureSuperadmin) { $missing += ("unexpected: EnsureSuperadmin (section:" + $section + " expects EnsureStaff)") }
                    } else {
                        if (-not $hasEnsureSuperadmin) { $missing += ("missing: EnsureSuperadmin (expected for section:" + $section + ")") }
                        if ($hasEnsureStaff) { $missing += ("unexpected: EnsureStaff (section:" + $section + " expects EnsureSuperadmin)") }
                    }
                } else {
                    if (-not $hasEnsureStaff -and -not $hasEnsureSuperadmin) {
                        $missing += "missing: EnsureStaff/EnsureSuperadmin (cannot infer without section)"
                    }
                }

                if ($missing.Count -gt 0) {
                    $rn = $name
                    if ($rn -eq "") { $rn = "<no-route-name>" }
                    $issues += ("Route: {0}  URI: {1}  Issues: {2}" -f $rn, $uri, ($missing -join "; "))
                }
            }
        }

        # ---------------------------------------------------------------------
        # SSOT SOURCE SCAN (Routes files): role-reads combined with "deny" patterns
        # Goal: detect distributed guard logic in routes/web/admin/*.php.
        # - We flag only when a file contains BOTH:
        #   (A) role reads (current user or target user role usage), AND
        #   (B) deny/guard patterns (abort_*, Gate::, authorize, can/cannot, policy)
        # - We ignore obvious comment-only lines (// ...), but do not attempt a full parser.
        # ---------------------------------------------------------------------
        $sourceScanIssues = @()

        try {
            $adminDir = Join-Path $root "routes\web\admin"
            if (Test-Path $adminDir) {
                $roleReadPatterns = @(
                    'auth\(\)\-\>user\(\)\?\-\>role',
                    'auth\(\)\-\>user\(\)\-\>role',
                    '\-\>role\b',
                    '\$isAdminRole',
                    '\$isStaffRole',
                    '\bisAdminLike\b',
                    '\bisStaffLike\b'
                )

                $denyPatterns = @(
                    'abort_(un)?less\s*\(',
                    'abort_if\s*\(',
                    '\bGate::',
                    '\b(can|cannot)\s*\(',
                    '\-\>authorize\s*\(',
                    '\bpolicy\s*\('
                )

                $files = Get-ChildItem $adminDir -Recurse -File -Filter *.php -ErrorAction Stop

                foreach ($f in $files) {
                    $roleMatches = @()
                    $denyMatches = @()

                    try {
                        $roleMatches = Select-String -Path $f.FullName -Pattern $roleReadPatterns -AllMatches -ErrorAction SilentlyContinue
                    } catch { $roleMatches = @() }

                    try {
                        $denyMatches = Select-String -Path $f.FullName -Pattern $denyPatterns -AllMatches -ErrorAction SilentlyContinue
                    } catch { $denyMatches = @() }

                    # filter comment-only lines (best effort)
                    $roleLines = @()
                    foreach ($m in @($roleMatches)) {
                        $lineText = ("" + $m.Line).Trim()
                        if ($lineText -like "//*") { continue }
                        $roleLines += $m
                    }

                    $denyLines = @()
                    foreach ($m in @($denyMatches)) {
                        $lineText = ("" + $m.Line).Trim()
                        if ($lineText -like "//*") { continue }
                        $denyLines += $m
                    }

                    if ($roleLines.Count -gt 0 -and $denyLines.Count -gt 0) {
                        $sample = @()

                        $sample += "File: " + $f.FullName
                        $sample += "  Role-reads:"
                        foreach ($m in ($roleLines | Select-Object -First 5)) {
                            $sample += ("    L{0}: {1}" -f $m.LineNumber, ("" + $m.Line).Trim())
                        }

                        $sample += "  Deny/guards:"
                        foreach ($m in ($denyLines | Select-Object -First 5)) {
                            $sample += ("    L{0}: {1}" -f $m.LineNumber, ("" + $m.Line).Trim())
                        }

                        $sourceScanIssues += ($sample -join "`n")
                    }
                }
            }
        } catch {
            # ignore scan errors (informative)
        }

        $sw.Stop()

        if ($ec -ne 0) {
            return & $new -Id "routes_verbose" -Title "1v) Routes verbose inspection" -Status "WARN" -Summary ("route:list -vv exit code: " + $ec) -Details $details -Data @{ exit_code = $ec } -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        $warnCount = 0
        if ($issues.Count -gt 0) { $warnCount += [int]$issues.Count }
        if ($sourceScanIssues.Count -gt 0) { $warnCount += [int]$sourceScanIssues.Count }

        if ($warnCount -gt 0) {
            $details2 = @()
            $details2 += $details

            if ($issues.Count -gt 0) {
                $details2 += ""
                $details2 += "--- STRICT MIDDLEWARE VALIDATION (WARN) ---"
                $details2 += $issues
            }

            if ($sourceScanIssues.Count -gt 0) {
                $details2 += ""
                $details2 += "--- SSOT SOURCE SCAN (role-reads + deny/guard patterns) (WARN) ---"
                $details2 += $sourceScanIssues
            }

            $summaryParts = @()
            if ($issues.Count -gt 0) { $summaryParts += ("middleware issues: " + $issues.Count) }
            if ($sourceScanIssues.Count -gt 0) { $summaryParts += ("source scan issues: " + $sourceScanIssues.Count) }

            return & $new -Id "routes_verbose" -Title "1v) Routes verbose inspection" -Status "WARN" -Summary ($summaryParts -join " | ") -Details $details2 -Data @{ exit_code = $ec; issues = $issues; source_scan_issues = $sourceScanIssues } -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        return & $new -Id "routes_verbose" -Title "1v) Routes verbose inspection" -Status "OK" -Summary "Verbose admin route listing captured; middleware validation OK." -Details $details -Data @{ exit_code = $ec } -DurationMs ([int]$sw.ElapsedMilliseconds)
    } catch {
        $sw.Stop()
        return & $new -Id "routes_verbose" -Title "1v) Routes verbose inspection" -Status "WARN" -Summary ("Verbose routes failed: " + $_.Exception.Message) -Details @() -Data @{} -DurationMs ([int]$sw.ElapsedMilliseconds)
    }
}