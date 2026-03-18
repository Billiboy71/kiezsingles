# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\modules\support\ks-support-flow.psm1
# Purpose: Shared security support flow helpers for KiezSingles audit PowerShell scripts
# Created: 06-03-2026 22:30 (Europe/Berlin)
# Changed: 18-03-2026 00:47 (Europe/Berlin)
# Version: 1.5
# =============================================================================

Set-StrictMode -Version Latest

function Get-StrictSupportCodeEvidence {
    param(
        [Parameter(Mandatory=$true)][string]$Html,
        [Parameter(Mandatory=$true)][string]$Url
    )

    $values = New-Object System.Collections.ArrayList

    foreach ($fieldName in @('support_reference', 'support_ref', 'reference')) {
        $value = Get-HiddenFieldValueFromHtml -html $Html -name $fieldName
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            [void]$values.Add(($value.Trim()))
        }
    }

    try {
        $uri = [System.Uri]$Url
        $query = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
        foreach ($key in @('support_reference', 'support_ref', 'reference')) {
            $value = "" + $query[$key]
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                [void]$values.Add(($value.Trim()))
            }
        }
    } catch {
    }

    $distinctValues = @($values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    $resolvedValue = ""
    if ($distinctValues.Count -eq 1) {
        $resolvedValue = "" + $distinctValues[0]
    }

    return [PSCustomObject]@{
        Values        = $distinctValues
        Value         = $resolvedValue
        Found         = ($distinctValues.Count -ge 1)
        MultipleFound = ($distinctValues.Count -gt 1)
    }
}

function Get-SupportTicketReferenceFromDb {
    param(
        [Parameter(Mandatory=$true)][string]$SupportCode
    )

    if ([string]::IsNullOrWhiteSpace($SupportCode)) {
        return ""
    }

    $escapedSupportCode = $SupportCode.Replace("'", "''")
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')
    $artisanPath = Join-Path $projectRoot 'artisan'
    $command = @'
$ticket = \Illuminate\Support\Facades\DB::table('tickets')
    ->where('support_reference', '__SUPPORT_CODE__')
    ->first(['support_reference']);
if ($ticket) { echo (string) ($ticket->support_reference ?? ''); }
'@.Replace('__SUPPORT_CODE__', $escapedSupportCode)

    try {
        $output = & php $artisanPath tinker --execute=$command 2>$null
        if ($LASTEXITCODE -ne 0) {
            return ""
        }

        return (("" + ($output | Out-String)).Trim())
    } catch {
        return ""
    }
}

function Get-SupportMailReferenceEvidence {
    param(
        [Parameter(Mandatory=$true)][string]$SupportCode
    )

    return [PSCustomObject]@{
        Status = "INFO_NO_MAIL_SYSTEM"
        Value  = ""
    }
}

function Get-CommonFormData {
    param(
        [Parameter(Mandatory=$true)][string]$Html,
        [Parameter(Mandatory=$true)][string]$SupportCode,
        [Parameter(Mandatory=$true)][string]$FlowName
    )

    $form = @{}
    $csrf = Extract-CsrfTokenFromHtml -html $Html

    if (-not [string]::IsNullOrWhiteSpace($csrf)) {
        $form['_token'] = $csrf
    }

    $subject = ("{0} {1}" -f $script:SupportTicketSubjectPrefix, $SupportCode).Trim()
    $message = ("{0}`nFlow: {1}`nSupportRef: {2}" -f $script:SupportTicketMessage, $FlowName, $SupportCode)

    if (Test-HtmlHasFieldName -html $Html -name 'support_reference') { $form['support_reference'] = $SupportCode }
    if (Test-HtmlHasFieldName -html $Html -name 'support_ref') { $form['support_ref'] = $SupportCode }
    if (Test-HtmlHasFieldName -html $Html -name 'reference') { $form['reference'] = $SupportCode }

    if (Test-HtmlHasFieldName -html $Html -name 'source_context') {
        $sourceContext = Get-HiddenFieldValueFromHtml -html $Html -name 'source_context'
        if (-not [string]::IsNullOrWhiteSpace($sourceContext)) {
            $form['source_context'] = $sourceContext
        }
    }

    if (Test-HtmlHasFieldName -html $Html -name 'support_access_token') {
        $supportAccessToken = Get-HiddenFieldValueFromHtml -html $Html -name 'support_access_token'
        if (-not [string]::IsNullOrWhiteSpace($supportAccessToken)) {
            $form['support_access_token'] = $supportAccessToken
        }
    }

    if (Test-HtmlHasFieldName -html $Html -name 'name') { $form['name'] = $script:SupportTicketGuestName }
    if (Test-HtmlHasFieldName -html $Html -name 'full_name') { $form['full_name'] = $script:SupportTicketGuestName }
    if (Test-HtmlHasFieldName -html $Html -name 'display_name') { $form['display_name'] = $script:SupportTicketGuestName }

    if (Test-HtmlHasFieldName -html $Html -name 'email') { $form['email'] = $script:SupportTicketGuestEmail }

    if (Test-HtmlHasFieldName -html $Html -name 'subject') { $form['subject'] = $subject }
    if (Test-HtmlHasFieldName -html $Html -name 'title') { $form['title'] = $subject }

    if (Test-HtmlHasFieldName -html $Html -name 'message') { $form['message'] = $message }
    if (Test-HtmlHasFieldName -html $Html -name 'content') { $form['content'] = $message }
    if (Test-HtmlHasFieldName -html $Html -name 'body') { $form['body'] = $message }
    if (Test-HtmlHasFieldName -html $Html -name 'description') { $form['description'] = $message }

    $categoryId = Get-SelectValueFromHtml -html $Html -selectName 'category_id'
    if ($categoryId -ne "") { $form['category_id'] = $categoryId }

    $category = Get-SelectValueFromHtml -html $Html -selectName 'category'
    if ($category -ne "") { $form['category'] = $category }

    $priorityId = Get-SelectValueFromHtml -html $Html -selectName 'priority_id'
    if ($priorityId -ne "") { $form['priority_id'] = $priorityId }

    $priority = Get-SelectValueFromHtml -html $Html -selectName 'priority'
    if ($priority -ne "") { $form['priority'] = $priority }

    $typeId = Get-SelectValueFromHtml -html $Html -selectName 'type_id'
    if ($typeId -ne "") { $form['type_id'] = $typeId }

    $ticketTypeId = Get-SelectValueFromHtml -html $Html -selectName 'ticket_type_id'
    if ($ticketTypeId -ne "") { $form['ticket_type_id'] = $ticketTypeId }

    return $form
}

function Invoke-SupportTicketSubmit {
    param(
        [Parameter(Mandatory=$true)][string]$FlowName,
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$true)][string]$TargetUrl,
        [Parameter(Mandatory=$true)][string]$TargetHtml,
        [Parameter(Mandatory=$false)][string]$SupportCode,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{}
    )

    if (-not $script:SubmitSupportTicketTest) {
        return [PSCustomObject]@{
            Attempted         = $false
            Result            = "SKIP_DISABLED"
            SubmitUrl         = ""
            PostStatus        = ""
            FinalUrl          = ""
            FinalHtml         = ""
            CsrfPresent       = $false
            ValidationVisible = $false
        }
    }

    $csrf = Extract-CsrfTokenFromHtml -html $TargetHtml
    if ([string]::IsNullOrWhiteSpace($csrf)) {
        return [PSCustomObject]@{
            Attempted         = $true
            Result            = "FAIL_NO_CSRF"
            SubmitUrl         = ""
            PostStatus        = ""
            FinalUrl          = $TargetUrl
            FinalHtml         = $TargetHtml
            CsrfPresent       = $false
            ValidationVisible = $false
        }
    }

    $action = Get-FormActionFromHtml -html $TargetHtml
    if ([string]::IsNullOrWhiteSpace($action)) {
        return [PSCustomObject]@{
            Attempted         = $true
            Result            = "FAIL_NO_FORM_ACTION"
            SubmitUrl         = ""
            PostStatus        = ""
            FinalUrl          = $TargetUrl
            FinalHtml         = $TargetHtml
            CsrfPresent       = $true
            ValidationVisible = $false
        }
    }

    $submitUrl = Resolve-Url -BaseUrl $BaseUrl -CurrentUrl $TargetUrl -Location $action
    if ([string]::IsNullOrWhiteSpace($submitUrl)) {
        return [PSCustomObject]@{
            Attempted         = $true
            Result            = "FAIL_INVALID_FORM_ACTION"
            SubmitUrl         = $action
            PostStatus        = ""
            FinalUrl          = $TargetUrl
            FinalHtml         = $TargetHtml
            CsrfPresent       = $true
            ValidationVisible = $false
        }
    }

    $form = Get-CommonFormData -Html $TargetHtml -SupportCode $SupportCode -FlowName $FlowName

    $post = Invoke-HttpNoRedirect -Method 'POST' -Url $submitUrl -Session $Session -Headers $Headers -Form $form
    $loc = Try-GetLocationHeader -resp $post

    $finalUrl = $submitUrl
    $finalHtml = ""
    $usedFollow = $false

    $sc = 0
    try { $sc = [int]$post.StatusCode } catch { $sc = 0 }

    if ($script:FollowRedirectsEnabled -and ($sc -ge 300 -and $sc -lt 400) -and (-not [string]::IsNullOrWhiteSpace($loc))) {
        $target = Resolve-Url -BaseUrl $BaseUrl -CurrentUrl $submitUrl -Location $loc
        if (-not [string]::IsNullOrWhiteSpace($target)) {
            $follow = Invoke-FollowRedirects -BaseUrl $BaseUrl -StartUrl $target -Session $Session -Headers $Headers -Max $script:MaxRedirects
            $finalUrl = $follow.FinalUrl
            $finalHtml = $follow.FinalHtml
            $usedFollow = $true
        }
    }

    if (-not $usedFollow) {
        try {
            if ($null -ne $post.Content) {
                $finalHtml = "" + $post.Content
            } elseif ($null -ne $post.RawContent) {
                $finalHtml = "" + $post.RawContent
            } else {
                $finalHtml = ""
            }
        } catch {
            $finalHtml = ""
        }
    }

    $exportSubmit = Export-LoginHtml -label ("support_submit_{0}_final_html" -f $FlowName) -html $finalHtml
    if ($exportSubmit -ne "") { Write-Host "Exported HTML:" $exportSubmit }

    $validationVisible = $false
    if ($finalHtml -match '(?is)(fehler|error|validation|required|pflichtfeld|bitte.+ausf(ü|ue)llen)') {
        $validationVisible = $true
    }

    $result = "FAIL_UNKNOWN"
    if ($sc -ge 300 -and $sc -lt 400) {
        if (-not (Test-UrlContainsPath -u $finalUrl -path $script:ExpectedTicketCreatePath)) {
            $result = "PASS_REDIRECT"
        } else {
            $result = "FAIL_REDIRECT_BACK_TO_CREATE"
        }
    } elseif ($sc -eq 200) {
        if ($validationVisible) {
            $result = "FAIL_VALIDATION_VISIBLE"
        } elseif (-not (Test-UrlContainsPath -u $finalUrl -path $script:ExpectedTicketCreatePath)) {
            $result = "PASS_200_NON_CREATE"
        } else {
            $result = "WARN_200_CREATE_NO_VALIDATION_TEXT"
        }
    } else {
        $result = ("FAIL_HTTP_{0}" -f $sc)
    }

    $ticketSupportCode = ""
    if (($result -like 'PASS_*' -or $result -eq 'PASS_REDIRECT') -and -not [string]::IsNullOrWhiteSpace($SupportCode)) {
        $ticketSupportCode = Get-SupportTicketReferenceFromDb -SupportCode $SupportCode
    }

    $mailEvidence = Get-SupportMailReferenceEvidence -SupportCode $SupportCode

    return [PSCustomObject]@{
        Attempted         = $true
        Result            = $result
        SubmitUrl         = $submitUrl
        PostStatus        = $post.StatusCode
        FinalUrl          = $finalUrl
        FinalHtml         = $finalHtml
        CsrfPresent       = $true
        ValidationVisible = $validationVisible
        TicketSupportCode = $ticketSupportCode
        MailSupportCode   = $mailEvidence.Value
        MailResult        = $mailEvidence.Status
    }
}

function Invoke-SupportContactFlowCheck {
    param(
        [Parameter(Mandatory=$true)][string]$FlowName,
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$true)][string]$SourceUrl,
        [Parameter(Mandatory=$true)][string]$SourceHtml,
        [Parameter(Mandatory=$false)][hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)][string]$FallbackSupportCode = ""
    )

    if (-not $script:CheckSupportContactFlow) {
        return [PSCustomObject]@{
            Checked               = $false
            Result                = "SKIP_DISABLED"
            SupportLinkFound      = $false
            SupportLinkUrl        = ""
            FinalUrl              = ""
            TargetPathOk          = $false
            TargetCsrfPresent     = $false
            SourceSupportCode     = $FallbackSupportCode
            TargetSupportCode     = ""
            SupportCodeMatch      = $false
            TicketSubmitAttempted = $false
            TicketSubmitResult    = "SKIP_DISABLED"
            TicketSubmitUrl       = ""
            TicketSubmitFinalUrl  = ""
            TicketSubmitHttp      = ""
        }
    }

    $sourceCode = ""
    $sourceAn = Analyze-Html -html $SourceHtml

    if ($sourceAn.SecFound) {
        $sourceCode = $sourceAn.SecValue
    } elseif (-not [string]::IsNullOrWhiteSpace($FallbackSupportCode)) {
        $sourceCode = ("" + $FallbackSupportCode)
    }

    if ([string]::IsNullOrWhiteSpace($sourceCode)) {
        return [PSCustomObject]@{
            Checked               = $true
            Result                = "SKIP_NO_SUPPORT_REF"
            SupportLinkFound      = $false
            SupportLinkUrl        = ""
            FinalUrl              = ""
            TargetPathOk          = $false
            TargetCsrfPresent     = $false
            SourceSupportCode     = ""
            TargetSupportCode     = ""
            SupportCodeMatch      = $false
            TicketSubmitAttempted = $false
            TicketSubmitResult    = "SKIP_NO_SUPPORT_REF"
            TicketSubmitUrl       = ""
            TicketSubmitFinalUrl  = ""
            TicketSubmitHttp      = ""
        }
    }

    $supportHref = Extract-SupportContactLinkFromHtml -html $SourceHtml
    if ([string]::IsNullOrWhiteSpace($supportHref)) {
        return [PSCustomObject]@{
            Checked               = $true
            Result                = "FAIL_NO_SUPPORT_LINK"
            SupportLinkFound      = $false
            SupportLinkUrl        = ""
            FinalUrl              = ""
            TargetPathOk          = $false
            TargetCsrfPresent     = $false
            SourceSupportCode     = $sourceCode
            TargetSupportCode     = ""
            SupportCodeMatch      = $false
            TicketSubmitAttempted = $false
            TicketSubmitResult    = "SKIP_NO_SUPPORT_LINK"
            TicketSubmitUrl       = ""
            TicketSubmitFinalUrl  = ""
            TicketSubmitHttp      = ""
        }
    }

    $supportUrl = Resolve-Url -BaseUrl $BaseUrl -CurrentUrl $SourceUrl -Location $supportHref
    if ([string]::IsNullOrWhiteSpace($supportUrl)) {
        return [PSCustomObject]@{
            Checked               = $true
            Result                = "FAIL_INVALID_SUPPORT_LINK"
            SupportLinkFound      = $true
            SupportLinkUrl        = $supportHref
            FinalUrl              = ""
            TargetPathOk          = $false
            TargetCsrfPresent     = $false
            SourceSupportCode     = $sourceCode
            TargetSupportCode     = ""
            SupportCodeMatch      = $false
            TicketSubmitAttempted = $false
            TicketSubmitResult    = "SKIP_INVALID_SUPPORT_LINK"
            TicketSubmitUrl       = ""
            TicketSubmitFinalUrl  = ""
            TicketSubmitHttp      = ""
        }
    }

    $target = Invoke-GetWithOptionalRedirects -BaseUrl $BaseUrl -Url $supportUrl -Session $Session -Headers $Headers -Max $script:MaxRedirects
    $targetHtml = $target.FinalHtml
    $targetUrl = $target.FinalUrl
    $targetCsrf = Extract-CsrfTokenFromHtml -html $targetHtml
    $targetPathOk = Test-UrlContainsPath -u $targetUrl -path $script:ExpectedTicketCreatePath

    $exportTarget = Export-LoginHtml -label ("support_flow_{0}_ticket_target" -f $FlowName) -html $targetHtml
    if ($exportTarget -ne "") { Write-Host "Exported HTML:" $exportTarget }

    $targetCodeEvidence = Get-StrictSupportCodeEvidence -Html $targetHtml -Url $targetUrl
    $targetCode = $targetCodeEvidence.Value

    $submitState = [PSCustomObject]@{
        Attempted         = $false
        Result            = "SKIP_NOT_RUN"
        SubmitUrl         = ""
        PostStatus        = ""
        FinalUrl          = ""
        FinalHtml         = ""
        CsrfPresent       = (-not [string]::IsNullOrWhiteSpace($targetCsrf))
        ValidationVisible = $false
    }

    if (-not $targetPathOk) {
        return [PSCustomObject]@{
            Checked               = $true
            Result                = "FAIL_TARGET_PATH_MISMATCH"
            SupportLinkFound      = $true
            SupportLinkUrl        = $supportUrl
            FinalUrl              = $targetUrl
            TargetPathOk          = $false
            TargetCsrfPresent     = (-not [string]::IsNullOrWhiteSpace($targetCsrf))
            SourceSupportCode     = $sourceCode
            TargetSupportCode     = $targetCode
            SupportCodeMatch      = $false
            TicketSubmitAttempted = $false
            TicketSubmitResult    = "SKIP_TARGET_PATH_MISMATCH"
            TicketSubmitUrl       = ""
            TicketSubmitFinalUrl  = ""
            TicketSubmitHttp      = ""
            TicketSupportCode     = ""
            MailSupportCode       = ""
            MailResult            = "INFO_NOT_RUN"
            SecE2EResult          = "FAIL"
        }
    }

    if ($targetCodeEvidence.MultipleFound) {
        return [PSCustomObject]@{
            Checked               = $true
            Result                = "FAIL_MULTIPLE_TARGET_SUPPORT_REF"
            SupportLinkFound      = $true
            SupportLinkUrl        = $supportUrl
            FinalUrl              = $targetUrl
            TargetPathOk          = $true
            TargetCsrfPresent     = (-not [string]::IsNullOrWhiteSpace($targetCsrf))
            SourceSupportCode     = $sourceCode
            TargetSupportCode     = ""
            SupportCodeMatch      = $false
            TicketSubmitAttempted = $false
            TicketSubmitResult    = "SKIP_MULTIPLE_TARGET_SUPPORT_REF"
            TicketSubmitUrl       = ""
            TicketSubmitFinalUrl  = ""
            TicketSubmitHttp      = ""
            TicketSupportCode     = ""
            MailSupportCode       = ""
            MailResult            = "INFO_NOT_RUN"
            SecE2EResult          = "FAIL"
        }
    }

    if ([string]::IsNullOrWhiteSpace($targetCode)) {
        return [PSCustomObject]@{
            Checked               = $true
            Result                = "FAIL_NO_TARGET_SUPPORT_REF"
            SupportLinkFound      = $true
            SupportLinkUrl        = $supportUrl
            FinalUrl              = $targetUrl
            TargetPathOk          = $true
            TargetCsrfPresent     = (-not [string]::IsNullOrWhiteSpace($targetCsrf))
            SourceSupportCode     = $sourceCode
            TargetSupportCode     = ""
            SupportCodeMatch      = $false
            TicketSubmitAttempted = $false
            TicketSubmitResult    = "SKIP_NO_TARGET_SUPPORT_REF"
            TicketSubmitUrl       = ""
            TicketSubmitFinalUrl  = ""
            TicketSubmitHttp      = ""
            TicketSupportCode     = ""
            MailSupportCode       = ""
            MailResult            = "INFO_NOT_RUN"
            SecE2EResult          = "FAIL"
        }
    }

    if ($targetCode -ne $sourceCode) {
        return [PSCustomObject]@{
            Checked               = $true
            Result                = "FAIL_SUPPORT_REF_MISMATCH"
            SupportLinkFound      = $true
            SupportLinkUrl        = $supportUrl
            FinalUrl              = $targetUrl
            TargetPathOk          = $true
            TargetCsrfPresent     = (-not [string]::IsNullOrWhiteSpace($targetCsrf))
            SourceSupportCode     = $sourceCode
            TargetSupportCode     = $targetCode
            SupportCodeMatch      = $false
            TicketSubmitAttempted = $false
            TicketSubmitResult    = "SKIP_SUPPORT_REF_MISMATCH"
            TicketSubmitUrl       = ""
            TicketSubmitFinalUrl  = ""
            TicketSubmitHttp      = ""
            TicketSupportCode     = ""
            MailSupportCode       = ""
            MailResult            = "INFO_NOT_RUN"
            SecE2EResult          = "FAIL"
        }
    }

    $submitState = Invoke-SupportTicketSubmit -FlowName $FlowName -BaseUrl $BaseUrl -Session $Session -TargetUrl $targetUrl -TargetHtml $targetHtml -SupportCode $targetCode -Headers $Headers
    $secE2EResult = "FAIL"

    if ($submitState.Attempted -and
        ($submitState.Result -like 'PASS_*' -or $submitState.Result -eq 'PASS_REDIRECT') -and
        $targetCode -eq $sourceCode -and
        -not [string]::IsNullOrWhiteSpace($submitState.TicketSupportCode) -and
        $submitState.TicketSupportCode -eq $sourceCode) {
        $secE2EResult = "PASS"
    }

    return [PSCustomObject]@{
        Checked               = $true
        Result                = "PASS"
        SupportLinkFound      = $true
        SupportLinkUrl        = $supportUrl
        FinalUrl              = $targetUrl
        TargetPathOk          = $true
        TargetCsrfPresent     = (-not [string]::IsNullOrWhiteSpace($targetCsrf))
        SourceSupportCode     = $sourceCode
        TargetSupportCode     = $targetCode
        SupportCodeMatch      = $true
        TicketSubmitAttempted = $submitState.Attempted
        TicketSubmitResult    = $submitState.Result
        TicketSubmitUrl       = $submitState.SubmitUrl
        TicketSubmitFinalUrl  = $submitState.FinalUrl
        TicketSubmitHttp      = $submitState.PostStatus
        TicketSupportCode     = $submitState.TicketSupportCode
        MailSupportCode       = $submitState.MailSupportCode
        MailResult            = $submitState.MailResult
        SecE2EResult          = $secE2EResult
    }
}

function New-DefaultSupportFlowResult {
    return [PSCustomObject]@{
        Checked               = $false
        Result                = "SKIP_NO_SUPPORT_REF"
        SupportLinkFound      = $false
        SupportLinkUrl        = ""
        FinalUrl              = ""
        TargetPathOk          = $false
        TargetCsrfPresent     = $false
        SourceSupportCode     = ""
        TargetSupportCode     = ""
        SupportCodeMatch      = $false
        TicketSubmitAttempted = $false
        TicketSubmitResult    = "SKIP_NOT_RUN"
        TicketSubmitUrl       = ""
        TicketSubmitFinalUrl  = ""
        TicketSubmitHttp      = ""
        TicketSupportCode     = ""
        MailSupportCode       = ""
        MailResult            = "INFO_NOT_RUN"
        SecE2EResult          = "FAIL"
    }
}

Export-ModuleMember -Function *
