# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\checks\ks-ban-check.psm1
# Purpose: Ban check scenario (IP / Identity / Device) for KiezSingles audit PowerShell scripts
# Created: 06-03-2026 22:38 (Europe/Berlin)
# Changed: 11-03-2026 22:17 (Europe/Berlin)
# Version: 1.5
# =============================================================================

Set-StrictMode -Version Latest

function Get-SessionCookieValue {
    param(
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$CookieName
    )

    if ([string]::IsNullOrWhiteSpace($CookieName)) {
        return ""
    }

    try {
        $uri = [Uri]$BaseUrl
        $cookies = $Session.Cookies.GetCookies($uri)

        foreach ($cookie in $cookies) {
            try {
                if (("" + $cookie.Name) -eq $CookieName) {
                    return ("" + $cookie.Value)
                }
            } catch {
            }
        }
    } catch {
    }

    return ""
}

function Set-SessionCookieValue {
    param(
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$CookieName,
        [Parameter(Mandatory=$true)][string]$CookieValue
    )

    if ([string]::IsNullOrWhiteSpace($CookieName)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($CookieValue)) {
        return
    }

    try {
        $uri = [Uri]$BaseUrl
        $cookie = New-Object System.Net.Cookie
        $cookie.Name = $CookieName
        $cookie.Value = $CookieValue
        $cookie.Path = "/"
        $cookie.Domain = $uri.Host
        $Session.Cookies.Add($uri, $cookie)
    } catch {
    }
}

function Get-Sha256Hex {
    param(
        [Parameter(Mandatory=$true)][string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
            $hash = $sha.ComputeHash($bytes)
            return ([System.BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
        } finally {
            $sha.Dispose()
        }
    } catch {
        return ""
    }
}

function Run-BanCheck {
    param(
        [Parameter(Mandatory=$true)][string]$BanName,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$WrongPassword,
        [Parameter(Mandatory=$true)][string]$BanPattern,
        [Parameter(Mandatory=$false)][hashtable]$ExtraHeaders = @{},
        [Parameter(Mandatory=$false)][string]$DeviceCookieId = "",
        [Parameter(Mandatory=$false)][string]$ForcedAttemptIp = "",
        [Parameter(Mandatory=$false)][bool]$SkipSupportFlow = $false
    )

    Write-Section ("BAN CHECK: {0}" -f $BanName)
    Write-Host "Email:" $Email

    Reset-ClientIpRotation -Pool $script:ClientIpPool
    $session = New-Session

    $deviceCookieName = ""
    $deviceCookieId = ""
    $deviceCookieHash = ""
    $configuredDeviceCookieId = ""
    $effectiveForcedAttemptIp = ""

    try { $deviceCookieName = ("" + $script:DeviceCookieName).Trim() } catch { $deviceCookieName = "" }
    try { $configuredDeviceCookieId = ("" + $script:PinnedDeviceCookieId).Trim() } catch { $configuredDeviceCookieId = "" }

    if (-not [string]::IsNullOrWhiteSpace($DeviceCookieId)) {
        $configuredDeviceCookieId = ("" + $DeviceCookieId).Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($ForcedAttemptIp)) {
        $effectiveForcedAttemptIp = ("" + $ForcedAttemptIp).Trim()
    }
    elseif ($BanName -eq "ip" -and -not [string]::IsNullOrWhiteSpace($script:PinnedIpBanTestIp)) {
        $effectiveForcedAttemptIp = ("" + $script:PinnedIpBanTestIp).Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($effectiveForcedAttemptIp)) {
        Enter-ForcedClientIp $effectiveForcedAttemptIp
    }

    if ($BanName -eq "device" -and -not [string]::IsNullOrWhiteSpace($configuredDeviceCookieId) -and -not [string]::IsNullOrWhiteSpace($deviceCookieName)) {
        Set-SessionCookieValue -Session $session -BaseUrl $BaseUrl -CookieName $deviceCookieName -CookieValue $configuredDeviceCookieId
        $deviceCookieId = $configuredDeviceCookieId
        $deviceCookieHash = Get-Sha256Hex -Value $configuredDeviceCookieId
    }

    Begin-StepIp
    $hGet = Get-RequestHeaders -ExtraHeaders $ExtraHeaders -ForcedIp $effectiveForcedAttemptIp
    Write-Host "ClientIp:" $hGet.Ip

    $get = Get-LoginPage -BaseUrl $BaseUrl -Session $session -Headers $hGet.Headers
    $getStatusInt = 0
    try { $getStatusInt = [int]$get.StatusCode } catch { $getStatusInt = 0 }

    $getFinalHtml = "" + $get.Content
    $getFinalUrl = "$BaseUrl/login"
    $getFollowed = $false

    if ($script:FollowRedirectsEnabled -and ($getStatusInt -ge 300 -and $getStatusInt -lt 400)) {
        $getLoc = Try-GetLocationHeader -resp $get
        if (-not [string]::IsNullOrWhiteSpace($getLoc)) {
            $getTarget = Resolve-Url -BaseUrl $BaseUrl -CurrentUrl "$BaseUrl/login" -Location $getLoc
            if (-not [string]::IsNullOrWhiteSpace($getTarget)) {
                $getFollow = Invoke-FollowRedirects -BaseUrl $BaseUrl -StartUrl $getTarget -Session $session -Headers $hGet.Headers -Max $script:MaxRedirects
                $getFinalHtml = $getFollow.FinalHtml
                $getFinalUrl = $getFollow.FinalUrl
                $getFollowed = $true
            }
        }
    }

    if ($BanName -eq "device" -and -not [string]::IsNullOrWhiteSpace($deviceCookieName)) {
        if ([string]::IsNullOrWhiteSpace($configuredDeviceCookieId)) {
            $deviceCookieId = Get-SessionCookieValue -Session $session -BaseUrl $BaseUrl -CookieName $deviceCookieName
            $deviceCookieHash = Get-Sha256Hex -Value $deviceCookieId
        }

        Write-Host "DeviceCookieName:" $deviceCookieName
        Write-Host "DeviceCookieId:" $deviceCookieId
        Write-Host "DeviceCookieHash:" $deviceCookieHash
    }

    $getHtml = $getFinalHtml
    $getAn = Analyze-Html -html $getHtml
    $getBan = Analyze-TextPattern -html $getHtml -pattern $BanPattern

    Write-Host "GET /login Status:" $get.StatusCode "Followed:" $getFollowed "FinalUrl:" $getFinalUrl "BanTextFound:" $getBan.Found "SEC:" $getAn.SecFound "Lockout:" $getAn.LockoutFound

    if ($getAn.LockoutFound) {
        Write-Host "Lockout snippet:"
        Write-Host $getAn.LockoutSnippet
    }

    if ($getBan.Found) {
        Write-Host "Ban snippet:"
        Write-Host $getBan.Snippet
    }

    if ($getAn.SecFound) {
        Write-Host "SEC snippet:"
        Write-Host $getAn.SecSnippet
    }

    $exportGet = Export-LoginHtml -label ("ban_{0}_get_login" -f $BanName) -html $getHtml
    if ($exportGet -ne "") { Write-Host "Exported HTML:" $exportGet }

    if ($getAn.LockoutFound) {

        End-StepIp

        if (-not [string]::IsNullOrWhiteSpace($effectiveForcedAttemptIp)) {
            Exit-ForcedClientIp
        }

        Write-Host ("SKIP ban_{0} -> lockout_active_interference" -f $BanName)

        return [PSCustomObject]@{
            BanName                  = $BanName
            BanResult                = "SKIP_LOCKOUT_ACTIVE"
            PostStatus               = ""
            PostLocation             = ""
            FinalUrl                 = $getFinalUrl
            RedirectedToLogin        = $false
            BanTextFound             = $false
            SecFound                 = $false
            SecValue                 = ""
            TestIp                   = $hGet.Ip
            DeviceCookieName         = $deviceCookieName
            DeviceCookieId           = $deviceCookieId
            DeviceCookieHash         = $deviceCookieHash
            SupportFlowResult        = "SKIP_NO_SUPPORT_REF"
            SupportLinkFound         = $false
            SupportLinkUrl           = ""
            SupportTargetUrl         = ""
            SupportTargetPathOk      = $false
            SupportTargetCsrfPresent = $false
            SupportCodeOnTarget      = ""
            SupportCodeMatch         = $false
            TicketSubmitAttempted    = $false
            TicketSubmitResult       = "SKIP_NOT_RUN"
            TicketSubmitUrl          = ""
            TicketSubmitFinalUrl     = ""
            TicketSubmitHttp         = ""
        }
    }

    $supportSourceHtml = ""
    $supportSourceUrl = ""
    $supportFlow = New-DefaultSupportFlowResult
    $post = $null
    $postHtml = ""
    $postStatusInt = 0
    $redirectedToLogin = $false
    $banTextAny = ($getBan.Found)
    $secAny = ($getAn.SecFound)
    $status = "FAIL_NO_EVIDENCE"

    if ($getBan.Found -or $getAn.SecFound) {
        $supportSourceHtml = $getHtml
        $supportSourceUrl = $getFinalUrl

        $evidence = @()
        if ($getBan.Found) { $evidence += "BanText(GET)" }
        if ($getAn.SecFound) { $evidence += "SupportRef(GET)" }

        Write-Host "GET evidence is already sufficient; POST login attempt skipped."
        Write-Host "Evidence:" (($evidence | Where-Object { $_ -ne "" }) -join ", ")

        $status = "PASS"
    } else {
        $post = Post-LoginAttempt `
            -BaseUrl $BaseUrl `
            -Session $session `
            -Email $Email `
            -Password $WrongPassword `
            -ExtraHeaders $ExtraHeaders `
            -DeviceCookieId $configuredDeviceCookieId `
            -ForcedAttemptIp $effectiveForcedAttemptIp

        End-StepIp

        if (-not [string]::IsNullOrWhiteSpace($effectiveForcedAttemptIp)) {
            Exit-ForcedClientIp
        }

        if ($BanName -eq "device" -and -not [string]::IsNullOrWhiteSpace($deviceCookieName)) {
            if ([string]::IsNullOrWhiteSpace($configuredDeviceCookieId)) {
                $deviceCookieId = Get-SessionCookieValue -Session $session -BaseUrl $BaseUrl -CookieName $deviceCookieName
                $deviceCookieHash = Get-Sha256Hex -Value $deviceCookieId
            }
        }

        $postHtml = $post.FinalHtml
        $an = Analyze-Html -html $postHtml
        $ban = Analyze-TextPattern -html $postHtml -pattern $BanPattern

        try { $postStatusInt = [int]$post.PostStatus } catch { $postStatusInt = 0 }

        if ($postStatusInt -ge 300 -and $postStatusInt -lt 400) {
            if (Test-UrlLooksLikeLogin $post.PostLocation) {
                $redirectedToLogin = $true
            } elseif (Test-UrlLooksLikeLogin $post.FinalUrl) {
                $redirectedToLogin = $true
            }
        }

        $banTextAny = ($getBan.Found -or $ban.Found)
        $secAny = ($getAn.SecFound -or $an.SecFound)

        $evidence = @()
        if ($banTextAny) { $evidence += "BanText" }
        if ($secAny) { $evidence += "SupportRef" }
        if ($redirectedToLogin) { $evidence += "RedirectToLogin" }

        Write-Host "POST /login Status:" $post.PostStatus "Followed:" $post.Followed "FinalUrl:" $post.FinalUrl
        Write-Host "POST /login -> BanTextFound:" $ban.Found "SEC:" $an.SecFound "Lockout:" $an.LockoutFound "RedirectToLogin:" $redirectedToLogin
        Write-Host "Evidence:" (($evidence | Where-Object { $_ -ne "" }) -join ", ")

        if ($BanName -eq "device" -and -not [string]::IsNullOrWhiteSpace($deviceCookieName)) {
            Write-Host "DeviceCookieName:" $deviceCookieName
            Write-Host "DeviceCookieId:" $deviceCookieId
            Write-Host "DeviceCookieHash:" $deviceCookieHash
        }

        if ($secAny) {

            $secPrint = ""

            if ($an.SecFound) {
                $secPrint = $an.SecValue
            } elseif ($getAn.SecFound) {
                $secPrint = $getAn.SecValue
            }

            if (-not [string]::IsNullOrWhiteSpace($secPrint)) {
                Write-Host "SupportRef:" $secPrint
            }
        }

        if ($an.LockoutFound) {
            Write-Host "Lockout snippet:"
            Write-Host $an.LockoutSnippet
        }

        if ($ban.Found) {
            Write-Host "Ban snippet:"
            Write-Host $ban.Snippet
        }

        if ($an.SecFound) {
            Write-Host "SEC snippet:"
            Write-Host $an.SecSnippet
        }

        $exportPost = Export-LoginHtml -label ("ban_{0}_post_login_final_html" -f $BanName) -html $postHtml
        if ($exportPost -ne "") { Write-Host "Exported HTML:" $exportPost }

        if ($an.LockoutFound) {

            Write-Host ("SKIP ban_{0} -> lockout_active_interference" -f $BanName)

            return [PSCustomObject]@{
                BanName                  = $BanName
                BanResult                = "SKIP_LOCKOUT_ACTIVE"
                PostStatus               = $post.PostStatus
                PostLocation             = $post.PostLocation
                FinalUrl                 = $post.FinalUrl
                RedirectedToLogin        = $redirectedToLogin
                BanTextFound             = $false
                SecFound                 = $false
                SecValue                 = ""
                TestIp                   = $post.AttemptIp
                DeviceCookieName         = $deviceCookieName
                DeviceCookieId           = $deviceCookieId
                DeviceCookieHash         = $deviceCookieHash
                SupportFlowResult        = "SKIP_NO_SUPPORT_REF"
                SupportLinkFound         = $false
                SupportLinkUrl           = ""
                SupportTargetUrl         = ""
                SupportTargetPathOk      = $false
                SupportTargetCsrfPresent = $false
                SupportCodeOnTarget      = ""
                SupportCodeMatch         = $false
                TicketSubmitAttempted    = $false
                TicketSubmitResult       = "SKIP_NOT_RUN"
                TicketSubmitUrl          = ""
                TicketSubmitFinalUrl     = ""
                TicketSubmitHttp         = ""
            }
        }

        $status = "FAIL_NO_EVIDENCE"

        if ($banTextAny -or $secAny) {
            $status = "PASS"
        } elseif ($redirectedToLogin) {
            $status = "FAIL_REDIRECT_NO_BAN_UI"
        }

        if ($an.SecFound) {
            $supportSourceHtml = $postHtml
            $supportSourceUrl = $post.FinalUrl
        } elseif ($getAn.SecFound) {
            $supportSourceHtml = $getHtml
            $supportSourceUrl = $getFinalUrl
        }

        if ($status -eq "PASS") {

            $secValue = ""

            if ($an.SecFound) {
                $secValue = $an.SecValue
            } elseif ($getAn.SecFound) {
                $secValue = $getAn.SecValue
            }

            Write-Host ("PASS ban_{0} (SEC:{1})" -f $BanName, $secValue)

        } else {

            Write-Host ("FAIL ban_{0} -> {1}" -f $BanName, $status)

        }
    }

    if ($post -eq $null) {
        End-StepIp

        if (-not [string]::IsNullOrWhiteSpace($effectiveForcedAttemptIp)) {
            Exit-ForcedClientIp
        }
    }

    $secValueOut = ""

    if ($getAn.SecFound) {
        $secValueOut = $getAn.SecValue
    }

    if (-not [string]::IsNullOrWhiteSpace($supportSourceHtml) -and (-not $SkipSupportFlow)) {
        $supportFlow = Invoke-SupportContactFlowCheck `
            -FlowName ("ban_{0}" -f $BanName) `
            -BaseUrl $BaseUrl `
            -Session $session `
            -SourceUrl $supportSourceUrl `
            -SourceHtml $supportSourceHtml `
            -Headers $ExtraHeaders `
            -FallbackSupportCode $secValueOut

        Write-Host "SupportContactFlow:" $supportFlow.Result `
                   "LinkFound:" $supportFlow.SupportLinkFound `
                   "TargetPathOk:" $supportFlow.TargetPathOk `
                   "TargetCsrfPresent:" $supportFlow.TargetCsrfPresent `
                   "SecMatch:" $supportFlow.SupportCodeMatch

        Write-Host "SupportTicketSubmit:" $supportFlow.TicketSubmitResult `
                   "Attempted:" $supportFlow.TicketSubmitAttempted `
                   "HTTP:" $supportFlow.TicketSubmitHttp

        if (-not [string]::IsNullOrWhiteSpace($supportFlow.SupportLinkUrl)) {
            Write-Host "SupportContactLink:" $supportFlow.SupportLinkUrl
        }

        if (-not [string]::IsNullOrWhiteSpace($supportFlow.FinalUrl)) {
            Write-Host "SupportContactTarget:" $supportFlow.FinalUrl
        }

        if (-not [string]::IsNullOrWhiteSpace($supportFlow.TargetSupportCode)) {
            Write-Host "TargetSupportRef:" $supportFlow.TargetSupportCode
        }

        if (-not [string]::IsNullOrWhiteSpace($supportFlow.TicketSubmitUrl)) {
            Write-Host "SupportTicketSubmitUrl:" $supportFlow.TicketSubmitUrl
        }

        if (-not [string]::IsNullOrWhiteSpace($supportFlow.TicketSubmitFinalUrl)) {
            Write-Host "SupportTicketSubmitTarget:" $supportFlow.TicketSubmitFinalUrl
        }
    }

    return [PSCustomObject]@{
        BanName                  = $BanName
        BanResult                = $status
        PostStatus               = $(if ($null -ne $post) { $post.PostStatus } else { "" })
        PostLocation             = $(if ($null -ne $post) { $post.PostLocation } else { "" })
        FinalUrl                 = $(if ($null -ne $post) { $post.FinalUrl } else { $getFinalUrl })
        RedirectedToLogin        = $redirectedToLogin
        BanTextFound             = $banTextAny
        SecFound                 = $secAny
        SecValue                 = $secValueOut
        TestIp                   = $(if ($null -ne $post) { $post.AttemptIp } else { $hGet.Ip })
        DeviceCookieName         = $deviceCookieName
        DeviceCookieId           = $deviceCookieId
        DeviceCookieHash         = $deviceCookieHash
        SupportFlowResult        = $supportFlow.Result
        SupportLinkFound         = $supportFlow.SupportLinkFound
        SupportLinkUrl           = $supportFlow.SupportLinkUrl
        SupportTargetUrl         = $supportFlow.FinalUrl
        SupportTargetPathOk      = $supportFlow.TargetPathOk
        SupportTargetCsrfPresent = $supportFlow.TargetCsrfPresent
        SupportCodeOnTarget      = $supportFlow.TargetSupportCode
        SupportCodeMatch         = $supportFlow.SupportCodeMatch
        TicketSubmitAttempted    = $supportFlow.TicketSubmitAttempted
        TicketSubmitResult       = $supportFlow.TicketSubmitResult
        TicketSubmitUrl          = $supportFlow.TicketSubmitUrl
        TicketSubmitFinalUrl     = $supportFlow.TicketSubmitFinalUrl
        TicketSubmitHttp         = $supportFlow.TicketSubmitHttp
    }
}

Export-ModuleMember -Function *
