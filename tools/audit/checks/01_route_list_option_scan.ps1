# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\01_route_list_option_scan.ps1
# Purpose: Audit check - scan project for route:list usage with --columns / --format
# Created: 13-03-2026 02:35 (Europe/Berlin)
# Changed: 13-03-2026 21:26 (Europe/Berlin)
# Version: 0.2
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_RouteListOptionScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $new = $Context.Helpers.NewAuditResult
    $root = $Context.ProjectRoot
    $scanFullProject = $false
    try { $scanFullProject = [bool]$Context.RouteListOptionScanFullProject } catch { $scanFullProject = $false }

    try {
        & $Context.Helpers.WriteSection "1x) route:list option scan (--columns / --format)"

        function Normalize-PathForCompare {
            param([string]$PathValue)

            try {
                if ($null -eq $PathValue) { return "" }
                $p = ("" + $PathValue).Trim()
                if ($p -eq "") { return "" }
                return $p.Replace('/', '\').Trim().ToLowerInvariant()
            } catch {
                return ""
            }
        }

        function Test-PathExcluded {
            param(
                [string]$FullPath,
                [string[]]$ExcludedPaths
            )

            $norm = Normalize-PathForCompare $FullPath
            if ($norm -eq "") { return $false }

            foreach ($ex in @($ExcludedPaths)) {
                $en = Normalize-PathForCompare $ex
                if ($en -eq "") { continue }

                if ($norm -eq $en) { return $true }
                if ($norm.StartsWith($en + "\")) { return $true }
            }

            return $false
        }

        function Get-ScanRoots {
            param(
                [string]$ProjectRoot,
                [bool]$FullProject
            )

            $items = New-Object System.Collections.Generic.List[string]

            if ($FullProject) {
                $items.Add($ProjectRoot) | Out-Null
                return @($items.ToArray())
            }

            $preferred = @(
                (Join-Path $ProjectRoot ".vscode"),
                (Join-Path $ProjectRoot "tools"),
                (Join-Path $ProjectRoot "scripts"),
                (Join-Path $ProjectRoot "composer.json"),
                (Join-Path $ProjectRoot "package.json")
            )

            foreach ($p in @($preferred)) {
                if (Test-Path -LiteralPath $p) {
                    $items.Add($p) | Out-Null
                }
            }

            return @($items.ToArray())
        }

        function Get-ExcludedPaths {
            param(
                [string]$ProjectRoot,
                [bool]$FullProject
            )

            $items = New-Object System.Collections.Generic.List[string]

            $items.Add((Join-Path $ProjectRoot "tools\audit\ks-admin-audit.ps1")) | Out-Null
            $items.Add((Join-Path $ProjectRoot "tools\audit\checks")) | Out-Null

            if ($FullProject) {
                $items.Add((Join-Path $ProjectRoot "vendor")) | Out-Null
                $items.Add((Join-Path $ProjectRoot "node_modules")) | Out-Null
                $items.Add((Join-Path $ProjectRoot "storage")) | Out-Null
                $items.Add((Join-Path $ProjectRoot "bootstrap\cache")) | Out-Null
                $items.Add((Join-Path $ProjectRoot ".git")) | Out-Null
            }

            return @($items.ToArray())
        }

        function Get-FileCandidates {
            param(
                [string[]]$ScanRoots,
                [string[]]$ExcludedPaths
            )

            $files = New-Object System.Collections.Generic.List[string]
            $seen = @{}

            foreach ($rootItem in @($ScanRoots)) {
                if (-not (Test-Path -LiteralPath $rootItem)) { continue }

                $item = Get-Item -LiteralPath $rootItem -ErrorAction SilentlyContinue
                if ($null -eq $item) { continue }

                if ($item.PSIsContainer) {
                    $childFiles = @()
                    try {
                        $childFiles = @(Get-ChildItem -LiteralPath $item.FullName -Recurse -File -ErrorAction SilentlyContinue)
                    } catch {
                        $childFiles = @()
                    }

                    foreach ($f in @($childFiles)) {
                        $full = ""
                        try { $full = ("" + $f.FullName).Trim() } catch { $full = "" }
                        if ($full -eq "") { continue }
                        if (Test-PathExcluded -FullPath $full -ExcludedPaths $ExcludedPaths) { continue }

                        $norm = Normalize-PathForCompare $full
                        if ($norm -eq "") { continue }
                        if ($seen.ContainsKey($norm)) { continue }
                        $seen[$norm] = $true
                        $files.Add($full) | Out-Null
                    }
                } else {
                    $full = ""
                    try { $full = ("" + $item.FullName).Trim() } catch { $full = "" }
                    if ($full -eq "") { continue }
                    if (Test-PathExcluded -FullPath $full -ExcludedPaths $ExcludedPaths) { continue }

                    $norm = Normalize-PathForCompare $full
                    if ($norm -eq "") { continue }
                    if ($seen.ContainsKey($norm)) { continue }
                    $seen[$norm] = $true
                    $files.Add($full) | Out-Null
                }
            }

            return @($files.ToArray())
        }

        function Test-LikelyRouteListOptionUsage {
            param(
                [string[]]$Lines,
                [int]$Index
            )

            if ($null -eq $Lines -or $Index -lt 0 -or $Index -ge $Lines.Count) { return $false }

            $start = [Math]::Max(0, $Index - 5)
            $end = [Math]::Min(($Lines.Count - 1), $Index + 5)

            $foundRouteList = $false
            $foundOption = $false

            for ($i = $start; $i -le $end; $i++) {
                $line = ""
                try { $line = ("" + $Lines[$i]) } catch { $line = "" }
                if ($line -eq "") { continue }

                if ($line -match '(?i)\broute:list\b') {
                    $foundRouteList = $true
                }

                if ($line -match '(?i)--columns\b' -or $line -match '(?i)--format(?:=|\s+json|\s+\w+)') {
                    $foundOption = $true
                }
            }

            return ($foundRouteList -and $foundOption)
        }

        function Build-ContextSnippet {
            param(
                [string[]]$Lines,
                [int]$Index
            )

            $out = New-Object System.Collections.Generic.List[string]
            if ($null -eq $Lines -or $Index -lt 0 -or $Index -ge $Lines.Count) { return @() }

            $start = [Math]::Max(0, $Index - 5)
            $end = [Math]::Min(($Lines.Count - 1), $Index + 5)

            for ($i = $start; $i -le $end; $i++) {
                $line = ""
                try { $line = ("" + $Lines[$i]) } catch { $line = "" }
                $displayNo = $i + 1
                $out.Add(("  L{0}: {1}" -f $displayNo, $line)) | Out-Null
            }

            return @($out.ToArray())
        }

        $scanRoots = @(Get-ScanRoots -ProjectRoot $root -FullProject $scanFullProject)
        $excludedPaths = @(Get-ExcludedPaths -ProjectRoot $root -FullProject $scanFullProject)
        $files = @(Get-FileCandidates -ScanRoots $scanRoots -ExcludedPaths $excludedPaths)

        $matches = New-Object System.Collections.Generic.List[object]

        foreach ($file in @($files)) {
            $contentLines = @()
            try {
                $contentLines = @(Get-Content -LiteralPath $file -ErrorAction Stop)
            } catch {
                continue
            }

            for ($i = 0; $i -lt $contentLines.Count; $i++) {
                $line = ""
                try { $line = ("" + $contentLines[$i]) } catch { $line = "" }
                if ($line -eq "") { continue }

                $looksRelevant = $false
                if ($line -match '(?i)\broute:list\b') { $looksRelevant = $true }
                if ($line -match '(?i)--columns\b') { $looksRelevant = $true }
                if ($line -match '(?i)--format\b') { $looksRelevant = $true }

                if (-not $looksRelevant) { continue }
                if (-not (Test-LikelyRouteListOptionUsage -Lines $contentLines -Index $i)) { continue }

                $matches.Add([pscustomobject]@{
                    file = $file
                    line_index = $i
                    snippet = @(Build-ContextSnippet -Lines $contentLines -Index $i)
                }) | Out-Null

                break
            }
        }

        $details = @()

        $scanRootsDisplay = @()
        foreach ($p in @($scanRoots)) {
            $rel = $p
            try {
                if ($p.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $rel = $p.Substring($root.Length).TrimStart('\')
                    if ($rel -eq "") { $rel = "." }
                }
            } catch { }
            $scanRootsDisplay += $rel
        }

        if ($matches.Count -gt 0) {
            $details += ("Found potential callers (scan roots: " + (($scanRootsDisplay | ForEach-Object { "" + $_ }) -join ", ") + "; excludes tools/audit/ks-admin-audit.ps1 and tools/audit/checks/*" + $(if ($scanFullProject) { ", vendor, node_modules, storage, bootstrap/cache, .git" } else { "" }) + ").")
            $details += "Only showing likely invocations (route:list with --columns/--format on same line or within +/- 5 lines)."
            $details += ""

            foreach ($m in @($matches)) {
                $details += ("File: " + $m.file)
                foreach ($s in @($m.snippet)) {
                    $details += ("" + $s)
                }
                $details += ""
            }

            $sw.Stop()
            return & $new -Id "route_list_option_scan" -Title "1x) route:list option scan (--columns / --format)" -Status "WARN" -Summary ("Found " + $matches.Count + " potential caller file(s) using route:list with '--columns'/'--format'.") -Details $details -Data @{
                scan_full_project = [bool]$scanFullProject
                scan_roots = @($scanRootsDisplay)
                match_count = [int]$matches.Count
                files = @($matches | ForEach-Object { $_.file })
            } -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        $details += ("Scan roots: " + (($scanRootsDisplay | ForEach-Object { "" + $_ }) -join ", "))
        $details += "No likely route:list callers with --columns/--format found."

        $sw.Stop()
        return & $new -Id "route_list_option_scan" -Title "1x) route:list option scan (--columns / --format)" -Status "OK" -Summary "No likely route:list callers with '--columns'/'--format' found." -Details $details -Data @{
            scan_full_project = [bool]$scanFullProject
            scan_roots = @($scanRootsDisplay)
            match_count = 0
            files = @()
        } -DurationMs ([int]$sw.ElapsedMilliseconds)
    } catch {
        try { $sw.Stop() } catch { }

        return & $new `
            -Id "route_list_option_scan" `
            -Title "1x) route:list option scan (--columns / --format)" `
            -Status "FAIL" `
            -Summary ("Internal exception during route:list option scan: " + $_.Exception.Message) `
            -Details @(
                "Exception type: " + $_.Exception.GetType().FullName,
                "Message: " + $_.Exception.Message
            ) `
            -Data @{
                exception = $_.Exception.Message
            } `
            -DurationMs ([int]$sw.ElapsedMilliseconds)
    }
}
