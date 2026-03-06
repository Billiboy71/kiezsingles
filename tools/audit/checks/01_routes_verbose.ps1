# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\01_routes_verbose.ps1
# Purpose: Audit check - verbose route inspection (informative)
# Created: 21-02-2026 00:10 (Europe/Berlin)
# Changed: 04-03-2026 22:56 (Europe/Berlin)
# Version: 0.7
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

    function Normalize-MiddlewareToken([string]$s) {
        if ($null -eq $s) { return "" }
        $t = ("" + $s).Trim()
        if ($t -eq "") { return "" }
        $t = $t.Trim(',', ';', '[', ']', '(', ')')
        $t = $t.Trim()
        return $t
    }

    function Try-LoadAdminRoutesFromRouteListJson([string]$Root, [int]$TimeoutSec = 120) {
        try {
            $rj = $null
            try { $rj = & $run $Root @("route:list", "--path=admin", "--json", "--no-ansi", "--no-interaction") $TimeoutSec } catch { $rj = $null }
            if ($null -eq $rj) { return [pscustomobject]@{ ok = $false; routes = @(); note = "route:list --json could not be executed." } }

            $out = ""
            try { $out = ("" + $rj.StdOut).Trim() } catch { $out = "" }
            if ($out -eq "") { return [pscustomobject]@{ ok = $false; routes = @(); note = "route:list --json returned empty output." } }

            $obj = $null
            try { $obj = $out | ConvertFrom-Json -ErrorAction Stop } catch { $obj = $null }
            if ($null -eq $obj) { return [pscustomobject]@{ ok = $false; routes = @(); note = "route:list --json output not parseable as JSON." } }

            $items = @()
            if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
                $items = @($obj)
            } elseif ($obj.PSObject -and ($obj.PSObject.Properties.Name -contains "routes")) {
                $items = @($obj.routes)
            } else {
                $items = @()
            }

            if ($items.Count -le 0) { return [pscustomobject]@{ ok = $true; routes = @(); note = "route:list --json parsed but no routes found." } }

            $routes = New-Object System.Collections.Generic.List[object]
            foreach ($it in @($items)) {
                if ($null -eq $it) { continue }

                $uri = ""
                $name = ""
                $mw = @()

                try {
                    if ($it.PSObject -and ($it.PSObject.Properties.Name -contains "uri")) { $uri = ("" + $it.uri).Trim() }
                } catch { $uri = "" }

                try {
                    if ($it.PSObject -and ($it.PSObject.Properties.Name -contains "name")) { $name = ("" + $it.name).Trim() }
                } catch { $name = "" }

                try {
                    if ($it.PSObject -and ($it.PSObject.Properties.Name -contains "middleware")) {
                        $mwRaw = $it.middleware
                        if ($mwRaw -is [string]) {
                            $mw = @($mwRaw -split "[,\s]+" | ForEach-Object { Normalize-MiddlewareToken $_ } | Where-Object { $_ -ne "" })
                        } else {
                            $mw = @($mwRaw | ForEach-Object { Normalize-MiddlewareToken $_ } | Where-Object { $_ -ne "" })
                        }
                    }
                } catch { $mw = @() }

                if ($uri -eq "" -and $name -eq "" -and @($mw).Count -eq 0) { continue }

                $routes.Add([pscustomobject]@{
                    Uri = $uri
                    Name = $name
                    Middleware = @($mw)
                }) | Out-Null
            }

            return [pscustomobject]@{ ok = $true; routes = @($routes.ToArray()); note = "route:list --json" }
        } catch {
            return [pscustomobject]@{ ok = $false; routes = @(); note = ("route:list --json exception: " + $_.Exception.Message) }
        }
    }

    function Parse-AdminRoutesFromRouteListVerboseText([string]$Text) {
        $routes = New-Object System.Collections.Generic.List[object]
        try {
            $cur = $null
            foreach ($line in @($Text -split "`r?`n")) {
                $l = ("" + $line)

                # Route header line (e.g. "GET|HEAD   admin .... admin.home")
                if ($l -match '^\s*[A-Z\|]+\s+admin(\S*)\s+\.+') {
                    if ($null -ne $cur) { $routes.Add($cur) | Out-Null }

                    $routeName = ""
                    $uri = ""

                    try {
                        if ($l -match '^\s*[A-Z\|]+\s+(admin[^\s]*)\s+\.+') {
                            $uri = ("" + $Matches[1]).Trim()
                        }

                        $idx = $l.IndexOf("admin.")
                        if ($idx -ge 0) {
                            $tail = $l.Substring($idx).Trim()
                            $cut = $tail.IndexOf(" › ")
                            if ($cut -ge 0) { $tail = $tail.Substring(0, $cut).Trim() }
                            $parts = $tail -split '\s+'
                            if ($parts.Count -gt 0) { $routeName = ("" + $parts[0]).Trim() }
                        }
                    } catch {
                        $routeName = ""
                        $uri = ""
                    }

                    $cur = [pscustomobject]@{
                        Uri = $uri
                        Name = $routeName
                        Middleware = New-Object System.Collections.Generic.List[string]
                    }
                    continue
                }

                if ($null -eq $cur) { continue }

                $trim = ("" + $l).Trim()
                if ($trim -eq "") { continue }

                # Preferred: "Middleware: a, b, c"
                if ($trim -match '^(?i)Middleware\s*:\s*(?<mw>.+)$') {
                    $mwText = ("" + $Matches["mw"]).Trim()
                    if ($mwText -ne "") {
                        $parts = @($mwText -split "[,]+" | ForEach-Object { Normalize-MiddlewareToken $_ } | Where-Object { $_ -ne "" })
                        foreach ($p in @($parts)) { $cur.Middleware.Add($p) | Out-Null }
                    }
                    continue
                }

                # Fallback: last token is often class name; keep encoding-safe behavior
                $tokens = $trim -split '\s+'
                if ($tokens.Count -gt 0) {
                    $last = Normalize-MiddlewareToken ("" + $tokens[$tokens.Count - 1])
                    if ($last -ne "" -and ($last -like "Illuminate\*" -or $last -like "App\*")) {
                        $cur.Middleware.Add($last) | Out-Null
                        continue
                    }
                }
            }

            if ($null -ne $cur) { $routes.Add($cur) | Out-Null }
        } catch { }

        return @($routes.ToArray())
    }

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
        # Primary: route:list --json (middleware list)
        # Fallback: route:list -vv text parse (encoding-safe + Middleware: lines)
        # ---------------------------------------------------------------------
        $issues = @()

        $routes = @()
        $routeSourceNote = ""

        $jsonTry = Try-LoadAdminRoutesFromRouteListJson -Root $root -TimeoutSec 120
        if ($jsonTry.ok) {
            $routes = @($jsonTry.routes)
            $routeSourceNote = ("" + $jsonTry.note).Trim()
        } else {
            if ($out -ne "") {
                $routes = @(Parse-AdminRoutesFromRouteListVerboseText -Text $out)
                $routeSourceNote = "route:list -vv (text parse)"
            } else {
                $routes = @()
                $routeSourceNote = "no routes available (json failed; -vv empty)"
            }
        }

        if (@($routes).Count -gt 0) {
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
                    $mm = ("" + $m)

                    if ($mm -like "*Illuminate\Auth\Middleware\Authenticate*" -or ($mm -ieq "auth")) { $hasAuth = $true }
                    if ($mm -like "*App\Http\Middleware\MaintenanceMode*" -or ($mm -ieq "maintenance")) { $hasMaintenance = $true }
                    if ($mm -like "*App\Http\Middleware\EnsureStaff*" -or ($mm -match '(?i)\bensurestaff\b')) { $hasEnsureStaff = $true }
                    if ($mm -like "*App\Http\Middleware\EnsureSuperadmin*" -or ($mm -match '(?i)\bensuresuperadmin\b')) { $hasEnsureSuperadmin = $true }

                    if ($mm -match 'EnsureSectionAccess:(?<sec>[a-z0-9_]+)') {
                        $section = ("" + $Matches["sec"]).Trim()
                    }
                }

                $missing = @()
                $skipEnsureSectionAccessRequirement = (($name -ieq "admin.settings.layout_outlines") -or ($uri -ieq "admin/settings/layout-outlines"))

                if (-not $hasAuth) { $missing += "missing: Authenticate" }
                if (-not $hasMaintenance) { $missing += "missing: MaintenanceMode" }
                if ($section -eq "" -and -not $skipEnsureSectionAccessRequirement) { $missing += "missing: EnsureSectionAccess:<section>" }

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

            $details2 += ""
            $details2 += ("Route source (strict validation): " + $routeSourceNote)

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

            return & $new -Id "routes_verbose" -Title "1v) Routes verbose inspection" -Status "WARN" -Summary ($summaryParts -join " | ") -Details $details2 -Data @{
                exit_code = $ec
                issues = $issues
                source_scan_issues = $sourceScanIssues
                strict_route_source = $routeSourceNote
            } -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        $detailsOk = @()
        $detailsOk += $details
        $detailsOk += ""
        $detailsOk += ("Route source (strict validation): " + $routeSourceNote)

        return & $new -Id "routes_verbose" -Title "1v) Routes verbose inspection" -Status "OK" -Summary "Verbose admin route listing captured; middleware validation OK." -Details $detailsOk -Data @{ exit_code = $ec; strict_route_source = $routeSourceNote } -DurationMs ([int]$sw.ElapsedMilliseconds)
    } catch {
        $sw.Stop()
        return & $new -Id "routes_verbose" -Title "1v) Routes verbose inspection" -Status "WARN" -Summary ("Verbose routes failed: " + $_.Exception.Message) -Details @() -Data @{} -DurationMs ([int]$sw.ElapsedMilliseconds)
    }
}