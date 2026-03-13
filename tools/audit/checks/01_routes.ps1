# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\01_routes.ps1
# Purpose: Audit check - routes / collisions / admin scope (deterministic)
# Created: 21-02-2026 00:06 (Europe/Berlin)
# Changed: 13-03-2026 23:16 (Europe/Berlin)
# Version: 0.6
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

    function Try-LoadAdminRoutesFromRouteListJson([string]$Root, [int]$TimeoutSec = 90) {
        try {
            $rj = $null
            try { $rj = & $run $Root @("route:list", "--path=admin", "--json", "--no-ansi", "--no-interaction") $TimeoutSec } catch { $rj = $null }
            if ($null -eq $rj) { return [pscustomobject]@{ ok = $false; routes = @(); note = "route:list --json could not be executed."; stderr = ""; exit_code = 0 } }

            $out = ""
            $err = ""
            $exitCode = 0
            try { $out = ("" + $rj.StdOut) } catch { $out = "" }
            try { $err = ("" + $rj.StdErr) } catch { $err = "" }
            try { $exitCode = [int]$rj.ExitCode } catch { $exitCode = 0 }

            if (($out.Trim() -eq "")) {
                return [pscustomobject]@{ ok = $false; routes = @(); note = "route:list --json returned empty output."; stderr = $err; exit_code = $exitCode }
            }

            $obj = $null
            try { $obj = ($out.Trim()) | ConvertFrom-Json -ErrorAction Stop } catch { $obj = $null }
            if ($null -eq $obj) {
                return [pscustomobject]@{ ok = $false; routes = @(); note = "route:list --json output not parseable as JSON."; stderr = $err; exit_code = $exitCode }
            }

            $items = @()
            if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
                $items = @($obj)
            } elseif ($obj.PSObject -and ($obj.PSObject.Properties.Name -contains "routes")) {
                $items = @($obj.routes)
            } else {
                $items = @()
            }

            $routes = New-Object System.Collections.Generic.List[object]
            foreach ($it in @($items)) {
                if ($null -eq $it) { continue }

                $methods = ""
                $uri = ""
                $name = ""

                try {
                    if ($it.PSObject -and ($it.PSObject.Properties.Name -contains "method")) { $methods = ("" + $it.method).Trim() }
                    elseif ($it.PSObject -and ($it.PSObject.Properties.Name -contains "methods")) { $methods = ("" + $it.methods).Trim() }
                } catch { $methods = "" }

                try {
                    if ($it.PSObject -and ($it.PSObject.Properties.Name -contains "uri")) { $uri = ("" + $it.uri).Trim() }
                } catch { $uri = "" }

                try {
                    if ($it.PSObject -and ($it.PSObject.Properties.Name -contains "name")) { $name = ("" + $it.name).Trim() }
                } catch { $name = "" }

                if ($methods -eq "" -and $uri -eq "" -and $name -eq "") { continue }

                $routes.Add([pscustomobject]@{
                    methods = $methods
                    uri     = $uri
                    name    = $name
                }) | Out-Null
            }

            return [pscustomobject]@{ ok = $true; routes = @($routes.ToArray()); note = "route:list --json"; stderr = $err; exit_code = $exitCode }
        } catch {
            return [pscustomobject]@{ ok = $false; routes = @(); note = ("route:list --json exception: " + $_.Exception.Message); stderr = ""; exit_code = 0 }
        }
    }

    function Parse-AdminRoutesFromRouteListText([string]$Text) {
        $routes = New-Object System.Collections.Generic.List[object]
        try {
            foreach ($raw in @($Text -split "`r?`n")) {
                $line = ("" + $raw)
                if ($line.Trim() -eq "") { continue }

                $flat = ($line -replace "\s+", " ").Trim()

                # Typical table line starts with methods + uri + ... + name ...
                if ($flat -match "^(?<methods>(?:GET|HEAD|POST|PUT|PATCH|DELETE|OPTIONS)(?:\|(?:GET|HEAD|POST|PUT|PATCH|DELETE|OPTIONS))*)\s+(?<uri>\S+)\s") {
                    $methodsRaw = ("" + $Matches["methods"]).Trim()
                    $u = ("" + $Matches["uri"]).Trim()

                    $n = ""
                    if ($flat -match "\s(admin\.[A-Za-z0-9\._-]+)\s") {
                        $n = ("" + $Matches[1]).Trim()
                    }

                    $routes.Add([pscustomobject]@{
                        methods = $methodsRaw
                        uri     = $u
                        name    = $n
                    }) | Out-Null
                }
            }
        } catch { }
        return @($routes.ToArray())
    }

    $r = $null
    $stdout = ""
    $stderr = ""
    $exitCode = 0
    $routeSource = ""

    $jsonTry = Try-LoadAdminRoutesFromRouteListJson -Root $root -TimeoutSec 90
    $routes = @()
    if ($jsonTry.ok) {
        $routes = @($jsonTry.routes)
        $routeSource = ("" + $jsonTry.note).Trim()
        try { $stderr = ("" + $jsonTry.stderr) } catch { $stderr = "" }
        try { $exitCode = [int]$jsonTry.exit_code } catch { $exitCode = 0 }
        try { $stdout = "" } catch { $stdout = "" }
    } else {
        try {
            $r = & $run $root @("route:list", "--path=admin", "--no-ansi", "--no-interaction") 90
        } catch {
            $sw.Stop()
            return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "CRITICAL" -Summary ("route:list failed: " + $_.Exception.Message) -Details @() -Data @{} -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        try { $stdout = ("" + $r.StdOut) } catch { $stdout = "" }
        try { $stderr = ("" + $r.StdErr) } catch { $stderr = "" }
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

        $routes = @(Parse-AdminRoutesFromRouteListText -Text $stdout)
        $routeSource = "route:list (text parse)"
    }

    # Collect route names and admin URIs from parsed routes.
    $names = New-Object System.Collections.Generic.List[string]
    $uris  = New-Object System.Collections.Generic.List[string]
    $methodUriKeys = New-Object System.Collections.Generic.List[string]
    $nonAdminUris = New-Object System.Collections.Generic.List[string]

    foreach ($rt in @($routes)) {
        if ($null -eq $rt) { continue }

        $methodsRaw = ""
        $u = ""
        $n = ""

        try { $methodsRaw = ("" + $rt.methods).Trim() } catch { $methodsRaw = "" }
        try { $u = ("" + $rt.uri).Trim() } catch { $u = "" }
        try { $n = ("" + $rt.name).Trim() } catch { $n = "" }

        if ($n -ne "") { $names.Add($n) | Out-Null }

        if ($u -ne "") {
            $uris.Add($u) | Out-Null

            $methodParts = @()
            if ($methodsRaw -ne "") {
                try { $methodParts = @($methodsRaw -split '\|') } catch { $methodParts = @($methodsRaw) }
            } else {
                $methodParts = @()
            }

            foreach ($m in @($methodParts)) {
                $mm = ("" + $m).Trim().ToUpper()
                if ($mm -eq "") { continue }
                $methodUriKeys.Add(($mm + "|" + $u)) | Out-Null
            }

            if (-not ($u -like "admin*")) {
                $nonAdminUris.Add($u) | Out-Null
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
    $dupMethodUris = Get-DupGroups ($methodUriKeys.ToArray())

    $dupAdminUsersUserCount = 0
    foreach ($g in @($dupMethodUris)) {
        $nKey = ("" + $g.Name).Trim()
        if ($nKey -match '^[A-Z]+\|admin/users/\{user\}$') {
            $dupAdminUsersUserCount = [int]$g.Count
            break
        }
    }

    $details = @()
    $data = @{
        route_list_exit_code = $exitCode
        route_source         = $routeSource
        admin_routes_parsed  = [int]($uris.Count)
        admin_names_parsed   = [int]($names.Count)
        dup_name_count       = [int](@($dupNames).Count)
        dup_method_uri_count = [int](@($dupMethodUris).Count)
        dup_admin_users_user_count = [int]$dupAdminUsersUserCount
        non_admin_uri_count  = [int]($nonAdminUris.Count)
    }

    if ($stderr -and $stderr.Trim() -ne "") {
        $details += ("STDERR: " + $stderr.Trim())
    }
    if ($routeSource -and $routeSource.Trim() -ne "") {
        $details += ("Route source: " + $routeSource)
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

    if (@($dupMethodUris).Count -gt 0) {
        $details += "Duplicate Method+URI pairs detected:"
        foreach ($g in (@($dupMethodUris) | Select-Object -First 12)) {
            $pair = ("" + $g.Name)
            $method = ""
            $uri = $pair
            if ($pair -match '^(?<method>[A-Z]+)\|(?<uri>.+)$') {
                $method = ("" + $Matches["method"]).Trim()
                $uri = ("" + $Matches["uri"]).Trim()
            }
            if ($method -ne "") {
                $details += ("  " + $method + " " + $uri + " (x" + $g.Count + ")")
            } else {
                $details += ("  " + $pair + " (x" + $g.Count + ")")
            }
        }
        if (@($dupMethodUris).Count -gt 12) { $details += ("  ... (" + (@($dupMethodUris).Count - 12) + " more)") }
    }

    if ($dupAdminUsersUserCount -ge 2) {
        $details += ("WARN: duplicate Method+URI for 'admin/users/{user}' detected (x" + $dupAdminUsersUserCount + ").")
    }

    $sw.Stop()

    if ($nonAdminUris.Count -gt 0) {
        return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "FAIL" -Summary "Admin route scope mismatch detected." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if (@($dupNames).Count -gt 0 -or @($dupMethodUris).Count -gt 0) {
        return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "FAIL" -Summary "Route collisions detected (duplicate names and/or Method+URI)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($uris.Count -le 0) {
        return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "WARN" -Summary "No admin routes found via route:list --path=admin." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    return & $new -Id "routes" -Title "1) Routes / collisions / admin scope" -Status "OK" -Summary ("Parsed " + $uris.Count + " admin routes; no collisions.") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
}
