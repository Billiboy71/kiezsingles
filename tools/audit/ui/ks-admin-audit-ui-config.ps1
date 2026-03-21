# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ui\ks-admin-audit-ui-config.ps1
# Purpose: Config and small GUI-near helpers for ks-admin-audit-ui
# Created: 14-03-2026 02:06 (Europe/Berlin)
# Changed: 21-03-2026 15:16 (Europe/Berlin)
# Version: 0.2
# =============================================================================

function ConvertTo-QuotedArg([string]$s) {
    if ($null -eq $s) { return '""' }
    $t = ("" + $s) -replace '"', '""'
    return ('"' + $t + '"')
}

function Get-MaskedArgumentList([string[]]$InputArgs) {
    $out = New-Object System.Collections.Generic.List[string]
    if ($null -eq $InputArgs) { return @() }

    $sensitiveNames = @(
        "-SuperadminPassword",
        "-AdminPassword",
        "-ModeratorPassword"
    )

    $i = 0
    while ($i -lt $InputArgs.Count) {
        $cur = "" + $InputArgs[$i]
        $out.Add($cur) | Out-Null

        $isSensitiveName = $false
        foreach ($sn in $sensitiveNames) {
            if ($cur -ieq $sn) { $isSensitiveName = $true; break }
        }

        if ($isSensitiveName -and (($i + 1) -lt $InputArgs.Count)) {
            $out.Add("<redacted>") | Out-Null
            $i += 2
            continue
        }

        $i++
    }

    return @($out.ToArray())
}

function Get-KsAuditPathsConfig([string]$ConfigPath) {
    if (-not $ConfigPath -or ("" + $ConfigPath).Trim() -eq "") { return $null }
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $null }

    try {
        $raw = [string](Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 -ErrorAction Stop)
        if ($raw.Trim() -eq "") { return $null }
        $cfg = $raw | ConvertFrom-Json -ErrorAction Stop
        return $cfg
    } catch {
        return $null
    }
}

function Save-KsAuditPathsConfig([string]$ConfigPath, [string[]]$ProbePathsToSave, [string[]]$RoleSmokePathsToSave) {
    $dir = Split-Path -Parent $ConfigPath
    if ($dir -and (-not (Test-Path -LiteralPath $dir -PathType Container))) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $payload = [ordered]@{
        probe_paths = @($ProbePathsToSave | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
        role_smoke_paths = @($RoleSmokePathsToSave | ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne "" })
    }

    $json = $payload | ConvertTo-Json -Depth 5
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ConfigPath, $json, $utf8NoBom)
}

function Get-KsAuditCredentialsConfig([string]$ConfigPath) {
    if (-not $ConfigPath -or ("" + $ConfigPath).Trim() -eq "") { return $null }
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $null }

    try {
        $raw = [string](Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 -ErrorAction Stop)
        if ($raw.Trim() -eq "") { return $null }
        return ($raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        return $null
    }
}

function Save-KsAuditCredential([string]$ConfigPath, [string]$Role, [string]$Email, [string]$Password, [bool]$ClearRole = $false) {
    $dir = Split-Path -Parent $ConfigPath
    if ($dir -and (-not (Test-Path -LiteralPath $dir -PathType Container))) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $payload = [ordered]@{
        superadmin = [ordered]@{ email = ""; password = "" }
        admin = [ordered]@{ email = ""; password = "" }
        moderator = [ordered]@{ email = ""; password = "" }
    }

    $existing = Get-KsAuditCredentialsConfig -ConfigPath $ConfigPath
    if ($null -ne $existing) {
        foreach ($rk in @("superadmin","admin","moderator")) {
            try {
                if ($existing.PSObject.Properties.Name -contains $rk) {
                    $r = $existing.$rk
                    if ($null -ne $r) {
                        $payload[$rk]["email"] = ("" + $r.email)
                        $payload[$rk]["password"] = ("" + $r.password)
                    }
                }
            } catch { }
        }
    }

    $k = ("" + $Role).Trim().ToLower()
    if (@("superadmin","admin","moderator") -contains $k) {
        if ($ClearRole) {
            $payload[$k]["email"] = ""
            $payload[$k]["password"] = ""
        } else {
            $payload[$k]["email"] = ("" + $Email)
            $payload[$k]["password"] = ("" + $Password)
        }
    }

    $json = $payload | ConvertTo-Json -Depth 6
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ConfigPath, $json, $utf8NoBom)
}
