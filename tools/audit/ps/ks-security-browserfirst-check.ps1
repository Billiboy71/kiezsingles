# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\ks-security-browserfirst-check.ps1
# Purpose: Browser-first Security Login/Ban evidence check via PowerShell (no audit-tool)
# Created: 05-03-2026 01:19 (Europe/Berlin)
# Changed: 16-03-2026 19:04 (Europe/Berlin)
# Version: 6.0
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# MODULES
# -----------------------------------------------------------------------------
Remove-Item function:Invoke-AbuseAdminValidation -ErrorAction SilentlyContinue

Import-Module "$PSScriptRoot\modules\core\ks-http.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\modules\core\ks-evidence.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\modules\core\ks-client-ip.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\modules\support\ks-support-flow.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\modules\checks\ks-ban-check.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\modules\checks\ks-lockout-scenario.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\modules\checks\ks-abuse-admin-validation.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\modules\auth\ks-login-attempt.psm1" -Force -DisableNameChecking

. "$PSScriptRoot\modules\checks\check-session-reuse.ps1"
. "$PSScriptRoot\modules\checks\check-account-enumeration.ps1"
. "$PSScriptRoot\modules\checks\check-security-event-logging.ps1"

# DEBUG: anzeigen welche Version geladen wurde
try {
    $module = Get-Module -Name 'ks-abuse-admin-validation' -ErrorAction Stop | Select-Object -First 1
    if ($null -ne $module -and -not [string]::IsNullOrWhiteSpace($module.Path) -and (Test-Path -LiteralPath $module.Path)) {
        $moduleHeader = Get-Content -Path $module.Path -TotalCount 8
        $versionLine = $moduleHeader | Where-Object { $_ -match '^# Version:\s*' } | Select-Object -First 1
        if ($null -ne $versionLine -and ("" + $versionLine) -match 'Version:\s*([0-9\.]+)') {
            Write-Host ("Loaded AbuseAdminValidation Version: {0}" -f $matches[1])
        } else {
            Write-Host ("Loaded AbuseAdminValidation Module: {0}" -f $module.Name)
        }
    } else {
        Write-Host "Loaded AbuseAdminValidation (module path not detected)"
    }
} catch {
    Write-Host "WARNING: Invoke-AbuseAdminValidation not loaded"
}

function Set-AuditModuleRuntimeVariable {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)]$Value
    )

    $moduleNames = @(
        'ks-http',
        'ks-evidence',
        'ks-client-ip',
        'ks-support-flow',
        'ks-ban-check',
        'ks-lockout-scenario',
        'ks-abuse-admin-validation',
        'ks-login-attempt'
    )

    foreach ($moduleName in $moduleNames) {
        $module = Get-Module -Name $moduleName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $module) {
            continue
        }

        try {
            $module.SessionState.PSVariable.Set($Name, $Value)
        } catch {
        }
    }
}

function Sync-AuditModuleRuntimeVariables {
    try {
        $scriptVariables = @(Get-Variable -Scope Script)
    } catch {
        $scriptVariables = @()
    }

    foreach ($scriptVariable in $scriptVariables) {
        if ($null -eq $scriptVariable) {
            continue
        }

        $variableName = ""
        try { $variableName = ("" + $scriptVariable.Name).Trim() } catch { $variableName = "" }

        if ([string]::IsNullOrWhiteSpace($variableName)) {
            continue
        }

        Set-AuditModuleRuntimeVariable -Name $variableName -Value $scriptVariable.Value
    }
}

# -----------------------------------------------------------------------------
# CONFIG LOADER
# -----------------------------------------------------------------------------
$ConfigFilePath = Join-Path $PSScriptRoot "ks-security-browserfirst-check.config.ps1"

if (-not (Test-Path -LiteralPath $ConfigFilePath)) {
    throw "Config file not found: $ConfigFilePath"
}

try {
    . $ConfigFilePath
} catch {
    throw "Config file load failed: $ConfigFilePath`n$($_.Exception.Message)"
}

# -----------------------------------------------------------------------------
# RUNTIME NORMALIZATION / DEFAULTS
# -----------------------------------------------------------------------------
if (-not (Get-Variable -Name BaseUrl -Scope Script -ErrorAction SilentlyContinue)) { $script:BaseUrl = "http://kiezsingles.test" }
if (-not (Get-Variable -Name RegisteredEmail -Scope Script -ErrorAction SilentlyContinue)) { $script:RegisteredEmail = "admin@web.de" }
if (-not (Get-Variable -Name UnregisteredEmail -Scope Script -ErrorAction SilentlyContinue)) { $script:UnregisteredEmail = "audit-test1@kiezsingles.local" }
if (-not (Get-Variable -Name IdentityBanEmail -Scope Script -ErrorAction SilentlyContinue)) { $script:IdentityBanEmail = "banned-mail@web.de" }
if (-not (Get-Variable -Name WrongPassword -Scope Script -ErrorAction SilentlyContinue)) { $script:WrongPassword = "falschespasswort" }
if (-not (Get-Variable -Name LockoutAttempts -Scope Script -ErrorAction SilentlyContinue)) { $script:LockoutAttempts = 7 }

if (-not (Get-Variable -Name CheckIpBan -Scope Script -ErrorAction SilentlyContinue)) { $script:CheckIpBan = $false }
if (-not (Get-Variable -Name CheckIdentityBan -Scope Script -ErrorAction SilentlyContinue)) { $script:CheckIdentityBan = $false }
if (-not (Get-Variable -Name CheckDeviceBan -Scope Script -ErrorAction SilentlyContinue)) { $script:CheckDeviceBan = $false }

if (-not (Get-Variable -Name DeviceCookieName -Scope Script -ErrorAction SilentlyContinue)) { $script:DeviceCookieName = "ks_device_id" }
if (-not (Get-Variable -Name TestDeviceCookieId -Scope Script -ErrorAction SilentlyContinue)) { $script:TestDeviceCookieId = "ks-test-device-001" }
if (-not (Get-Variable -Name PinnedDeviceCookieId -Scope Script -ErrorAction SilentlyContinue)) { $script:PinnedDeviceCookieId = "" }

if (-not (Get-Variable -Name SkipLockoutScenariosIfIpBanPass -Scope Script -ErrorAction SilentlyContinue)) { $script:SkipLockoutScenariosIfIpBanPass = $true }
if (-not (Get-Variable -Name PinnedIpBanTestIp -Scope Script -ErrorAction SilentlyContinue)) { $script:PinnedIpBanTestIp = "" }
if (-not (Get-Variable -Name PinnedLockoutTestIp -Scope Script -ErrorAction SilentlyContinue)) { $script:PinnedLockoutTestIp = "" }
if (-not (Get-Variable -Name AutoSelectFreeLockoutTestIp -Scope Script -ErrorAction SilentlyContinue)) { $script:AutoSelectFreeLockoutTestIp = $true }

if (-not (Get-Variable -Name IpBanPattern -Scope Script -ErrorAction SilentlyContinue)) {
    $script:IpBanPattern = '(?is)(anmeldung\s+aktuell\s+nicht\s+m(ö|oe)glich|zugriff\s+ist\s+aktuell\s+eingeschr(ä|ae)nkt|der\s+zugriff\s+ist\s+aktuell\s+eingeschr(ä|ae)nkt|access\s+is\s+currently\s+restricted)'
}
if (-not (Get-Variable -Name IdentityBanPattern -Scope Script -ErrorAction SilentlyContinue)) {
    $script:IdentityBanPattern = '(?is)(anmeldung\s+(aktuell|derzeit)\s+nicht\s+m(ö|oe)glich|login\s+currently\s+not\s+possible|sign\s+in\s+is\s+currently\s+not\s+possible)'
}
if (-not (Get-Variable -Name DeviceBanPattern -Scope Script -ErrorAction SilentlyContinue)) {
    $script:DeviceBanPattern = '(?is)(ger(ä|ae)t\s+ist\s+gesperrt|device\s+is\s+blocked|device\s+blocked)'
}

if (-not (Get-Variable -Name DeviceHeaderName -Scope Script -ErrorAction SilentlyContinue)) { $script:DeviceHeaderName = "" }
if (-not (Get-Variable -Name DeviceHeaderValue -Scope Script -ErrorAction SilentlyContinue)) { $script:DeviceHeaderValue = "" }

if (-not (Get-Variable -Name CheckSupportContactFlow -Scope Script -ErrorAction SilentlyContinue)) { $script:CheckSupportContactFlow = $true }
if (-not (Get-Variable -Name ExpectedTicketCreatePath -Scope Script -ErrorAction SilentlyContinue)) { $script:ExpectedTicketCreatePath = "/support/security" }
if (-not (Get-Variable -Name SupportContactTextPattern -Scope Script -ErrorAction SilentlyContinue)) { $script:SupportContactTextPattern = '(?is)\bsupport\s+kontaktieren\b' }

if (-not (Get-Variable -Name SubmitSupportTicketTest -Scope Script -ErrorAction SilentlyContinue)) { $script:SubmitSupportTicketTest = $true }
if (-not (Get-Variable -Name SupportTicketGuestName -Scope Script -ErrorAction SilentlyContinue)) { $script:SupportTicketGuestName = "PS Supportcode Test" }
if (-not (Get-Variable -Name SupportTicketGuestEmail -Scope Script -ErrorAction SilentlyContinue)) { $script:SupportTicketGuestEmail = "audit-supportcode@kiezsingles.local" }
if (-not (Get-Variable -Name SupportTicketSubjectPrefix -Scope Script -ErrorAction SilentlyContinue)) { $script:SupportTicketSubjectPrefix = "[PS Supportcode Test]" }
if (-not (Get-Variable -Name SupportTicketMessage -Scope Script -ErrorAction SilentlyContinue)) { $script:SupportTicketMessage = "Automatischer Supportcode-Test aus ks-security-browserfirst-check.ps1" }
if (-not (Get-Variable -Name SupportTicketSourceContext -Scope Script -ErrorAction SilentlyContinue)) { $script:SupportTicketSourceContext = "security_browserfirst_check_ps" }

if (-not (Get-Variable -Name SimulateClientIpEnabled -Scope Script -ErrorAction SilentlyContinue)) { $script:SimulateClientIpEnabled = $true }
if (-not (Get-Variable -Name ClientIpHeaderMode -Scope Script -ErrorAction SilentlyContinue)) { $script:ClientIpHeaderMode = "standard" }
if (-not (Get-Variable -Name TestIpPool -Scope Script -ErrorAction SilentlyContinue)) { $script:TestIpPool = @() }
if (-not (Get-Variable -Name IpRotationMode -Scope Script -ErrorAction SilentlyContinue)) { $script:IpRotationMode = "per_step" }

if (-not (Get-Variable -Name CheckAbuseSimulation -Scope Script -ErrorAction SilentlyContinue)) { $script:CheckAbuseSimulation = $false }
if (-not (Get-Variable -Name AbuseSimulationAttemptsPerStep -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseSimulationAttemptsPerStep = 1 }
if (-not (Get-Variable -Name AbuseSimulationSkipSupportFlow -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseSimulationSkipSupportFlow = $true }

if (-not (Get-Variable -Name AbuseScenarioDeviceReuseEnabled -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseScenarioDeviceReuseEnabled = $true }
if (-not (Get-Variable -Name AbuseScenarioAccountSharingEnabled -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseScenarioAccountSharingEnabled = $true }
if (-not (Get-Variable -Name AbuseScenarioBotPatternEnabled -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseScenarioBotPatternEnabled = $true }
if (-not (Get-Variable -Name AbuseScenarioDeviceClusterEnabled -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseScenarioDeviceClusterEnabled = $true }

if (-not (Get-Variable -Name AbuseFixedDevicePool -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseFixedDevicePool = @() }
if (-not (Get-Variable -Name AbuseFixedEmailPool -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseFixedEmailPool = @() }
if (-not (Get-Variable -Name AbuseFixedIpPool -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseFixedIpPool = @() }

if (-not (Get-Variable -Name AbuseDevicePoolPrefix -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseDevicePoolPrefix = "ks-sim-device-audit-"  }
if (-not (Get-Variable -Name AbuseEmailPoolPrefix -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseEmailPoolPrefix = "audit-abuse-" }
if (-not (Get-Variable -Name AbuseEmailDomain -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseEmailDomain = "kiezsingles.local" }

if (-not (Get-Variable -Name AbuseDevicePoolCount -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseDevicePoolCount = 12 }
if (-not (Get-Variable -Name AbuseEmailPoolCount -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseEmailPoolCount = 40 }
if (-not (Get-Variable -Name AbuseIpPoolCount -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseIpPoolCount = 50 }

if (-not (Get-Variable -Name ExportHtmlEnabled -Scope Script -ErrorAction SilentlyContinue)) { $script:ExportHtmlEnabled = $true }
if (-not (Get-Variable -Name ExportHtmlDir -Scope Script -ErrorAction SilentlyContinue)) { $script:ExportHtmlDir = (Join-Path $PSScriptRoot "output") }

if (-not (Get-Variable -Name SecPattern -Scope Script -ErrorAction SilentlyContinue)) { $script:SecPattern = 'SEC-[A-Z0-9]{6,8}' }
if (-not (Get-Variable -Name SnippetRadiusChars -Scope Script -ErrorAction SilentlyContinue)) { $script:SnippetRadiusChars = 80 }
if (-not (Get-Variable -Name WrongCredsPattern -Scope Script -ErrorAction SilentlyContinue)) {
    $script:WrongCredsPattern = '(?is)(zugangsdaten\s+sind\s+ung(ü|ue)ltig|passwort\s+ist\s+falsch|benutzername\/e-?mail\s+oder\s+passwort\s+ist\s+falsch|these\s+credentials\s+do\s+not\s+match|invalid\s+credentials|ung(ü|ue)ltig)'
}
if (-not (Get-Variable -Name LockoutPattern -Scope Script -ErrorAction SilentlyContinue)) {
    $script:LockoutPattern = '(?is)(zu viele|zu\s+viele|too many|throttle|lockout|locked|versuche).{0,220}?(\d{1,5})\s*(sek|sekunden|second|seconds|min|minute|minuten)\b'
}

if (-not (Get-Variable -Name FollowRedirectsEnabled -Scope Script -ErrorAction SilentlyContinue)) { $script:FollowRedirectsEnabled = $true }
if (-not (Get-Variable -Name MaxRedirects -Scope Script -ErrorAction SilentlyContinue)) { $script:MaxRedirects = 5 }

if (-not (Get-Variable -Name AdminValidationEnabled -Scope Script -ErrorAction SilentlyContinue)) { $script:AdminValidationEnabled = $false }
if (-not (Get-Variable -Name AdminValidationLoginEmail -Scope Script -ErrorAction SilentlyContinue)) { $script:AdminValidationLoginEmail = "" }
if (-not (Get-Variable -Name AdminValidationLoginPassword -Scope Script -ErrorAction SilentlyContinue)) { $script:AdminValidationLoginPassword = "" }
if (-not (Get-Variable -Name AdminValidationEventsPath -Scope Script -ErrorAction SilentlyContinue)) { $script:AdminValidationEventsPath = "/admin/security/events" }
if (-not (Get-Variable -Name AdminValidationMaxSamplesPerCheck -Scope Script -ErrorAction SilentlyContinue)) { $script:AdminValidationMaxSamplesPerCheck = 3 }
if (-not (Get-Variable -Name AdminValidationDeviceCookieId -Scope Script -ErrorAction SilentlyContinue)) { $script:AdminValidationDeviceCookieId = "" }

if (-not (Get-Variable -Name AbuseAdminValidationExpectedSteps -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseAdminValidationExpectedSteps = 0 }
if (-not (Get-Variable -Name AbuseAdminValidationExpectedScenarioStepCounts -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseAdminValidationExpectedScenarioStepCounts = @{} }
if (-not (Get-Variable -Name AbuseAdminValidationExpectedDeviceSummary -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseAdminValidationExpectedDeviceSummary = $null }
if (-not (Get-Variable -Name AbuseAdminValidationTopDevicesLimit -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseAdminValidationTopDevicesLimit = 10 }
if (-not (Get-Variable -Name AbuseAdminValidationTopEmailsLimit -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseAdminValidationTopEmailsLimit = 10 }
if (-not (Get-Variable -Name AbuseAdminValidationTopIpsLimit -Scope Script -ErrorAction SilentlyContinue)) { $script:AbuseAdminValidationTopIpsLimit = 10 }

$BaseUrl = $script:BaseUrl
$RegisteredEmail = $script:RegisteredEmail
$UnregisteredEmail = $script:UnregisteredEmail
$IdentityBanEmail = $script:IdentityBanEmail
$WrongPassword = $script:WrongPassword
$LockoutAttempts = [int]$script:LockoutAttempts

$CheckIpBan = [bool]$script:CheckIpBan
$CheckIdentityBan = [bool]$script:CheckIdentityBan
$CheckDeviceBan = [bool]$script:CheckDeviceBan

$DeviceCookieName = $script:DeviceCookieName
$TestDeviceCookieId = $script:TestDeviceCookieId
$PinnedDeviceCookieId = $script:PinnedDeviceCookieId

$SkipLockoutScenariosIfIpBanPass = [bool]$script:SkipLockoutScenariosIfIpBanPass
$PinnedIpBanTestIp = $script:PinnedIpBanTestIp
$PinnedLockoutTestIp = $script:PinnedLockoutTestIp
$AutoSelectFreeLockoutTestIp = [bool]$script:AutoSelectFreeLockoutTestIp

$IpBanPattern = $script:IpBanPattern
$IdentityBanPattern = $script:IdentityBanPattern
$DeviceBanPattern = $script:DeviceBanPattern

$DeviceHeaderName = $script:DeviceHeaderName
$DeviceHeaderValue = $script:DeviceHeaderValue

$CheckSupportContactFlow = [bool]$script:CheckSupportContactFlow
$ExpectedTicketCreatePath = $script:ExpectedTicketCreatePath
$SupportContactTextPattern = $script:SupportContactTextPattern

$SubmitSupportTicketTest = [bool]$script:SubmitSupportTicketTest
$SupportTicketGuestName = $script:SupportTicketGuestName
$SupportTicketGuestEmail = $script:SupportTicketGuestEmail
$SupportTicketSubjectPrefix = $script:SupportTicketSubjectPrefix
$SupportTicketMessage = $script:SupportTicketMessage
$SupportTicketSourceContext = $script:SupportTicketSourceContext

$SimulateClientIpEnabled = [bool]$script:SimulateClientIpEnabled
$ClientIpHeaderMode = $script:ClientIpHeaderMode
$TestIpPool = @($script:TestIpPool)
$IpRotationMode = $script:IpRotationMode

$CheckAbuseSimulation = [bool]$script:CheckAbuseSimulation
$AbuseSimulationAttemptsPerStep = [int]$script:AbuseSimulationAttemptsPerStep
$AbuseSimulationSkipSupportFlow = [bool]$script:AbuseSimulationSkipSupportFlow

$AbuseScenarioDeviceReuseEnabled = [bool]$script:AbuseScenarioDeviceReuseEnabled
$AbuseScenarioAccountSharingEnabled = [bool]$script:AbuseScenarioAccountSharingEnabled
$AbuseScenarioBotPatternEnabled = [bool]$script:AbuseScenarioBotPatternEnabled
$AbuseScenarioDeviceClusterEnabled = [bool]$script:AbuseScenarioDeviceClusterEnabled

$AbuseFixedDevicePool = @($script:AbuseFixedDevicePool)
$AbuseFixedEmailPool = @($script:AbuseFixedEmailPool)
$AbuseFixedIpPool = @($script:AbuseFixedIpPool)

$AbuseDevicePoolPrefix = $script:AbuseDevicePoolPrefix
$AbuseEmailPoolPrefix = $script:AbuseEmailPoolPrefix
$AbuseEmailDomain = $script:AbuseEmailDomain

$AbuseDevicePoolCount = [int]$script:AbuseDevicePoolCount
$AbuseEmailPoolCount = [int]$script:AbuseEmailPoolCount
$AbuseIpPoolCount = [int]$script:AbuseIpPoolCount

$ExportHtmlEnabled = [bool]$script:ExportHtmlEnabled
$ExportHtmlDir = $script:ExportHtmlDir

$SecPattern = $script:SecPattern
$SnippetRadiusChars = [int]$script:SnippetRadiusChars
$WrongCredsPattern = $script:WrongCredsPattern
$LockoutPattern = $script:LockoutPattern

$FollowRedirectsEnabled = [bool]$script:FollowRedirectsEnabled
$MaxRedirects = [int]$script:MaxRedirects

$AdminValidationEnabled = [bool]$script:AdminValidationEnabled
$AdminValidationLoginEmail = $script:AdminValidationLoginEmail
$AdminValidationLoginPassword = $script:AdminValidationLoginPassword
$AdminValidationEventsPath = $script:AdminValidationEventsPath
$AdminValidationMaxSamplesPerCheck = [int]$script:AdminValidationMaxSamplesPerCheck
$AdminValidationDeviceCookieId = $script:AdminValidationDeviceCookieId

function Convert-ToLocalStringArray {
    param(
        [Parameter(Mandatory=$false)]$InputObject
    )

    $result = New-Object System.Collections.ArrayList

    if ($null -eq $InputObject) {
        return @()
    }

    if ($InputObject -is [string]) {
        $value = ("" + $InputObject)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            [void]$result.Add($value)
        }

        return @($result.ToArray())
    }

    if ($InputObject -is [System.Collections.IEnumerable]) {
        foreach ($item in $InputObject) {
            if ($null -eq $item) {
                continue
            }

            $value = ""
            try { $value = ("" + $item) } catch { $value = "" }

            if (-not [string]::IsNullOrWhiteSpace($value)) {
                [void]$result.Add($value)
            }
        }

        return @($result.ToArray())
    }

    $singleValue = ""
    try { $singleValue = ("" + $InputObject) } catch { $singleValue = "" }

    if (-not [string]::IsNullOrWhiteSpace($singleValue)) {
        [void]$result.Add($singleValue)
    }

    return @($result.ToArray())
}

function Assert-ConfigStringNotEmpty {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$false)][string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Config validation failed: '$Name' is empty."
    }
}

function Assert-ConfigIntegerMin {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][int]$Value,
        [Parameter(Mandatory=$true)][int]$Min
    )

    if ($Value -lt $Min) {
        throw "Config validation failed: '$Name' must be >= $Min (current: $Value)."
    }
}

function Get-EnabledAbuseScenarioStepCounts {
    $counts = [ordered]@{}

    if ($AbuseScenarioDeviceReuseEnabled) {
        $counts["abuse_device_reuse"] = 10
    }

    if ($AbuseScenarioAccountSharingEnabled) {
        $counts["abuse_account_sharing"] = 5
    }

    if ($AbuseScenarioBotPatternEnabled) {
        $counts["abuse_bot_pattern"] = 50
    }

    if ($AbuseScenarioDeviceClusterEnabled) {
        for ($cluster = 1; $cluster -le 5; $cluster++) {
            $counts[("abuse_device_cluster_{0}" -f $cluster)] = 10
        }
    }

    return $counts
}

function Get-EnabledAbuseScenarioTotalSteps {
    $counts = Get-EnabledAbuseScenarioStepCounts
    $total = 0

    foreach ($key in $counts.Keys) {
        $total += [int]$counts[$key]
    }

    return $total
}

function Validate-BrowserFirstConfig {
    Assert-ConfigStringNotEmpty -Name "BaseUrl" -Value $BaseUrl
    Assert-ConfigStringNotEmpty -Name "RegisteredEmail" -Value $RegisteredEmail
    Assert-ConfigStringNotEmpty -Name "UnregisteredEmail" -Value $UnregisteredEmail
    Assert-ConfigStringNotEmpty -Name "WrongPassword" -Value $WrongPassword
    Assert-ConfigIntegerMin -Name "LockoutAttempts" -Value $LockoutAttempts -Min 1
    Assert-ConfigIntegerMin -Name "MaxRedirects" -Value $MaxRedirects -Min 1
    Assert-ConfigIntegerMin -Name "SnippetRadiusChars" -Value $SnippetRadiusChars -Min 1

    if ($CheckDeviceBan -or $CheckAbuseSimulation) {
        Assert-ConfigStringNotEmpty -Name "DeviceCookieName" -Value $DeviceCookieName
    }

    if ($CheckSupportContactFlow -or $SubmitSupportTicketTest) {
        Assert-ConfigStringNotEmpty -Name "ExpectedTicketCreatePath" -Value $ExpectedTicketCreatePath
        Assert-ConfigStringNotEmpty -Name "SupportContactTextPattern" -Value $SupportContactTextPattern
    }

    if ($SubmitSupportTicketTest) {
        Assert-ConfigStringNotEmpty -Name "SupportTicketGuestName" -Value $SupportTicketGuestName
        Assert-ConfigStringNotEmpty -Name "SupportTicketGuestEmail" -Value $SupportTicketGuestEmail
        Assert-ConfigStringNotEmpty -Name "SupportTicketSubjectPrefix" -Value $SupportTicketSubjectPrefix
        Assert-ConfigStringNotEmpty -Name "SupportTicketMessage" -Value $SupportTicketMessage
        Assert-ConfigStringNotEmpty -Name "SupportTicketSourceContext" -Value $SupportTicketSourceContext
    }

    if ($CheckAbuseSimulation) {
        Assert-ConfigIntegerMin -Name "AbuseSimulationAttemptsPerStep" -Value $AbuseSimulationAttemptsPerStep -Min 1
        Assert-ConfigIntegerMin -Name "AbuseDevicePoolCount" -Value $AbuseDevicePoolCount -Min 1
        Assert-ConfigIntegerMin -Name "AbuseEmailPoolCount" -Value $AbuseEmailPoolCount -Min 1
        Assert-ConfigIntegerMin -Name "AbuseIpPoolCount" -Value $AbuseIpPoolCount -Min 1
        Assert-ConfigStringNotEmpty -Name "AbuseDevicePoolPrefix" -Value $AbuseDevicePoolPrefix
        Assert-ConfigStringNotEmpty -Name "AbuseEmailPoolPrefix" -Value $AbuseEmailPoolPrefix
        Assert-ConfigStringNotEmpty -Name "AbuseEmailDomain" -Value $AbuseEmailDomain
    }

    if ($CheckIpBan -and [string]::IsNullOrWhiteSpace($IpBanPattern)) {
        throw "Config validation failed: 'IpBanPattern' is empty while CheckIpBan is enabled."
    }

    if ($CheckIdentityBan -and [string]::IsNullOrWhiteSpace($IdentityBanPattern)) {
        throw "Config validation failed: 'IdentityBanPattern' is empty while CheckIdentityBan is enabled."
    }

    if ($CheckDeviceBan -and [string]::IsNullOrWhiteSpace($DeviceBanPattern)) {
        throw "Config validation failed: 'DeviceBanPattern' is empty while CheckDeviceBan is enabled."
    }

    if ($AdminValidationEnabled) {
        Assert-ConfigStringNotEmpty -Name "AdminValidationLoginEmail" -Value $AdminValidationLoginEmail
        Assert-ConfigStringNotEmpty -Name "AdminValidationLoginPassword" -Value $AdminValidationLoginPassword
        Assert-ConfigStringNotEmpty -Name "AdminValidationEventsPath" -Value $AdminValidationEventsPath
        Assert-ConfigIntegerMin -Name "AdminValidationMaxSamplesPerCheck" -Value $AdminValidationMaxSamplesPerCheck -Min 1
    }
}

Validate-BrowserFirstConfig

# PS 5.1: avoid Invoke-WebRequest prompt + DOM script execution warning
$IwrSupportsUseBasicParsing = $false
try {
    $cmd = Get-Command Invoke-WebRequest -ErrorAction Stop
    if ($null -ne $cmd -and $null -ne $cmd.Parameters -and $cmd.Parameters.ContainsKey('UseBasicParsing')) {
        $IwrSupportsUseBasicParsing = $true
    }
} catch {
    $IwrSupportsUseBasicParsing = $false
}

# -----------------------------------------------------------------------------
# RUN IDENT / EXPORT SEQUENCE (keeps all files grouped per run, avoids "duplicate" names)
# -----------------------------------------------------------------------------
$script:RunId = (Get-Date).ToString("ddMMyyyy-HHmmss")
$script:ExportSeq = 0
$script:ExportRunDir = ""

# -----------------------------------------------------------------------------
# IP ROTATION STATE
# -----------------------------------------------------------------------------
$script:ClientIpPool = @()
$script:ClientIpIndex = -1
$script:ClientIpStepIp = ""

# Forced client IP (when you want one stable IP for a whole test segment)
$script:ForcedClientIp = ""

# Resolved lockout IP (either pinned or auto-selected)
$script:ResolvedLockoutTestIp = ""

function Write-Section([string]$t){
    Write-Host ""
    Write-Host ("="*70)
    Write-Host $t
    Write-Host ("="*70)
}

function Invoke-SessionSecurityChecks {
    $checks = New-Object System.Collections.ArrayList

    [void]$checks.Add((Invoke-SessionReuseProtectionCheck))
    [void]$checks.Add((Invoke-AccountEnumerationProtectionCheck))
    [void]$checks.Add((Invoke-SecurityEventLoggingCheck))

    return @($checks.ToArray())
}

function Write-SessionSecurityChecksSummary {
    param(
        [Parameter(Mandatory=$true)]$Checks
    )

    Write-Section "SESSION SECURITY CHECKS"

    foreach ($check in @($Checks)) {
        Write-Host ("{0} -> {1}" -f $check.CheckName, $check.Result)
    }
}

function New-SkippedScenarioResult {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$SkipReason
    )

    return [PSCustomObject]@{
        ScenarioName             = $ScenarioName
        Email                    = $Email
        DeviceCookieId           = ""
        AttemptIp                = ""
        WrongCredsDetected       = $false
        LockoutDetected          = $false
        LockoutSeconds           = ""
        SupportCodeDetected      = $false
        SupportCodeValue         = ""
        SupportFlowResult        = $SkipReason
        SupportLinkFound         = $false
        SupportLinkUrl           = ""
        SupportTargetUrl         = ""
        SupportTargetPathOk      = $false
        SupportTargetCsrfPresent = $false
        SupportCodeOnTarget      = ""
        SupportCodeMatch         = $false
        TicketSubmitAttempted    = $false
        TicketSubmitResult       = $SkipReason
        TicketSubmitUrl          = ""
        TicketSubmitFinalUrl     = ""
        TicketSubmitHttp         = ""
        SkipReason               = $SkipReason
    }
}

function Test-IsBanOnlyMode {
    $enabledCount = 0

    if ($CheckIpBan) { $enabledCount++ }
    if ($CheckIdentityBan) { $enabledCount++ }
    if ($CheckDeviceBan) { $enabledCount++ }

    return ($enabledCount -eq 1)
}

function New-AbuseStep {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName,
        [Parameter(Mandatory=$true)][int]$StepNumber,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$DeviceCookieId,
        [Parameter(Mandatory=$true)][string]$AttemptIp
    )

    return [PSCustomObject]@{
        ScenarioName   = $ScenarioName
        StepNumber     = $StepNumber
        Email          = $Email
        DeviceCookieId = $DeviceCookieId
        AttemptIp      = $AttemptIp
    }
}

function Get-AbuseDevicePool {
    if ($AbuseFixedDevicePool -and $AbuseFixedDevicePool.Count -gt 0) {
        return @(Convert-ToLocalStringArray -InputObject $AbuseFixedDevicePool)
    }

    return @(Convert-ToLocalStringArray -InputObject (New-SequentialPool -Prefix $AbuseDevicePoolPrefix -Count $AbuseDevicePoolCount -StartIndex 1 -PadWidth 3))
}

function Get-AbuseEmailPool {
    if ($AbuseFixedEmailPool -and $AbuseFixedEmailPool.Count -gt 0) {
        return @(Convert-ToLocalStringArray -InputObject $AbuseFixedEmailPool)
    }

    return @(Convert-ToLocalStringArray -InputObject (New-EmailPool -Prefix $AbuseEmailPoolPrefix -Count $AbuseEmailPoolCount -Domain $AbuseEmailDomain -StartIndex 1 -PadWidth 3))
}

function Get-AbuseIpPool {
    if ($AbuseFixedIpPool -and $AbuseFixedIpPool.Count -gt 0) {
        return @(Convert-ToLocalStringArray -InputObject $AbuseFixedIpPool)
    }

    if ($TestIpPool -and $TestIpPool.Count -gt 0) {
        return @(Convert-ToLocalStringArray -InputObject ($TestIpPool | Select-Object -First $AbuseIpPoolCount))
    }

    return @(Convert-ToLocalStringArray -InputObject (Build-DefaultTestIpPool | Select-Object -First $AbuseIpPoolCount))
}

function Build-AbuseScenarioSteps {
    param(
        [Parameter(Mandatory=$true)]$DevicePool,
        [Parameter(Mandatory=$true)]$EmailPool,
        [Parameter(Mandatory=$true)]$IpPool
    )

    $resolvedDevicePool = @(Convert-ToLocalStringArray -InputObject $DevicePool)
    $resolvedEmailPool = @(Convert-ToLocalStringArray -InputObject $EmailPool)
    $resolvedIpPool = @(Convert-ToLocalStringArray -InputObject $IpPool)

    $steps = New-Object System.Collections.ArrayList

    if ($AbuseScenarioDeviceReuseEnabled) {
        $scenarioName = "abuse_device_reuse"
        for ($i = 0; $i -lt 10; $i++) {
            [void]$steps.Add((New-AbuseStep `
                -ScenarioName $scenarioName `
                -StepNumber ($steps.Count + 1) `
                -Email (Select-PoolValue -Pool $resolvedEmailPool -Index $i) `
                -DeviceCookieId (Select-PoolValue -Pool $resolvedDevicePool -Index 0) `
                -AttemptIp (Select-PoolValue -Pool $resolvedIpPool -Index $i)))
        }
    }

    if ($AbuseScenarioAccountSharingEnabled) {
        $scenarioName = "abuse_account_sharing"
        for ($i = 0; $i -lt 5; $i++) {
            [void]$steps.Add((New-AbuseStep `
                -ScenarioName $scenarioName `
                -StepNumber ($steps.Count + 1) `
                -Email (Select-PoolValue -Pool $resolvedEmailPool -Index 10) `
                -DeviceCookieId (Select-PoolValue -Pool $resolvedDevicePool -Index ($i + 1)) `
                -AttemptIp (Select-PoolValue -Pool $resolvedIpPool -Index ($i + 10))))
        }
    }

    if ($AbuseScenarioBotPatternEnabled) {
        $scenarioName = "abuse_bot_pattern"
        for ($i = 0; $i -lt 50; $i++) {
            [void]$steps.Add((New-AbuseStep `
                -ScenarioName $scenarioName `
                -StepNumber ($steps.Count + 1) `
                -Email (Select-PoolValue -Pool $resolvedEmailPool -Index (20 + ($i % 10))) `
                -DeviceCookieId (Select-PoolValue -Pool $resolvedDevicePool -Index 0) `
                -AttemptIp (Select-PoolValue -Pool $resolvedIpPool -Index $i)))
        }
    }

    if ($AbuseScenarioDeviceClusterEnabled) {
        $clusterDeviceStart = 5
        $clusterEmailStart  = 0
        $clusterIpStart     = 0

        for ($cluster = 0; $cluster -lt 5; $cluster++) {
            $scenarioName = ("abuse_device_cluster_{0}" -f ($cluster + 1))
            $deviceId = Select-PoolValue -Pool $resolvedDevicePool -Index ($clusterDeviceStart + $cluster)

            for ($offset = 0; $offset -lt 4; $offset++) {
                [void]$steps.Add((New-AbuseStep `
                    -ScenarioName $scenarioName `
                    -StepNumber ($steps.Count + 1) `
                    -Email (Select-PoolValue -Pool $resolvedEmailPool -Index ($clusterEmailStart + ($cluster * 4) + $offset)) `
                    -DeviceCookieId $deviceId `
                    -AttemptIp (Select-PoolValue -Pool $resolvedIpPool -Index ($clusterIpStart + ($cluster * 10) + $offset))))
            }

            for ($offset = 4; $offset -lt 10; $offset++) {
                [void]$steps.Add((New-AbuseStep `
                    -ScenarioName $scenarioName `
                    -StepNumber ($steps.Count + 1) `
                    -Email (Select-PoolValue -Pool $resolvedEmailPool -Index ($clusterEmailStart + ($cluster * 4) + ($offset % 4))) `
                    -DeviceCookieId $deviceId `
                    -AttemptIp (Select-PoolValue -Pool $resolvedIpPool -Index ($clusterIpStart + ($cluster * 10) + $offset))))
            }
        }
    }

    return @($steps.ToArray())
}

function Get-AbuseScenarioExpectedPattern {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName
    )

    switch -Regex ($ScenarioName) {
        '^abuse_device_reuse$'       { return "1 Device -> viele Emails -> viele IPs" }
        '^abuse_account_sharing$'    { return "1 Email -> viele Devices -> viele IPs" }
        '^abuse_bot_pattern$'        { return "1 Device -> viele Emails -> sehr viele IPs" }
        '^abuse_device_cluster_\d+$' { return "1 Cluster-Device -> wenige Emails mehrfach -> fester IP-Bereich" }
        default                      { return "" }
    }
}

function Export-AbuseSimulationArtifacts {
    param(
        [Parameter(Mandatory=$true)]$SimulationResult
    )

    $results = @($SimulationResult.Results)
    $exports = [ordered]@{
        StepsCsv           = ""
        ResultsCsv         = ""
        DeviceSummaryCsv   = ""
        EmailSummaryCsv    = ""
        ScenarioSummaryCsv = ""
        ValidationTxt      = ""
        JsonReport         = ""
    }

    if ($results.Count -eq 0) {
        return [PSCustomObject]$exports
    }

    Ensure-ExportDir

    $effectiveExportRunDir = ""
    try { $effectiveExportRunDir = ("" + $script:ExportRunDir).Trim() } catch { $effectiveExportRunDir = "" }

    if ([string]::IsNullOrWhiteSpace($effectiveExportRunDir) -and -not [string]::IsNullOrWhiteSpace($ExportHtmlDir)) {
        $effectiveExportRunDir = Join-Path $ExportHtmlDir $script:RunId
    }

    if ([string]::IsNullOrWhiteSpace($effectiveExportRunDir)) {
        throw "ABUSE_EXPORT_RUN_DIR_EMPTY"
    }

    if (-not (Test-Path -LiteralPath $effectiveExportRunDir)) {
        [void](New-Item -ItemType Directory -Path $effectiveExportRunDir -Force)
    }

    $script:ExportRunDir = $effectiveExportRunDir
    Set-AuditModuleRuntimeVariable -Name 'ExportRunDir' -Value $script:ExportRunDir

    $stepsCsvPath = Join-Path $script:ExportRunDir ("{0}_abuse_steps.csv" -f $script:RunId)
    $resultsCsvPath = Join-Path $script:ExportRunDir ("{0}_abuse_results.csv" -f $script:RunId)
    $deviceSummaryCsvPath = Join-Path $script:ExportRunDir ("{0}_abuse_device_summary.csv" -f $script:RunId)
    $emailSummaryCsvPath = Join-Path $script:ExportRunDir ("{0}_abuse_email_summary.csv" -f $script:RunId)
    $scenarioSummaryCsvPath = Join-Path $script:ExportRunDir ("{0}_abuse_scenario_summary.csv" -f $script:RunId)
    $validationTxtPath = Join-Path $script:ExportRunDir ("{0}_abuse_admin_validation.txt" -f $script:RunId)
    $jsonPath = Join-Path $script:ExportRunDir ("{0}_abuse_report.json" -f $script:RunId)

    @($SimulationResult.Steps) |
        Select-Object ScenarioName, StepNumber, Email, DeviceCookieId, AttemptIp |
        Export-Csv -LiteralPath $stepsCsvPath -NoTypeInformation -Encoding UTF8

    $results |
        Select-Object ScenarioName, StepNumber, Email, DeviceCookieId, AttemptIp, WrongCredsDetected, LockoutDetected, SupportCodeDetected, SupportCodeValue |
        Export-Csv -LiteralPath $resultsCsvPath -NoTypeInformation -Encoding UTF8

    $deviceSummary = foreach ($group in ($results | Group-Object DeviceCookieId)) {
        $emailsSeen = @($group.Group | Select-Object -ExpandProperty Email -Unique)
        $ipsSeen = @($group.Group | Select-Object -ExpandProperty AttemptIp -Unique)
        $scenariosSeen = @($group.Group | Select-Object -ExpandProperty ScenarioName -Unique)

        [PSCustomObject]@{
            DeviceCookieId = $group.Name
            EmailsSeen     = $emailsSeen.Count
            IPsSeen        = $ipsSeen.Count
            Requests       = $group.Count
            Scenarios      = ($scenariosSeen -join ", ")
        }
    }

    $emailSummary = foreach ($group in ($results | Group-Object Email)) {
        $devicesSeen = @($group.Group | Select-Object -ExpandProperty DeviceCookieId -Unique)
        $ipsSeen = @($group.Group | Select-Object -ExpandProperty AttemptIp -Unique)
        $scenariosSeen = @($group.Group | Select-Object -ExpandProperty ScenarioName -Unique)

        [PSCustomObject]@{
            Email       = $group.Name
            DevicesSeen = $devicesSeen.Count
            IPsSeen     = $ipsSeen.Count
            Requests    = $group.Count
            Scenarios   = ($scenariosSeen -join ", ")
        }
    }

    $scenarioSummary = foreach ($group in ($results | Group-Object ScenarioName)) {
        $devicesSeen = @($group.Group | Select-Object -ExpandProperty DeviceCookieId -Unique)
        $emailsSeen = @($group.Group | Select-Object -ExpandProperty Email -Unique)
        $ipsSeen = @($group.Group | Select-Object -ExpandProperty AttemptIp -Unique)

        [PSCustomObject]@{
            ScenarioName    = $group.Name
            ExpectedPattern = Get-AbuseScenarioExpectedPattern -ScenarioName $group.Name
            Requests        = $group.Count
            Devices         = $devicesSeen.Count
            Emails          = $emailsSeen.Count
            IPs             = $ipsSeen.Count
        }
    }

    $deviceSummary | Export-Csv -LiteralPath $deviceSummaryCsvPath -NoTypeInformation -Encoding UTF8
    $emailSummary | Export-Csv -LiteralPath $emailSummaryCsvPath -NoTypeInformation -Encoding UTF8
    $scenarioSummary | Export-Csv -LiteralPath $scenarioSummaryCsvPath -NoTypeInformation -Encoding UTF8

    $validationLines = New-Object System.Collections.Generic.List[string]
    $validationLines.Add("RunId: $($script:RunId)")
    $validationLines.Add("Admin Validation Hints")
    $validationLines.Add("")

    foreach ($group in ($results | Group-Object ScenarioName)) {
        $sampleEmail = ""
        $sampleDevice = ""
        $sampleIp = ""

        try { $sampleEmail = "" + ($group.Group | Select-Object -First 1 -ExpandProperty Email) } catch { $sampleEmail = "" }
        try { $sampleDevice = "" + ($group.Group | Select-Object -First 1 -ExpandProperty DeviceCookieId) } catch { $sampleDevice = "" }
        try { $sampleIp = "" + ($group.Group | Select-Object -First 1 -ExpandProperty AttemptIp) } catch { $sampleIp = "" }

        $validationLines.Add(("Scenario: {0}" -f $group.Name))
        $validationLines.Add(("Expected: {0}" -f (Get-AbuseScenarioExpectedPattern -ScenarioName $group.Name)))
        $validationLines.Add(("Filter Email: {0}" -f $sampleEmail))
        $validationLines.Add(("Filter DeviceCookieId/Test Device: {0}" -f $sampleDevice))
        $validationLines.Add(("Sample IP: {0}" -f $sampleIp))
        $validationLines.Add("")
    }

    [System.IO.File]::WriteAllLines($validationTxtPath, $validationLines, [System.Text.Encoding]::UTF8)

    $jsonReport = [PSCustomObject]@{
        RunId           = $script:RunId
        GeneratedAt     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Steps           = @($SimulationResult.Steps)
        Results         = $results
        DeviceSummary   = @($deviceSummary)
        EmailSummary    = @($emailSummary)
        ScenarioSummary = @($scenarioSummary)
    }

    ($jsonReport | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $exports["StepsCsv"] = $stepsCsvPath
    $exports["ResultsCsv"] = $resultsCsvPath
    $exports["DeviceSummaryCsv"] = $deviceSummaryCsvPath
    $exports["EmailSummaryCsv"] = $emailSummaryCsvPath
    $exports["ScenarioSummaryCsv"] = $scenarioSummaryCsvPath
    $exports["ValidationTxt"] = $validationTxtPath
    $exports["JsonReport"] = $jsonPath

    return [PSCustomObject]$exports
}

function Invoke-AbuseSimulation {
    param(
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][string]$WrongPassword
    )

    $devicePool = @()
    $emailPool = @()
    $ipPool = @()
    $steps = @()

    try {
        $devicePool = @(Convert-ToLocalStringArray -InputObject (Get-AbuseDevicePool))
        $emailPool = @(Convert-ToLocalStringArray -InputObject (Get-AbuseEmailPool))
        $ipPool = @(Convert-ToLocalStringArray -InputObject (Get-AbuseIpPool))
        $steps = @(Build-AbuseScenarioSteps -DevicePool $devicePool -EmailPool $emailPool -IpPool $ipPool)
    } catch {
        $devicePoolType = ""
        $emailPoolType = ""
        $ipPoolType = ""

        try { if ($null -ne $devicePool) { $devicePoolType = $devicePool.GetType().FullName } } catch { $devicePoolType = "" }
        try { if ($null -ne $emailPool) { $emailPoolType = $emailPool.GetType().FullName } } catch { $emailPoolType = "" }
        try { if ($null -ne $ipPool) { $ipPoolType = $ipPool.GetType().FullName } } catch { $ipPoolType = "" }

        throw ("Invoke-AbuseSimulation failed during pool/step preparation. DevicePoolType='{0}' EmailPoolType='{1}' IpPoolType='{2}' Error='{3}'" -f $devicePoolType, $emailPoolType, $ipPoolType, $_.Exception.Message)
    }

    Write-Section "ABUSE SIMULATION"
    Write-Host "Enabled:" $CheckAbuseSimulation
    Write-Host "StepCount:" $steps.Count
    Write-Host "DevicePoolCount:" $devicePool.Count
    Write-Host "EmailPoolCount:" $emailPool.Count
    Write-Host "IpPoolCount:" $ipPool.Count

    $results = New-Object System.Collections.ArrayList

    foreach ($step in $steps) {
        Write-Host ("[{0}] Step {1} -> Email:{2} DeviceCookieId:{3} AttemptIp:{4}" -f $step.ScenarioName, $step.StepNumber, $step.Email, $step.DeviceCookieId, $step.AttemptIp)

        $result = Run-Scenario `
            -ScenarioName ("{0}_step_{1}" -f $step.ScenarioName, $step.StepNumber) `
            -Email $step.Email `
            -WrongPassword $WrongPassword `
            -Attempts $AbuseSimulationAttemptsPerStep `
            -ExtraHeaders @{} `
            -DeviceCookieId $step.DeviceCookieId `
            -ForcedAttemptIp $step.AttemptIp `
            -SkipSupportFlow $AbuseSimulationSkipSupportFlow

        $resolvedResultEmail = ""
        $resolvedResultDeviceCookieId = ""
        $resolvedResultAttemptIp = ""

        try { $resolvedResultEmail = ("" + $result.Email).Trim() } catch { $resolvedResultEmail = "" }
        try { $resolvedResultDeviceCookieId = ("" + $result.DeviceCookieId).Trim() } catch { $resolvedResultDeviceCookieId = "" }
        try { $resolvedResultAttemptIp = ("" + $result.AttemptIp).Trim() } catch { $resolvedResultAttemptIp = "" }

        if ([string]::IsNullOrWhiteSpace($resolvedResultEmail)) {
            $resolvedResultEmail = "" + $step.Email
        }

        if ([string]::IsNullOrWhiteSpace($resolvedResultDeviceCookieId)) {
            $resolvedResultDeviceCookieId = "" + $step.DeviceCookieId
        }

        if ([string]::IsNullOrWhiteSpace($resolvedResultAttemptIp)) {
            $resolvedResultAttemptIp = "" + $step.AttemptIp
        }

        [void]$results.Add([PSCustomObject]@{
            ScenarioName        = $step.ScenarioName
            StepNumber          = $step.StepNumber
            Email               = $resolvedResultEmail
            DeviceCookieId      = $resolvedResultDeviceCookieId
            AttemptIp           = $resolvedResultAttemptIp
            WrongCredsDetected  = $result.WrongCredsDetected
            LockoutDetected     = $result.LockoutDetected
            SupportCodeDetected = $result.SupportCodeDetected
            SupportCodeValue    = $result.SupportCodeValue
        })
    }

    return [PSCustomObject]@{
        DevicePool = $devicePool
        EmailPool  = $emailPool
        IpPool     = $ipPool
        Steps      = $steps
        Results    = @($results.ToArray())
        Exports    = $null
    }
}

function Write-AbuseSimulationSummary {
    param(
        [Parameter(Mandatory=$true)]$SimulationResult
    )

    $results = @($SimulationResult.Results)

    if ($results.Count -eq 0) {
        Write-Section "ABUSE SUMMARY"
        Write-Host "No abuse simulation results."
        return
    }

    Write-Section "ABUSE SUMMARY"

    $deviceGroups = $results | Group-Object DeviceCookieId
    foreach ($group in $deviceGroups) {
        $emailsSeen = @($group.Group | Select-Object -ExpandProperty Email -Unique)
        $ipsSeen = @($group.Group | Select-Object -ExpandProperty AttemptIp -Unique)
        $scenariosSeen = @($group.Group | Select-Object -ExpandProperty ScenarioName -Unique)

        Write-Host ("Device {0} -> EmailsSeen:{1} IPsSeen:{2} Requests:{3} Scenarios:{4}" -f $group.Name, $emailsSeen.Count, $ipsSeen.Count, $group.Count, ($scenariosSeen -join ", "))
    }

    $emailGroups = $results | Group-Object Email
    foreach ($group in $emailGroups) {
        $devicesSeen = @($group.Group | Select-Object -ExpandProperty DeviceCookieId -Unique)
        $ipsSeen = @($group.Group | Select-Object -ExpandProperty AttemptIp -Unique)
        if ($devicesSeen.Count -gt 1 -or $ipsSeen.Count -gt 1) {
            Write-Host ("Email {0} -> DevicesSeen:{1} IPsSeen:{2} Requests:{3}" -f $group.Name, $devicesSeen.Count, $ipsSeen.Count, $group.Count)
        }
    }

    $scenarioGroups = $results | Group-Object ScenarioName
    foreach ($group in $scenarioGroups) {
        $devicesSeen = @($group.Group | Select-Object -ExpandProperty DeviceCookieId -Unique)
        $emailsSeen = @($group.Group | Select-Object -ExpandProperty Email -Unique)
        $ipsSeen = @($group.Group | Select-Object -ExpandProperty AttemptIp -Unique)

        Write-Host ("Scenario {0} -> Requests:{1} Devices:{2} Emails:{3} IPs:{4} Expected:{5}" -f $group.Name, $group.Count, $devicesSeen.Count, $emailsSeen.Count, $ipsSeen.Count, (Get-AbuseScenarioExpectedPattern -ScenarioName $group.Name))
    }

    if ($null -ne $SimulationResult.Exports) {
        Write-Section "ABUSE EXPORTS"
        Write-Host "StepsCsv:" $SimulationResult.Exports.StepsCsv
        Write-Host "ResultsCsv:" $SimulationResult.Exports.ResultsCsv
        Write-Host "DeviceSummaryCsv:" $SimulationResult.Exports.DeviceSummaryCsv
        Write-Host "EmailSummaryCsv:" $SimulationResult.Exports.EmailSummaryCsv
        Write-Host "ScenarioSummaryCsv:" $SimulationResult.Exports.ScenarioSummaryCsv
        Write-Host "ValidationTxt:" $SimulationResult.Exports.ValidationTxt
        Write-Host "JsonReport:" $SimulationResult.Exports.JsonReport
    }
}

# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------
$BaseUrl = Normalize-BaseUrl -s $BaseUrl

$script:CheckSupportContactFlow = $CheckSupportContactFlow
$script:ExpectedTicketCreatePath = $ExpectedTicketCreatePath
$script:SupportContactTextPattern = $SupportContactTextPattern
$script:SubmitSupportTicketTest = $SubmitSupportTicketTest
$script:SupportTicketGuestName = $SupportTicketGuestName
$script:SupportTicketGuestEmail = $SupportTicketGuestEmail
$script:SupportTicketSubjectPrefix = $SupportTicketSubjectPrefix
$script:SupportTicketMessage = $SupportTicketMessage
$script:SupportTicketSourceContext = $SupportTicketSourceContext
$script:DeviceHeaderName = $DeviceHeaderName
$script:DeviceHeaderValue = $DeviceHeaderValue
$script:DeviceCookieName = $DeviceCookieName
$script:SimulateClientIpEnabled = $SimulateClientIpEnabled
$script:ClientIpHeaderMode = $ClientIpHeaderMode
$script:IpRotationMode = $IpRotationMode
$script:ExportHtmlEnabled = $ExportHtmlEnabled
$script:ExportHtmlDir = $ExportHtmlDir
$script:SecPattern = $SecPattern
$script:SnippetRadiusChars = $SnippetRadiusChars
$script:WrongCredsPattern = $WrongCredsPattern
$script:LockoutPattern = $LockoutPattern
$script:FollowRedirectsEnabled = $FollowRedirectsEnabled
$script:MaxRedirects = $MaxRedirects
$script:AbuseAdminValidationEnabled = $AdminValidationEnabled
$script:AbuseAdminValidationExpectedSteps = Get-EnabledAbuseScenarioTotalSteps
$script:AbuseAdminValidationExpectedScenarioStepCounts = Get-EnabledAbuseScenarioStepCounts
$script:AbuseAdminValidationExpectedDeviceSummary = $null
$script:AbuseAdminValidationTopDevicesLimit = [int]$script:AbuseAdminValidationTopDevicesLimit
$script:AbuseAdminValidationTopEmailsLimit = [int]$script:AbuseAdminValidationTopEmailsLimit
$script:AbuseAdminValidationTopIpsLimit = [int]$script:AbuseAdminValidationTopIpsLimit
$script:AdminValidationEnabled = $AdminValidationEnabled
$script:AdminValidationLoginEmail = $AdminValidationLoginEmail
$script:AdminValidationLoginPassword = $AdminValidationLoginPassword
$script:AdminValidationEventsPath = $AdminValidationEventsPath
$script:AdminValidationMaxSamplesPerCheck = $AdminValidationMaxSamplesPerCheck
$script:AdminValidationDeviceCookieId = $AdminValidationDeviceCookieId

$localIps = Get-LocalClientIPs
$identityBanEmailResolved = ""
$effectivePinnedDeviceCookieId = ""
$effectiveAdminValidationDeviceCookieId = ""

try { $identityBanEmailResolved = ("" + $IdentityBanEmail).Trim() } catch { $identityBanEmailResolved = "" }
try { $effectivePinnedDeviceCookieId = ("" + $PinnedDeviceCookieId).Trim() } catch { $effectivePinnedDeviceCookieId = "" }
try { $effectiveAdminValidationDeviceCookieId = ("" + $AdminValidationDeviceCookieId).Trim() } catch { $effectiveAdminValidationDeviceCookieId = "" }

if ([string]::IsNullOrWhiteSpace($effectivePinnedDeviceCookieId) -and $CheckDeviceBan) {
    try { $effectivePinnedDeviceCookieId = ("" + $TestDeviceCookieId).Trim() } catch { $effectivePinnedDeviceCookieId = "" }
}

if ([string]::IsNullOrWhiteSpace($effectiveAdminValidationDeviceCookieId)) {
    $effectiveAdminValidationDeviceCookieId = "ks-admin-validation-device-001"
}

$script:PinnedDeviceCookieId = $effectivePinnedDeviceCookieId
$script:AdminValidationDeviceCookieId = $effectiveAdminValidationDeviceCookieId

if ($TestIpPool -and $TestIpPool.Count -gt 0) {
    $script:ClientIpPool = $TestIpPool
} else {
    $script:ClientIpPool = Build-DefaultTestIpPool
}

$script:PinnedIpBanTestIp           = $PinnedIpBanTestIp
$script:PinnedLockoutTestIp         = $PinnedLockoutTestIp
$script:AutoSelectFreeLockoutTestIp = $AutoSelectFreeLockoutTestIp

Sync-AuditModuleRuntimeVariables
$script:ResolvedLockoutTestIp       = Resolve-LockoutTestIp -BaseUrl $BaseUrl
Set-AuditModuleRuntimeVariable -Name 'ResolvedLockoutTestIp' -Value $script:ResolvedLockoutTestIp

Write-Section "CONFIG"
Write-Host "ConfigFilePath:" $ConfigFilePath
Write-Host "BaseUrl:" $BaseUrl
Write-Host "RegisteredEmail:" $RegisteredEmail
Write-Host "UnregisteredEmail:" $UnregisteredEmail
Write-Host "IdentityBanEmail:" $identityBanEmailResolved
Write-Host "LockoutAttempts:" $LockoutAttempts
Write-Host "Invoke-WebRequest UseBasicParsing supported:" $IwrSupportsUseBasicParsing
Write-Host "ExportHtmlEnabled:" $ExportHtmlEnabled
Write-Host "ExportHtmlDir:" $ExportHtmlDir
Write-Host "ExportRunDir:" (Join-Path $ExportHtmlDir $script:RunId)
Write-Host "FollowRedirectsEnabled:" $FollowRedirectsEnabled
Write-Host "MaxRedirects:" $MaxRedirects
Write-Host "CheckIpBan:" $CheckIpBan
Write-Host "CheckIdentityBan:" $CheckIdentityBan
Write-Host "CheckDeviceBan:" $CheckDeviceBan
Write-Host "DeviceCookieName:" $DeviceCookieName
Write-Host "TestDeviceCookieId:" $TestDeviceCookieId
Write-Host "PinnedDeviceCookieId:" $PinnedDeviceCookieId
Write-Host "EffectiveDeviceCookieId:" $effectivePinnedDeviceCookieId
Write-Host "CheckSupportContactFlow:" $CheckSupportContactFlow
Write-Host "SubmitSupportTicketTest:" $SubmitSupportTicketTest
Write-Host "ExpectedTicketCreatePath:" $ExpectedTicketCreatePath
Write-Host "SkipLockoutScenariosIfIpBanPass:" $SkipLockoutScenariosIfIpBanPass
Write-Host "PinnedIpBanTestIp:" $PinnedIpBanTestIp
Write-Host "PinnedLockoutTestIp:" $PinnedLockoutTestIp
Write-Host "AutoSelectFreeLockoutTestIp:" $AutoSelectFreeLockoutTestIp
Write-Host "ResolvedLockoutTestIp:" $script:ResolvedLockoutTestIp
Write-Host "LocalClientIPs:" ($localIps -join ", ")
Write-Host "SimulateClientIpEnabled:" $SimulateClientIpEnabled
Write-Host "ClientIpHeaderMode:" $ClientIpHeaderMode
Write-Host "IpRotationMode:" $IpRotationMode
Write-Host "TestIpPoolCount:" $script:ClientIpPool.Count
Write-Host "TestIpPoolPreview:" (($script:ClientIpPool | Select-Object -First 8) -join ", ")
Write-Host "BanOnlyMode:" (Test-IsBanOnlyMode)
Write-Host "CheckAbuseSimulation:" $CheckAbuseSimulation
Write-Host "AbuseSimulationAttemptsPerStep:" $AbuseSimulationAttemptsPerStep
Write-Host "AbuseSimulationSkipSupportFlow:" $AbuseSimulationSkipSupportFlow
Write-Host "AbuseScenarioDeviceReuseEnabled:" $AbuseScenarioDeviceReuseEnabled
Write-Host "AbuseScenarioAccountSharingEnabled:" $AbuseScenarioAccountSharingEnabled
Write-Host "AbuseScenarioBotPatternEnabled:" $AbuseScenarioBotPatternEnabled
Write-Host "AbuseScenarioDeviceClusterEnabled:" $AbuseScenarioDeviceClusterEnabled
Write-Host "AdminValidationEnabled:" $AdminValidationEnabled
Write-Host "AdminValidationLoginEmail:" $AdminValidationLoginEmail
Write-Host "AdminValidationEventsPath:" $AdminValidationEventsPath
Write-Host "AdminValidationMaxSamplesPerCheck:" $AdminValidationMaxSamplesPerCheck
Write-Host "AdminValidationDeviceCookieId:" $effectiveAdminValidationDeviceCookieId
Write-Host "AbuseAdminValidationExpectedSteps:" $script:AbuseAdminValidationExpectedSteps
Write-Host "AbuseAdminValidationTopDevicesLimit:" $script:AbuseAdminValidationTopDevicesLimit
Write-Host "AbuseAdminValidationTopEmailsLimit:" $script:AbuseAdminValidationTopEmailsLimit
Write-Host "AbuseAdminValidationTopIpsLimit:" $script:AbuseAdminValidationTopIpsLimit

$banResults = @()

if ($CheckIpBan) {
    $banResults += Run-BanCheck -BanName "ip" -Email $UnregisteredEmail -WrongPassword $WrongPassword -BanPattern $IpBanPattern
}

if ($CheckIdentityBan) {
    if ([string]::IsNullOrWhiteSpace($identityBanEmailResolved)) {
        Write-Section "BAN CHECK: identity"
        Write-Host "SKIP: Identity ban check enabled, but IdentityBanEmail is empty."

        $banResults += [PSCustomObject]@{
            BanName                  = "identity"
            BanResult                = "SKIP_NO_IDENTITY_BAN_EMAIL"
            PostStatus               = ""
            PostLocation             = ""
            FinalUrl                 = ""
            RedirectedToLogin        = $false
            BanTextFound             = $false
            SecFound                 = $false
            SecValue                 = ""
            TestIp                   = ""
            DeviceCookieName         = ""
            DeviceCookieId           = ""
            DeviceCookieHash         = ""
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
    } else {
        $banResults += Run-BanCheck -BanName "identity" -Email $identityBanEmailResolved -WrongPassword $WrongPassword -BanPattern $IdentityBanPattern
    }
}

if ($CheckDeviceBan) {
    $deviceHeaders = Get-DeviceHeaders
    $banResults += Run-BanCheck -BanName "device" -Email $RegisteredEmail -WrongPassword $WrongPassword -BanPattern $DeviceBanPattern -ExtraHeaders $deviceHeaders
}

$ipBanPass = $false
$lockoutHasSeparatePinnedIp = $false

try {
    foreach ($b in $banResults) {
        if ($null -ne $b -and ("" + $b.BanName) -eq "ip" -and ("" + $b.BanResult) -eq "PASS") {
            $ipBanPass = $true
            break
        }
    }
} catch { $ipBanPass = $false }

try {
    $lockoutHasSeparatePinnedIp = Test-LockoutHasSeparatePinnedIp
} catch { $lockoutHasSeparatePinnedIp = $false }

$res1 = $null
$res2 = $null
$abuseSimulationResult = $null
$abuseAdminValidationResult = $null
$sessionSecurityChecks = @()
$sessionSecurityExports = $null

if (Test-IsBanOnlyMode) {
    Write-Section "SCENARIOS"
    Write-Host "SKIP: ban_only_mode (nur aktivierte Ban-Prüfung wird bewertet)."

    $res1 = New-SkippedScenarioResult -ScenarioName "unregistered_email" -Email $UnregisteredEmail -SkipReason "SKIP_BAN_ONLY_MODE"
    $res2 = New-SkippedScenarioResult -ScenarioName "registered_email" -Email $RegisteredEmail -SkipReason "SKIP_BAN_ONLY_MODE"
} elseif ($ipBanPass -and $SkipLockoutScenariosIfIpBanPass -and (-not $lockoutHasSeparatePinnedIp)) {
    Write-Section "SCENARIO: unregistered_email"
    Write-Host "SKIP: ip_ban_pass_interference (run lockout test without active IP ban)."
    $res1 = New-SkippedScenarioResult -ScenarioName "unregistered_email" -Email $UnregisteredEmail -SkipReason "SKIP_IP_BAN_INTERFERENCE"

    Write-Section "SCENARIO: registered_email"
    Write-Host "SKIP: ip_ban_pass_interference (run lockout test without active IP ban)."
    $res2 = New-SkippedScenarioResult -ScenarioName "registered_email" -Email $RegisteredEmail -SkipReason "SKIP_IP_BAN_INTERFERENCE"
} else {
    $res1 = Run-Scenario -ScenarioName "unregistered_email" -Email $UnregisteredEmail -WrongPassword $WrongPassword -Attempts $LockoutAttempts
    $res2 = Run-Scenario -ScenarioName "registered_email" -Email $RegisteredEmail -WrongPassword $WrongPassword -Attempts $LockoutAttempts
}

if ($CheckAbuseSimulation) {
    $abuseSimulationResult = Invoke-AbuseSimulation -BaseUrl $BaseUrl -WrongPassword $WrongPassword
    if ($null -ne $abuseSimulationResult) {
        $abuseSimulationResult.Exports = Export-AbuseSimulationArtifacts -SimulationResult $abuseSimulationResult

        if ($AdminValidationEnabled) {
            $abuseAdminValidationResult = Invoke-AbuseAdminValidation -SimulationResult $abuseSimulationResult
        }
    }
}

$sessionSecurityChecks = @(Invoke-SessionSecurityChecks)
if (@($sessionSecurityChecks).Count -gt 0) {
    $sessionSecurityExports = Export-SessionSecurityCheckArtifacts -Checks $sessionSecurityChecks
}

Write-Section "RESULT SUMMARY"
Write-Host "UnregisteredEmail -> WrongCredsDetected:" $res1.WrongCredsDetected "LockoutDetected:" $res1.LockoutDetected "Seconds:" $res1.LockoutSeconds "SupportCodeDetected:" $res1.SupportCodeDetected "SupportCode:" $res1.SupportCodeValue "SupportFlow:" $res1.SupportFlowResult "SupportLinkFound:" $res1.SupportLinkFound "SupportTargetPathOk:" $res1.SupportTargetPathOk "SupportTargetCsrfPresent:" $res1.SupportTargetCsrfPresent "SupportCodeMatch:" $res1.SupportCodeMatch "TicketSubmitAttempted:" $res1.TicketSubmitAttempted "TicketSubmitResult:" $res1.TicketSubmitResult "TicketSubmitHttp:" $res1.TicketSubmitHttp "SkipReason:" $res1.SkipReason
Write-Host "RegisteredEmail   -> WrongCredsDetected:" $res2.WrongCredsDetected "LockoutDetected:" $res2.LockoutDetected "Seconds:" $res2.LockoutSeconds "SupportCodeDetected:" $res2.SupportCodeDetected "SupportCode:" $res2.SupportCodeValue "SupportFlow:" $res2.SupportFlowResult "SupportLinkFound:" $res2.SupportLinkFound "SupportTargetPathOk:" $res2.SupportTargetPathOk "SupportTargetCsrfPresent:" $res2.SupportTargetCsrfPresent "SupportCodeMatch:" $res2.SupportCodeMatch "TicketSubmitAttempted:" $res2.TicketSubmitAttempted "TicketSubmitResult:" $res2.TicketSubmitResult "TicketSubmitHttp:" $res2.TicketSubmitHttp "SkipReason:" $res2.SkipReason

if ($banResults.Count -gt 0) {
    Write-Section "BAN SUMMARY"
    foreach ($b in $banResults) {
        $tip = ""
        $deviceCookieNameOut = ""
        $deviceCookieIdOut = ""
        $deviceCookieHashOut = ""

        try { $tip = "" + $b.TestIp } catch { $tip = "" }
        try { $deviceCookieNameOut = "" + $b.DeviceCookieName } catch { $deviceCookieNameOut = "" }
        try { $deviceCookieIdOut = "" + $b.DeviceCookieId } catch { $deviceCookieIdOut = "" }
        try { $deviceCookieHashOut = "" + $b.DeviceCookieHash } catch { $deviceCookieHashOut = "" }

        Write-Host ("{0} -> {1} (TestIp:{2} DeviceCookieName:{3} DeviceCookieId:{4} DeviceCookieHash:{5} SEC:{6} SecValue:{7} BanText:{8} RedirectToLogin:{9} HTTP:{10} SupportFlow:{11} SupportLinkFound:{12} SupportTargetPathOk:{13} SupportTargetCsrfPresent:{14} SupportCodeMatch:{15} TicketSubmitAttempted:{16} TicketSubmitResult:{17} TicketSubmitHttp:{18})" -f $b.BanName, $b.BanResult, $tip, $deviceCookieNameOut, $deviceCookieIdOut, $deviceCookieHashOut, $b.SecFound, $b.SecValue, $b.BanTextFound, $b.RedirectedToLogin, $b.PostStatus, $b.SupportFlowResult, $b.SupportLinkFound, $b.SupportTargetPathOk, $b.SupportTargetCsrfPresent, $b.SupportCodeMatch, $b.TicketSubmitAttempted, $b.TicketSubmitResult, $b.TicketSubmitHttp)
    }
}

if ($CheckAbuseSimulation -and $null -ne $abuseSimulationResult) {
    Write-AbuseSimulationSummary -SimulationResult $abuseSimulationResult
}

if (@($sessionSecurityChecks).Count -gt 0) {
    Write-SessionSecurityChecksSummary -Checks $sessionSecurityChecks
}

if ($AdminValidationEnabled -and $null -ne $abuseAdminValidationResult) {
    Write-Section "ABUSE ADMIN VALIDATION EXPORTS"
    Write-Host "ChecksTxt:" $abuseAdminValidationResult.ChecksTxtPath
    Write-Host "ChecksJson:" $abuseAdminValidationResult.ChecksJsonPath
}

if ($null -ne $sessionSecurityExports) {
    Write-Section "SESSION SECURITY EXPORTS"
    Write-Host "ChecksTxt:" $sessionSecurityExports.TxtPath
    Write-Host "ChecksJson:" $sessionSecurityExports.JsonPath
    Write-Host "ChecksCsv:" $sessionSecurityExports.CsvPath
}
