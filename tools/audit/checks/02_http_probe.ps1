# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\02_http_probe.ps1
# Purpose: Audit check - HTTP exposure probe (deterministic interpretation)
# Created: 21-02-2026 00:18 (Europe/Berlin)
# Changed: 23-02-2026 03:24 (Europe/Berlin)
# Version: 1.5
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_HttpProbe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $new = $Context.Helpers.NewAuditResult
    $baseUrl = ("" + $Context.BaseUrl).TrimEnd('/')
    $paths = $Context.ProbePaths
    $expected = $Context.ExpectedUnauthedHttpCodes
    $timeoutSec = [int]$Context.HttpTimeoutSec

    & $Context.Helpers.WriteSection "2) HTTP exposure probe (unauthenticated)"

    function Normalize-ProbePaths {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $false)]
            $Value
        )

        $out = New-Object System.Collections.Generic.List[string]

        if ($null -eq $Value) { return @() }

        function Strip-SurroundingQuotes([string]$Text) {
            if ($null -eq $Text) { return "" }

            $t = ("" + $Text).Trim()

            # Remove matching surrounding quotes repeatedly: "x" -> x, 'x' -> x
            while ($t.Length -ge 2) {
                $first = $t.Substring(0, 1)
                $last  = $t.Substring($t.Length - 1, 1)

                if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
                    $t = $t.Substring(1, $t.Length - 2).Trim()
                    continue
                }

                break
            }

            # If runner produced tokens like "/admin" as a literal with quotes included
            # (e.g. starts with '"', then '/', but doesn't end with '"'), trim leading quote.
            if ($t.Length -ge 2) {
                if (($t.StartsWith('"') -and $t.Substring(1, 1) -eq "/")) {
                    $t = $t.Substring(1).Trim()
                } elseif (($t.StartsWith("'") -and $t.Substring(1, 1) -eq "/")) {
                    $t = $t.Substring(1).Trim()
                }
            }

            # Also trim trailing quote if it ends with a quote
            if ($t.EndsWith('"') -or $t.EndsWith("'")) {
                $t = $t.TrimEnd('"', "'").Trim()
            }

            return $t
        }

        # Treat scalar as single-item array.
        $arr = @($Value)

        foreach ($item in $arr) {
            if ($null -eq $item) { continue }

            $s = ""
            try { $s = ("" + $item) } catch { $s = "" }
            $s = (Strip-SurroundingQuotes $s).Trim()
            if ($s -eq "") { continue }

            # If a single element contains multiple paths (space/newline separated), split it.
            if ($s -match "\r?\n" -or $s -match "\s") {
                $tokens = $s -split "[\s,;]+"
                foreach ($t in $tokens) {
                    $p = ""
                    try { $p = ("" + $t) } catch { $p = "" }
                    $p = (Strip-SurroundingQuotes $p).Trim()
                    if ($p -eq "") { continue }

                    # Accept absolute URLs too; extract AbsolutePath.
                    if ($p -match '^(?i)https?://') {
                        try {
                            $u = $null
                            $ok = $false
                            try { $ok = [System.Uri]::TryCreate($p, [System.UriKind]::Absolute, [ref]$u) } catch { $ok = $false }
                            if ($ok -and $u -and $u.AbsolutePath) { $p = ("" + $u.AbsolutePath) }
                        } catch { }
                    }

                    if (-not $p.StartsWith("/")) { continue }
                    $out.Add($p) | Out-Null
                }
                continue
            }

            # Accept absolute URLs too; extract AbsolutePath.
            if ($s -match '^(?i)https?://') {
                try {
                    $u = $null
                    $ok = $false
                    try { $ok = [System.Uri]::TryCreate($s, [System.UriKind]::Absolute, [ref]$u) } catch { $ok = $false }
                    if ($ok -and $u -and $u.AbsolutePath) { $s = ("" + $u.AbsolutePath).Trim() }
                } catch { }
            }

            if (-not $s.StartsWith("/")) { continue }
            $out.Add($s) | Out-Null
        }

        # De-duplicate (preserve order)
        $dedup = New-Object System.Collections.Generic.List[string]
        $seen = @{}
        foreach ($p in @($out.ToArray())) {
            if (-not $p) { continue }
            if ($seen.ContainsKey($p)) { continue }
            $seen[$p] = $true
            $dedup.Add($p) | Out-Null
        }

        # IMPORTANT: return a plain PowerShell array (not the List object itself)
        return @($dedup.ToArray())
    }

    $rawPaths = @()
    try { $rawPaths = @($paths) } catch { $rawPaths = @() }

    $paths = Normalize-ProbePaths $paths
    $paths = @($paths)

    $expected = @($expected)

    if (@($paths).Count -eq 0) {
        $sw.Stop()

        $diag = @()
        $diag += ("BaseUrl: " + $baseUrl)
        $diag += ("ProbePaths(raw): " + (@($rawPaths).Count))
        try { $diag += ("ProbePaths(raw values): " + (($rawPaths | ForEach-Object { "" + $_ }) -join " | ")) } catch { }

        return & $new -Id "http_probe" -Title "2) HTTP exposure probe" -Status "WARN" -Summary "No ProbePaths configured after normalization." -Details $diag -Data @{ base_url = $baseUrl } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    function Get-ValuesAsString($Values) {
        if ($null -eq $Values) { return "" }
        try {
            if ($Values -is [string]) { return ("" + $Values) }
        } catch { }
        try {
            $arr = @($Values)
            if ($arr.Count -le 0) { return "" }
            return (($arr | ForEach-Object { "" + $_ }) -join ", ")
        } catch { }
        return ("" + $Values)
    }

    function Try-GetHeaderValueFromHashtable {
        param(
            [Parameter(Mandatory = $true)]$Headers,
            [Parameter(Mandatory = $true)][string]$Name
        )

        try {
            if ($Headers -is [System.Collections.IDictionary]) {
                foreach ($k in @($Headers.Keys)) {
                    try {
                        if (("" + $k).Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                            return Get-ValuesAsString $Headers[$k]
                        }
                    } catch { }
                }
            }
        } catch { }

        return ""
    }

    function Ensure-SystemNetHttp {
        [CmdletBinding()]
        param()

        # On some hosts the assembly is not loaded; without it, HttpClient types are "not found".
        try {
            $t = $null
            try { $t = [type]"System.Net.Http.HttpClient" } catch { $t = $null }
            if ($t -ne $null) { return $true }

            Add-Type -AssemblyName "System.Net.Http" -ErrorAction Stop | Out-Null

            $t2 = $null
            try { $t2 = [type]"System.Net.Http.HttpClient" } catch { $t2 = $null }
            return ($t2 -ne $null)
        } catch {
            return $false
        }
    }

    function Invoke-HttpClientRequest {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)][string]$Url,
            [Parameter(Mandatory = $true)][bool]$AllowRedirects
        )

        if (-not (Ensure-SystemNetHttp)) {
            return [pscustomobject]@{
                ok = $false
                status = 0
                location = ""
                x_role = ""
                x_section = ""
                set_cookie = ""
                finalUri = ""
                error = "System.Net.Http is not available in this PowerShell host."
            }
        }

        $handler = $null
        $client = $null
        $resp = $null

        try {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $handler.AllowAutoRedirect = $AllowRedirects

            $client = [System.Net.Http.HttpClient]::new($handler)
            $client.Timeout = [System.TimeSpan]::FromSeconds([double]$timeoutSec)

            $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Url)
            $resp = $client.SendAsync($req).GetAwaiter().GetResult()

            $status = 0
            try { $status = [int]$resp.StatusCode } catch { $status = 0 }

            $finalUri = ""
            try {
                if ($resp.RequestMessage -and $resp.RequestMessage.RequestUri) {
                    $finalUri = ("" + $resp.RequestMessage.RequestUri.AbsoluteUri)
                }
            } catch { $finalUri = "" }

            $loc = ""
            $xRole = ""
            $xSection = ""
            $setCookie = ""

            # HttpResponseMessage headers
            try {
                $vals = $null
                if ($resp.Headers.TryGetValues("Location", [ref]$vals)) { $loc = Get-ValuesAsString $vals }
            } catch { }
            try {
                $vals = $null
                if ($resp.Headers.TryGetValues("X-KS-Role", [ref]$vals)) { $xRole = Get-ValuesAsString $vals }
            } catch { }
            try {
                $vals = $null
                if ($resp.Headers.TryGetValues("X-KS-Section", [ref]$vals)) { $xSection = Get-ValuesAsString $vals }
            } catch { }
            try {
                $vals = $null
                if ($resp.Headers.TryGetValues("Set-Cookie", [ref]$vals)) { $setCookie = Get-ValuesAsString $vals }
            } catch { }

            # Fallback to content headers if needed (rare)
            try {
                if ($resp.Content -and $resp.Content.Headers) {
                    if ($loc -eq "") {
                        $vals = $null
                        if ($resp.Content.Headers.TryGetValues("Location", [ref]$vals)) { $loc = Get-ValuesAsString $vals }
                    }
                    if ($setCookie -eq "") {
                        $vals = $null
                        if ($resp.Content.Headers.TryGetValues("Set-Cookie", [ref]$vals)) { $setCookie = Get-ValuesAsString $vals }
                    }
                }
            } catch { }

            return [pscustomobject]@{
                ok = $true
                status = $status
                location = $loc
                x_role = $xRole
                x_section = $xSection
                set_cookie = $setCookie
                finalUri = $finalUri
                error = ""
            }
        } catch {
            return [pscustomobject]@{
                ok = $false
                status = 0
                location = ""
                x_role = ""
                x_section = ""
                set_cookie = ""
                finalUri = ""
                error = ("" + $_.Exception.Message)
            }
        } finally {
            try { if ($resp) { $resp.Dispose() } } catch { }
            try { if ($client) { $client.Dispose() } } catch { }
            try { if ($handler) { $handler.Dispose() } } catch { }
        }
    }

    function Invoke-IwrRequest {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)][string]$Url,
            [Parameter(Mandatory = $true)][int]$MaxRedirs
        )

        $useBasicParsingSupported = $false
        try {
            $cmd = Get-Command Invoke-WebRequest -ErrorAction Stop
            if ($cmd -and $cmd.Parameters -and $cmd.Parameters.ContainsKey("UseBasicParsing")) {
                $useBasicParsingSupported = $true
            }
        } catch { $useBasicParsingSupported = $false }

        try {
            $iwrParams = @{
                Uri                = $Url
                MaximumRedirection = $MaxRedirs
                TimeoutSec         = $timeoutSec
                Method             = "GET"
                ErrorAction        = "Stop"
            }
            if ($useBasicParsingSupported) {
                $iwrParams.UseBasicParsing = $true
            }

            $r = Invoke-WebRequest @iwrParams

            $status = 0
            try { $status = [int]$r.StatusCode } catch { $status = 0 }

            $finalUri = ""
            try {
                if ($r.BaseResponse -and $r.BaseResponse.ResponseUri) { $finalUri = ("" + $r.BaseResponse.ResponseUri.AbsoluteUri) }
            } catch { $finalUri = "" }

            $loc = Try-GetHeaderValueFromHashtable -Headers $r.Headers -Name "Location"
            $xRole = Try-GetHeaderValueFromHashtable -Headers $r.Headers -Name "X-KS-Role"
            $xSection = Try-GetHeaderValueFromHashtable -Headers $r.Headers -Name "X-KS-Section"
            $setCookie = Try-GetHeaderValueFromHashtable -Headers $r.Headers -Name "Set-Cookie"

            return [pscustomobject]@{
                ok = $true
                status = $status
                location = $loc
                x_role = $xRole
                x_section = $xSection
                set_cookie = $setCookie
                finalUri = $finalUri
                error = ""
            }
        } catch {
            $resp = $null
            try {
                if ($_.Exception -and ($_.Exception | Get-Member -Name Response -ErrorAction SilentlyContinue)) {
                    $resp = $_.Exception.Response
                }
            } catch { $resp = $null }

            if ($resp) {
                $st = 0
                try { $st = [int]$resp.StatusCode } catch { $st = 0 }

                $headers = $null
                try { $headers = $resp.Headers } catch { $headers = $null }

                $finalUri = ""
                try {
                    if ($resp.ResponseUri) { $finalUri = ("" + $resp.ResponseUri.AbsoluteUri) }
                } catch { $finalUri = "" }

                $loc = ""
                $xRole = ""
                $xSection = ""
                $setCookie = ""

                try {
                    if ($headers) {
                        $loc = Try-GetHeaderValueFromHashtable -Headers $headers -Name "Location"
                        $xRole = Try-GetHeaderValueFromHashtable -Headers $headers -Name "X-KS-Role"
                        $xSection = Try-GetHeaderValueFromHashtable -Headers $headers -Name "X-KS-Section"
                        $setCookie = Try-GetHeaderValueFromHashtable -Headers $headers -Name "Set-Cookie"
                    }
                } catch { }

                return [pscustomobject]@{
                    ok = $true
                    status = $st
                    location = $loc
                    x_role = $xRole
                    x_section = $xSection
                    set_cookie = $setCookie
                    finalUri = $finalUri
                    error = ""
                }
            }

            return [pscustomobject]@{
                ok = $false
                status = 0
                location = ""
                x_role = ""
                x_section = ""
                set_cookie = ""
                finalUri = ""
                error = ("" + $_.Exception.Message)
            }
        }
    }

    function Is-LoginRedirect([string]$LocationValue) {
        if ($null -eq $LocationValue) { return $false }
        $loc = ("" + $LocationValue).Trim()
        if ($loc -eq "") { return $false }

        try {
            $u = $null
            $ok = $false
            try { $ok = [System.Uri]::TryCreate($loc, [System.UriKind]::Absolute, [ref]$u) } catch { $ok = $false }
            if ($ok -and $u -and $u.AbsolutePath) {
                return (($u.AbsolutePath.TrimEnd('/')) -ieq "/login")
            }
        } catch { }

        if ($loc.StartsWith("/")) {
            return (($loc.TrimEnd('/')) -ieq "/login")
        }

        return $false
    }

    function Is-LoginFinalUri([string]$FinalUriValue) {
        if ($null -eq $FinalUriValue) { return $false }
        $uText = ("" + $FinalUriValue).Trim()
        if ($uText -eq "") { return $false }

        try {
            $u = $null
            $ok = $false
            try { $ok = [System.Uri]::TryCreate($uText, [System.UriKind]::Absolute, [ref]$u) } catch { $ok = $false }
            if ($ok -and $u -and $u.AbsolutePath) {
                return (($u.AbsolutePath.TrimEnd('/')) -ieq "/login")
            }
        } catch { }

        if ($uText.StartsWith("/")) {
            return (($uText.TrimEnd('/')) -ieq "/login")
        }

        return $false
    }

    function FinalUri-LooksLikeAdmin([string]$FinalUriValue) {
        if ($null -eq $FinalUriValue) { return $false }
        $uText = ("" + $FinalUriValue).Trim()
        if ($uText -eq "") { return $false }

        try {
            $u = $null
            $ok = $false
            try { $ok = [System.Uri]::TryCreate($uText, [System.UriKind]::Absolute, [ref]$u) } catch { $ok = $false }
            if ($ok -and $u -and $u.AbsolutePath) {
                return ($u.AbsolutePath -match '(^|/)admin(/|$)')
            }
        } catch { }

        return ($uText -match '(^|/)admin(/|$)')
    }

    $plannedPaths = @($paths)
    $executedPaths = New-Object System.Collections.Generic.List[string]
    $skippedPaths = New-Object System.Collections.Generic.List[string]

    $findings = @()
    $exposure = @()
    $followIssues = @()
    $details = @()

    # Deterministic diagnostics: show probe path normalization outcome.
    $details += ("INFO: BaseUrl: " + $baseUrl)
    $details += ("INFO: ProbePaths(raw count): " + (@($rawPaths).Count))
    try { $details += ("INFO: ProbePaths(raw): " + (($rawPaths | ForEach-Object { "" + $_ }) -join " | ")) } catch { }
    $details += ("INFO: ProbePaths(normalized count): " + (@($plannedPaths).Count))
    $details += ("INFO: ProbePaths(normalized): " + ((@($plannedPaths) | ForEach-Object { "" + $_ }) -join " | "))
    $details += ""

    foreach ($p in @($plannedPaths)) {
        $path = ("" + $p).Trim()
        if ($path -eq "") {
            $skippedPaths.Add("(empty)") | Out-Null
            continue
        }

        $executedPaths.Add($path) | Out-Null
        $url = $baseUrl + $path

        # Prefer HttpClient for deterministic redirect handling; fallback to IWR if HttpClient isn't available.
        $r0 = Invoke-HttpClientRequest -Url $url -AllowRedirects:$false
        $r1 = Invoke-HttpClientRequest -Url $url -AllowRedirects:$true

        if (-not $r0.ok -and ($r0.error -match "System\.Net\.Http is not available")) {
            $r0 = Invoke-IwrRequest -Url $url -MaxRedirs 0
            $r1 = Invoke-IwrRequest -Url $url -MaxRedirs 20
        }

        $status0 = [int]$r0.status
        $statusFinal = [int]$r1.status

        $expectedStr = (@($expected) -join ",")
        $ok = (@($expected) -contains $status0)

        if (-not $ok) {
            if ($status0 -eq 200) {
                $exposure += ($url + " returned 200 (unauthenticated)")
            } elseif ($status0 -gt 0) {
                $exposure += ($url + " returned unexpected status " + $status0 + " (expected " + $expectedStr + ")")
            } else {
                $exposure += ($url + " request failed: " + $r0.error)
            }
        }

        # Follow sanity: only relevant when we're in the "expected unauth" case but want to detect broken login targets.
        $loginRedirectExpected = $false
        try {
            if ($ok -and $status0 -eq 302 -and (Is-LoginRedirect $r0.location)) { $loginRedirectExpected = $true }
        } catch { $loginRedirectExpected = $false }

        if ($loginRedirectExpected) {
            $followBad = $false
            try {
                if (-not $r1.ok) { $followBad = $true }
                elseif ($statusFinal -ge 400) { $followBad = $true }
                elseif (-not (Is-LoginFinalUri $r1.finalUri)) { $followBad = $true }
                elseif (FinalUri-LooksLikeAdmin $r1.finalUri) { $followBad = $true }
            } catch { $followBad = $true }

            if ($followBad) {
                $followIssues += ($url + " redirected to /login but follow result looks wrong (status=" + $statusFinal + ", uri=" + ("" + $r1.finalUri) + ")")
            }
        }

        $showFollow = $false
        try {
            if (-not $r1.ok) { $showFollow = $true }
            elseif (-not $ok) { $showFollow = $true }
            elseif ($status0 -eq 302 -and (-not (Is-LoginRedirect $r0.location))) { $showFollow = $true }
            elseif ($statusFinal -ge 400) { $showFollow = $true }
            elseif ($r1.finalUri -and ("" + $r1.finalUri).Trim() -ne "" -and (-not (Is-LoginFinalUri $r1.finalUri))) { $showFollow = $true }
            elseif (FinalUri-LooksLikeAdmin $r1.finalUri) { $showFollow = $true }
        } catch { $showFollow = $true }

        $details += ("--- " + $url + " ---")
        if ($r0.ok) {
            $details += ("Status(no-redirect): " + $status0)
            if ($r0.location -and $r0.location.Trim() -ne "") { $details += ("Location: " + $r0.location) }
            if ($r0.set_cookie -and $r0.set_cookie.Trim() -ne "") { $details += ("Set-Cookie: " + $r0.set_cookie) }
            if ($r0.x_role -and $r0.x_role.Trim() -ne "") { $details += ("X-KS-Role: " + $r0.x_role) }
            if ($r0.x_section -and $r0.x_section.Trim() -ne "") { $details += ("X-KS-Section: " + $r0.x_section) }

            if ($ok) {
                if ($status0 -eq 302 -and (Is-LoginRedirect $r0.location)) {
                    $details += "Result: OK (302 -> /login)"
                } else {
                    $details += ("Result: OK (" + $status0 + ")")
                }
            } else {
                $details += ("Result: NOT OK (" + $status0 + " expected " + $expectedStr + ")")
            }
        } else {
            $details += ("Request error (no-redirect): " + $r0.error)
            $showFollow = $true
        }

        if ($showFollow) {
            if ($r1.ok) {
                # INFO only: follow output can show 200 /login and should not look like exposure.
                $details += ("INFO: FollowStatus: " + $statusFinal)
                if ($r1.finalUri -and $r1.finalUri.Trim() -ne "") { $details += ("INFO: FollowUri: " + $r1.finalUri) }
            } else {
                $details += ("Request error (follow): " + $r1.error)
            }
        }

        $findings += [pscustomobject]@{
            url = $url
            status_no_redirect = $status0
            location = $r0.location
            status_final = $statusFinal
            final_uri = $r1.finalUri
            expected_unauthed = @($expected)
        }
    }

    $plannedCount = [int](@($plannedPaths).Count)
    $executedCount = [int](@($executedPaths.ToArray()).Count)
    $skippedCount = [int](@($skippedPaths.ToArray()).Count)

    $details += ""
    $details += ("INFO: Probed endpoints executed/planned: " + $executedCount + "/" + $plannedCount)
    if ($skippedCount -gt 0) {
        $details += ("INFO: Skipped ProbePaths entries: " + $skippedCount)
    }

    $sw.Stop()

    $data = @{
        base_url = $baseUrl
        expected_unauthed = @($expected)
        findings = @($findings)
        exposure_count = [int](@($exposure).Count)
        follow_issue_count = [int](@($followIssues).Count)
        probe_paths_raw_count = [int](@($rawPaths).Count)
        probe_paths_normalized_count = [int](@($plannedPaths).Count)
        probe_paths_normalized = @($plannedPaths)
        probe_paths_executed_count = $executedCount
        probe_paths_executed = @($executedPaths.ToArray())
        probe_paths_skipped_count = $skippedCount
        probe_paths_skipped = @($skippedPaths.ToArray())
    }

    if (@($exposure).Count -gt 0) {
        $critDetails = @()
        $critDetails += "Exposure findings (unauthenticated):"
        $critDetails += @($exposure)
        $critDetails += ""
        $critDetails += @($details)

        return & $new -Id "http_probe" -Title "2) HTTP exposure probe" -Status "CRITICAL" -Summary ("Exposure detected (" + @($exposure).Count + ").") -Details $critDetails -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if (@($followIssues).Count -gt 0) {
        $warnDetails = @()
        $warnDetails += "Follow anomalies (unauthenticated; redirect target sanity):"
        $warnDetails += @($followIssues)
        $warnDetails += ""
        $warnDetails += @($details)

        return & $new -Id "http_probe" -Title "2) HTTP exposure probe" -Status "WARN" -Summary ("No exposure detected for " + $executedCount + " endpoints, but follow anomalies: " + @($followIssues).Count + ".") -Details $warnDetails -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($executedCount -ne $plannedCount) {
        $warnDetails = @()
        $warnDetails += "ProbePaths execution mismatch:"
        $warnDetails += ("Planned (normalized): " + $plannedCount)
        $warnDetails += ("Executed: " + $executedCount)
        if ($skippedCount -gt 0) {
            $warnDetails += ("Skipped entries: " + $skippedCount)
            foreach ($s in @($skippedPaths.ToArray())) { $warnDetails += ("  " + $s) }
        }
        $warnDetails += ""
        $warnDetails += @($details)

        return & $new -Id "http_probe" -Title "2) HTTP exposure probe" -Status "WARN" -Summary ("No exposure detected, but only executed " + $executedCount + " of " + $plannedCount + " ProbePaths.") -Details $warnDetails -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    return & $new -Id "http_probe" -Title "2) HTTP exposure probe" -Status "OK" -Summary ("No exposure detected for " + $executedCount + " endpoints.") -Details @($details) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
}