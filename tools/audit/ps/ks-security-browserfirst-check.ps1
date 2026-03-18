# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\ks-security-browserfirst-check.ps1
# Purpose: Browser-first Security Login/Ban evidence check via PowerShell (no audit-tool)
# Created: 05-03-2026 01:19 (Europe/Berlin)
# Changed: 17-03-2026 23:44 (Europe/Berlin)
# Version: 7.4
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Global:Write-Section([string]$t){
    Write-Host ""
    Write-Host ("="*70)
    Write-Host $t
    Write-Host ("="*70)
}

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

function Get-AuditRunRequestHeaders {
    $headers = @{}
    $auditRunId = ""

    try { $auditRunId = ("" + $script:AuditRunId).Trim() } catch { $auditRunId = "" }

    if (-not [string]::IsNullOrWhiteSpace($auditRunId)) {
        $headers["X-Audit-Run-Id"] = $auditRunId
    }

    return $headers
}

function Merge-AuditRequestHeaders {
    param(
        [Parameter(Mandatory=$false)]$Headers = @{}
    )

    $resolvedHeaders = Convert-ToLocalHashtable -InputObject $Headers
    $auditHeaders = Get-AuditRunRequestHeaders

    foreach ($key in $auditHeaders.Keys) {
        $resolvedHeaders[$key] = $auditHeaders[$key]
    }

    return $resolvedHeaders
}

function Global:Get-DeviceHeaders {
    $headers = @{}

    try {
        if (-not [string]::IsNullOrWhiteSpace($script:DeviceHeaderName) -and -not [string]::IsNullOrWhiteSpace($script:DeviceHeaderValue)) {
            $headers[$script:DeviceHeaderName] = $script:DeviceHeaderValue
        }
    } catch {
    }

    return (Merge-AuditRequestHeaders -Headers $headers)
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
if (-not (Get-Variable -Name AdminValidationTestIp -Scope Script -ErrorAction SilentlyContinue)) { $script:AdminValidationTestIp = "198.51.100.210" }
if (-not (Get-Variable -Name ScenarioIpMap -Scope Script -ErrorAction SilentlyContinue)) { $script:ScenarioIpMap = @{} }
if (-not (Get-Variable -Name ScenarioDeviceMap -Scope Script -ErrorAction SilentlyContinue)) { $script:ScenarioDeviceMap = @{} }

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

if ($CheckAbuseSimulation -and $AbuseSimulationAttemptsPerStep -ne 1) {
    $AbuseSimulationAttemptsPerStep = 1
    $script:AbuseSimulationAttemptsPerStep = 1
}

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
$AdminValidationTestIp = $script:AdminValidationTestIp
$ScenarioIpMap = $script:ScenarioIpMap
$ScenarioDeviceMap = $script:ScenarioDeviceMap

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

function Convert-ToLocalHashtable {
    param(
        [Parameter(Mandatory=$false)]$InputObject
    )

    if ($null -eq $InputObject) {
        return @{}
    }

    if ($InputObject -is [hashtable]) {
        return $InputObject
    }

    $result = @{}

    try {
        if ($InputObject.PSObject -and $InputObject.PSObject.Properties) {
            foreach ($property in $InputObject.PSObject.Properties) {
                $name = ""
                try { $name = ("" + $property.Name).Trim() } catch { $name = "" }

                if ([string]::IsNullOrWhiteSpace($name)) {
                    continue
                }

                $result[$name] = $property.Value
            }
        }
    } catch {
    }

    return $result
}

function Get-ScenarioConfigValue {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName,
        [Parameter(Mandatory=$false)]$Map,
        [Parameter(Mandatory=$false)][string]$Fallback = ""
    )

    $resolvedMap = Convert-ToLocalHashtable -InputObject $Map
    $resolvedValue = ""

    if (-not [string]::IsNullOrWhiteSpace($ScenarioName) -and $resolvedMap.ContainsKey($ScenarioName)) {
        try { $resolvedValue = ("" + $resolvedMap[$ScenarioName]).Trim() } catch { $resolvedValue = "" }
    }

    if (-not [string]::IsNullOrWhiteSpace($resolvedValue)) {
        return $resolvedValue
    }

    return $Fallback
}

function Get-RequiredScenarioIsolationKeys {
    return @(
        "unregistered_email",
        "registered_email",
        "security_event_lockout",
        "ban_ip",
        "ban_identity",
        "ban_device"
    )
}

function Test-ScenarioIsolationDuplicateAllowed {
    param(
        [Parameter(Mandatory=$true)][string]$FirstKey,
        [Parameter(Mandatory=$true)][string]$SecondKey
    )

    $allowedKeys = @("ban_ip", "ban_identity", "ban_device")

    return (($allowedKeys -contains $FirstKey) -and ($allowedKeys -contains $SecondKey))
}

function Assert-ScenarioIsolationMap {
    param(
        [Parameter(Mandatory=$true)][string]$MapName,
        [Parameter(Mandatory=$false)]$Map
    )

    $resolvedMap = Convert-ToLocalHashtable -InputObject $Map
    $requiredKeys = @(Get-RequiredScenarioIsolationKeys)
    $seenValues = @{}

    foreach ($key in $requiredKeys) {
        $value = Get-ScenarioConfigValue -ScenarioName $key -Map $resolvedMap -Fallback ""
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Config validation failed: '$MapName.$key' is empty."
        }

        if ($seenValues.ContainsKey($value)) {
            $firstKey = ""
            try { $firstKey = ("" + $seenValues[$value]).Trim() } catch { $firstKey = "" }

            if (-not (Test-ScenarioIsolationDuplicateAllowed -FirstKey $firstKey -SecondKey $key)) {
                throw "Config validation failed: '$MapName' contains duplicate value '$value'."
            }
        }

        if (-not $seenValues.ContainsKey($value)) {
            $seenValues[$value] = $key
        }
    }
}

function Get-ScenarioIsolationIp {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName,
        [Parameter(Mandatory=$false)][string]$Fallback = ""
    )

    return (Get-ScenarioConfigValue -ScenarioName $ScenarioName -Map $script:ScenarioIpMap -Fallback $Fallback)
}

function Get-ScenarioIsolationDeviceId {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName,
        [Parameter(Mandatory=$false)][string]$Fallback = ""
    )

    return (Get-ScenarioConfigValue -ScenarioName $ScenarioName -Map $script:ScenarioDeviceMap -Fallback $Fallback)
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
        $counts["abuse_bot_pattern"] = 10
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

    Assert-ScenarioIsolationMap -MapName "ScenarioIpMap" -Map $ScenarioIpMap
    Assert-ScenarioIsolationMap -MapName "ScenarioDeviceMap" -Map $ScenarioDeviceMap
}

Validate-BrowserFirstConfig

# -----------------------------------------------------------------------------
# LARAVEL RESET
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "======================================================================"
Write-Host "LARAVEL RESET"
Write-Host "======================================================================"

try {
    Push-Location "C:\laragon\www\kiezsingles"

    Write-Host "Running: php artisan optimize:clear"
    php artisan optimize:clear

    Write-Host "Running: php artisan cache:clear"
    php artisan cache:clear

    Write-Host "Running: php artisan config:clear"
    php artisan config:clear

    Write-Host "Running: php artisan route:clear"
    php artisan route:clear

    Write-Host "RESET: DONE"
}
catch {
    Write-Host "RESET WARNING: Laravel reset failed"
}
finally {
    Pop-Location
}

Write-Host ""

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
$script:RunId = ("{0}-{1}" -f (Get-Date).ToString("ddMMyyyy-HHmmss"), ([System.Guid]::NewGuid().ToString("N").Substring(0, 8)))
$script:AuditRunId = $script:RunId
$script:AuditWindowStartSql = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
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

function Invoke-AccountEnumerationProtectionCheck {
    $checkName = "AccountEnumerationProtection"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $details = New-Object System.Collections.Generic.List[string]
    $evidence = New-Object System.Collections.Generic.List[string]
    $data = [ordered]@{}

    try {
        Write-Section "SESSION CHECK: AccountEnumerationProtection"

        $registeredAttempt = Invoke-SessionSecurityMeasuredLoginAttempt `
            -Email ("" + $script:RegisteredEmail) `
            -Password ("" + $script:WrongPassword) `
            -ForcedAttemptIp (Get-ScenarioIsolationIp -ScenarioName "registered_email" -Fallback (Get-SessionSecurityPrimaryTestIp)) `
            -DeviceCookieId (Get-ScenarioIsolationDeviceId -ScenarioName "registered_email" -Fallback "ks-audit-registered")

        $unregisteredAttempt = Invoke-SessionSecurityMeasuredLoginAttempt `
            -Email ("" + $script:UnregisteredEmail) `
            -Password ("" + $script:WrongPassword) `
            -ForcedAttemptIp (Get-ScenarioIsolationIp -ScenarioName "unregistered_email" -Fallback (Get-SessionSecurityPrimaryTestIp)) `
            -DeviceCookieId (Get-ScenarioIsolationDeviceId -ScenarioName "unregistered_email" -Fallback "ks-audit-unregistered")

        $sizeDelta = [Math]::Abs(([int]$registeredAttempt.ResponseSize) - ([int]$unregisteredAttempt.ResponseSize))
        $maxSize = [Math]::Max([int]$registeredAttempt.ResponseSize, [int]$unregisteredAttempt.ResponseSize)
        $sizeSimilar = ($sizeDelta -le 120)
        if (-not $sizeSimilar -and $maxSize -gt 0) {
            $sizeSimilar = (([double]$sizeDelta / [double]$maxSize) -le 0.15)
        }

        $timeDelta = [Math]::Abs(([int]$registeredAttempt.ResponseMs) - ([int]$unregisteredAttempt.ResponseMs))
        $timeSimilar = ($timeDelta -le 2500)

        $statusMatches = ((("" + $registeredAttempt.Status).Trim()) -eq (("" + $unregisteredAttempt.Status).Trim()))
        $messageMatches = ((("" + $registeredAttempt.ErrorText).Trim()) -eq (("" + $unregisteredAttempt.ErrorText).Trim()))

        $details.Add(("RegisteredEmail Status: {0}" -f $registeredAttempt.Status)) | Out-Null
        $details.Add(("UnregisteredEmail Status: {0}" -f $unregisteredAttempt.Status)) | Out-Null
        $details.Add(("RegisteredEmail ResponseSize: {0}" -f $registeredAttempt.ResponseSize)) | Out-Null
        $details.Add(("UnregisteredEmail ResponseSize: {0}" -f $unregisteredAttempt.ResponseSize)) | Out-Null
        $details.Add(("RegisteredEmail ResponseMs: {0}" -f $registeredAttempt.ResponseMs)) | Out-Null
        $details.Add(("UnregisteredEmail ResponseMs: {0}" -f $unregisteredAttempt.ResponseMs)) | Out-Null
        $details.Add(("RegisteredEmail AttemptIp: {0}" -f $registeredAttempt.AttemptIp)) | Out-Null
        $details.Add(("UnregisteredEmail AttemptIp: {0}" -f $unregisteredAttempt.AttemptIp)) | Out-Null
        $details.Add(("RegisteredEmail DeviceCookieId: {0}" -f $registeredAttempt.DeviceCookieId)) | Out-Null
        $details.Add(("UnregisteredEmail DeviceCookieId: {0}" -f $unregisteredAttempt.DeviceCookieId)) | Out-Null
        $details.Add(("StatusMatches: {0}" -f $statusMatches)) | Out-Null
        $details.Add(("MessageMatches: {0}" -f $messageMatches)) | Out-Null
        $details.Add(("SizeSimilar: {0}" -f $sizeSimilar)) | Out-Null
        $details.Add(("TimeSimilar: {0}" -f $timeSimilar)) | Out-Null

        if (-not [string]::IsNullOrWhiteSpace($registeredAttempt.ErrorText)) {
            $evidence.Add(("RegisteredEmail Message: {0}" -f $registeredAttempt.ErrorText)) | Out-Null
        }

        if (-not [string]::IsNullOrWhiteSpace($unregisteredAttempt.ErrorText)) {
            $evidence.Add(("UnregisteredEmail Message: {0}" -f $unregisteredAttempt.ErrorText)) | Out-Null
        }

        $data["RegisteredEmailStatus"] = $registeredAttempt.Status
        $data["UnregisteredEmailStatus"] = $unregisteredAttempt.Status
        $data["RegisteredEmailMessage"] = $registeredAttempt.ErrorText
        $data["UnregisteredEmailMessage"] = $unregisteredAttempt.ErrorText
        $data["RegisteredEmailResponseSize"] = [int]$registeredAttempt.ResponseSize
        $data["UnregisteredEmailResponseSize"] = [int]$unregisteredAttempt.ResponseSize
        $data["RegisteredEmailResponseMs"] = [int]$registeredAttempt.ResponseMs
        $data["UnregisteredEmailResponseMs"] = [int]$unregisteredAttempt.ResponseMs
        $data["RegisteredEmailAttemptIp"] = $registeredAttempt.AttemptIp
        $data["UnregisteredEmailAttemptIp"] = $unregisteredAttempt.AttemptIp
        $data["RegisteredEmailDeviceCookieId"] = $registeredAttempt.DeviceCookieId
        $data["UnregisteredEmailDeviceCookieId"] = $unregisteredAttempt.DeviceCookieId

        if ($statusMatches -and $messageMatches -and $sizeSimilar) {
            if ($timeSimilar) {
                Write-Host ("{0} -> PASS" -f $checkName)
                $sw.Stop()
                return (New-SessionSecurityCheckResult -CheckName $checkName -Result "PASS" -Summary "Registered and unregistered login failures looked equivalent." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
            }

            Write-Host ("{0} -> WARN" -f $checkName)
            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary "Responses matched, but response times differed noticeably." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        Write-Host ("{0} -> FAIL" -f $checkName)
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "FAIL" -Summary "Login responses exposed detectable differences between existing and non-existing accounts." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host ("{0} -> WARN ({1})" -f $checkName, $errorMessage)
        $details.Add(("CheckError: {0}" -f $errorMessage)) | Out-Null
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary ("Check error: {0}" -f $errorMessage) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    }
}

function Invoke-SecurityEventLoggingCheck {
    $checkName = "SecurityEventLogging"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $details = New-Object System.Collections.Generic.List[string]
    $evidence = New-Object System.Collections.Generic.List[string]
    $data = [ordered]@{}

    try {
        Write-Section "SESSION CHECK: SecurityEventLogging"

        $typeColumn = Get-SessionSecurityEventColumnName -Candidates @("type", "event_type")
        $ipColumn = Get-SessionSecurityEventColumnName -Candidates @("ip")
        $deviceHashColumn = Get-SessionSecurityEventColumnName -Candidates @("device_hash")
        $createdAtColumn = Get-SessionSecurityEventColumnName -Candidates @("created_at")

        if ([string]::IsNullOrWhiteSpace($typeColumn) -or [string]::IsNullOrWhiteSpace($ipColumn) -or [string]::IsNullOrWhiteSpace($deviceHashColumn) -or [string]::IsNullOrWhiteSpace($createdAtColumn)) {
            Write-Host ("{0} -> WARN (SECURITY_EVENTS_REQUIRED_COLUMNS_MISSING)" -f $checkName)
            $details.Add("Required columns missing in security_events.") | Out-Null
            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary "security_events schema is missing required columns." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        $windowStart = (Get-Date).AddMinutes(-15).ToString("yyyy-MM-dd HH:mm:ss")
        $failedIp = "198.51.100.221"
        $successIp = "198.51.100.222"
        $lockoutIp = Get-ScenarioIsolationIp -ScenarioName "security_event_lockout" -Fallback "198.51.100.223"
        $deviceIp = "198.51.100.224"
        $deviceCookieFailed = "ks-event-failed-001"
        $deviceCookieSuccess = "ks-event-success-001"
        $deviceCookieDevice = "ks-event-device-001"
        $deviceCookieLockout = Get-ScenarioIsolationDeviceId -ScenarioName "security_event_lockout" -Fallback "ks-audit-security-event"
        $failedDeviceHash = Get-Sha256Hex -Value $deviceCookieFailed
        $successDeviceHash = Get-Sha256Hex -Value $deviceCookieSuccess
        $deviceDetectionHash = Get-Sha256Hex -Value $deviceCookieDevice

        [void](Post-LoginAttempt -BaseUrl $script:BaseUrl -Session (New-Session) -Email ("" + $script:RegisteredEmail) -Password ("" + $script:WrongPassword) -ExtraHeaders (Get-DeviceHeaders) -DeviceCookieId $deviceCookieFailed -ForcedAttemptIp $failedIp)

        $loginSession = $null
        $originalDeviceCookieId = ""
        $originalAdminValidationTestIp = ""
        try { $originalDeviceCookieId = ("" + $script:AdminValidationDeviceCookieId).Trim() } catch { $originalDeviceCookieId = "" }
        try { $originalAdminValidationTestIp = ("" + $script:AdminValidationTestIp).Trim() } catch { $originalAdminValidationTestIp = "" }

        try {
            $script:AdminValidationDeviceCookieId = $deviceCookieSuccess
            $script:AdminValidationTestIp = $successIp
            try {
                if (Get-Command Set-AuditModuleRuntimeVariable -ErrorAction SilentlyContinue) {
                    Set-AuditModuleRuntimeVariable -Name 'AdminValidationDeviceCookieId' -Value $script:AdminValidationDeviceCookieId
                    Set-AuditModuleRuntimeVariable -Name 'AdminValidationTestIp' -Value $script:AdminValidationTestIp
                }
            } catch {
            }
            $loginSession = Get-AbuseAdminValidationLoginSession
        } finally {
            $script:AdminValidationDeviceCookieId = $originalDeviceCookieId
            $script:AdminValidationTestIp = $originalAdminValidationTestIp
            try {
                if (Get-Command Set-AuditModuleRuntimeVariable -ErrorAction SilentlyContinue) {
                    Set-AuditModuleRuntimeVariable -Name 'AdminValidationDeviceCookieId' -Value $script:AdminValidationDeviceCookieId
                    Set-AuditModuleRuntimeVariable -Name 'AdminValidationTestIp' -Value $script:AdminValidationTestIp
                }
            } catch {
            }
        }

        [void](Post-LoginAttempt -BaseUrl $script:BaseUrl -Session (New-Session) -Email ("" + $script:RegisteredEmail) -Password ("" + $script:WrongPassword) -ExtraHeaders (Get-DeviceHeaders) -DeviceCookieId $deviceCookieDevice -ForcedAttemptIp $deviceIp)
        $lockoutResult = Run-Scenario -ScenarioName "security_event_lockout" -Email ("" + $script:UnregisteredEmail) -WrongPassword ("" + $script:WrongPassword) -Attempts ([int]$script:LockoutAttempts) -DeviceCookieId $deviceCookieLockout -ForcedAttemptIp $lockoutIp -SkipSupportFlow $true

        $successLoginAvailable = ($null -ne $loginSession -and [bool]$loginSession.Success)
        $lockoutTriggered = $false
        try { $lockoutTriggered = [bool]$lockoutResult.LockoutDetected } catch { $lockoutTriggered = $false }

        $failedWhere = "{0} >= {1} AND {2} = 'login_failed' AND COALESCE({3},'') = {4} AND COALESCE({5},'') = {6} AND COALESCE({7},'') <> ''" -f $createdAtColumn, (Convert-SessionSecuritySqlValue -Value $windowStart), $typeColumn, $ipColumn, (Convert-SessionSecuritySqlValue -Value $failedIp), $deviceHashColumn, (Convert-SessionSecuritySqlValue -Value $failedDeviceHash), $createdAtColumn
        $successWhere = "{0} >= {1} AND {2} = 'login_success' AND COALESCE({3},'') = {4} AND COALESCE({5},'') = {6} AND COALESCE({7},'') <> ''" -f $createdAtColumn, (Convert-SessionSecuritySqlValue -Value $windowStart), $typeColumn, $ipColumn, (Convert-SessionSecuritySqlValue -Value $successIp), $deviceHashColumn, (Convert-SessionSecuritySqlValue -Value $successDeviceHash), $createdAtColumn
        $lockoutWhere = "{0} >= {1} AND {2} = 'login_lockout' AND COALESCE({3},'') = {4} AND COALESCE({5},'') <> '' AND COALESCE({6},'') <> ''" -f $createdAtColumn, (Convert-SessionSecuritySqlValue -Value $windowStart), $typeColumn, $ipColumn, (Convert-SessionSecuritySqlValue -Value $lockoutIp), $deviceHashColumn, $createdAtColumn
        $deviceWhere = "{0} >= {1} AND COALESCE({2},'') = {3} AND COALESCE({4},'') = {5} AND COALESCE({6},'') <> '' AND COALESCE({7},'') <> ''" -f $createdAtColumn, (Convert-SessionSecuritySqlValue -Value $windowStart), $deviceHashColumn, (Convert-SessionSecuritySqlValue -Value $deviceDetectionHash), $ipColumn, (Convert-SessionSecuritySqlValue -Value $deviceIp), $typeColumn, $createdAtColumn

        $failedCount = Get-SessionSecurityEventCount -WhereClause $failedWhere
        $successCount = $(if ($successLoginAvailable) { Get-SessionSecurityEventCount -WhereClause $successWhere } else { 0 })
        $lockoutCount = $(if ($lockoutTriggered) { Get-SessionSecurityEventCount -WhereClause $lockoutWhere } else { 0 })
        $deviceCount = Get-SessionSecurityEventCount -WhereClause $deviceWhere
        $recentEvents = @(Get-SessionSecurityRecentEvents)

        $details.Add("FailedLoginTriggered: True") | Out-Null
        $details.Add(("FailedLoginEvents: {0}" -f $failedCount)) | Out-Null
        $details.Add(("SuccessfulLoginTriggered: {0}" -f $successLoginAvailable)) | Out-Null
        $details.Add(("SuccessfulLoginEvents: {0}" -f $successCount)) | Out-Null
        $details.Add(("LockoutTriggered: {0}" -f $lockoutTriggered)) | Out-Null
        $details.Add(("LockoutEvents: {0}" -f $lockoutCount)) | Out-Null
        $details.Add(("LockoutScenarioIp: {0}" -f $lockoutIp)) | Out-Null
        $details.Add(("LockoutScenarioDeviceCookieId: {0}" -f $deviceCookieLockout)) | Out-Null
        $details.Add("DeviceDetectionTriggered: True") | Out-Null
        $details.Add(("DeviceDetectionEvents: {0}" -f $deviceCount)) | Out-Null

        foreach ($row in @($recentEvents)) {
            $evidence.Add(("RecentEvent: {0} | {1} | {2} | {3}" -f $row.EventType, $row.Ip, $row.DeviceHash, $row.CreatedAt)) | Out-Null
        }

        $data["FailedLoginEvents"] = $failedCount
        $data["SuccessfulLoginEvents"] = $successCount
        $data["LockoutEvents"] = $lockoutCount
        $data["DeviceDetectionEvents"] = $deviceCount
        $data["LockoutScenarioIp"] = $lockoutIp
        $data["LockoutScenarioDeviceCookieId"] = $deviceCookieLockout
        $data["RecentEvents"] = @($recentEvents)
        $data["WindowStart"] = $windowStart

        $missing = New-Object System.Collections.Generic.List[string]
        $triggerWarnings = New-Object System.Collections.Generic.List[string]
        if ($failedCount -le 0) { $missing.Add("failed_login") | Out-Null }
        if ($successLoginAvailable -and $successCount -le 0) { $missing.Add("successful_login") | Out-Null }
        if ($lockoutTriggered -and $lockoutCount -le 0) { $missing.Add("lockout_trigger") | Out-Null }
        if ($deviceCount -le 0) { $missing.Add("device_detection") | Out-Null }
        if (-not $successLoginAvailable) { $triggerWarnings.Add("successful_login_not_triggered") | Out-Null }
        if (-not $lockoutTriggered) { $triggerWarnings.Add("lockout_not_triggered") | Out-Null }

        if ($missing.Count -eq 0) {
            if ($triggerWarnings.Count -gt 0) {
                Write-Host ("{0} -> WARN" -f $checkName)
                $details.Add(("TriggerWarnings: {0}" -f (($triggerWarnings.ToArray()) -join ", "))) | Out-Null
                $sw.Stop()
                return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary ("Events found, but not all trigger actions completed: {0}" -f (($triggerWarnings.ToArray()) -join ", ")) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
            }

            Write-Host ("{0} -> PASS" -f $checkName)
            $sw.Stop()
            return (New-SessionSecurityCheckResult -CheckName $checkName -Result "PASS" -Summary "Triggered security actions were persisted in security_events." -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
        }

        Write-Host ("{0} -> FAIL" -f $checkName)
        $details.Add(("MissingEvents: {0}" -f (($missing.ToArray()) -join ", "))) | Out-Null
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "FAIL" -Summary ("Missing security events for: {0}" -f (($missing.ToArray()) -join ", ")) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host ("{0} -> WARN ({1})" -f $checkName, $errorMessage)
        $details.Add(("CheckError: {0}" -f $errorMessage)) | Out-Null
        $sw.Stop()
        return (New-SessionSecurityCheckResult -CheckName $checkName -Result "WARN" -Summary ("Check error: {0}" -f $errorMessage) -Details @($details.ToArray()) -Evidence @($evidence.ToArray()) -Data $data -DurationMs ([int]$sw.ElapsedMilliseconds))
    }
}

function Get-LoginAttemptResultLabel {
    param(
        [Parameter(Mandatory=$false)]$WrongCredsFound,
        [Parameter(Mandatory=$false)]$LockoutFound,
        [Parameter(Mandatory=$false)]$SecFound,
        [Parameter(Mandatory=$false)]$LockoutSeconds,
        [Parameter(Mandatory=$false)]$SecValue
    )

    $resolvedWrongCredsFound = $false
    $resolvedLockoutFound = $false
    $resolvedSecFound = $false
    $resolvedLockoutSeconds = ""
    $resolvedSecValue = ""
    $LoginResult = "UNKNOWN"

    try { $resolvedWrongCredsFound = [bool]$WrongCredsFound } catch { $resolvedWrongCredsFound = $false }
    try { $resolvedLockoutFound = [bool]$LockoutFound } catch { $resolvedLockoutFound = $false }
    try { $resolvedSecFound = [bool]$SecFound } catch { $resolvedSecFound = $false }
    try { $resolvedLockoutSeconds = Convert-ToScenarioString -Value $LockoutSeconds } catch { $resolvedLockoutSeconds = "" }
    try { $resolvedSecValue = Convert-ToScenarioString -Value $SecValue } catch { $resolvedSecValue = "" }

    if ($resolvedLockoutFound) {
        if (-not [string]::IsNullOrWhiteSpace($resolvedLockoutSeconds)) {
            $LoginResult = "LOCKOUT_ACTIVE ($resolvedLockoutSeconds s)"
        } else {
            $LoginResult = "LOCKOUT_ACTIVE"
        }
    }
    elseif ($resolvedSecFound) {
        if (-not [string]::IsNullOrWhiteSpace($resolvedSecValue)) {
            $LoginResult = "SECURITY_BLOCK ($resolvedSecValue)"
        } else {
            $LoginResult = "SECURITY_BLOCK"
        }
    }
    elseif ($resolvedWrongCredsFound) {
        $LoginResult = "WRONG_CREDENTIALS"
    }

    return $LoginResult
}

function Get-BanResultLabel {
    param(
        [Parameter(Mandatory=$false)]$BanTextFound,
        [Parameter(Mandatory=$false)]$SecFound,
        [Parameter(Mandatory=$false)]$SecValue,
        [Parameter(Mandatory=$false)]$RedirectToLogin,
        [Parameter(Mandatory=$false)]$SupportCodeOnTarget
    )

    $resolvedBanTextFound = $false
    $resolvedSecFound = $false
    $resolvedRedirectToLogin = $false
    $resolvedSecValue = ""
    $resolvedSupportCodeOnTarget = ""
    $BanResult = "BAN_NOT_TRIGGERED"

    try { $resolvedBanTextFound = [bool]$BanTextFound } catch { $resolvedBanTextFound = $false }
    try { $resolvedSecFound = [bool]$SecFound } catch { $resolvedSecFound = $false }
    try { $resolvedRedirectToLogin = [bool]$RedirectToLogin } catch { $resolvedRedirectToLogin = $false }
    try { $resolvedSecValue = Convert-ToScenarioString -Value $SecValue } catch { $resolvedSecValue = "" }
    try { $resolvedSupportCodeOnTarget = Convert-ToScenarioString -Value $SupportCodeOnTarget } catch { $resolvedSupportCodeOnTarget = "" }

    if ([string]::IsNullOrWhiteSpace($resolvedSecValue) -and (-not [string]::IsNullOrWhiteSpace($resolvedSupportCodeOnTarget))) {
        $resolvedSecValue = $resolvedSupportCodeOnTarget
    }

    if ($resolvedSecFound -and (-not [string]::IsNullOrWhiteSpace($resolvedSecValue))) {
        $BanResult = "BAN_BLOCKED_WITH_SEC ($resolvedSecValue)"
    }
    elseif ($resolvedBanTextFound) {
        $BanResult = "BAN_CONFIRMED"
    }
    elseif ($resolvedRedirectToLogin) {
        $BanResult = "BAN_REDIRECT_ONLY"
    }

    return $BanResult
}

function Get-SupportResultLabel {
    param(
        [Parameter(Mandatory=$false)]$SupportLinkFound,
        [Parameter(Mandatory=$false)]$SupportTargetPathOk,
        [Parameter(Mandatory=$false)]$SupportTargetCsrfPresent,
        [Parameter(Mandatory=$false)]$TicketSubmitResult
    )

    $resolvedSupportLinkFound = $false
    $resolvedSupportTargetPathOk = $false
    $resolvedSupportTargetCsrfPresent = $false
    $resolvedTicketSubmitResult = ""
    $SupportResult = "SUPPORT_FLOW_BROKEN"

    try { $resolvedSupportLinkFound = [bool]$SupportLinkFound } catch { $resolvedSupportLinkFound = $false }
    try { $resolvedSupportTargetPathOk = [bool]$SupportTargetPathOk } catch { $resolvedSupportTargetPathOk = $false }
    try { $resolvedSupportTargetCsrfPresent = [bool]$SupportTargetCsrfPresent } catch { $resolvedSupportTargetCsrfPresent = $false }
    try { $resolvedTicketSubmitResult = Convert-ToScenarioString -Value $TicketSubmitResult } catch { $resolvedTicketSubmitResult = "" }

    if ($resolvedSupportLinkFound -and $resolvedSupportTargetPathOk -and $resolvedSupportTargetCsrfPresent) {
        $SupportResult = "SUPPORT_LINK_OK"
    }

    if ($resolvedTicketSubmitResult -like "PASS*") {
        $SupportResult = "SUPPORT_SUBMIT_OK"
    }

    return $SupportResult
}

function Run-Scenario {
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioName,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string]$WrongPassword,
        [Parameter(Mandatory=$true)][int]$Attempts,
        [Parameter(Mandatory=$false)]$ExtraHeaders = @{},
        [Parameter(Mandatory=$false)]$DeviceCookieId = "",
        [Parameter(Mandatory=$false)]$ForcedAttemptIp = "",
        [Parameter(Mandatory=$false)]$SkipSupportFlow = $false
    )

    $resolvedHeaders = Merge-AuditRequestHeaders -Headers (Convert-ToScenarioHeaders -Value $ExtraHeaders)
    $requestedDeviceCookieId = Convert-ToScenarioString -Value $DeviceCookieId
    $requestedForcedAttemptIp = Convert-ToScenarioString -Value $ForcedAttemptIp
    $resolvedSkipSupportFlow = Convert-ToScenarioBool -Value $SkipSupportFlow -Default $false

    $supportFlow = New-DefaultSupportFlowResult
    $effectiveForcedAttemptIp = ""
    $effectiveDeviceCookieId = ""
    $lastAttemptIp = ""
    $lastDeviceCookieId = ""
    $forcedClientIpEntered = $false
    $finalLoginResult = "UNKNOWN"

    try {
        Write-Section ("SCENARIO: {0}" -f $ScenarioName)
        Write-Host "Email:" $Email
        Write-Host "Attempts:" $Attempts

        Reset-ClientIpRotation -Pool $script:ClientIpPool
        $session = New-Session

        $effectiveForcedAttemptIp = Get-ScenarioDefaultAttemptIp -RequestedAttemptIp $requestedForcedAttemptIp
        $effectiveDeviceCookieId = Get-ScenarioDefaultDeviceCookieId -RequestedDeviceCookieId $requestedDeviceCookieId

        if (-not [string]::IsNullOrWhiteSpace($requestedDeviceCookieId)) {
            Write-Host "RequestedDeviceCookieId:" $requestedDeviceCookieId
        }

        if (-not [string]::IsNullOrWhiteSpace($requestedForcedAttemptIp)) {
            Write-Host "RequestedForcedAttemptIp:" $requestedForcedAttemptIp
        }

        Write-Host "EffectiveDeviceCookieId:" $effectiveDeviceCookieId
        Write-Host "EffectiveAttemptIp:" $effectiveForcedAttemptIp

        if (-not [string]::IsNullOrWhiteSpace($effectiveForcedAttemptIp)) {
            Enter-ForcedClientIp $effectiveForcedAttemptIp
            $forcedClientIpEntered = $true
        }

        Begin-StepIp
        try {
            $hGet = Get-RequestHeaders -ExtraHeaders $resolvedHeaders -ForcedIp $effectiveForcedAttemptIp
            $r = Get-LoginPage $BaseUrl $session $hGet.Headers
        } finally {
            End-StepIp
        }

        $csrf = Extract-CsrfTokenFromHtml $r.Content

        Write-Host "GET /login Status:" $r.StatusCode `
                   "CSRF present:" (![string]::IsNullOrWhiteSpace($csrf)) `
                   "ClientIp:" $hGet.Ip

        $exportGet = Export-LoginHtml -label ("scenario_{0}_get_login" -f $ScenarioName) -html ("" + $r.Content)
        if ($exportGet -ne "") { Write-Host "Exported HTML:" $exportGet }

        $attempt1Result = Invoke-ScenarioLoginAttempt `
            -BaseUrl $BaseUrl `
            -Session $session `
            -Email $Email `
            -WrongPassword $WrongPassword `
            -ExtraHeaders $resolvedHeaders `
            -DeviceCookieId $effectiveDeviceCookieId `
            -ForcedAttemptIp $effectiveForcedAttemptIp

        $a1 = $attempt1Result.Attempt
        $an1 = $attempt1Result.Analysis
        $html1 = $attempt1Result.Html

        $lastAttemptIp = Convert-ToScenarioString -Value $a1.AttemptIp
        $lastDeviceCookieId = Convert-ToScenarioString -Value $a1.DeviceCookieId

        Write-Host "Attempt 1 Status:" $a1.PostStatus `
                   "Followed:" $a1.Followed `
                   "FinalUrl:" $a1.FinalUrl `
                   "ClientIp:" $a1.AttemptIp `
                   "DeviceCookieId:" $a1.DeviceCookieId

        Write-Host "Attempt 1 -> WrongCredsFound:" $an1.WrongCredsFound `
                   "LockoutFound:" $an1.LockoutFound `
                   "Seconds:" $an1.LockoutSeconds `
                   "SEC:" $an1.SecFound

        $LoginResult = "UNKNOWN"
        if ($an1.LockoutFound) {
            if ($an1.LockoutSeconds) {
                $LoginResult = "LOCKOUT_ACTIVE ($($an1.LockoutSeconds) s)"
            } else {
                $LoginResult = "LOCKOUT_ACTIVE"
            }
        }
        elseif ($an1.SecFound) {
            $LoginResult = "SECURITY_BLOCK ($($an1.SecValue))"
        }
        elseif ($an1.WrongCredsFound) {
            $LoginResult = "WRONG_CREDENTIALS"
        }

        Write-Host "Attempt 1 -> Result: $LoginResult"
        $finalLoginResult = $LoginResult

        $export1 = Export-LoginHtml -label ("scenario_{0}_attempt_1_final_html" -f $ScenarioName) -html $html1
        if ($export1 -ne "") { Write-Host "Exported HTML:" $export1 }

        $lockHit = $false
        $last = $an1
        $lastHtml = $html1
        $lastUrl = $a1.FinalUrl
        $exportLock = ""

        for ($i = 2; $i -le $Attempts; $i++) {

            $attemptResult = Invoke-ScenarioLoginAttempt `
                -BaseUrl $BaseUrl `
                -Session $session `
                -Email $Email `
                -WrongPassword $WrongPassword `
                -ExtraHeaders $resolvedHeaders `
                -DeviceCookieId $effectiveDeviceCookieId `
                -ForcedAttemptIp $effectiveForcedAttemptIp

            $a = $attemptResult.Attempt
            $an = $attemptResult.Analysis
            $html = $attemptResult.Html

            $last = $an
            $lastHtml = $html
            $lastUrl = $a.FinalUrl
            $lastAttemptIp = Convert-ToScenarioString -Value $a.AttemptIp
            $lastDeviceCookieId = Convert-ToScenarioString -Value $a.DeviceCookieId

            Write-Host ("Attempt {0} Status:" -f $i) $a.PostStatus `
                       "Followed:" $a.Followed `
                       "FinalUrl:" $a.FinalUrl `
                       "ClientIp:" $a.AttemptIp `
                       "DeviceCookieId:" $a.DeviceCookieId

            Write-Host ("Attempt {0} -> WrongCredsFound:" -f $i) $an.WrongCredsFound `
                       "LockoutFound:" $an.LockoutFound `
                       "Seconds:" $an.LockoutSeconds `
                       "SEC:" $an.SecFound

            $LoginResult = "UNKNOWN"
            if ($an.LockoutFound) {
                if ($an.LockoutSeconds) {
                    $LoginResult = "LOCKOUT_ACTIVE ($($an.LockoutSeconds) s)"
                } else {
                    $LoginResult = "LOCKOUT_ACTIVE"
                }
            }
            elseif ($an.SecFound) {
                $LoginResult = "SECURITY_BLOCK ($($an.SecValue))"
            }
            elseif ($an.WrongCredsFound) {
                $LoginResult = "WRONG_CREDENTIALS"
            }

            Write-Host ("Attempt {0} -> Result: {1}" -f $i, $LoginResult)
            $finalLoginResult = $LoginResult

            if ($a.PostStatus -eq 429 -or $an.LockoutFound) {

                $lockHit = $true

                $exportLock = Export-LoginHtml `
                    -label ("scenario_{0}_lockout_attempt_{1}_final_html" -f $ScenarioName, $i) `
                    -html $html

                break
            }
        }

        if ($lockHit) {

            Write-Host "Lockout detected"

            if ($last.LockoutFound) {
                Write-Host "Lockout seconds:" $last.LockoutSeconds
                Write-Host "Lockout snippet:"
                Write-Host $last.LockoutSnippet
            }

            if ($exportLock -ne "") { Write-Host "Exported HTML:" $exportLock }

        } else {

            Write-Host "Lockout NOT detected"

            $exportNo = Export-LoginHtml `
                -label ("scenario_{0}_lockout_not_detected_final_html_after_{1}_attempts" -f $ScenarioName, $Attempts) `
                -html $lastHtml

            if ($exportNo -ne "") { Write-Host "Exported HTML:" $exportNo }
        }

        if ((-not $resolvedSkipSupportFlow) -and $last.SecFound) {

            Write-Host "SupportRef:" $last.SecValue

            $supportFlow = Invoke-SupportContactFlowCheck `
                -FlowName ("scenario_{0}" -f $ScenarioName) `
                -BaseUrl $BaseUrl `
                -Session $session `
                -SourceUrl $lastUrl `
                -SourceHtml $lastHtml `
                -Headers $resolvedHeaders `
                -FallbackSupportCode $last.SecValue

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

            $SupportResult = "SUPPORT_FLOW_BROKEN"

            if ($supportFlow.SupportLinkFound -and $supportFlow.TargetPathOk -and $supportFlow.TargetCsrfPresent) {
                $SupportResult = "SUPPORT_LINK_OK"
            }

            if ($supportFlow.TicketSubmitResult -like "PASS*") {
                $SupportResult = "SUPPORT_SUBMIT_OK"
            }

            Write-Host "SupportResult: $SupportResult"
        }

        return [PSCustomObject]@{
            ScenarioName             = $ScenarioName
            Email                    = $Email
            DeviceCookieId           = $lastDeviceCookieId
            AttemptIp                = $lastAttemptIp
            WrongCredsDetected       = $an1.WrongCredsFound
            LockoutDetected          = $last.LockoutFound
            LockoutSeconds           = $last.LockoutSeconds
            SupportCodeDetected      = $last.SecFound
            SupportCodeValue         = $last.SecValue
            LoginResult              = $finalLoginResult
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
            TicketSupportCode        = $supportFlow.TicketSupportCode
            MailSupportCode          = $supportFlow.MailSupportCode
            MailResult               = $supportFlow.MailResult
            SecE2EResult             = $supportFlow.SecE2EResult
            SkipReason               = ""
        }
    } catch {
        $errorMessage = Convert-ToScenarioString -Value $_.Exception.Message

        Write-Host ("SCENARIO ERROR: {0}" -f $errorMessage)

        return (New-ScenarioDefaultResult `
            -ScenarioName $ScenarioName `
            -Email $Email `
            -DeviceCookieId $lastDeviceCookieId `
            -AttemptIp $lastAttemptIp `
            -SkipReason ("SCENARIO_ERROR: {0}" -f $errorMessage))
    } finally {
        if ($forcedClientIpEntered) {
            Exit-ForcedClientIp
        }
    }
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

        if (($check.CheckName -eq "SessionReuseProtection") -and ($check.Result -eq "PASS")) {
            Write-Host "SessionResult: SESSION_REUSE_OK"
        }

        if (($check.CheckName -eq "AccountEnumerationProtection") -and ($check.Result -eq "PASS")) {
            Write-Host "SessionResult: ENUM_PROTECTION_OK"
        }

        if (($check.CheckName -eq "SecurityEventLogging") -and ($check.Result -eq "PASS")) {
            Write-Host "SessionResult: SEC_EVENT_LOG_OK"
        }
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
        TicketSupportCode        = ""
        MailSupportCode          = ""
        MailResult               = "INFO_NOT_RUN"
        SecE2EResult             = "FAIL"
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

function Get-AbuseScopedDeviceId {
    param(
        [Parameter(Mandatory=$true)][string]$BaseDeviceId,
        [Parameter(Mandatory=$true)][string]$ScenarioName
    )

    $safeScenarioName = ("" + $ScenarioName).Trim()
    $safeRunId = ("" + $script:RunId).Trim()

    if ([string]::IsNullOrWhiteSpace($safeScenarioName) -or [string]::IsNullOrWhiteSpace($safeRunId)) {
        return $BaseDeviceId
    }

    return ("{0}-{1}-{2}" -f $BaseDeviceId, $safeScenarioName, $safeRunId)
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
        $deviceId = Get-AbuseScopedDeviceId -BaseDeviceId (Select-PoolValue -Pool $resolvedDevicePool -Index 0) -ScenarioName $scenarioName
        for ($i = 0; $i -lt 10; $i++) {
            [void]$steps.Add((New-AbuseStep `
                -ScenarioName $scenarioName `
                -StepNumber ($steps.Count + 1) `
                -Email (Select-PoolValue -Pool $resolvedEmailPool -Index $i) `
                -DeviceCookieId $deviceId `
                -AttemptIp (Select-PoolValue -Pool $resolvedIpPool -Index $i)))
        }
    }

    if ($AbuseScenarioAccountSharingEnabled) {
        $scenarioName = "abuse_account_sharing"
        for ($i = 0; $i -lt 5; $i++) {
            $deviceId = Get-AbuseScopedDeviceId -BaseDeviceId (Select-PoolValue -Pool $resolvedDevicePool -Index ($i + 1)) -ScenarioName $scenarioName
            [void]$steps.Add((New-AbuseStep `
                -ScenarioName $scenarioName `
                -StepNumber ($steps.Count + 1) `
                -Email (Select-PoolValue -Pool $resolvedEmailPool -Index 0) `
                -DeviceCookieId $deviceId `
                -AttemptIp (Select-PoolValue -Pool $resolvedIpPool -Index $i)))
        }
    }

    if ($AbuseScenarioBotPatternEnabled) {
        $scenarioName = "abuse_bot_pattern"
        $deviceId = Get-AbuseScopedDeviceId -BaseDeviceId (Select-PoolValue -Pool $resolvedDevicePool -Index 0) -ScenarioName $scenarioName
        for ($i = 0; $i -lt 10; $i++) {
            [void]$steps.Add((New-AbuseStep `
                -ScenarioName $scenarioName `
                -StepNumber ($steps.Count + 1) `
                -Email (Select-PoolValue -Pool $resolvedEmailPool -Index $i) `
                -DeviceCookieId $deviceId `
                -AttemptIp (Select-PoolValue -Pool $resolvedIpPool -Index $i)))
        }
    }

    if ($AbuseScenarioDeviceClusterEnabled) {
        $clusterDeviceStart = 5
        $clusterEmailIndices = @(0, 1, 2, 3)

        for ($cluster = 0; $cluster -lt 5; $cluster++) {
            $scenarioName = ("abuse_device_cluster_{0}" -f ($cluster + 1))
            $deviceId = Get-AbuseScopedDeviceId -BaseDeviceId (Select-PoolValue -Pool $resolvedDevicePool -Index ($clusterDeviceStart + $cluster)) -ScenarioName $scenarioName

            for ($offset = 0; $offset -lt 10; $offset++) {
                [void]$steps.Add((New-AbuseStep `
                    -ScenarioName $scenarioName `
                    -StepNumber ($steps.Count + 1) `
                    -Email (Select-PoolValue -Pool $resolvedEmailPool -Index $clusterEmailIndices[($offset % $clusterEmailIndices.Count)]) `
                    -DeviceCookieId $deviceId `
                    -AttemptIp (Select-PoolValue -Pool $resolvedIpPool -Index $offset)))
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
$effectiveAdminValidationTestIp = ""
$resolvedScenarioIpMap = Convert-ToLocalHashtable -InputObject $ScenarioIpMap
$resolvedScenarioDeviceMap = Convert-ToLocalHashtable -InputObject $ScenarioDeviceMap
$scenarioIpUnregisteredEmail = ""
$scenarioIpRegisteredEmail = ""
$scenarioIpSecurityEventLockout = ""
$scenarioIpBanIp = ""
$scenarioIpBanIdentity = ""
$scenarioIpBanDevice = ""
$scenarioDeviceUnregisteredEmail = ""
$scenarioDeviceRegisteredEmail = ""
$scenarioDeviceSecurityEventLockout = ""
$scenarioDeviceBanIp = ""
$scenarioDeviceBanIdentity = ""
$scenarioDeviceBanDevice = ""

try { $identityBanEmailResolved = ("" + $IdentityBanEmail).Trim() } catch { $identityBanEmailResolved = "" }
try { $effectivePinnedDeviceCookieId = ("" + $PinnedDeviceCookieId).Trim() } catch { $effectivePinnedDeviceCookieId = "" }
try { $effectiveAdminValidationDeviceCookieId = ("" + $AdminValidationDeviceCookieId).Trim() } catch { $effectiveAdminValidationDeviceCookieId = "" }
try { $effectiveAdminValidationTestIp = ("" + $AdminValidationTestIp).Trim() } catch { $effectiveAdminValidationTestIp = "" }

$scenarioIpUnregisteredEmail = Get-ScenarioConfigValue -ScenarioName "unregistered_email" -Map $resolvedScenarioIpMap -Fallback $PinnedLockoutTestIp
$scenarioIpRegisteredEmail = Get-ScenarioConfigValue -ScenarioName "registered_email" -Map $resolvedScenarioIpMap -Fallback ""
$scenarioIpSecurityEventLockout = Get-ScenarioConfigValue -ScenarioName "security_event_lockout" -Map $resolvedScenarioIpMap -Fallback ""
$scenarioIpBanIp = Get-ScenarioConfigValue -ScenarioName "ban_ip" -Map $resolvedScenarioIpMap -Fallback $PinnedIpBanTestIp
$scenarioIpBanIdentity = Get-ScenarioConfigValue -ScenarioName "ban_identity" -Map $resolvedScenarioIpMap -Fallback ""
$scenarioIpBanDevice = Get-ScenarioConfigValue -ScenarioName "ban_device" -Map $resolvedScenarioIpMap -Fallback ""

$scenarioDeviceUnregisteredEmail = Get-ScenarioConfigValue -ScenarioName "unregistered_email" -Map $resolvedScenarioDeviceMap -Fallback ""
$scenarioDeviceRegisteredEmail = Get-ScenarioConfigValue -ScenarioName "registered_email" -Map $resolvedScenarioDeviceMap -Fallback ""
$scenarioDeviceSecurityEventLockout = Get-ScenarioConfigValue -ScenarioName "security_event_lockout" -Map $resolvedScenarioDeviceMap -Fallback ""
$scenarioDeviceBanIp = Get-ScenarioConfigValue -ScenarioName "ban_ip" -Map $resolvedScenarioDeviceMap -Fallback ""
$scenarioDeviceBanIdentity = Get-ScenarioConfigValue -ScenarioName "ban_identity" -Map $resolvedScenarioDeviceMap -Fallback ""
$scenarioDeviceBanDevice = Get-ScenarioConfigValue -ScenarioName "ban_device" -Map $resolvedScenarioDeviceMap -Fallback $effectivePinnedDeviceCookieId

if ([string]::IsNullOrWhiteSpace($effectivePinnedDeviceCookieId) -and $CheckDeviceBan) {
    try { $effectivePinnedDeviceCookieId = ("" + $TestDeviceCookieId).Trim() } catch { $effectivePinnedDeviceCookieId = "" }
}

if ([string]::IsNullOrWhiteSpace($effectiveAdminValidationDeviceCookieId)) {
    $effectiveAdminValidationDeviceCookieId = "ks-admin-validation-device-001"
}

$effectivePinnedDeviceCookieId = Get-ScenarioConfigValue -ScenarioName "ban_device" -Map $resolvedScenarioDeviceMap -Fallback $effectivePinnedDeviceCookieId

if ([string]::IsNullOrWhiteSpace($effectiveAdminValidationTestIp)) {
    $effectiveAdminValidationTestIp = "198.51.100.210"
}

$script:PinnedDeviceCookieId = $effectivePinnedDeviceCookieId
$script:AdminValidationDeviceCookieId = $effectiveAdminValidationDeviceCookieId
$script:AdminValidationTestIp = $effectiveAdminValidationTestIp
$script:ScenarioIpMap = $resolvedScenarioIpMap
$script:ScenarioDeviceMap = $resolvedScenarioDeviceMap

if ($TestIpPool -and $TestIpPool.Count -gt 0) {
    $script:ClientIpPool = $TestIpPool
} else {
    $script:ClientIpPool = Build-DefaultTestIpPool
}

$script:PinnedIpBanTestIp           = $scenarioIpBanIp
$script:PinnedLockoutTestIp         = $scenarioIpUnregisteredEmail
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
Write-Host "AdminValidationTestIp:" $effectiveAdminValidationTestIp
Write-Host "ScenarioIpMapKeys:" (($resolvedScenarioIpMap.Keys | Sort-Object) -join ", ")
Write-Host "ScenarioDeviceMapKeys:" (($resolvedScenarioDeviceMap.Keys | Sort-Object) -join ", ")
Write-Host "ScenarioIp[unregistered_email]:" $scenarioIpUnregisteredEmail
Write-Host "ScenarioIp[registered_email]:" $scenarioIpRegisteredEmail
Write-Host "ScenarioIp[security_event_lockout]:" $scenarioIpSecurityEventLockout
Write-Host "ScenarioIp[ban_ip]:" $scenarioIpBanIp
Write-Host "ScenarioIp[ban_identity]:" $scenarioIpBanIdentity
Write-Host "ScenarioIp[ban_device]:" $scenarioIpBanDevice
Write-Host "ScenarioDevice[unregistered_email]:" $scenarioDeviceUnregisteredEmail
Write-Host "ScenarioDevice[registered_email]:" $scenarioDeviceRegisteredEmail
Write-Host "ScenarioDevice[security_event_lockout]:" $scenarioDeviceSecurityEventLockout
Write-Host "ScenarioDevice[ban_ip]:" $scenarioDeviceBanIp
Write-Host "ScenarioDevice[ban_identity]:" $scenarioDeviceBanIdentity
Write-Host "ScenarioDevice[ban_device]:" $scenarioDeviceBanDevice
Write-Host "AbuseAdminValidationExpectedSteps:" $script:AbuseAdminValidationExpectedSteps
Write-Host "AbuseAdminValidationTopDevicesLimit:" $script:AbuseAdminValidationTopDevicesLimit
Write-Host "AbuseAdminValidationTopEmailsLimit:" $script:AbuseAdminValidationTopEmailsLimit
Write-Host "AbuseAdminValidationTopIpsLimit:" $script:AbuseAdminValidationTopIpsLimit

$banResults = @()

if ($CheckIpBan) {
    $banResults += Run-BanCheck -BanName "ip" -Email $UnregisteredEmail -WrongPassword $WrongPassword -BanPattern $IpBanPattern -ExtraHeaders (Get-AuditRunRequestHeaders) -DeviceCookieId $scenarioDeviceBanIp -ForcedAttemptIp $scenarioIpBanIp
    $lastBanResult = $banResults[-1]
    Write-Host "BanResult:" (Get-BanResultLabel -BanTextFound $lastBanResult.BanTextFound -SecFound $lastBanResult.SecFound -SecValue $lastBanResult.SecValue -RedirectToLogin $lastBanResult.RedirectedToLogin -SupportCodeOnTarget $lastBanResult.SupportCodeOnTarget)
    Write-Host "SupportResult:" (Get-SupportResultLabel -SupportLinkFound $lastBanResult.SupportLinkFound -SupportTargetPathOk $lastBanResult.SupportTargetPathOk -SupportTargetCsrfPresent $lastBanResult.SupportTargetCsrfPresent -TicketSubmitResult $lastBanResult.TicketSubmitResult)
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
        $banResults += Run-BanCheck -BanName "identity" -Email $identityBanEmailResolved -WrongPassword $WrongPassword -BanPattern $IdentityBanPattern -ExtraHeaders (Get-AuditRunRequestHeaders) -DeviceCookieId $scenarioDeviceBanIdentity -ForcedAttemptIp $scenarioIpBanIdentity
        $lastBanResult = $banResults[-1]
        Write-Host "BanResult:" (Get-BanResultLabel -BanTextFound $lastBanResult.BanTextFound -SecFound $lastBanResult.SecFound -SecValue $lastBanResult.SecValue -RedirectToLogin $lastBanResult.RedirectedToLogin -SupportCodeOnTarget $lastBanResult.SupportCodeOnTarget)
        Write-Host "SupportResult:" (Get-SupportResultLabel -SupportLinkFound $lastBanResult.SupportLinkFound -SupportTargetPathOk $lastBanResult.SupportTargetPathOk -SupportTargetCsrfPresent $lastBanResult.SupportTargetCsrfPresent -TicketSubmitResult $lastBanResult.TicketSubmitResult)
    }
}

if ($CheckDeviceBan) {
    $deviceHeaders = Merge-AuditRequestHeaders -Headers (Get-DeviceHeaders)
    $banResults += Run-BanCheck -BanName "device" -Email $RegisteredEmail -WrongPassword $WrongPassword -BanPattern $DeviceBanPattern -ExtraHeaders $deviceHeaders -DeviceCookieId $scenarioDeviceBanDevice -ForcedAttemptIp $scenarioIpBanDevice
    $lastBanResult = $banResults[-1]
    Write-Host "BanResult:" (Get-BanResultLabel -BanTextFound $lastBanResult.BanTextFound -SecFound $lastBanResult.SecFound -SecValue $lastBanResult.SecValue -RedirectToLogin $lastBanResult.RedirectedToLogin -SupportCodeOnTarget $lastBanResult.SupportCodeOnTarget)
    Write-Host "SupportResult:" (Get-SupportResultLabel -SupportLinkFound $lastBanResult.SupportLinkFound -SupportTargetPathOk $lastBanResult.SupportTargetPathOk -SupportTargetCsrfPresent $lastBanResult.SupportTargetCsrfPresent -TicketSubmitResult $lastBanResult.TicketSubmitResult)
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
    $res1 = Run-Scenario -ScenarioName "unregistered_email" -Email $UnregisteredEmail -WrongPassword $WrongPassword -Attempts $LockoutAttempts -DeviceCookieId $scenarioDeviceUnregisteredEmail -ForcedAttemptIp $scenarioIpUnregisteredEmail
    $res2 = Run-Scenario -ScenarioName "registered_email" -Email $RegisteredEmail -WrongPassword $WrongPassword -Attempts $LockoutAttempts -DeviceCookieId $scenarioDeviceRegisteredEmail -ForcedAttemptIp $scenarioIpRegisteredEmail
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
Write-Host "UnregisteredEmail -> WrongCredsDetected:" $res1.WrongCredsDetected "LockoutDetected:" $res1.LockoutDetected "Seconds:" $res1.LockoutSeconds "SupportCodeDetected:" $res1.SupportCodeDetected "SupportCode:" $res1.SupportCodeValue "Result:" (Get-LoginAttemptResultLabel -WrongCredsFound $res1.WrongCredsDetected -LockoutFound $res1.LockoutDetected -SecFound $res1.SupportCodeDetected -LockoutSeconds $res1.LockoutSeconds -SecValue $res1.SupportCodeValue) "SupportFlow:" $res1.SupportFlowResult "SupportLinkFound:" $res1.SupportLinkFound "SupportTargetPathOk:" $res1.SupportTargetPathOk "SupportTargetCsrfPresent:" $res1.SupportTargetCsrfPresent "SupportCodeMatch:" $res1.SupportCodeMatch "TicketSubmitAttempted:" $res1.TicketSubmitAttempted "TicketSubmitResult:" $res1.TicketSubmitResult "TicketSubmitHttp:" $res1.TicketSubmitHttp "SkipReason:" $res1.SkipReason
Write-Host "ResultSummary:" (Get-LoginAttemptResultLabel -WrongCredsFound $res1.WrongCredsDetected -LockoutFound $res1.LockoutDetected -SecFound $res1.SupportCodeDetected -LockoutSeconds $res1.LockoutSeconds -SecValue $res1.SupportCodeValue)
Write-Host "SupportResult:" (Get-SupportResultLabel -SupportLinkFound $res1.SupportLinkFound -SupportTargetPathOk $res1.SupportTargetPathOk -SupportTargetCsrfPresent $res1.SupportTargetCsrfPresent -TicketSubmitResult $res1.TicketSubmitResult)
Write-Host "SEC_E2E ->" $res1.SecE2EResult
Write-Host "Login:" $res1.SupportCodeValue
Write-Host "Ticket:" $res1.TicketSupportCode
Write-Host "Mail:" $(if ([string]::IsNullOrWhiteSpace($res1.MailSupportCode)) { $res1.MailResult } else { $res1.MailSupportCode })
Write-Host "RegisteredEmail   -> WrongCredsDetected:" $res2.WrongCredsDetected "LockoutDetected:" $res2.LockoutDetected "Seconds:" $res2.LockoutSeconds "SupportCodeDetected:" $res2.SupportCodeDetected "SupportCode:" $res2.SupportCodeValue "Result:" (Get-LoginAttemptResultLabel -WrongCredsFound $res2.WrongCredsDetected -LockoutFound $res2.LockoutDetected -SecFound $res2.SupportCodeDetected -LockoutSeconds $res2.LockoutSeconds -SecValue $res2.SupportCodeValue) "SupportFlow:" $res2.SupportFlowResult "SupportLinkFound:" $res2.SupportLinkFound "SupportTargetPathOk:" $res2.SupportTargetPathOk "SupportTargetCsrfPresent:" $res2.SupportTargetCsrfPresent "SupportCodeMatch:" $res2.SupportCodeMatch "TicketSubmitAttempted:" $res2.TicketSubmitAttempted "TicketSubmitResult:" $res2.TicketSubmitResult "TicketSubmitHttp:" $res2.TicketSubmitHttp "SkipReason:" $res2.SkipReason
Write-Host "ResultSummary:" (Get-LoginAttemptResultLabel -WrongCredsFound $res2.WrongCredsDetected -LockoutFound $res2.LockoutDetected -SecFound $res2.SupportCodeDetected -LockoutSeconds $res2.LockoutSeconds -SecValue $res2.SupportCodeValue)
Write-Host "SupportResult:" (Get-SupportResultLabel -SupportLinkFound $res2.SupportLinkFound -SupportTargetPathOk $res2.SupportTargetPathOk -SupportTargetCsrfPresent $res2.SupportTargetCsrfPresent -TicketSubmitResult $res2.TicketSubmitResult)
Write-Host "SEC_E2E ->" $res2.SecE2EResult
Write-Host "Login:" $res2.SupportCodeValue
Write-Host "Ticket:" $res2.TicketSupportCode
Write-Host "Mail:" $(if ([string]::IsNullOrWhiteSpace($res2.MailSupportCode)) { $res2.MailResult } else { $res2.MailSupportCode })

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
        Write-Host "BanSummaryResult:" (Get-BanResultLabel -BanTextFound $b.BanTextFound -SecFound $b.SecFound -SecValue $b.SecValue -RedirectToLogin $b.RedirectedToLogin -SupportCodeOnTarget $b.SupportCodeOnTarget)
        Write-Host "SupportResult:" (Get-SupportResultLabel -SupportLinkFound $b.SupportLinkFound -SupportTargetPathOk $b.SupportTargetPathOk -SupportTargetCsrfPresent $b.SupportTargetCsrfPresent -TicketSubmitResult $b.TicketSubmitResult)
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
