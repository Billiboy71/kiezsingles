# ============================================================================
# File: C:\laragon\www\kiezsingles\scripts\ks-admin-route-guard-audit.ps1
# Purpose: Audit admin routes for expected middleware (auth/staff/superadmin + section:*) via artisan route:list
# Changed: 23-02-2026 00:53 (Europe/Berlin)
# Version: 0.1
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host "`n=== ADMIN ROUTE GUARD AUDIT (middleware expectations) ===`n"

function Normalize-MiddlewareList {
    param([string]$Raw)

    if (-not $Raw) { return @() }

    # route:list middleware is usually like: "web, auth, staff, section:overview"
    # sometimes separated by "|" or "," depending on environment/output
    $parts = $Raw -split '[,\|]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    return @($parts | ForEach-Object { $_.ToLowerInvariant() })
}

function Has-All {
    param(
        [string[]]$Have,
        [string[]]$Need
    )
    foreach ($n in $Need) {
        if (-not ($Have -contains $n)) { return $false }
    }
    return $true
}

function Has-Any {
    param(
        [string[]]$Have,
        [string[]]$Need
    )
    foreach ($n in $Need) {
        if ($Have -contains $n) { return $true }
    }
    return $false
}

function Get-ExpectedByNameOrUri {
    param(
        [string]$Name,
        [string]$Uri
    )

    $name = ($Name ?? "").ToLowerInvariant()
    $uri  = ($Uri  ?? "").ToLowerInvariant()

    # Defaults: we only assert the core guards + section:* conventions.
    # "web" etc. are intentionally not enforced.
    $expected = @{
        Need = @()
        Forbid = @()
        Bucket = "unknown"
    }

    if ($name -ne "") {
        if ($name -eq "admin.home" -or $name -eq "admin.overview") {
            $expected.Need   = @("auth", "staff", "section:overview")
            $expected.Forbid = @("superadmin")
            $expected.Bucket = "staff/overview"
            return $expected
        }

        if ($name.StartsWith("admin.tickets")) {
            $expected.Need   = @("auth", "staff", "section:tickets")
            $expected.Forbid = @("superadmin")
            $expected.Bucket = "staff/tickets"
            return $expected
        }

        if ($name.StartsWith("admin.debug") -or $name.StartsWith("admin.status")) {
            $expected.Need   = @("auth", "superadmin", "section:debug")
            $expected.Forbid = @("staff")
            $expected.Bucket = "superadmin/debug"
            return $expected
        }

        if ($name.StartsWith("admin.moderation")) {
            $expected.Need   = @("auth", "superadmin", "section:moderation")
            $expected.Forbid = @("staff")
            $expected.Bucket = "superadmin/moderation"
            return $expected
        }

        if ($name.StartsWith("admin.roles")) {
            $expected.Need   = @("auth", "superadmin", "section:roles")
            $expected.Forbid = @("staff")
            $expected.Bucket = "superadmin/roles"
            return $expected
        }

        # Wartung: deine Maintenance-Section enthält auch settings/noteinstieg (laut routes/web/admin.php)
        if ($name.StartsWith("admin.maintenance") -or $name.Contains(".settings") -or $name.Contains(".noteinstieg")) {
            $expected.Need   = @("auth", "superadmin", "section:maintenance")
            $expected.Forbid = @("staff")
            $expected.Bucket = "superadmin/maintenance"
            return $expected
        }
    }

    # Fallback über URI, falls Name leer/ungewöhnlich.
    if ($uri -eq "admin" -or $uri -eq "admin/" -or $uri -eq "/admin") {
        $expected.Need   = @("auth", "staff", "section:overview")
        $expected.Forbid = @("superadmin")
        $expected.Bucket = "staff/overview"
        return $expected
    }

    if ($uri.StartsWith("admin/tickets")) {
        $expected.Need   = @("auth", "staff", "section:tickets")
        $expected.Forbid = @("superadmin")
        $expected.Bucket = "staff/tickets"
        return $expected
    }

    if ($uri.StartsWith("admin/debug") -or $uri.StartsWith("admin/status")) {
        $expected.Need   = @("auth", "superadmin", "section:debug")
        $expected.Forbid = @("staff")
        $expected.Bucket = "superadmin/debug"
        return $expected
    }

    if ($uri.StartsWith("admin/moderation")) {
        $expected.Need   = @("auth", "superadmin", "section:moderation")
        $expected.Forbid = @("staff")
        $expected.Bucket = "superadmin/moderation"
        return $expected
    }

    if ($uri.StartsWith("admin/roles")) {
        $expected.Need   = @("auth", "superadmin", "section:roles")
        $expected.Forbid = @("staff")
        $expected.Bucket = "superadmin/roles"
        return $expected
    }

    if ($uri.StartsWith("admin/maintenance") -or $uri.StartsWith("admin/settings") -or $uri.StartsWith("admin/noteinstieg")) {
        $expected.Need   = @("auth", "superadmin", "section:maintenance")
        $expected.Forbid = @("staff")
        $expected.Bucket = "superadmin/maintenance"
        return $expected
    }

    return $expected
}

function Extract-JsonFromArtisanOutput {
    param([string[]]$Lines)

    if (-not $Lines -or $Lines.Count -lt 1) { return $null }

    # Find first line that looks like JSON start and try to join from there.
    $startIdx = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $t = ($Lines[$i] ?? "").TrimStart()
        if ($t.StartsWith("[") -or $t.StartsWith("{")) {
            $startIdx = $i
            break
        }
    }
    if ($startIdx -lt 0) { return $null }

    $json = ($Lines[$startIdx..($Lines.Count - 1)] -join "`n").Trim()
    if ($json -eq "") { return $null }

    return $json
}

# Prefer JSON if available; otherwise fallback to text table parsing.
# We intentionally avoid relying on a specific Laravel/Artisan JSON switch behavior.
$cmd = @(
    "php", "artisan", "route:list",
    "--path=admin",
    "-vv"
)

Write-Host "Running: $($cmd -join ' ')" -ForegroundColor DarkGray

# Capture stdout+stderr (some environments print INFO to stdout)
$rawLines = & $cmd[0] $cmd[1] $cmd[2] $cmd[3] $cmd[4] $cmd[5] 2>&1 | ForEach-Object { "$_" }

if (-not $rawLines -or $rawLines.Count -lt 1) {
    Write-Host "❌ No output from artisan route:list. Are you in the project root?" -ForegroundColor Red
    exit 1
}

# Try JSON mode first (some Laravel versions accept --format=json, some don't).
# If supported, this is best. If not, it will likely print a normal table and we fall back.
$jsonRoutes = $null
try {
    $rawJsonLines = & php artisan route:list --path=admin -vv --format=json 2>&1 | ForEach-Object { "$_" }
    $jsonText = Extract-JsonFromArtisanOutput -Lines $rawJsonLines
    if ($jsonText) {
        $jsonRoutes = $jsonText | ConvertFrom-Json
    }
} catch {
    $jsonRoutes = $null
}

$routes = @()

if ($jsonRoutes) {
    foreach ($r in $jsonRoutes) {
        $routes += [pscustomobject]@{
            Method     = ($r.method ?? $r.methods ?? "")
            Uri        = ($r.uri ?? "")
            Name       = ($r.name ?? "")
            Middleware = ($r.middleware ?? "")
        }
    }
    Write-Host "Parsed routes from JSON output." -ForegroundColor Green
} else {
    # Fallback: parse table-ish output. We do a best-effort parse:
    # We look for lines starting with HTTP method(s) and containing an "admin" URI.
    $tableLines = $rawLines | Where-Object {
        $l = ($_ ?? "")
        $l -match '^\s*(GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD)\b' -and $l -match '\badmin\b'
    }

    foreach ($l in $tableLines) {
        # Typical format:
        # GET|HEAD  admin  admin.home  web,auth,staff,section:overview
        # or with columns aligned.
        $clean = ($l -replace '\s{2,}', "`t").Trim()
        $cols = $clean -split "`t"

        if ($cols.Count -lt 3) { continue }

        $method = $cols[0].Trim()
        $uri    = $cols[1].Trim()
        $name   = ""
        $mw     = ""

        if ($cols.Count -ge 4) {
            $name = $cols[2].Trim()
            $mw   = ($cols[3..($cols.Count - 1)] -join " ").Trim()
        } else {
            # No middleware column? Keep empty
            $name = $cols[2].Trim()
            $mw   = ""
        }

        $routes += [pscustomobject]@{
            Method     = $method
            Uri        = $uri
            Name       = $name
            Middleware = $mw
        }
    }

    if ($routes.Count -eq 0) {
        Write-Host "❌ Could not parse any admin routes from artisan output." -ForegroundColor Red
        Write-Host "Raw output (first 40 lines):" -ForegroundColor DarkGray
        $rawLines | Select-Object -First 40 | ForEach-Object { Write-Host $_ }
        exit 1
    }

    Write-Host "Parsed routes from text output (fallback)." -ForegroundColor Yellow
}

# Audit
$issues = @()
$ok = 0
$total = 0

foreach ($r in $routes) {
    $total++

    $mw = Normalize-MiddlewareList -Raw ($r.Middleware ?? "")
    $expected = Get-ExpectedByNameOrUri -Name ($r.Name ?? "") -Uri ($r.Uri ?? "")

    if ($expected.Bucket -eq "unknown") {
        # we don't fail unknown; just report as info
        continue
    }

    $needOk = Has-All -Have $mw -Need $expected.Need
    $forbidHit = $false
    if ($expected.Forbid -and $expected.Forbid.Count -gt 0) {
        $forbidHit = Has-Any -Have $mw -Need $expected.Forbid
    }

    if ($needOk -and -not $forbidHit) {
        $ok++
        continue
    }

    $issues += [pscustomobject]@{
        Method     = $r.Method
        Uri        = $r.Uri
        Name       = $r.Name
        Bucket     = $expected.Bucket
        Need       = ($expected.Need -join ", ")
        Forbid     = ($expected.Forbid -join ", ")
        Middleware = (($mw | Sort-Object) -join ", ")
        Missing    = (@($expected.Need | Where-Object { -not ($mw -contains $_) }) -join ", ")
        Forbidden  = (@($expected.Forbid | Where-Object { $mw -contains $_ }) -join ", ")
    }
}

Write-Host ""
Write-Host "Total parsed routes: $total" -ForegroundColor DarkGray
Write-Host "Routes with enforced expectations (known buckets): $ok ok, $($issues.Count) issues" -ForegroundColor DarkGray
Write-Host ""

if ($issues.Count -gt 0) {
    Write-Host "❌ Middleware mismatches:" -ForegroundColor Red
    $issues |
        Sort-Object Bucket, Uri |
        Select-Object Bucket, Method, Uri, Name, Missing, Forbidden, Need, Middleware |
        Format-Table -AutoSize

    exit 2
}

Write-Host "✅ All checked admin routes match expected middleware (auth/staff/superadmin + section:*)." -ForegroundColor Green
exit 0