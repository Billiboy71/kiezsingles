# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\core\ks-evidence.psm1
# Purpose: HTML/evidence parsing helpers for KiezSingles audit PowerShell scripts
# Created: 06-03-2026 22:18 (Europe/Berlin)
# Changed: 11-03-2026 23:04 (Europe/Berlin)
# Version: 1.2
# =============================================================================

Set-StrictMode -Version Latest

function Extract-CsrfTokenFromHtml {
    param(
        [Parameter(Mandatory=$false)][string]$html
    )

    if ([string]::IsNullOrWhiteSpace($html)) { return "" }

    $m = [regex]::Match($html, 'name="_token"\s+value="([^"]+)"', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }

    $m2 = [regex]::Match($html, 'name="csrf-token"\s+content="([^"]+)"', 'IgnoreCase')
    if ($m2.Success) { return $m2.Groups[1].Value }

    return ""
}

function Get-Snippet {
    param(
        [Parameter(Mandatory=$true)][string]$text,
        [Parameter(Mandatory=$true)][int]$index,
        [Parameter(Mandatory=$true)][int]$radius
    )

    if ($null -eq $text) { return "" }
    if ($index -lt 0) { return "" }

    $start = [Math]::Max(0, $index - $radius)
    $len = [Math]::Min($text.Length - $start, $radius * 2)

    if ($len -le 0) { return "" }

    return $text.Substring($start, $len)
}

function Convert-ToSearchText {
    param(
        [Parameter(Mandatory=$false)][string]$text
    )

    if ([string]::IsNullOrWhiteSpace($text)) { return "" }

    $t = "" + $text

    try { $t = [System.Net.WebUtility]::HtmlDecode($t) } catch { }

    $t = ($t -replace '(?is)<script\b[^>]*>.*?</script>', ' ')
    $t = ($t -replace '(?is)<style\b[^>]*>.*?</style>', ' ')
    $t = ($t -replace '(?is)<[^>]+>', ' ')
    $t = ($t -replace '(?is)&nbsp;', ' ')
    $t = ($t -replace '(?is)\s+', ' ').Trim()

    return $t
}

function Ensure-ExportDir {

    if (-not $script:ExportHtmlEnabled) { return }
    if ([string]::IsNullOrWhiteSpace($script:ExportHtmlDir)) { return }

    if (-not (Test-Path -LiteralPath $script:ExportHtmlDir)) {
        New-Item -ItemType Directory -Path $script:ExportHtmlDir | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($script:ExportRunDir)) {
        $script:ExportRunDir = Join-Path $script:ExportHtmlDir $script:RunId
    }

    if (-not (Test-Path -LiteralPath $script:ExportRunDir)) {
        New-Item -ItemType Directory -Path $script:ExportRunDir | Out-Null
    }
}

function Export-LoginHtml {
    param(
        [Parameter(Mandatory=$true)][string]$label,
        [Parameter(Mandatory=$false)][string]$html
    )

    if (-not $script:ExportHtmlEnabled) { return "" }

    Ensure-ExportDir

    $script:ExportSeq = $script:ExportSeq + 1
    $seq = "{0:D4}" -f [int]$script:ExportSeq

    $safeLabel = ($label -replace '[^a-zA-Z0-9_\-]+','_')
    $file = Join-Path $script:ExportRunDir ("{0}_{1}_{2}.html" -f $script:RunId, $seq, $safeLabel)

    $content = ""
    if ($null -ne $html) { $content = $html }

    [System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)

    return $file
}

function Analyze-TextPattern {
    param(
        [Parameter(Mandatory=$false)][string]$html,
        [Parameter(Mandatory=$true)][string]$pattern
    )

    $snippet = ""
    $value = ""
    $found = $false

    $m = [regex]::Match($html, $pattern, 'IgnoreCase')
    if ($m.Success) {
        $found = $true
        $value = $m.Value
        $snippet = Get-Snippet -text $html -index $m.Index -radius $script:SnippetRadiusChars
    } else {
        $searchText = Convert-ToSearchText $html
        if (-not [string]::IsNullOrWhiteSpace($searchText)) {

            $m2 = [regex]::Match($searchText, $pattern, 'IgnoreCase')
            if ($m2.Success) {
                $found = $true
                $value = $m2.Value
                $snippet = Get-Snippet -text $searchText -index $m2.Index -radius $script:SnippetRadiusChars
            }
        }
    }

    return [PSCustomObject]@{
        Found   = $found
        Snippet = $snippet
        Value   = $value
    }
}

function Analyze-Html {
    param(
        [Parameter(Mandatory=$false)][string]$html
    )

    $sec = [regex]::Match($html, $script:SecPattern, 'IgnoreCase')

    $secSnippet = ""
    if ($sec.Success) {
        $secSnippet = Get-Snippet -text $html -index $sec.Index -radius $script:SnippetRadiusChars
    }

    $wrong = [regex]::Match($html, $script:WrongCredsPattern, 'IgnoreCase')

    $wrongSnippet = ""
    if ($wrong.Success) {
        $wrongSnippet = Get-Snippet -text $html -index $wrong.Index -radius $script:SnippetRadiusChars
    }

    $lock = [regex]::Match($html, $script:LockoutPattern, 'IgnoreCase')

    $lockSeconds = ""
    $lockSnippet = ""

    if ($lock.Success) {
        $lockSeconds = $lock.Groups[2].Value
        $lockSnippet = Get-Snippet -text $html -index $lock.Index -radius $script:SnippetRadiusChars
    }

    return [PSCustomObject]@{
        SecFound          = $sec.Success
        SecValue          = $sec.Value
        SecSnippet        = $secSnippet

        WrongCredsFound   = $wrong.Success
        WrongCredsSnippet = $wrongSnippet

        LockoutFound      = $lock.Success
        LockoutSeconds    = $lockSeconds
        LockoutSnippet    = $lockSnippet
    }
}

function Test-UrlLooksLikeLogin {
    param(
        [Parameter(Mandatory=$false)][string]$u
    )

    if ([string]::IsNullOrWhiteSpace($u)) { return $false }

    return ($u -match '(?is)(/login)(\?|$)')
}

function Test-UrlContainsPath {
    param(
        [Parameter(Mandatory=$false)][string]$u,
        [Parameter(Mandatory=$false)][string]$path
    )

    if ([string]::IsNullOrWhiteSpace($u)) { return $false }
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }

    $uu = ""
    $pp = ""

    try { $uu = ("" + $u).Trim() } catch { $uu = "" }
    try { $pp = ("" + $path).Trim() } catch { $pp = "" }

    if ($uu -eq "" -or $pp -eq "") { return $false }

    return ($uu -match [regex]::Escape($pp))
}

function Get-QueryParameterFromUrl {
    param(
        [Parameter(Mandatory=$false)][string]$url,
        [Parameter(Mandatory=$true)][string]$name
    )

    if ([string]::IsNullOrWhiteSpace($url)) { return "" }

    try {
        $uri = [Uri]$url
        $query = "" + $uri.Query

        if ([string]::IsNullOrWhiteSpace($query)) { return "" }

        if ($query.StartsWith("?")) {
            $query = $query.Substring(1)
        }

        foreach ($pair in ($query -split '&')) {

            if ([string]::IsNullOrWhiteSpace($pair)) { continue }

            $parts = $pair -split '=', 2

            $k = ""
            $v = ""

            try { $k = [System.Net.WebUtility]::UrlDecode("" + $parts[0]) } catch { $k = "" }

            if ($parts.Count -gt 1) {
                try { $v = [System.Net.WebUtility]::UrlDecode("" + $parts[1]) } catch { $v = "" }
            }

            if ($k -eq $name) {
                return $v
            }
        }

    } catch {
        return ""
    }

    return ""
}

function Get-FormActionFromHtml {
    param(
        [Parameter(Mandatory=$false)][string]$html
    )

    if ([string]::IsNullOrWhiteSpace($html)) { return "" }

    $m = [regex]::Match($html, '(?is)<form\b[^>]*action\s*=\s*["'']([^"'']+)["''][^>]*>')

    if ($m.Success) {
        try {
            return [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value)
        } catch {
            return $m.Groups[1].Value
        }
    }

    return ""
}

function Test-HtmlHasFieldName {
    param(
        [Parameter(Mandatory=$false)][string]$html,
        [Parameter(Mandatory=$true)][string]$name
    )

    if ([string]::IsNullOrWhiteSpace($html)) { return $false }

    return ([regex]::IsMatch($html, ('(?is)\bname\s*=\s*["'']{0}["'']' -f [regex]::Escape($name))))
}

function Get-HiddenFieldValueFromHtml {
    param(
        [Parameter(Mandatory=$false)][string]$html,
        [Parameter(Mandatory=$true)][string]$name
    )

    if ([string]::IsNullOrWhiteSpace($html)) { return "" }

    $pattern = '(?is)<input\b[^>]*name\s*=\s*["'']' + [regex]::Escape($name) + '["''][^>]*value\s*=\s*["'']([^"'']*)["''][^>]*>'
    $m = [regex]::Match($html, $pattern)

    if ($m.Success) {
        try { return [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value) } catch { return $m.Groups[1].Value }
    }

    $patternReversed = '(?is)<input\b[^>]*value\s*=\s*["'']([^"'']*)["''][^>]*name\s*=\s*["'']' + [regex]::Escape($name) + '["''][^>]*>'
    $m2 = [regex]::Match($html, $patternReversed)

    if ($m2.Success) {
        try { return [System.Net.WebUtility]::HtmlDecode($m2.Groups[1].Value) } catch { return $m2.Groups[1].Value }
    }

    return ""
}

function Get-SelectValueFromHtml {
    param(
        [Parameter(Mandatory=$false)][string]$html,
        [Parameter(Mandatory=$true)][string]$selectName
    )

    if ([string]::IsNullOrWhiteSpace($html)) { return "" }

    $pattern = '(?is)<select\b[^>]*name\s*=\s*["'']' + [regex]::Escape($selectName) + '["''][^>]*>(.*?)</select>'
    $m = [regex]::Match($html, $pattern)

    if (-not $m.Success) { return "" }

    $inner = "" + $m.Groups[1].Value

    $selected = [regex]::Match($inner, '(?is)<option\b[^>]*value\s*=\s*["'']([^"'']+)["''][^>]*selected[^>]*>')
    if ($selected.Success) {
        return $selected.Groups[1].Value
    }

    $first = [regex]::Matches($inner, '(?is)<option\b[^>]*value\s*=\s*["'']([^"'']+)["''][^>]*>')

    foreach ($opt in $first) {
        $value = ""
        try { $value = ("" + $opt.Groups[1].Value).Trim() } catch { $value = "" }
        if ($value -ne "") { return $value }
    }

    return ""
}

function Extract-SupportCodeFromHtmlOrUrl {
    param(
        [Parameter(Mandatory=$false)][string]$html,
        [Parameter(Mandatory=$false)][string]$url
    )

    $an = Analyze-Html -html $html
    if ($an.SecFound) { return $an.SecValue }

    $hiddenNames = @('support_reference','support_ref','reference')

    foreach ($fieldName in $hiddenNames) {

        $value = Get-HiddenFieldValueFromHtml -html $html -name $fieldName

        if (-not [string]::IsNullOrWhiteSpace($value) -and ($value -match ('^{0}$' -f $script:SecPattern))) {
            return $value
        }
    }

    $urlValue = Get-QueryParameterFromUrl -url $url -name 'support_reference'

    if (-not [string]::IsNullOrWhiteSpace($urlValue) -and ($urlValue -match ('^{0}$' -f $script:SecPattern))) {
        return $urlValue
    }

    return ""
}

function Extract-SupportContactLinkFromHtml {
    param(
        [Parameter(Mandatory=$false)][string]$html
    )

    if ([string]::IsNullOrWhiteSpace($html)) { return "" }

    $anchorMatches = [regex]::Matches($html, '(?is)<a\b[^>]*href\s*=\s*["'']([^"'']+)["''][^>]*>(.*?)</a>')

    foreach ($m in $anchorMatches) {

        $href = ""
        $inner = ""

        try { $href = "" + $m.Groups[1].Value } catch { $href = "" }
        try { $inner = "" + $m.Groups[2].Value } catch { $inner = "" }

        try { $href = [System.Net.WebUtility]::HtmlDecode($href) } catch { }

        $innerText = Convert-ToSearchText $inner

        if (-not [string]::IsNullOrWhiteSpace($innerText) -and ($innerText -match $script:SupportContactTextPattern)) {
            return $href
        }
    }

    $fallbackPath = ""
    try { $fallbackPath = "" + $script:ExpectedTicketCreatePath } catch { $fallbackPath = "" }

    if (-not [string]::IsNullOrWhiteSpace($fallbackPath)) {

        $pathMatches = [regex]::Matches($html, '(?is)<a\b[^>]*href\s*=\s*["'']([^"'']+)["''][^>]*>')

        foreach ($m in $pathMatches) {

            $href = ""
            try { $href = "" + $m.Groups[1].Value } catch { $href = "" }

            try { $href = [System.Net.WebUtility]::HtmlDecode($href) } catch { }

            if (-not [string]::IsNullOrWhiteSpace($href) -and ($href -match [regex]::Escape($fallbackPath))) {
                return $href
            }
        }
    }

    return ""
}

Export-ModuleMember -Function *
