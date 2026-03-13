# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\core\ks-http.psm1
# Purpose: Shared HTTP/session/redirect helpers for KiezSingles audit PowerShell scripts
# Created: 06-03-2026 22:00 (Europe/Berlin)
# Changed: 11-03-2026 22:17 (Europe/Berlin)
# Version: 1.2
# =============================================================================

Set-StrictMode -Version Latest

function Normalize-BaseUrl {
    param(
        [Parameter(Mandatory=$true)][string]$s
    )

    $t = ""
    if ($null -ne $s) {
        try { $t = ("" + $s).Trim() } catch { $t = "" }
    }

    if ($t -eq "") {
        throw "BaseUrl is empty."
    }

    if ($t.EndsWith("/")) {
        $t = $t.Substring(0, $t.Length - 1)
    }

    return $t
}

function Resolve-Url {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$CurrentUrl,
        [Parameter(Mandatory=$true)][string]$Location
    )

    $loc = ""
    try { $loc = ("" + $Location).Trim() } catch { $loc = "" }

    if ($loc -eq "") {
        return ""
    }

    try { $loc = [System.Net.WebUtility]::HtmlDecode($loc) } catch { }

    if ($loc -match '^(?i)https?://') {
        return $loc
    }

    if ($loc.StartsWith("//")) {
        $u = [Uri]$BaseUrl
        return ("{0}:{1}" -f $u.Scheme, $loc)
    }

    if ($loc.StartsWith("/")) {
        return ($BaseUrl + $loc)
    }

    try {
        $cur = [Uri]$CurrentUrl
        $abs = New-Object Uri($cur, $loc)
        return $abs.AbsoluteUri
    } catch {
        return ($BaseUrl + "/" + $loc)
    }
}

function New-Session {
    return New-Object Microsoft.PowerShell.Commands.WebRequestSession
}

function Try-GetExceptionResponse {
    param(
        [Parameter(Mandatory=$false)]$ex
    )

    if ($null -eq $ex) {
        return $null
    }

    if ($ex -is [System.Net.WebException]) {
        if ($null -ne $ex.Response) {
            return $ex.Response
        }

        return $null
    }

    $p = $ex.PSObject.Properties['Response']
    if ($null -ne $p) {
        try {
            $r = $ex.Response
            if ($null -ne $r) {
                return $r
            }
        } catch {
            return $null
        }
    }

    $inner = $null
    try { $inner = $ex.InnerException } catch { $inner = $null }

    if ($null -ne $inner -and $inner -is [System.Net.WebException]) {
        if ($null -ne $inner.Response) {
            return $inner.Response
        }
    }

    return $null
}

function Read-ResponseBody {
    param(
        [Parameter(Mandatory=$false)][System.Net.WebResponse]$resp
    )

    if ($null -eq $resp) {
        return ""
    }

    try {
        $stream = $resp.GetResponseStream()
        if ($null -eq $stream) {
            return ""
        }

        $sr = New-Object System.IO.StreamReader($stream)
        $body = $sr.ReadToEnd()
        $sr.Dispose()

        return $body
    } catch {
        return ""
    }
}

function Invoke-HttpWebRequestNoRedirect {
    param(
        [Parameter(Mandatory=$true)][string]$Method,
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][hashtable]$Form = $null
    )

    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = $Method
    $req.AllowAutoRedirect = $false
    $req.CookieContainer = $Session.Cookies

    foreach ($k in $Headers.Keys) {
        $v = "" + $Headers[$k]
        if ([string]::IsNullOrWhiteSpace($k)) { continue }

        if ($k -ieq "Cookie") {
            $pairs = $v.Split(';')
            foreach ($pair in $pairs) {
                $kv = $pair.Split('=',2)
                if ($kv.Length -eq 2) {
                    try {
                        $cookie = New-Object System.Net.Cookie($kv[0].Trim(), $kv[1].Trim(), "/", ([Uri]$Url).Host)
                        $Session.Cookies.Add([Uri]$Url, $cookie)
                    } catch { }
                }
            }
            continue
        }

        try { $req.Headers[$k] = $v } catch { }
    }

    if ($null -ne $Form) {
        $pairs = New-Object System.Collections.Generic.List[string]

        foreach ($k in $Form.Keys) {
            $key = [System.Uri]::EscapeDataString("" + $k)
            $val = [System.Uri]::EscapeDataString("" + $Form[$k])
            $pairs.Add(("{0}={1}" -f $key, $val))
        }

        $bodyStr = [string]::Join("&", $pairs)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyStr)

        $req.ContentType = "application/x-www-form-urlencoded"
        $req.ContentLength = $bytes.Length

        try {
            $rs = $req.GetRequestStream()
            $rs.Write($bytes, 0, $bytes.Length)
            $rs.Dispose()
        } catch {
        }
    }

    try {
        $resp = $req.GetResponse()

        $statusCode = 0
        try { $statusCode = [int]([System.Net.HttpWebResponse]$resp).StatusCode } catch { $statusCode = 0 }

        $headersOut = @{}
        try {
            foreach ($hk in $resp.Headers.AllKeys) {
                $headersOut[$hk] = $resp.Headers[$hk]
            }
        } catch { }

        $body = Read-ResponseBody -resp $resp

        try { $resp.Close() } catch { }

        return [PSCustomObject]@{
            StatusCode = $statusCode
            Headers    = $headersOut
            Content    = $body
            RawContent = $body
        }
    } catch {
        $we = $_.Exception
        $resp = Try-GetExceptionResponse -ex $we

        $statusCode = 0
        $headersOut = @{}
        $body = ""

        if ($null -ne $resp) {
            try { $statusCode = [int]([System.Net.HttpWebResponse]$resp).StatusCode } catch { $statusCode = 0 }

            try {
                foreach ($hk in $resp.Headers.AllKeys) {
                    $headersOut[$hk] = $resp.Headers[$hk]
                }
            } catch { }

            $body = Read-ResponseBody -resp $resp

            try { $resp.Close() } catch { }
        }

        return [PSCustomObject]@{
            StatusCode = $statusCode
            Headers    = $headersOut
            Content    = $body
            RawContent = $body
        }
    }
}

function Invoke-HttpNoRedirect {
    param(
        [Parameter(Mandatory=$true)][string]$Method,
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][hashtable]$Form = $null
    )

    return Invoke-HttpWebRequestNoRedirect -Method $Method -Url $Url -Session $Session -Headers $Headers -Form $Form
}

function Try-GetLocationHeader {
    param(
        [Parameter(Mandatory=$false)]$resp
    )

    $loc = ""

    try {
        if ($null -ne $resp -and $null -ne $resp.Headers) {
            if ($resp.Headers['Location']) {
                $loc = "" + $resp.Headers['Location']
            } elseif ($resp.Headers['location']) {
                $loc = "" + $resp.Headers['location']
            }
        }
    } catch {
        $loc = ""
    }

    return $loc
}

function Invoke-FollowRedirects {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$StartUrl,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][int]$Max = 5
    )

    $curUrl = $StartUrl
    $last = $null

    for ($i = 0; $i -lt $Max; $i++) {
        $last = Invoke-HttpNoRedirect -Method 'GET' -Url $curUrl -Session $Session -Headers $Headers

        $sc = 0
        try { $sc = [int]$last.StatusCode } catch { $sc = 0 }

        if ($sc -ge 300 -and $sc -lt 400) {
            $loc = Try-GetLocationHeader -resp $last
            if ([string]::IsNullOrWhiteSpace($loc)) { break }

            $curUrl = Resolve-Url -BaseUrl $BaseUrl -CurrentUrl $curUrl -Location $loc
            if ([string]::IsNullOrWhiteSpace($curUrl)) { break }

            continue
        }

        break
    }

    $html = ""
    try {
        if ($null -ne $last.Content) {
            $html = "" + $last.Content
        } elseif ($null -ne $last.RawContent) {
            $html = "" + $last.RawContent
        } else {
            $html = ""
        }
    } catch {
        $html = ""
    }

    return [PSCustomObject]@{
        FinalUrl  = $curUrl
        FinalHtml = $html
        Raw       = $last
    }
}

function Invoke-GetWithOptionalRedirects {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][int]$Max = 5
    )

    $first = Invoke-HttpNoRedirect -Method 'GET' -Url $Url -Session $Session -Headers $Headers

    $sc = 0
    try { $sc = [int]$first.StatusCode } catch { $sc = 0 }

    if ($script:FollowRedirectsEnabled -and ($sc -ge 300 -and $sc -lt 400)) {
        $loc = Try-GetLocationHeader -resp $first
        if (-not [string]::IsNullOrWhiteSpace($loc)) {
            $target = Resolve-Url -BaseUrl $BaseUrl -CurrentUrl $Url -Location $loc

            if (-not [string]::IsNullOrWhiteSpace($target)) {
                $follow = Invoke-FollowRedirects -BaseUrl $BaseUrl -StartUrl $target -Session $Session -Headers $Headers -Max $Max

                return [PSCustomObject]@{
                    InitialStatus = $first.StatusCode
                    FinalUrl      = $follow.FinalUrl
                    FinalHtml     = $follow.FinalHtml
                    Raw           = $follow.Raw
                    Followed      = $true
                }
            }
        }
    }

    $html = ""
    try {
        if ($null -ne $first.Content) {
            $html = "" + $first.Content
        } elseif ($null -ne $first.RawContent) {
            $html = "" + $first.RawContent
        } else {
            $html = ""
        }
    } catch {
        $html = ""
    }

    return [PSCustomObject]@{
        InitialStatus = $first.StatusCode
        FinalUrl      = $Url
        FinalHtml     = $html
        Raw           = $first
        Followed      = $false
    }
}

function Get-LoginPage {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{}
    )

    $url = "$BaseUrl/login"
    return Invoke-HttpNoRedirect -Method 'GET' -Url $url -Session $Session -Headers $Headers
}

Export-ModuleMember -Function *
