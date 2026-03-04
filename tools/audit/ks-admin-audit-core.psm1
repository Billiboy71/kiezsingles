# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit-core.psm1
# Purpose: Core helper module for KiezSingles Admin Audit CLI
# Created: 03-03-2026 04:28 (Europe/Berlin)
# Changed: 04-03-2026 01:52 (Europe/Berlin)
# Version: 0.6
# =============================================================================

# Ensure predictable UTF-8 output for this module as well (no BOM)
try {
    if ($IsWindows -or $env:OS -eq "Windows_NT") { chcp 65001 | Out-Null }
} catch { }
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { }
try { [Console]::InputEncoding  = [Text.UTF8Encoding]::new($false) } catch { }

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function Get-SafeCount([object]$Value) {
    try {
        if ($null -eq $Value) { return 0 }

        if ($Value -is [string]) { return 1 }

        if ($Value -is [System.Collections.IDictionary]) {
            try { return [int]$Value.Count } catch { return 0 }
        }

        if ($Value -is [System.Collections.ICollection]) {
            try { return [int]$Value.Count } catch { return 0 }
        }

        try {
            $arr = @($Value)
            if ($null -eq $arr) { return 0 }
            try { return [int]$arr.Count } catch { return 0 }
        } catch {
            return 0
        }
    } catch {
        return 0
    }
}

function ConvertTo-SafeStringArray([object]$Value) {
    $out = New-Object System.Collections.Generic.List[string]
    try {
        if ($null -eq $Value) { return @() }

        if ($Value -is [string]) {
            $out.Add(("" + $Value)) | Out-Null
            return @($out.ToArray())
        }

        $items = @()
        try { $items = @($Value) } catch { $items = @() }

        foreach ($i in $items) {
            if ($null -eq $i) { continue }
            $out.Add(("" + $i)) | Out-Null
        }

        return @($out.ToArray())
    } catch {
        try { return @($out.ToArray()) } catch { return @() }
    }
}

function ConvertTo-SafeStringScalar([object]$Value) {
    try {
        if ($null -eq $Value) { return "" }
        if ($Value -is [string]) { return ("" + $Value) }

        if (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string])) {
            try { return ((@($Value) | ForEach-Object { "" + $_ }) -join ",") } catch { return ("" + $Value) }
        }

        return ("" + $Value)
    } catch {
        return ""
    }
}

function Stop-Program([int]$Code) {
    $noExitValue = $false
    try {
        $nv = Get-Variable -Name NoExit -Scope 1 -ErrorAction Stop
        $noExitValue = [bool]$nv.Value
    } catch { }
    if ($noExitValue) { return $Code }
    exit $Code
}

function Get-ArgValueFromToken([string]$token) {
    if ($null -eq $token) { return $null }
    $t = ("" + $token).Trim()
    if ($t -match '^(?<name>-[A-Za-z][A-Za-z0-9_]*)\s*:\s*(?<val>.*)$') {
        return $Matches['val']
    }
    return $null
}

function Get-ArgNameFromToken([string]$token) {
    if ($null -eq $token) { return "" }
    $t = ("" + $token).Trim()
    if ($t -match '^(?<name>-[A-Za-z][A-Za-z0-9_]*)(\s*:\s*.*)?$') {
        return $Matches['name']
    }
    return ""
}

function Test-KnownSwitch([string]$name) {
    switch ($name) {
        "-HttpProbe" { return $true }
        "-TailLog" { return $true }
        "-RoutesVerbose" { return $true }
        "-RouteListFindstrAdmin" { return $true }
        "-SuperadminCount" { return $true }
        "-LoginCsrfProbe" { return $true }
        "-RoleSmokeTest" { return $true }
        "-SessionCsrfBaseline" { return $true }
        "-LogSnapshot" { return $true }
        "-LogClearBefore" { return $true }
        "-LogClearAfter" { return $true }
        "-RouteListOptionScanFullProject" { return $true }
        "-SecurityProbe" { return $true }
        "-SecurityCheckIpBan" { return $true }
        "-SecurityCheckRegister" { return $true }
        "-SecurityExpect429" { return $true }
        "-SecurityE2E" { return $true }
        "-SecurityE2ELockout" { return $true }
        "-SecurityE2EIpAutoban" { return $true }
        "-SecurityE2EDeviceAutoban" { return $true }
        "-SecurityE2EIdentityBan" { return $true }
        "-SecurityE2ESupportRef" { return $true }
        "-SecurityE2EEventsCheck" { return $true }
        "-NoExit" { return $true }
        default { return $false }
    }
}

function Test-KnownValueParam([string]$name) {
    switch ($name) {
        "-BaseUrl" { return $true }
        "-ProbePaths" { return $true }
        "-PathsConfigFile" { return $true }
        "-SuperadminEmail" { return $true }
        "-SuperadminPassword" { return $true }
        "-AdminEmail" { return $true }
        "-AdminPassword" { return $true }
        "-ModeratorEmail" { return $true }
        "-ModeratorPassword" { return $true }
        "-RoleSmokePaths" { return $true }
        "-LogSnapshotLines" { return $true }
        "-SecurityLoginAttempts" { return $true }
        "-SecurityLockoutKeywords" { return $true }
        "-SecurityE2EAttempts" { return $true }
        "-SecurityE2EThreshold" { return $true }
        "-SecurityE2ESeconds" { return $true }
        "-SecurityE2ELogin" { return $true }
        "-SecurityE2EPassword" { return $true }
        "-SecurityE2ECleanup" { return $true }
        "-SecurityE2EDryRun" { return $true }
        "-SecurityE2EEnvGate" { return $true }
        "-ShowCheckDetails" { return $true }
        "-ExportLogs" { return $true }
        "-ExportLogsLines" { return $true }
        "-ExportFolder" { return $true }
        "-AutoOpenExportFolder" { return $true }
        "-PerCheckDetails" { return $true }
        "-PerCheckExport" { return $true }
        "-Gui" { return $true }
        default { return $false }
    }
}

function Test-RecoverArgsNeeded {
    try {
        if ($BaseUrl -and (("" + $BaseUrl).Trim() -match '^-')) { return $true }

        foreach ($v in @($ProbePaths)) {
            if ($v -and (("" + $v).Trim() -match '^-')) { return $true }
        }

        foreach ($v in @($IgnoredArgs)) {
            if ($v -and (("" + $v).Trim() -match '^-')) { return $true }
        }

        return $false
    } catch {
        return $false
    }
}

function Get-InvocationParameterValues {
    param(
        [Parameter(Mandatory = $true)][string]$ParamName
    )

    $out = New-Object System.Collections.Generic.List[string]
    $line = ""
    try { $line = ("" + $MyInvocation.Line) } catch { $line = "" }
    if ($line.Trim() -eq "") { return @() }

    $tokens = New-Object System.Collections.Generic.List[string]
    try {
        $rx = [regex]'("([^"\\]|\\.)*"|''[^'']*''|\S+)'
        foreach ($m in $rx.Matches($line)) {
            $t = ("" + $m.Value).Trim()
            if ($t -eq "") { continue }
            if (($t.StartsWith('"') -and $t.EndsWith('"')) -or ($t.StartsWith("'") -and $t.EndsWith("'"))) {
                if ($t.Length -ge 2) { $t = $t.Substring(1, $t.Length - 2) }
            }
            $tokens.Add($t) | Out-Null
        }
    } catch {
        return @()
    }

    if ($tokens.Count -le 0) { return @() }

    $nameNorm = ("-" + ("" + $ParamName).Trim().TrimStart("-"))
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $tok = ("" + $tokens[$i]).Trim()
        if ($tok -ne $nameNorm) { continue }

        $j = $i + 1
        while ($j -lt $tokens.Count) {
            $v = ("" + $tokens[$j]).Trim()
            if ($v -eq "") { $j++; continue }
            if ($v.StartsWith("-")) { break }
            $out.Add($v) | Out-Null
            $j++
        }
    }

    return @($out.ToArray())
}

function Get-ProcessArgParameterValues {
    param(
        [Parameter(Mandatory = $true)][string]$ParamName
    )

    $out = New-Object System.Collections.Generic.List[string]
    $argv = @()
    try { $argv = @([Environment]::GetCommandLineArgs()) } catch { $argv = @() }
    if ($argv.Count -le 0) { return @() }

    $nameNorm = ("-" + ("" + $ParamName).Trim().TrimStart("-"))
    for ($i = 0; $i -lt $argv.Count; $i++) {
        $tok = ("" + $argv[$i]).Trim()
        if ($tok -ne $nameNorm) { continue }

        $j = $i + 1
        while ($j -lt $argv.Count) {
            $v = ("" + $argv[$j]).Trim()
            if ($v -eq "") { $j++; continue }
            if ($v.StartsWith("-")) { break }
            $out.Add($v) | Out-Null
            $j++
        }
    }

    return @($out.ToArray())
}

function New-KsHttpClient([System.Net.CookieContainer]$CookieJar, [int]$TimeoutSeconds = 12) {
    try {
        $handler = [System.Net.Http.HttpClientHandler]::new()
        $handler.AllowAutoRedirect = $false
        $handler.UseCookies = $true
        if ($null -ne $CookieJar) {
            $handler.CookieContainer = $CookieJar
        } else {
            $handler.CookieContainer = [System.Net.CookieContainer]::new()
        }

        $client = [System.Net.Http.HttpClient]::new($handler)
        try { $client.Timeout = [System.TimeSpan]::FromSeconds([double]$TimeoutSeconds) } catch { }

        return [pscustomobject]@{
            Client = $client
            Handler = $handler
        }
    } catch {
        return $null
    }
}

function Invoke-KsHttpNoRedirect {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][ValidateSet("GET","POST","PUT","PATCH","DELETE")][string]$Method,
        [Parameter(Mandatory = $true)][System.Net.CookieContainer]$CookieJar,
        [object]$Body = $null,
        [hashtable]$Headers = $null,
        [string]$ContentType = "",
        [int]$TimeoutSeconds = 12
    )

    $result = [pscustomobject]@{
        ok = $false
        status = $null
        location = $null
        headers = @{}
        body = ""
        error = $null
    }

    $http = $null
    try {
        $http = New-KsHttpClient -CookieJar $CookieJar -TimeoutSeconds $TimeoutSeconds
        if ($null -eq $http -or $null -eq $http.Client) {
            $result.error = "httpclient_init_failed"
            return $result
        }

        $req = [System.Net.Http.HttpRequestMessage]::new()
        $req.Method = [System.Net.Http.HttpMethod]::$Method
        $req.RequestUri = [System.Uri]::new($Uri)

        if ($null -ne $Headers) {
            foreach ($k in @($Headers.Keys)) {
                if ($null -eq $k) { continue }
                $kk = ("" + $k).Trim()
                if ($kk -eq "") { continue }

                $vv = ""
                try { $vv = ConvertTo-SafeStringScalar $Headers[$k] } catch { $vv = "" }
                if ($vv -eq "") { continue }

                try { $null = $req.Headers.TryAddWithoutValidation($kk, $vv) } catch { }
            }
        }

        if ($Method -ne "GET" -and $Method -ne "DELETE") {
            if ($null -ne $Body) {
                if ($Body -is [hashtable] -or $Body -is [System.Collections.IDictionary]) {
                    $pairs = New-Object System.Collections.Generic.List[System.Collections.Generic.KeyValuePair[string,string]]
                    foreach ($key in @($Body.Keys)) {
                        if ($null -eq $key) { continue }
                        $k = ("" + $key)
                        $v = ""
                        try { $v = ConvertTo-SafeStringScalar $Body[$key] } catch { $v = "" }
                        $pairs.Add([System.Collections.Generic.KeyValuePair[string,string]]::new($k, $v)) | Out-Null
                    }
                    $content = [System.Net.Http.FormUrlEncodedContent]::new($pairs)
                    $req.Content = $content
                } else {
                    $payload = ""
                    try { $payload = ConvertTo-SafeStringScalar $Body } catch { $payload = "" }
                    $ctype = $ContentType
                    if ($ctype -eq "") { $ctype = "application/x-www-form-urlencoded" }
                    $req.Content = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, $ctype)
                }
            }
        }

        $resp = $http.Client.SendAsync($req).GetAwaiter().GetResult()

        try { $result.status = [int]$resp.StatusCode } catch { $result.status = $null }

        try {
            if ($resp.Headers -and $resp.Headers.Location) {
                $result.location = ("" + $resp.Headers.Location.ToString()).Trim()
            } elseif ($resp.Content -and $resp.Content.Headers -and $resp.Content.Headers.Location) {
                $result.location = ("" + $resp.Content.Headers.Location.ToString()).Trim()
            } else {
                $result.location = $null
            }
        } catch {
            $result.location = $null
        }

        $hdr = @{}
        try {
            foreach ($h in $resp.Headers) {
                try {
                    $name = "" + $h.Key
                    $val = ""
                    try { $val = ($h.Value -join ", ") } catch { $val = "" }
                    if ($name -ne "") { $hdr[$name] = $val }
                } catch { }
            }
        } catch { }

        try {
            if ($resp.Content -and $resp.Content.Headers) {
                foreach ($h in $resp.Content.Headers) {
                    try {
                        $name = "" + $h.Key
                        $val = ""
                        try { $val = ($h.Value -join ", ") } catch { $val = "" }
                        if ($name -ne "" -and (-not $hdr.ContainsKey($name))) { $hdr[$name] = $val }
                    } catch { }
                }
            }
        } catch { }

        $result.headers = $hdr

        try {
            if ($resp.Content) {
                $result.body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            } else {
                $result.body = ""
            }
        } catch {
            $result.body = ""
        }

        $result.ok = $true
        return $result
    } catch {
        $msg = ""
        try { $msg = ("" + $_.Exception.Message) } catch { $msg = "http_error" }
        $typeName = ""
        try { $typeName = ("" + $_.Exception.GetType().FullName) } catch { $typeName = "" }
        if ($typeName -ne "") { $msg = ($typeName + ": " + $msg) }

        $result.error = $msg
        $result.ok = $false
        return $result
    } finally {
        try { if ($null -ne $http -and $null -ne $http.Client) { $http.Client.Dispose() } } catch { }
        try { if ($null -ne $http -and $null -ne $http.Handler) { $http.Handler.Dispose() } } catch { }
    }
}

function Test-ProjectRoot([string]$Root) {
    $artisan = Join-Path $Root "artisan"
    if (!(Test-Path $artisan)) {
        throw "Project root not detected. Expected artisan at: $artisan"
    }
}

function ConvertTo-NormalizedProbePaths([object]$Value) {
    $out = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    if ($null -eq $Value) {
        return @()
    }

    $vals = @()
    try { $vals = @($Value) } catch { $vals = @() }

    foreach ($v in $vals) {
        if ($null -eq $v) { continue }
        $s = ("" + $v).Trim()
        if ($s -eq "") { continue }

        $parts = @()
        if ($s -match "\r?\n" -or $s -match "\s" -or $s -match "[,;]") {
            try { $parts = @($s -split "[\s,;]+") } catch { $parts = @() }
        } else {
            $parts = @($s)
        }

        foreach ($part in @($parts)) {
            $x = ("" + $part).Trim()
            if ($x -eq "") { continue }

            if ($x -match '^(?i)https?://') {
                try {
                    $u = $null
                    $ok = $false
                    try { $ok = [System.Uri]::TryCreate($x, [System.UriKind]::Absolute, [ref]$u) } catch { $ok = $false }
                    if ($ok -and $u -and $u.AbsolutePath) { $x = ("" + $u.AbsolutePath).Trim() }
                } catch { }
            }

            if ($x -eq "") { continue }
            if (-not $x.StartsWith("/")) { $x = "/" + $x.TrimStart("/") }
            if ($x -eq "/") { continue }

            if ($seen.ContainsKey($x)) { continue }
            $seen[$x] = $true
            $out.Add($x) | Out-Null
        }
    }

    return @($out.ToArray())
}

function Resolve-ParamValues([string]$Name) {
    $vals = @()
    try { $vals = @(Get-InvocationParameterValues -ParamName $Name) } catch { $vals = @() }
    if ($vals.Count -le 0) {
        try { $vals = @(Get-ProcessArgParameterValues -ParamName $Name) } catch { $vals = @() }
    }
    return @($vals)
}

function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 78)
    Write-Host $Title
    Write-Host ("=" * 78)
}

function ConvertTo-QuotedArgWindows([string]$s) {
    if ($null -eq $s) { return '""' }

    $t = "" + $s
    if ($t -eq "") { return '""' }

    if ($t -match '[\s"]') {
        $t = $t -replace '(\\*)"', '$1$1\"'
        $t = $t -replace '(\\+)$', '$1$1'
        return '"' + $t + '"'
    }

    return $t
}

function Invoke-ProcessToFiles(
    [string]$File,
    [string[]]$ArgumentList,
    [int]$TimeoutSeconds = 120,
    [string]$WorkingDirectory = ""
) {
    $stdout = ""
    $stderr = ""

    try {
        if ($null -eq $ArgumentList) { $ArgumentList = @() }
        $ArgumentList = @($ArgumentList | Where-Object { $_ -ne $null })

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = ("" + $File)

        $quotedArgs = @()
        foreach ($a in $ArgumentList) {
            $quotedArgs += (ConvertTo-QuotedArgWindows ("" + $a))
        }
        $psi.Arguments = ($quotedArgs -join " ")

        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true

        if ($WorkingDirectory -and ($WorkingDirectory.Trim() -ne "")) {
            $psi.WorkingDirectory = $WorkingDirectory
        }

        try { $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
        try { $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8 } catch { }

        $p = [System.Diagnostics.Process]::new()
        $p.StartInfo = $psi

        $null = $p.Start()

        try {
            $p.StandardInput.Write("")
            $p.StandardInput.Close()
        } catch { }

        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()

        $exited = $p.WaitForExit($TimeoutSeconds * 1000)

        if (-not $exited) {
            try { $p.Kill($true) } catch { }

            try { $stdout = $outTask.GetAwaiter().GetResult() } catch { $stdout = "" }
            try { $stderr = $errTask.GetAwaiter().GetResult() } catch { $stderr = "" }

            $argString = ($ArgumentList -join " ")
            return [pscustomobject]@{
                ExitCode = -1
                StdOut   = $stdout
                StdErr   = ("TIMEOUT after {0}s while running: {1} {2}" -f $TimeoutSeconds, $File, $argString) + "`n" + $stderr
            }
        }

        try { $p.WaitForExit() } catch { }

        try { $stdout = $outTask.GetAwaiter().GetResult() } catch { $stdout = "" }
        try { $stderr = $errTask.GetAwaiter().GetResult() } catch { $stderr = "" }

        $exitCode = 0
        try { $exitCode = [int]$p.ExitCode } catch { $exitCode = 0 }

        return [pscustomobject]@{
            ExitCode = [int]$exitCode
            StdOut   = $stdout
            StdErr   = $stderr
        }
    } catch {
        $msg = ""
        try { $msg = $_.Exception.Message } catch { $msg = "unknown_error" }

        return [pscustomobject]@{
            ExitCode = 2
            StdOut   = ""
            StdErr   = ("PROCESS RUNNER ERROR: " + $msg)
        }
    }
}

function Resolve-PHPExePath {
    try {
        $exe = $null

        try {
            $paths = ("" + $env:PATH).Split(";") | Where-Object { $_ -and ("" + $_).Trim() -ne "" }
            foreach ($p in $paths) {
                $candidate = Join-Path ($p.Trim()) "php.exe"
                if (Test-Path -LiteralPath $candidate) {
                    $exe = $candidate
                    break
                }
            }
        } catch { }

        if ($exe -and (("" + $exe).Trim() -ne "")) {
            return ("" + $exe).Trim()
        }

        try {
            $phpApp = Get-Command php -All -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandType -eq "Application" } |
                Select-Object -First 1

            if ($phpApp -and $phpApp.Source -and ("" + $phpApp.Source).Trim() -ne "") {
                return ("" + $phpApp.Source).Trim()
            }
        } catch { }

        return "php"
    } catch {
        return "php"
    }
}

function Invoke-PHPArtisan([string]$Root, [string[]]$ArgumentList, [int]$TimeoutSeconds = 120) {
    $php = Resolve-PHPExePath
    $artisan = Join-Path $Root "artisan"

    if ($null -eq $ArgumentList) { $ArgumentList = @() }

    $cmdArgs = @()
    $cmdArgs += $artisan
    $cmdArgs += $ArgumentList
    $cmdArgs = @($cmdArgs | Where-Object { $_ -ne $null })

    return Invoke-ProcessToFiles -File $php -ArgumentList $cmdArgs -TimeoutSeconds $TimeoutSeconds -WorkingDirectory $Root
}

function New-AuditResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][ValidateSet("OK","WARN","FAIL","CRITICAL","SKIP")][string]$Status,
        [Parameter(Mandatory = $true)][string]$Summary,
        [string[]]$Details = @(),
        [hashtable]$Data = @{},
        [string]$DetailsText = "",
        [object[]]$Evidence = @(),
        [string[]]$LogSlice = @(),
        [string]$LogExportPath = "",
        [int]$DurationMs = 0
    )

    $effectiveDetailsText = $DetailsText
    if (($effectiveDetailsText -eq "") -and ((Get-SafeCount $Details) -gt 0)) {
        try { $effectiveDetailsText = ((@($Details) | ForEach-Object { "" + $_ }) -join "`n") } catch { $effectiveDetailsText = "" }
    }

    return [pscustomobject]@{
        id = $Id
        title = $Title
        status = $Status
        summary = $Summary
        details = @($Details)
        data = $Data
        details_text = $effectiveDetailsText
        evidence = @($Evidence)
        log_slice = @($LogSlice)
        log_export_path = ("" + $LogExportPath)
        duration_ms = $DurationMs
    }
}

function Get-StatusScore([string]$Status) {
    switch ($Status) {
        "OK" { return 0 }
        "SKIP" { return 0 }
        "WARN" { return 1 }
        "FAIL" { return 2 }
        "CRITICAL" { return 3 }
        default { return 3 }
    }
}

function Format-StatusTag([string]$Status) {
    switch ($Status) {
        "OK" { return "[OK]" }
        "SKIP" { return "[SKIP]" }
        "WARN" { return "[WARN]" }
        "FAIL" { return "[FAIL]" }
        "CRITICAL" { return "[CRITICAL]" }
        default { return "[CRITICAL]" }
    }
}

function Test-FunctionExists([string]$Name) {
    try {
        $c = Get-Command $Name -CommandType Function -ErrorAction SilentlyContinue
        return ($null -ne $c)
    } catch {
        return $false
    }
}

function Get-ResultScore($Res) {
    if ($null -eq $Res) { return 3 }

    try {
        if (("" + $Res.id) -eq "log_snapshot" -and ("" + $Res.status) -eq "WARN") {
            return 0
        }
    } catch { }

    return Get-StatusScore ("" + $Res.status)
}

function Get-DetailsForOutput($Res) {
    try {
        if ($null -eq $Res) { return @() }

        $detailsArr = ConvertTo-SafeStringArray $Res.details
        if ((Get-SafeCount $detailsArr) -le 0) { return @() }

        $title = ""
        try { $title = "" + $Res.title } catch { $title = "" }

        # Cosmetic: suppress Set-Cookie noise in unauthenticated HTTP probe output.
        if ($title -match 'HTTP exposure probe') {
            $filtered = New-Object System.Collections.Generic.List[string]
            foreach ($d in $detailsArr) {
                $line = ""
                try { $line = "" + $d } catch { $line = "" }
                if ($line -match '^(?i:Set-Cookie\s*:)') { continue }

                # Cosmetic: mark "follow" lines as INFO so "200 /login" doesn't look like exposure.
                if ($line -match '^(?i:FinalStatus\(follow\):)') { $line = "INFO: " + $line }
                elseif ($line -match '^(?i:FinalUri\(follow\):)') { $line = "INFO: " + $line }

                $filtered.Add($line) | Out-Null
            }
            return @($filtered.ToArray())
        }

        return @($detailsArr)
    } catch {
        try { return @(ConvertTo-SafeStringArray $Res.details) } catch { return @() }
    }
}

function Get-LaravelLogPath([string]$Root) {
    try {
        $logsDir = Join-Path $Root "storage\logs"
        if (-not (Test-Path -LiteralPath $logsDir -PathType Container)) { return "" }

        $single = Join-Path $logsDir "laravel.log"
        if (Test-Path -LiteralPath $single -PathType Leaf) { return $single }

        $daily = @()
        try {
            $daily = @(Get-ChildItem -LiteralPath $logsDir -File -Filter "laravel-*.log" -ErrorAction Stop | Sort-Object LastWriteTime -Descending)
        } catch { $daily = @() }
        if ($daily.Count -gt 0) { return ("" + $daily[0].FullName) }

        return ""
    } catch {
        return ""
    }
}

function Get-ResultLogCandidatePaths([string]$PrimaryLogPath, [int]$MaxCandidates = 2) {
    $out = New-Object System.Collections.Generic.List[string]
    try {
        $primary = ("" + $PrimaryLogPath).Trim()
        if ($primary -ne "") {
            $out.Add($primary) | Out-Null
        }

        if ($out.Count -ge $MaxCandidates) { return @($out.ToArray()) }
        if ($primary -eq "") { return @($out.ToArray()) }

        $dir = ""
        try { $dir = [System.IO.Path]::GetDirectoryName($primary) } catch { $dir = "" }
        if ($dir -eq "" -or -not (Test-Path -LiteralPath $dir -PathType Container)) { return @($out.ToArray()) }

        # Prefer backups created by our rotation scheme: "<primary>.bak-YYYYMMDD-HHMMSS"
        try {
            $baseName = ""
            try { $baseName = [System.IO.Path]::GetFileName($primary) } catch { $baseName = "" }
            if ($baseName -ne "") {
                $bak = @()
                try {
                    $bak = @(Get-ChildItem -LiteralPath $dir -File -Filter ($baseName + ".bak-*") -ErrorAction Stop | Sort-Object LastWriteTime -Descending)
                } catch { $bak = @() }

                foreach ($f in $bak) {
                    if ($out.Count -ge $MaxCandidates) { break }
                    $path = ""
                    try { $path = ("" + $f.FullName).Trim() } catch { $path = "" }
                    if ($path -eq "") { continue }
                    if ($path -ieq $primary) { continue }
                    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
                    $out.Add($path) | Out-Null
                }
            }
        } catch { }

        if ($out.Count -ge $MaxCandidates) { return @($out.ToArray()) }

        $daily = @()
        try {
            $daily = @(Get-ChildItem -LiteralPath $dir -File -Filter "laravel-*.log" -ErrorAction Stop | Sort-Object LastWriteTime -Descending)
        } catch { $daily = @() }

        foreach ($f in $daily) {
            if ($out.Count -ge $MaxCandidates) { break }
            $path = ""
            try { $path = ("" + $f.FullName).Trim() } catch { $path = "" }
            if ($path -eq "") { continue }
            if ($path -ieq $primary) { continue }
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
            $out.Add($path) | Out-Null
        }

        if ($out.Count -ge $MaxCandidates) { return @($out.ToArray()) }

        $generic = @()
        try {
            $generic = @(Get-ChildItem -LiteralPath $dir -File -Filter "*.log" -ErrorAction Stop | Sort-Object LastWriteTime -Descending)
        } catch { $generic = @() }

        foreach ($f in $generic) {
            if ($out.Count -ge $MaxCandidates) { break }
            $path = ""
            try { $path = ("" + $f.FullName).Trim() } catch { $path = "" }
            if ($path -eq "") { continue }
            $existsAlready = $false
            foreach ($existing in @($out.ToArray())) {
                if ((("" + $existing).Trim()) -ieq $path) { $existsAlready = $true; break }
            }
            if ($existsAlready) { continue }
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
            $out.Add($path) | Out-Null
        }
    } catch { }

    return @($out.ToArray())
}

function Test-IsIgnoredAuditNoiseLogLine([string]$Line) {
    if ($null -eq $Line) { return $false }
    $l = ""
    try { $l = ("" + $Line).ToLowerInvariant() } catch { $l = "" }
    if ($l -eq "") { return $false }

    if ($l -match 'vendor/psy/psysh') { return $true }
    if ($l -match 'psy\\exception') { return $true }
    if ($l -match 'psy/shell') { return $true }
    if ($l -match 'laravel/tinker') { return $true }
    if ($l -match 'parseerrorexception') { return $true }
    if ($l -match 'codecleaner\.php') { return $true }
    if ($l -match '=config\(') { return $true }
    if ($l -match 'psy\\codecleaner') { return $true }
    if ($l -match 'psy/shell->') { return $true }

    return $false
}

function Convert-ToBooleanSafe([object]$Value, [bool]$Default = $false) {
    try {
        if ($null -eq $Value) { return $Default }
        if ($Value -is [bool]) { return [bool]$Value }
        $s = ("" + $Value).Trim()
        if ($s -eq "") { return $Default }
        if ($s -match '^(?i:1|true|\$true|yes|on)$') { return $true }
        if ($s -match '^(?i:0|false|\$false|no|off)$') { return $false }
        return [System.Convert]::ToBoolean($Value)
    } catch {
        return $Default
    }
}

function Convert-ToIntSafe([object]$Value, [int]$Default = 0) {
    try {
        if ($null -eq $Value) { return $Default }
        $n = [int]$Value
        return $n
    } catch {
        return $Default
    }
}

function Resolve-AuditExportFolder([string]$ProjectRoot, [string]$FolderValue) {
    try {
        $candidate = ("" + $FolderValue).Trim()
        if ($candidate -eq "") { $candidate = "tools/audit/output" }
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            return (Join-Path $ProjectRoot $candidate)
        }
        return $candidate
    } catch {
        return (Join-Path $ProjectRoot "tools/audit/output")
    }
}

function Convert-ToSafeFileSegment([string]$Value) {
    $s = ("" + $Value).Trim().ToLowerInvariant()
    if ($s -eq "") { $s = "check" }
    $s = $s -replace '[^a-z0-9\-_]+', '-'
    $s = $s.Trim('-')
    if ($s -eq "") { $s = "check" }
    return $s
}

function Convert-PerCheckSettingMap([string]$JsonText) {
    $out = @{}
    $raw = ""
    try { $raw = ("" + $JsonText).Trim() } catch { $raw = "" }
    if ($raw -eq "") { return $out }

    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $obj) { return $out }

        foreach ($p in @($obj.PSObject.Properties)) {
            $k = ""
            try { $k = ("" + $p.Name).Trim().ToLowerInvariant() } catch { $k = "" }
            if ($k -eq "") { continue }
            $out[$k] = (Convert-ToBooleanSafe $p.Value $false)
        }
    } catch { }

    return $out
}

function Get-PerCheckEnabled([hashtable]$Map, [string]$CheckId, [bool]$Default = $false) {
    if ($null -eq $Map) { return $Default }
    $k = ""
    try { $k = ("" + $CheckId).Trim().ToLowerInvariant() } catch { $k = "" }
    if ($k -eq "") { return $Default }
    try {
        if ($Map.Contains($k)) { return (Convert-ToBooleanSafe $Map[$k] $Default) }
    } catch { }
    return $Default
}

function Resolve-LaravelLogTimestamp([string]$Line) {
    if ($null -eq $Line) { return $null }
    try {
        if ($Line -match '^\[(?<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\]') {
            return [datetime]::ParseExact($Matches['ts'], 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
        }
    } catch { }
    return $null
}

function Get-ValueFromResultData {
    param(
        [Parameter(Mandatory = $true)]$Data,
        [Parameter(Mandatory = $true)][string[]]$Keys
    )
    foreach ($k in @($Keys)) {
        try {
            if ($Data -is [System.Collections.IDictionary]) {
                if ($Data.Contains($k)) { return $Data[$k] }
            }
            if ($Data.PSObject -and ($Data.PSObject.Properties.Name -contains $k)) {
                return $Data.$k
            }
        } catch { }
    }
    return $null
}

function Get-ResultLogSlice {
    param(
        [Parameter(Mandatory = $true)][string]$LogPath,
        [Parameter(Mandatory = $true)]$Res,
        [Parameter(Mandatory = $true)][datetime]$CheckStartedAt,
        [Parameter(Mandatory = $true)][datetime]$CheckFinishedAt,
        [Parameter(Mandatory = $true)][int]$MaxLines
    )

    $evidence = New-Object System.Collections.Generic.List[string]
    $slice = New-Object System.Collections.Generic.List[string]

    if ($LogPath -eq "") {
        $evidence.Add("No Laravel log file found.") | Out-Null
        return [pscustomobject]@{
            lines = @()
            evidence = @($evidence.ToArray())
            mode = "missing"
        }
    }

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        $evidence.Add("No Laravel log file found.") | Out-Null
        return [pscustomobject]@{
            lines = @()
            evidence = @($evidence.ToArray())
            mode = "missing"
        }
    }

    $all = New-Object System.Collections.Generic.List[string]
    $readOk = $false
    $readErrors = New-Object System.Collections.Generic.List[string]

    # Prefer reading ONLY current laravel.log first to avoid mixing older backups into every run.
    try {
        $primaryPart = @(Get-Content -LiteralPath $LogPath -ErrorAction Stop)
        foreach ($line in $primaryPart) { $all.Add(("" + $line)) | Out-Null }
        $readOk = $true
    } catch {
        $readErrors.Add((("" + $LogPath) + ": " + $_.Exception.Message)) | Out-Null
        $readOk = $false
    }

    # Fallback: if current log is not readable OR empty, scan candidates (bak/daily).
    if ((-not $readOk) -or ($all.Count -le 0)) {
        $all = New-Object System.Collections.Generic.List[string]
        $readOk = $false

        $scanPaths = @(Get-ResultLogCandidatePaths -PrimaryLogPath $LogPath -MaxCandidates 2)
        if ($scanPaths.Count -le 0) { $scanPaths = @($LogPath) }

        foreach ($scanPath in $scanPaths) {
            if (-not (Test-Path -LiteralPath $scanPath -PathType Leaf)) { continue }
            try {
                $part = @(Get-Content -LiteralPath $scanPath -ErrorAction Stop)
                foreach ($line in $part) { $all.Add(("" + $line)) | Out-Null }
                $readOk = $true
            } catch {
                $readErrors.Add((("" + $scanPath) + ": " + $_.Exception.Message)) | Out-Null
            }
        }
    }

    if (-not $readOk) {
        $msg = "LogSlice: failed to read log file."
        if ($readErrors.Count -gt 0) { $msg = ("LogSlice: failed to read log file (" + (($readErrors.ToArray() | Select-Object -First 1) -join "") + ").") }
        $evidence.Add($msg) | Out-Null
        return [pscustomobject]@{
            lines = @()
            evidence = @($evidence.ToArray())
            mode = "read_error"
        }
    }

    if ($all.Count -le 0) {
        $evidence.Add("Log file contains no entries during this run.") | Out-Null
        return [pscustomobject]@{
            lines = @()
            evidence = @($evidence.ToArray())
            mode = "empty"
        }
    }

    $data = $null
    try { $data = $Res.data } catch { $data = $null }

    $corr = ""
    if ($null -ne $data) {
        $corrRaw = Get-ValueFromResultData -Data $data -Keys @("correlation_id","correlationId","request_id","requestId","trace_id","traceId")
        if ($null -ne $corrRaw) { $corr = ("" + $corrRaw).Trim() }
    }

    $nonNoise = New-Object System.Collections.Generic.List[string]
    foreach ($line in $all) {
        $text = "" + $line
        if (Test-IsIgnoredAuditNoiseLogLine $text) { continue }
        $nonNoise.Add($text) | Out-Null
    }
    $allFiltered = @($nonNoise.ToArray())

    if ($allFiltered.Count -le 0) {
        $evidence.Add("Log file contains only Tinker/PsySH noise (ignored).") | Out-Null
        return [pscustomobject]@{
            lines = @()
            evidence = @($evidence.ToArray())
            mode = "empty_filtered"
        }
    }

    if ($corr -ne "") {
        foreach ($line in $allFiltered) {
            $text = "" + $line
            if ($text -like ("*" + $corr + "*")) { $slice.Add($text) | Out-Null }
        }
        if ($slice.Count -gt 0) {
            $evidence.Add("LogSlice mode: correlation_id ($corr)") | Out-Null
            if ($slice.Count -gt $MaxLines) { $slice = New-Object System.Collections.Generic.List[string] (@($slice.ToArray() | Select-Object -Last $MaxLines)) }
            return [pscustomobject]@{
                lines = @($slice.ToArray())
                evidence = @($evidence.ToArray())
                mode = "correlation"
            }
        }
    }

    $from = $CheckStartedAt
    $to = $CheckFinishedAt
    if ($to -lt $from) { $to = $from }
    $to = $to.AddSeconds(2)

    $hasParseableTimestamp = $false
    foreach ($line in $allFiltered) {
        $text = "" + $line
        $ts = Resolve-LaravelLogTimestamp $text
        if ($null -eq $ts) { continue }
        $hasParseableTimestamp = $true
        if ($ts -ge $from -and $ts -le $to) { $slice.Add($text) | Out-Null }
    }

    if ($slice.Count -gt 0) {
        $evidence.Add("LogSlice mode: time_window ($($from.ToString('yyyy-MM-dd HH:mm:ss')) .. $($to.ToString('yyyy-MM-dd HH:mm:ss'))).") | Out-Null
        if ($slice.Count -gt $MaxLines) { $slice = New-Object System.Collections.Generic.List[string] (@($slice.ToArray() | Select-Object -Last $MaxLines)) }
        return [pscustomobject]@{
            lines = @($slice.ToArray())
            evidence = @($evidence.ToArray())
            mode = "time_window"
        }
    }

    if ($hasParseableTimestamp) {
        $nearSlice = New-Object System.Collections.Generic.List[string]
        $nearFrom = $from.AddMinutes(-2)
        $nearTo = $to.AddMinutes(2)
        foreach ($line in $allFiltered) {
            $text = "" + $line
            $ts = Resolve-LaravelLogTimestamp $text
            if ($null -eq $ts) { continue }
            if ($ts -ge $nearFrom -and $ts -le $nearTo) { $nearSlice.Add($text) | Out-Null }
        }

        if ($nearSlice.Count -gt 0) {
            $evidence.Add("LogSlice mode: fallback near time window ($($nearFrom.ToString('yyyy-MM-dd HH:mm:ss')) .. $($nearTo.ToString('yyyy-MM-dd HH:mm:ss'))).") | Out-Null
            if ($nearSlice.Count -gt $MaxLines) { $nearSlice = New-Object System.Collections.Generic.List[string] (@($nearSlice.ToArray() | Select-Object -Last $MaxLines)) }
            return [pscustomobject]@{
                lines = @($nearSlice.ToArray())
                evidence = @($evidence.ToArray())
                mode = "time_window_fallback_near"
            }
        }

        $evidence.Add("LogSlice mode: fallback tail ($MaxLines lines) after empty check window.") | Out-Null
        $tailAfterWindowMiss = @($allFiltered | Select-Object -Last $MaxLines)
        return [pscustomobject]@{
            lines = @($tailAfterWindowMiss)
            evidence = @($evidence.ToArray())
            mode = "time_window_empty_tail"
        }
    }

    $evidence.Add("LogSlice mode: fallback tail ($MaxLines lines).") | Out-Null
    $tail = @($allFiltered | Select-Object -Last $MaxLines)
    return [pscustomobject]@{
        lines = @($tail)
        evidence = @($evidence.ToArray())
        mode = "tail"
    }
}

function Invoke-LaravelLogRotateIfExists([string]$Root, [string]$PhaseLabel) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $logPath = ""
    try { $logPath = Get-LaravelLogPath $Root } catch { $logPath = "" }

    if (-not $logPath -or ("" + $logPath).Trim() -eq "") {
        $sw.Stop()
        return (New-AuditResult -Id ("log_clear_" + $PhaseLabel) -Title ("Log cleanup (" + $PhaseLabel + ")") -Status "WARN" -Summary "Could not determine laravel.log path." -Details @() -Data @{} -DurationMs ([int]$sw.ElapsedMilliseconds))
    }

    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
        $sw.Stop()
        return (New-AuditResult -Id ("log_clear_" + $PhaseLabel) -Title ("Log cleanup (" + $PhaseLabel + ")") -Status "OK" -Summary "laravel.log not found; nothing to do." -Details @("Path: " + $logPath) -Data @{ path = $logPath; action = "none"; exists = $false } -DurationMs ([int]$sw.ElapsedMilliseconds))
    }

    $ts = ""
    try { $ts = (Get-Date).ToString("yyyyMMdd-HHmmss") } catch { $ts = "unknown" }

    $bakPath = ""
    try { $bakPath = ($logPath + ".bak-" + $ts) } catch { $bakPath = "" }

    try {
        Move-Item -LiteralPath $logPath -Destination $bakPath -Force -ErrorAction Stop | Out-Null

        # Recreate empty laravel.log (UTF-8, no BOM)
        try {
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($logPath, "", $utf8NoBom)
        } catch {
            # Fallback: create empty file
            try { New-Item -ItemType File -Path $logPath -Force | Out-Null } catch { }
        }

        $sw.Stop()
        return (New-AuditResult -Id ("log_clear_" + $PhaseLabel) -Title ("Log cleanup (" + $PhaseLabel + ")") -Status "OK" -Summary "Rotated laravel.log to backup and recreated empty log." -Details @("Path: " + $logPath, "Backup: " + $bakPath) -Data @{ path = $logPath; backup = $bakPath; action = "rotate" } -DurationMs ([int]$sw.ElapsedMilliseconds))
    } catch {
        $msg = ""
        try { $msg = $_.Exception.Message } catch { $msg = "unknown_error" }

        $sw.Stop()
        return (New-AuditResult -Id ("log_clear_" + $PhaseLabel) -Title ("Log cleanup (" + $PhaseLabel + ")") -Status "WARN" -Summary ("Failed to rotate laravel.log: " + $msg) -Details @("Path: " + $logPath, "Backup: " + $bakPath) -Data @{ path = $logPath; backup = $bakPath; action = "failed" } -DurationMs ([int]$sw.ElapsedMilliseconds))
    }
}

Export-ModuleMember -Function *
