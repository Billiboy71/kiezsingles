# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\core\ks-client-ip.psm1
# Purpose: Shared client IP simulation and rotation helpers for KiezSingles audit PowerShell scripts
# Created: 06-03-2026 22:24 (Europe/Berlin)
# Changed: 17-03-2026 12:26 (Europe/Berlin)
# Version: 1.6
# =============================================================================

Set-StrictMode -Version Latest

function Convert-ToStringArray {
    param(
        [Parameter(Mandatory=$false)]$InputObject
    )

    $result = New-Object System.Collections.Generic.List[string]

    if ($null -eq $InputObject) {
        return @($result.ToArray())
    }

    if ($InputObject -is [string]) {
        if (-not [string]::IsNullOrWhiteSpace($InputObject)) {
            $result.Add("" + $InputObject)
        }

        return @($result.ToArray())
    }

    foreach ($item in $InputObject) {
        $value = ""
        try { $value = "" + $item } catch { $value = "" }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $result.Add($value)
        }
    }

    return @($result.ToArray())
}

function Get-DeviceHeaders {
    $h = @{}

    if (-not [string]::IsNullOrWhiteSpace($script:DeviceHeaderName) -and -not [string]::IsNullOrWhiteSpace($script:DeviceHeaderValue)) {
        $h[$script:DeviceHeaderName] = $script:DeviceHeaderValue
    }

    return $h
}

function Get-LocalClientIPs {
    $ips = New-Object System.Collections.Generic.List[string]

    try {
        $rows = Get-NetIPAddress -ErrorAction Stop | Where-Object {
            $_.IPAddress -and ($_.AddressFamily -eq "IPv4" -or $_.AddressFamily -eq "IPv6")
        }

        foreach ($r in $rows) {
            $ip = "" + $r.IPAddress
            if (-not [string]::IsNullOrWhiteSpace($ip)) {
                $ips.Add($ip)
            }
        }
    } catch {
    }

    try {
        $dnsEntry = [System.Net.Dns]::GetHostEntry([System.Net.Dns]::GetHostName())

        foreach ($a in $dnsEntry.AddressList) {
            $ip = "" + $a.IPAddressToString
            if (-not [string]::IsNullOrWhiteSpace($ip)) {
                $ips.Add($ip)
            }
        }
    } catch {
    }

    $ips.Add("::1")
    $ips.Add("127.0.0.1")

    $uniq = New-Object System.Collections.Generic.List[string]
    foreach ($ip in $ips) {
        if ($uniq -notcontains $ip) {
            $uniq.Add($ip)
        }
    }

    return @($uniq.ToArray())
}

function Build-DefaultTestIpPool {
    $pool = New-Object System.Collections.Generic.List[string]

    for ($i = 10; $i -le 29; $i++) { $pool.Add(("203.0.113.{0}" -f $i)) }
    for ($i = 10; $i -le 29; $i++) { $pool.Add(("198.51.100.{0}" -f $i)) }
    for ($i = 10; $i -le 29; $i++) { $pool.Add(("192.0.2.{0}" -f $i)) }

    return @($pool.ToArray())
}

function New-SequentialPool {
    param(
        [Parameter(Mandatory=$true)][string]$Prefix,
        [Parameter(Mandatory=$true)][int]$Count,
        [Parameter(Mandatory=$false)][int]$StartIndex = 1,
        [Parameter(Mandatory=$false)][int]$PadWidth = 3,
        [Parameter(Mandatory=$false)][string]$Suffix = ""
    )

    $pool = New-Object System.Collections.Generic.List[string]

    if ($Count -le 0) {
        return @($pool.ToArray())
    }

    for ($i = 0; $i -lt $Count; $i++) {
        $n = $StartIndex + $i
        $pool.Add(("{0}{1}{2}" -f $Prefix, $n.ToString(("D{0}" -f $PadWidth)), $Suffix))
    }

    return @($pool.ToArray())
}

function New-EmailPool {
    param(
        [Parameter(Mandatory=$true)][string]$Prefix,
        [Parameter(Mandatory=$true)][int]$Count,
        [Parameter(Mandatory=$false)][string]$Domain = "kiezsingles.local",
        [Parameter(Mandatory=$false)][int]$StartIndex = 1,
        [Parameter(Mandatory=$false)][int]$PadWidth = 3
    )

    $pool = New-Object System.Collections.Generic.List[string]

    if ($Count -le 0) {
        return @($pool.ToArray())
    }

    for ($i = 0; $i -lt $Count; $i++) {
        $n = $StartIndex + $i
        $pool.Add(("{0}{1}@{2}" -f $Prefix, $n.ToString(("D{0}" -f $PadWidth)), $Domain))
    }

    return @($pool.ToArray())
}

function Select-PoolValue {
    param(
        [Parameter(Mandatory=$true)]$Pool,
        [Parameter(Mandatory=$true)][int]$Index
    )

    $poolValues = @(Convert-ToStringArray -InputObject $Pool)

    if ($poolValues.Count -eq 0) {
        return ""
    }

    if ($Index -lt 0) {
        return ""
    }

    $resolvedIndex = $Index % $poolValues.Count
    return ("" + $poolValues[$resolvedIndex])
}

function Reset-ClientIpRotation {
    param(
        [Parameter(Mandatory=$false)]$Pool
    )

    $script:ClientIpPool = @()

    $normalizedPool = @(Convert-ToStringArray -InputObject $Pool)
    if ($normalizedPool.Count -gt 0) {
        $script:ClientIpPool = $normalizedPool
    }

    $script:ClientIpIndex = -1
    $script:ClientIpStepIp = ""
}

function Next-TestIp {
    if (-not $script:SimulateClientIpEnabled) { return "" }
    if ($null -eq $script:ClientIpPool -or $script:ClientIpPool.Count -eq 0) { return "" }

    $script:ClientIpIndex = $script:ClientIpIndex + 1
    if ($script:ClientIpIndex -ge $script:ClientIpPool.Count) {
        $script:ClientIpIndex = 0
    }

    return ("" + $script:ClientIpPool[$script:ClientIpIndex])
}

function Get-StepIp {
    if (-not $script:SimulateClientIpEnabled) { return "" }

    if (-not [string]::IsNullOrWhiteSpace($script:ForcedClientIp)) {
        return ("" + $script:ForcedClientIp)
    }

    if ($script:IpRotationMode -in @("per_step", "fixed_per_scenario")) {
        if ([string]::IsNullOrWhiteSpace($script:ClientIpStepIp)) {
            $script:ClientIpStepIp = Next-TestIp
        }

        return $script:ClientIpStepIp
    }

    return Next-TestIp
}

function Begin-StepIp {
    if (-not $script:SimulateClientIpEnabled) { return }
    if (-not [string]::IsNullOrWhiteSpace($script:ForcedClientIp)) { return }

    if ($script:IpRotationMode -in @("per_step", "fixed_per_scenario")) {
        $script:ClientIpStepIp = Next-TestIp
    }
}

function End-StepIp {
    if (-not $script:SimulateClientIpEnabled) { return }
    if (-not [string]::IsNullOrWhiteSpace($script:ForcedClientIp)) { return }

    if ($script:IpRotationMode -in @("per_step", "fixed_per_scenario")) {
        $script:ClientIpStepIp = ""
    }
}

function Enter-ForcedClientIp {
    param(
        [Parameter(Mandatory=$false)][string]$ip
    )

    if (-not $script:SimulateClientIpEnabled) {
        $script:ForcedClientIp = ""
        try {
            if (Get-Command Set-AuditModuleRuntimeVariable -ErrorAction SilentlyContinue) {
                Set-AuditModuleRuntimeVariable -Name 'ForcedClientIp' -Value $script:ForcedClientIp
            }
        } catch {
        }
        return
    }

    if ([string]::IsNullOrWhiteSpace($ip)) {
        $script:ForcedClientIp = ""
        try {
            if (Get-Command Set-AuditModuleRuntimeVariable -ErrorAction SilentlyContinue) {
                Set-AuditModuleRuntimeVariable -Name 'ForcedClientIp' -Value $script:ForcedClientIp
            }
        } catch {
        }
        return
    }

    $script:ForcedClientIp = ("" + $ip)

    try {
        if (Get-Command Set-AuditModuleRuntimeVariable -ErrorAction SilentlyContinue) {
            Set-AuditModuleRuntimeVariable -Name 'ForcedClientIp' -Value $script:ForcedClientIp
        }
    } catch {
    }
}

function Exit-ForcedClientIp {
    $script:ForcedClientIp = ""

    try {
        if (Get-Command Set-AuditModuleRuntimeVariable -ErrorAction SilentlyContinue) {
            Set-AuditModuleRuntimeVariable -Name 'ForcedClientIp' -Value $script:ForcedClientIp
        }
    } catch {
    }
}

function Test-LockoutHasSeparatePinnedIp {
    $banIp = ""
    $lockoutIp = ""

    try { $banIp = ("" + $script:PinnedIpBanTestIp).Trim() } catch { $banIp = "" }
    try { $lockoutIp = ("" + $script:ResolvedLockoutTestIp).Trim() } catch { $lockoutIp = "" }

    if ([string]::IsNullOrWhiteSpace($lockoutIp)) { return $false }
    if ([string]::IsNullOrWhiteSpace($banIp)) { return $true }
    if ($lockoutIp -ne $banIp) { return $true }

    return $false
}

function Test-LockoutCandidateLooksClean {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$CandidateIp
    )

    if ([string]::IsNullOrWhiteSpace($CandidateIp)) { return $false }

    $session = New-Session
    $headers = Get-ClientIpHeaders -ip $CandidateIp
    $resp = Get-LoginPage -BaseUrl $BaseUrl -Session $session -Headers $headers

    $html = ""
    try { $html = "" + $resp.Content } catch { $html = "" }

    $an = Analyze-Html -html $html

    if ($an.LockoutFound) { return $false }
    if ($an.SecFound) { return $false }

    return $true
}

function Resolve-LockoutTestIp {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl
    )

    if (-not $script:SimulateClientIpEnabled) { return "" }

    $pinned = ""
    $banIp = ""

    try { $pinned = ("" + $script:PinnedLockoutTestIp).Trim() } catch { $pinned = "" }
    try { $banIp = ("" + $script:PinnedIpBanTestIp).Trim() } catch { $banIp = "" }

    if (-not [string]::IsNullOrWhiteSpace($pinned)) {
        return $pinned
    }

    if (-not $script:AutoSelectFreeLockoutTestIp) {
        return ""
    }

    if ($null -eq $script:ClientIpPool -or $script:ClientIpPool.Count -eq 0) {
        return ""
    }

    $candidates = @()
    for ($i = $script:ClientIpPool.Count - 1; $i -ge 0; $i--) {
        $ip = "" + $script:ClientIpPool[$i]
        if ([string]::IsNullOrWhiteSpace($ip)) { continue }
        if (-not [string]::IsNullOrWhiteSpace($banIp) -and $ip -eq $banIp) { continue }
        $candidates += $ip
    }

    foreach ($candidate in $candidates) {
        if (Test-LockoutCandidateLooksClean -BaseUrl $BaseUrl -CandidateIp $candidate) {
            return $candidate
        }
    }

    if ($candidates.Count -gt 0) {
        return ("" + $candidates[0])
    }

    return ""
}

function Get-ClientIpHeaders {
    param(
        [Parameter(Mandatory=$false)][string]$ip
    )

    $h = @{}

    if (-not $script:SimulateClientIpEnabled) { return $h }
    if ([string]::IsNullOrWhiteSpace($ip)) { return $h }

    if ($script:ClientIpHeaderMode -eq "xff_only") {
        $h["X-Forwarded-For"] = $ip
        return $h
    }

    $h["X-Forwarded-For"] = $ip
    $h["X-Real-IP"] = $ip
    $h["CF-Connecting-IP"] = $ip

    return $h
}

function Merge-Headers {
    param(
        [Parameter(Mandatory=$false)][hashtable]$A = @{},
        [Parameter(Mandatory=$false)][hashtable]$B = @{}
    )

    $h = @{}

    if ($null -ne $A) {
        foreach ($k in $A.Keys) {
            $h[$k] = $A[$k]
        }
    }

    if ($null -ne $B) {
        foreach ($k in $B.Keys) {
            $h[$k] = $B[$k]
        }
    }

    return $h
}

function Get-RequestHeaders {
    param(
        [Parameter(Mandatory=$false)][hashtable]$ExtraHeaders = @{},
        [Parameter(Mandatory=$false)][string]$ForcedIp = ""
    )

    $ip = ""

    if (-not [string]::IsNullOrWhiteSpace($ForcedIp)) {
        $ip = "" + $ForcedIp
    }
    else {
        $ip = Get-StepIp
    }

    $ipHeaders = Get-ClientIpHeaders -ip $ip
    $h = Merge-Headers -A $ExtraHeaders -B $ipHeaders

    return [PSCustomObject]@{
        Headers = $h
        Ip      = $ip
    }
}

Export-ModuleMember -Function *
