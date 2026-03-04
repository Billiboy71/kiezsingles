# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\checks\02_login_csrf_probe.ps1
# Purpose: Audit check - Login/CSRF probe (optional preflight)
# Created: 28-02-2026 (Europe/Berlin)
# Changed: 04-03-2026 01:38 (Europe/Berlin)
# Version: 2.1
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-KsAuditCheck_LoginCsrfProbe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $new = $Context.Helpers.NewAuditResult
    $baseUrl = (("" + $Context.BaseUrl).TrimEnd("/")).Trim()
    if ($baseUrl -ne "" -and $baseUrl -notmatch '^(?i)https?://') { $baseUrl = ("http://" + $baseUrl) }
    $email = ("" + $Context.SuperadminEmail).Trim()
    $password = ("" + $Context.SuperadminPassword)

    & $Context.Helpers.WriteSection "2) Login CSRF probe (preflight)"

    function Invoke-KsHttpNoRedirect {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)][string]$Uri,
            [Parameter(Mandatory = $true)][ValidateSet("GET","POST")][string]$Method,
            [Parameter(Mandatory = $true)][System.Net.CookieContainer]$CookieJar,
            [Parameter(Mandatory = $false)][hashtable]$Headers = @{},
            [Parameter(Mandatory = $false)]$Body = $null,
            [Parameter(Mandatory = $false)][int]$TimeoutSeconds = 12,
            [Parameter(Mandatory = $false)][hashtable]$ManualCookieStore = $null,
            [Parameter(Mandatory = $false)][bool]$DisableCookieContainer = $false
        )

        function Normalize-CookieValue {
            param(
                [Parameter(Mandatory = $true)][string]$Value
            )
            $v = ("" + $Value).Trim()
            if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) {
                $v = $v.Substring(1, $v.Length - 2)
            }
            return $v
        }

        function Split-SetCookieHeaderValueIntoCookies {
            param(
                [Parameter(Mandatory = $true)][string]$HeaderValue
            )

            $h = ("" + $HeaderValue).Trim()
            if ($h -eq "") { return @() }

            # Some servers/proxies can combine multiple Set-Cookie values into one header line separated by comma.
            # We split on commas that introduce a new cookie ("..., <name>="), but do NOT split within Expires which contains a comma.
            try {
                $parts = $h -split ',(?=\s*[^\s;,]+=)', 0, [System.Text.RegularExpressions.RegexOptions]::None
                $out = @()
                foreach ($p in @($parts)) {
                    $t = ("" + $p).Trim()
                    if ($t -ne "") { $out += $t }
                }
                return $out
            } catch {
                return @($h)
            }
        }

        $result = [pscustomobject]@{
            ok               = $false
            status           = 0
            body             = ""
            location         = ""
            error            = ""
            set_cookie_count = 0
        }

        $handler = $null
        $client = $null
        $req = $null
        $resp = $null

        try {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $handler.AllowAutoRedirect = $false

            if ($DisableCookieContainer) {
                $handler.UseCookies = $false
            } else {
                $handler.UseCookies = $true
                $handler.CookieContainer = $CookieJar
            }

            try { $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate } catch { }

            $client = [System.Net.Http.HttpClient]::new($handler)
            $client.Timeout = [System.TimeSpan]::FromSeconds([Math]::Max(1, $TimeoutSeconds))

            $httpMethod = $null
            if ($Method -eq "POST") { $httpMethod = [System.Net.Http.HttpMethod]::Post } else { $httpMethod = [System.Net.Http.HttpMethod]::Get }

            $req = [System.Net.Http.HttpRequestMessage]::new($httpMethod, $Uri)

            if ($Method -eq "POST") {
                if ($null -ne $Body) {
                    if ($Body -is [hashtable]) {
                        $pairs = [System.Collections.Generic.List[System.Collections.Generic.KeyValuePair[string,string]]]::new()
                        foreach ($k in @($Body.Keys)) {
                            $key = ("" + $k)
                            $rawVal = $Body[$k]
                            $val = ""
                            if ($null -ne $rawVal) {
                                if (($rawVal -is [System.Collections.IEnumerable]) -and -not ($rawVal -is [string])) {
                                    $val = (@($rawVal) | ForEach-Object { "" + $_ }) -join ","
                                } else {
                                    $val = "" + $rawVal
                                }
                            }
                            $pairs.Add([System.Collections.Generic.KeyValuePair[string,string]]::new($key, $val))
                        }
                        $req.Content = [System.Net.Http.FormUrlEncodedContent]::new($pairs)
                    } else {
                        $rawBody = $Body
                        $bodyStr = ""
                        if ($null -ne $rawBody) {
                            if (($rawBody -is [System.Collections.IEnumerable]) -and -not ($rawBody -is [string])) {
                                $bodyStr = (@($rawBody) | ForEach-Object { "" + $_ }) -join ","
                            } else {
                                $bodyStr = "" + $rawBody
                            }
                        }
                        $req.Content = [System.Net.Http.StringContent]::new($bodyStr, [System.Text.Encoding]::UTF8, "application/x-www-form-urlencoded")
                    }
                } else {
                    $req.Content = [System.Net.Http.StringContent]::new("", [System.Text.Encoding]::UTF8, "application/x-www-form-urlencoded")
                }
            }

            if ($null -ne $Headers) {
                foreach ($k in @($Headers.Keys)) {
                    $name = ("" + $k).Trim()
                    if ($name -eq "") { continue }

                    $rawVal = $Headers[$k]
                    $val = ""
                    if ($null -ne $rawVal) {
                        if (($rawVal -is [System.Collections.IEnumerable]) -and -not ($rawVal -is [string])) {
                            $val = (@($rawVal) | ForEach-Object { "" + $_ }) -join ","
                        } else {
                            $val = "" + $rawVal
                        }
                    }

                    $added = $false
                    try { $added = $req.Headers.TryAddWithoutValidation($name, $val) } catch { $added = $false }
                    if (-not $added -and $null -ne $req.Content) {
                        try { [void]$req.Content.Headers.TryAddWithoutValidation($name, $val) } catch { }
                    }
                }
            }

            # Always send cookies manually if we have them (removes CookieContainer domain/secure quirks).
            if ($null -ne $ManualCookieStore -and $ManualCookieStore.Count -gt 0) {
                try {
                    $cookieParts = New-Object System.Collections.Generic.List[string]
                    foreach ($ck in @($ManualCookieStore.Keys)) {
                        $n = ("" + $ck).Trim()
                        if ($n -eq "") { continue }
                        $v = $ManualCookieStore[$ck]
                        if ($null -eq $v) { continue }
                        $cookieParts.Add(($n + "=" + ("" + $v))) | Out-Null
                    }
                    if ($cookieParts.Count -gt 0) {
                        $cookieHeader = ($cookieParts.ToArray() -join "; ")
                        try {
                            try { [void]$req.Headers.Remove("Cookie") } catch { }
                            [void]$req.Headers.TryAddWithoutValidation("Cookie", $cookieHeader)
                        } catch { }
                    }
                } catch { }
            }

            $resp = $client.SendAsync($req).GetAwaiter().GetResult()

            # Capture and apply Set-Cookie headers to ManualCookieStore (and CookieJar best-effort).
            try {
                $u = $null
                if ([System.Uri]::TryCreate($Uri, [System.UriKind]::Absolute, [ref]$u) -and $null -ne $u) {
                    $setCookieHeadersRaw = New-Object System.Collections.Generic.List[string]
                    try {
                        if ($resp.Headers -and $resp.Headers.Contains("Set-Cookie")) {
                            foreach ($v in @($resp.Headers.GetValues("Set-Cookie"))) {
                                $h = ("" + $v).Trim()
                                if ($h -ne "") { $setCookieHeadersRaw.Add($h) | Out-Null }
                            }
                        }
                    } catch { }
                    try {
                        if ($resp.Content -and $resp.Content.Headers -and $resp.Content.Headers.Contains("Set-Cookie")) {
                            foreach ($v in @($resp.Content.Headers.GetValues("Set-Cookie"))) {
                                $h = ("" + $v).Trim()
                                if ($h -ne "") { $setCookieHeadersRaw.Add($h) | Out-Null }
                            }
                        }
                    } catch { }

                    $setCookieHeaders = New-Object System.Collections.Generic.List[string]
                    foreach ($raw in @($setCookieHeadersRaw.ToArray())) {
                        foreach ($cookieSpec in @(Split-SetCookieHeaderValueIntoCookies -HeaderValue ("" + $raw))) {
                            $t = ("" + $cookieSpec).Trim()
                            if ($t -ne "") { $setCookieHeaders.Add($t) | Out-Null }
                        }
                    }

                    $result.set_cookie_count = [int]$setCookieHeaders.Count

                    foreach ($h in @($setCookieHeaders.ToArray())) {
                        try { $CookieJar.SetCookies($u, $h) } catch { }

                        if ($null -ne $ManualCookieStore) {
                            try {
                                $first = ("" + $h).Split(";", 2)[0]
                                $eq = $first.IndexOf("=")
                                if ($eq -gt 0) {
                                    $cn = ($first.Substring(0, $eq)).Trim()
                                    $cv = ($first.Substring($eq + 1)).Trim()
                                    $cv = Normalize-CookieValue -Value ("" + $cv)
                                    if ($cn -ne "") { $ManualCookieStore[$cn] = $cv }
                                }
                            } catch { }
                        }
                    }
                }
            } catch { }

            $statusInt = 0
            try { $statusInt = [int]$resp.StatusCode } catch { $statusInt = 0 }

            $location = ""
            try {
                if ($resp.Headers.Location) {
                    $location = ("" + $resp.Headers.Location.ToString()).Trim()
                } elseif ($resp.Headers.Contains("Location")) {
                    $vals = $resp.Headers.GetValues("Location")
                    foreach ($v in @($vals)) { $location = ("" + $v).Trim(); break }
                }
            } catch { $location = "" }

            $bodyText = ""
            try {
                if ($null -ne $resp.Content) {
                    $bodyText = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                    if ($null -eq $bodyText) { $bodyText = "" }
                }
            } catch { $bodyText = "" }

            $result.ok = $true
            $result.status = $statusInt
            $result.location = $location
            $result.body = ("" + $bodyText)
            $result.error = ""
            return $result
        } catch {
            $msg = ("" + $_.Exception.Message)
            if ($msg -eq "") { $msg = ("" + $_) }
            $typeName = ""
            try { $typeName = ("" + $_.Exception.GetType().FullName) } catch { $typeName = "" }
            if ($typeName -ne "") { $msg = ($typeName + ": " + $msg) }

            $result.ok = $false
            $result.status = 0
            $result.location = ""
            $result.body = ""
            $result.error = $msg
            return $result
        } finally {
            try { if ($null -ne $resp) { $resp.Dispose() } } catch { }
            try { if ($null -ne $req) { $req.Dispose() } } catch { }
            try { if ($null -ne $client) { $client.Dispose() } } catch { }
            try { if ($null -ne $handler) { $handler.Dispose() } } catch { }
        }
    }

    function Get-CookieValue {
        param(
            [Parameter(Mandatory = $true)][System.Net.CookieContainer]$CookieJar,
            [Parameter(Mandatory = $true)][string]$Uri,
            [Parameter(Mandatory = $true)][string]$CookieName
        )
        try {
            $u = $null
            $okUri = [System.Uri]::TryCreate($Uri, [System.UriKind]::Absolute, [ref]$u)
            if (-not $okUri -or $null -eq $u) { return "" }
            $cookies = $CookieJar.GetCookies($u)
            foreach ($c in @($cookies)) {
                if ((("" + $c.Name).Trim()).Equals($CookieName, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return ("" + $c.Value)
                }
            }
        } catch { }
        return ""
    }

    function Get-ManualCookieValue {
        param(
            [Parameter(Mandatory = $true)][hashtable]$ManualCookieStore,
            [Parameter(Mandatory = $true)][string]$CookieName
        )
        try {
            foreach ($k in @($ManualCookieStore.Keys)) {
                if ((("" + $k).Trim()).Equals($CookieName, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $v = $ManualCookieStore[$k]
                    if ($null -eq $v) { return "" }
                    return ("" + $v)
                }
            }
        } catch { }
        return ""
    }

    function Get-CookieStoreKeyNames {
        param(
            [Parameter(Mandatory = $true)][hashtable]$ManualCookieStore
        )
        try {
            $names = @()
            foreach ($k in @($ManualCookieStore.Keys)) {
                $n = ("" + $k).Trim()
                if ($n -ne "") { $names += $n }
            }
            return ($names | Sort-Object -Unique)
        } catch {
            return @()
        }
    }

    function Test-CookiePresentAny {
        param(
            [Parameter(Mandatory = $true)][System.Net.CookieContainer]$CookieJar,
            [Parameter(Mandatory = $true)][hashtable]$ManualCookieStore,
            [Parameter(Mandatory = $true)][string]$Uri,
            [Parameter(Mandatory = $true)][string]$CookieName
        )
        $v1 = Get-CookieValue -CookieJar $CookieJar -Uri $Uri -CookieName $CookieName
        if ($v1 -ne "") { return $true }
        $v2 = Get-ManualCookieValue -ManualCookieStore $ManualCookieStore -CookieName $CookieName
        return ($v2 -ne "")
    }

    function Get-PathFromLocation {
        param(
            [Parameter(Mandatory = $false)][string]$Location,
            [Parameter(Mandatory = $true)][string]$BaseUrl
        )
        $loc = ("" + $Location).Trim()
        if ($loc -eq "") { return "" }

        try {
            $u = $null
            if ([System.Uri]::TryCreate($loc, [System.UriKind]::Absolute, [ref]$u) -and $null -ne $u) {
                return (("" + $u.AbsolutePath).ToLowerInvariant().TrimEnd("/"))
            }
        } catch { }

        try {
            $base = [System.Uri]::new($BaseUrl)
            $rel = [System.Uri]::new($base, $loc)
            if ($null -ne $rel) { return (("" + $rel.AbsolutePath).ToLowerInvariant().TrimEnd("/")) }
        } catch { }

        return (("" + $loc).ToLowerInvariant().TrimEnd("/"))
    }

    function Get-LoginErrorSummaryFromHtml {
        param(
            [Parameter(Mandatory = $true)][string]$Html
        )

        $h = ("" + $Html)
        if ($h.Trim() -eq "") { return "" }

        try {
            if ($h -match '(?i)These credentials do not match our records\.') {
                return "These credentials do not match our records."
            }
        } catch { }

        # Try Breeze-style red error blocks (best-effort).
        try {
            $m1 = [regex]::Match($h, '(?is)<div[^>]*class\s*=\s*"[^"]*text-red-600[^"]*"[^>]*>\s*([^<]{1,200})\s*</div>')
            if ($m1.Success) {
                $t = ("" + $m1.Groups[1].Value).Trim()
                $t = [regex]::Replace($t, '\s+', ' ').Trim()
                if ($t -ne "") { return $t }
            }
        } catch { }

        try {
            $m2 = [regex]::Match($h, '(?is)<li[^>]*>\s*([^<]{1,200})\s*</li>')
            if ($m2.Success) {
                $t = ("" + $m2.Groups[1].Value).Trim()
                $t = [regex]::Replace($t, '\s+', ' ').Trim()
                if ($t -ne "") { return $t }
            }
        } catch { }

        return ""
    }

    function Get-PwshPasswordExpansionHeuristic {
        param(
            [Parameter(Mandatory = $true)][string]$Password
        )

        $p = ("" + $Password)
        $hasDollar = $false
        try { $hasDollar = ($p.IndexOf('$') -ge 0) } catch { $hasDollar = $false }

        $isAlnumOnly = $false
        try { $isAlnumOnly = ($p -match '^[A-Za-z0-9]+$') } catch { $isAlnumOnly = $false }

        $len = 0
        try { $len = [int]$p.Length } catch { $len = 0 }

        $suspected = $false
        $signal = "unknown"

        # Heuristic (best-effort):
        # Common failure: user passes -SuperadminPassword "abc$xyz" -> $xyz expands -> becomes "abc"
        # If final value has no '$' and looks "too simple" (short alnum-only), we mark as suspected.
        if (-not $hasDollar -and $isAlnumOnly -and $len -gt 0 -and $len -le 12) {
            $suspected = $true
            $signal = "possible_pwsh_dollar_expansion"
        } elseif ($hasDollar) {
            $suspected = $false
            $signal = "dollar_present_in_value"
        } else {
            $suspected = $false
            $signal = "no_strong_signal"
        }

        $hint = ""
        if ($suspected) {
            $hint = "Possible PowerShell `$-expansion in -SuperadminPassword. Use single quotes: -SuperadminPassword '...$...' or escape `$ as ``$ inside double quotes."
        }

        return [pscustomobject]@{
            suspected = [bool]$suspected
            signal    = ("" + $signal)
            length    = [int]$len
            hint      = ("" + $hint)
        }
    }

    function Get-HostFromUrl {
        param(
            [Parameter(Mandatory = $true)][string]$Url
        )
        try {
            $u = $null
            if ([System.Uri]::TryCreate($Url, [System.UriKind]::Absolute, [ref]$u) -and $null -ne $u) {
                return ("" + $u.Host).Trim().ToLowerInvariant()
            }
        } catch { }
        return ""
    }

    $details = @()
    $data = @{}

    if ($email -eq "" -or $password -eq "") {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "missing_credentials"; status = 0 }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "WARN" -Summary "Skipped: missing superadmin credentials (-SuperadminEmail / -SuperadminPassword)." -Details @() -Data @{ base_url = $baseUrl } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $pwHeu = $null
    try { $pwHeu = Get-PwshPasswordExpansionHeuristic -Password ("" + $password) } catch { $pwHeu = $null }

    $cookieJar = $null
    try { $cookieJar = [System.Net.CookieContainer]::new() } catch { $cookieJar = $null }
    if ($null -eq $cookieJar) {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "cookiejar_init_failed"; status = 0 }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "FAIL" -Summary "Cannot initialize CookieContainer." -Details @() -Data @{ base_url = $baseUrl } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $manualCookies = @{}

    $loginUrl = $baseUrl + "/login"
    $baseHost = Get-HostFromUrl -Url $baseUrl
    $loginHost = Get-HostFromUrl -Url $loginUrl

    $getHeaders = @{
        "Accept"      = "text/html,application/xhtml+xml"
        "User-Agent"  = "ks-admin-audit/1.0 (LoginCsrfProbe)"
        "Connection"  = "close"
        "Cache-Control" = "no-cache"
        "Pragma"      = "no-cache"
    }

    # Disable CookieContainer to avoid domain/secure/samesite quirks; rely on manual cookie store.
    $rGet = Invoke-KsHttpNoRedirect -Uri $loginUrl -Method "GET" -CookieJar $cookieJar -Headers $getHeaders -TimeoutSeconds 12 -ManualCookieStore $manualCookies -DisableCookieContainer $true
    if (-not $rGet.ok) {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "get_failed"; status = $rGet.status }) -Force
        } catch { }
        $details += ("GET /login status(no-redirect): " + [int]$rGet.status)
        return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "FAIL" -Summary ("GET /login failed: " + $rGet.error) -Details $details -Data @{ base_url = $baseUrl; get_status = [int]$rGet.status } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $details += ("GET /login status(no-redirect): " + [int]$rGet.status)
    $details += ("GET /login set-cookie headers: " + ([int]$rGet.set_cookie_count))
    $details += ("Manual cookie store size(after GET): " + ([int]$manualCookies.Count))

    $cookieNamesAfterGet = @()
    try { $cookieNamesAfterGet = @(Get-CookieStoreKeyNames -ManualCookieStore $manualCookies) } catch { $cookieNamesAfterGet = @() }
    if ($cookieNamesAfterGet.Count -gt 0) {
        $details += ("Manual cookie names(after GET): " + (($cookieNamesAfterGet -join ", ")))
    }

    $token = ""
    try {
        $m = [regex]::Match(("" + $rGet.body), 'name\s*=\s*"[_]?token"\s+value\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { $token = ("" + $m.Groups[1].Value) }
    } catch { $token = "" }

    if ($token -eq "") {
        $sw.Stop()
        $details += "_token: missing"
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "missing_token"; status = [int]$rGet.status }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "FAIL" -Summary "GET /login did not expose _token." -Details $details -Data @{ base_url = $baseUrl; get_status = [int]$rGet.status } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $details += ("_token: present (len=" + $token.Length + ")")

    $sessionCookiePresent = Test-CookiePresentAny -CookieJar $cookieJar -ManualCookieStore $manualCookies -Uri $loginUrl -CookieName "laravel_session"
    $xsrfCookieRaw = Get-CookieValue -CookieJar $cookieJar -Uri $loginUrl -CookieName "XSRF-TOKEN"
    if ($xsrfCookieRaw -eq "") { $xsrfCookieRaw = Get-ManualCookieValue -ManualCookieStore $manualCookies -CookieName "XSRF-TOKEN" }
    $xsrfCookiePresent = ($xsrfCookieRaw -ne "")

    $details += ("Cookie laravel_session present(GET): " + $sessionCookiePresent)
    $details += ("Cookie XSRF-TOKEN present(GET): " + $xsrfCookiePresent)

    if (-not $sessionCookiePresent -or -not $xsrfCookiePresent) {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "missing_login_cookies"; status = [int]$rGet.status }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "FAIL" -Summary "GET /login missing required cookies (laravel_session and/or XSRF-TOKEN)." -Details $details -Data @{ base_url = $baseUrl; get_status = [int]$rGet.status; has_laravel_session = [bool]$sessionCookiePresent; has_xsrf_token = [bool]$xsrfCookiePresent; manual_cookie_store_size = [int]$manualCookies.Count; set_cookie_count = [int]$rGet.set_cookie_count } -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $xsrfCookieDecoded = ""
    try { $xsrfCookieDecoded = [uri]::UnescapeDataString($xsrfCookieRaw) } catch { $xsrfCookieDecoded = $xsrfCookieRaw }
    $xsrfCookieDecoded = ("" + $xsrfCookieDecoded).Trim()
    if ($xsrfCookieDecoded.Length -ge 2 -and $xsrfCookieDecoded.StartsWith('"') -and $xsrfCookieDecoded.EndsWith('"')) {
        $xsrfCookieDecoded = $xsrfCookieDecoded.Substring(1, $xsrfCookieDecoded.Length - 2)
    }

    $postBody = @{
        _token   = $token
        email    = $email
        password = $password
    }

    $postHeaders = @{
        "Accept"            = "text/html,application/xhtml+xml"
        "Referer"           = $loginUrl
        "Origin"            = $baseUrl
        "X-XSRF-TOKEN"      = $xsrfCookieDecoded
        "X-CSRF-TOKEN"      = $token
        "X-Requested-With"  = "XMLHttpRequest"
        "User-Agent"        = "ks-admin-audit/1.0 (LoginCsrfProbe)"
        "Connection"        = "close"
        "Cache-Control"     = "no-cache"
        "Pragma"            = "no-cache"
    }

    $details += ("Header X-XSRF-TOKEN set: " + ([bool]($xsrfCookieDecoded -ne "")) + " (len=" + ([int]$xsrfCookieDecoded.Length) + ")")
    $details += ("Header X-CSRF-TOKEN set: " + ([bool]($token -ne "")) + " (len=" + ([int]$token.Length) + ")")

    # POST: fully manual cookie sending (no CookieContainer)
    $rPost = Invoke-KsHttpNoRedirect -Uri $loginUrl -Method "POST" -CookieJar $cookieJar -Body $postBody -Headers $postHeaders -TimeoutSeconds 12 -ManualCookieStore $manualCookies -DisableCookieContainer $true

    $postStatus = [int]$rPost.status
    $postLocation = ("" + $rPost.location).Trim()
    $postLocationPath = Get-PathFromLocation -Location $postLocation -BaseUrl $baseUrl

    $details += ("POST /login status(no-redirect): " + $postStatus)
    if ($postLocation -ne "") { $details += ("POST /login location: " + $postLocation) }
    $details += ("POST /login set-cookie headers: " + ([int]$rPost.set_cookie_count))
    $details += ("Manual cookie store size(after POST): " + ([int]$manualCookies.Count))

    $cookieNamesAfterPost = @()
    try { $cookieNamesAfterPost = @(Get-CookieStoreKeyNames -ManualCookieStore $manualCookies) } catch { $cookieNamesAfterPost = @() }
    if ($cookieNamesAfterPost.Count -gt 0) {
        $details += ("Manual cookie names(after POST): " + (($cookieNamesAfterPost -join ", ")))
    }

    $sessionCookiePresentPost = Test-CookiePresentAny -CookieJar $cookieJar -ManualCookieStore $manualCookies -Uri $loginUrl -CookieName "laravel_session"
    $xsrfCookieRawPost = Get-CookieValue -CookieJar $cookieJar -Uri $loginUrl -CookieName "XSRF-TOKEN"
    if ($xsrfCookieRawPost -eq "") { $xsrfCookieRawPost = Get-ManualCookieValue -ManualCookieStore $manualCookies -CookieName "XSRF-TOKEN" }
    $xsrfCookiePresentPost = ($xsrfCookieRawPost -ne "")

    $details += ("Cookie laravel_session present(POST): " + $sessionCookiePresentPost)
    $details += ("Cookie XSRF-TOKEN present(POST): " + $xsrfCookiePresentPost)

    $data = @{
        base_url = $baseUrl
        base_host = $baseHost
        login_host = $loginHost
        get_status = [int]$rGet.status
        post_status = $postStatus
        post_location = $postLocation
        post_location_path = $postLocationPath
        post_has_response = [bool]$rPost.ok
        token_present = $true
        token_length = [int]$token.Length
        cookie_laravel_session_present_get = [bool]$sessionCookiePresent
        cookie_xsrf_token_present_get = [bool]$xsrfCookiePresent
        cookie_laravel_session_present_post = [bool]$sessionCookiePresentPost
        cookie_xsrf_token_present_post = [bool]$xsrfCookiePresentPost
        xsrf_header_present = [bool]($xsrfCookieDecoded -ne "")
        xsrf_header_length = [int]$xsrfCookieDecoded.Length
        csrf_header_present = [bool]($token -ne "")
        csrf_header_length = [int]$token.Length
        manual_cookie_store_size = [int]$manualCookies.Count
        manual_cookie_names = @($cookieNamesAfterPost)
        get_set_cookie_count = [int]$rGet.set_cookie_count
        post_set_cookie_count = [int]$rPost.set_cookie_count
    }

    if ($null -ne $pwHeu) {
        $data["pwsh_password_expansion_suspected"] = [bool]$pwHeu.suspected
        $data["pwsh_password_expansion_signal"] = ("" + $pwHeu.signal)
        $data["pwsh_password_value_length"] = [int]$pwHeu.length
    }

    if (-not $rPost.ok) {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "login_post_no_response"; status = $postStatus }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "FAIL" -Summary ("POST /login failed: " + $rPost.error) -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($postStatus -eq 419) {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "csrf_419"; status = 419 }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "FAIL" -Summary "POST /login returned 419 (csrf_419)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($postStatus -eq 302 -and ($postLocationPath -eq "/login" -or $postLocationPath -eq "login")) {
        # Follow-up GET /login to extract likely error message (Laravel flashes errors to the redirected page).
        $rLogin2 = Invoke-KsHttpNoRedirect -Uri $loginUrl -Method "GET" -CookieJar $cookieJar -Headers $getHeaders -TimeoutSeconds 12 -ManualCookieStore $manualCookies -DisableCookieContainer $true
        $login2Status = [int]$rLogin2.status
        $login2Err = ""
        if ($rLogin2.ok) {
            $login2Err = Get-LoginErrorSummaryFromHtml -Html ("" + $rLogin2.body)
        }

        $details += ("GET /login(after reject) status(no-redirect): " + $login2Status)
        $details += ("GET /login(after reject) set-cookie headers: " + ([int]$rLogin2.set_cookie_count))
        $details += ("Manual cookie store size(after GET /login reject): " + ([int]$manualCookies.Count))

        $cookieNamesAfterReject = @()
        try { $cookieNamesAfterReject = @(Get-CookieStoreKeyNames -ManualCookieStore $manualCookies) } catch { $cookieNamesAfterReject = @() }
        if ($cookieNamesAfterReject.Count -gt 0) {
            $details += ("Manual cookie names(after GET /login reject): " + (($cookieNamesAfterReject -join ", ")))
        }

        if ($login2Err -ne "") { $details += ("Login error (best-effort): " + $login2Err) }

        if ($null -ne $pwHeu) {
            $details += ("Password expansion suspected: " + ([bool]$pwHeu.suspected) + " (" + ("" + $pwHeu.signal) + ")")
            if (([bool]$pwHeu.suspected) -and ("" + $pwHeu.hint).Trim() -ne "") {
                $details += ("Password quoting hint: " + ("" + $pwHeu.hint))
            }
        }

        $data["login_followup_get_status"] = $login2Status
        $data["login_followup_get_has_response"] = [bool]$rLogin2.ok
        $data["login_followup_get_set_cookie_count"] = [int]$rLogin2.set_cookie_count
        $data["login_error_summary"] = $login2Err
        $data["manual_cookie_names_after_reject_get"] = @($cookieNamesAfterReject)

        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "login_rejected"; status = $postStatus }) -Force
        } catch { }

        $sum = "Login rejected (302 -> /login)."
        if ($login2Err -ne "") { $sum = ($sum + " " + $login2Err) }

        return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "WARN" -Summary $sum -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($postStatus -eq 302 -and ($postLocationPath -ne "" -and $postLocationPath -ne "/login" -and $postLocationPath -ne "login")) {
        $adminUrl = $baseUrl + "/admin"
        $rAdmin = Invoke-KsHttpNoRedirect -Uri $adminUrl -Method "GET" -CookieJar $cookieJar -Headers $getHeaders -TimeoutSeconds 12 -ManualCookieStore $manualCookies -DisableCookieContainer $true
        $adminStatus = [int]$rAdmin.status
        $adminLocation = ("" + $rAdmin.location).Trim()

        $details += ("GET /admin status(no-redirect): " + $adminStatus)
        if ($adminLocation -ne "") { $details += ("GET /admin location: " + $adminLocation) }
        $details += ("GET /admin set-cookie headers: " + ([int]$rAdmin.set_cookie_count))
        $details += ("Manual cookie store size(after /admin): " + ([int]$manualCookies.Count))

        $cookieNamesAfterAdmin = @()
        try { $cookieNamesAfterAdmin = @(Get-CookieStoreKeyNames -ManualCookieStore $manualCookies) } catch { $cookieNamesAfterAdmin = @() }
        if ($cookieNamesAfterAdmin.Count -gt 0) {
            $details += ("Manual cookie names(after /admin): " + (($cookieNamesAfterAdmin -join ", ")))
        }

        $data["admin_probe_status"] = $adminStatus
        $data["admin_probe_location"] = $adminLocation
        $data["admin_probe_has_response"] = [bool]$rAdmin.ok
        $data["admin_probe_set_cookie_count"] = [int]$rAdmin.set_cookie_count
        $data["manual_cookie_names_after_admin_get"] = @($cookieNamesAfterAdmin)

        $adminHost = ""
        try { $adminHost = Get-HostFromUrl -Url $adminUrl } catch { $adminHost = "" }
        $postLocHost = ""
        try { if ($postLocation -ne "") { $postLocHost = Get-HostFromUrl -Url $postLocation } } catch { $postLocHost = "" }
        $data["admin_host"] = $adminHost
        $data["post_location_host"] = $postLocHost

        if ($baseHost -ne "" -and $postLocHost -ne "" -and $baseHost -ne $postLocHost) {
            $details += ("Host mismatch detected: base_host=" + $baseHost + ", post_location_host=" + $postLocHost)
        }

        if (-not $rAdmin.ok) {
            $sw.Stop()
            try {
                $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "admin_probe_no_response"; status = $adminStatus }) -Force
            } catch { }
            return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "FAIL" -Summary ("GET /admin probe failed: " + $rAdmin.error) -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        if ($adminStatus -eq 200) {
            $sw.Stop()
            try {
                $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $true; reason = "success"; status = $adminStatus }) -Force
            } catch { }
            return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "OK" -Summary ("Login probe success (POST status=" + $postStatus + ", /admin status=" + $adminStatus + ").") -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
        }

        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "admin_probe_unexpected"; status = $adminStatus }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "WARN" -Summary "Login probe ended in unexpected /admin probe state." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    if ($postStatus -eq 200) {
        $sw.Stop()
        try {
            $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "login_rejected"; status = $postStatus }) -Force
        } catch { }
        return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "WARN" -Summary "Login likely rejected (POST returned 200 without redirect)." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
    }

    $sw.Stop()
    try {
        $Context | Add-Member -NotePropertyName LoginCsrfProbeState -NotePropertyValue ([pscustomobject]@{ ok = $false; reason = "post_unexpected"; status = $postStatus }) -Force
    } catch { }
    return & $new -Id "login_csrf_probe" -Title "2) Login CSRF probe" -Status "WARN" -Summary "Login probe ended in unexpected POST state." -Details $details -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds)
}