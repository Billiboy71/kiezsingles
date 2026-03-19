# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\ks-security-browserfirst-check.config.ps1
# Purpose: Central config for browser-first Security Login/Ban/Abuse audit checks
# Created: 08-03-2026 00:12 (Europe/Berlin)
# Changed: 19-03-2026 20:38 (Europe/Berlin)
# Version: 2.3
# =============================================================================

$script:BanTestData = @{
    Ip     = "192.168.200.13"
    Email  = "audit_banned@web.de"
    Device = "5a8c7a71ef98416cb7b28a38b242bce10774242820aaf99b0d7308d4d52dc8f4"
}

# -----------------------------------------------------------------------------
# BASE
# -----------------------------------------------------------------------------
$script:BaseUrl               = "http://kiezsingles.test"
$script:RegisteredEmail       = "audit_admin@web.de"
$script:UnregisteredEmail     = "audit-test1@kiezsingles.local"
$script:IdentityBanEmail      = $script:BanTestData.Email
$script:WrongPassword         = "falschespasswort"
$script:LockoutAttempts       = 7

# -----------------------------------------------------------------------------
# MODE
# -----------------------------------------------------------------------------
# Ban / Lockout Testlauf
$script:CheckIpBan            = $true
$script:CheckIdentityBan      = $true
$script:CheckDeviceBan        = $true
$script:AggregationEnabled    = $true
$script:AggregationHeaderValue = if ($script:AggregationEnabled) { "1" } else { "0" }
$script:GlobalAuditHeaders    = @{
    "X-Audit-Aggregation" = $script:AggregationHeaderValue
}

# ✅ ABUSE TEST AKTIVIERT
$script:CheckAbuseSimulation           = $true
$script:AbuseSimulationAttemptsPerStep = 6
$script:AbuseSimulationSkipSupportFlow = $true

# -----------------------------------------------------------------------------
# DEVICE COOKIE
# -----------------------------------------------------------------------------
# Rotation über Gerätepool
$script:DeviceCookieName      = "ks_device_id"
$script:TestDeviceCookieId    = ""
$script:PinnedDeviceCookieId  = ""

# -----------------------------------------------------------------------------
# LOCKOUT / BAN TEST IP HANDLING
# -----------------------------------------------------------------------------
$script:SkipLockoutScenariosIfIpBanPass = $true
$script:PinnedIpBanTestIp               = $script:BanTestData.Ip
$script:PinnedLockoutTestIp             = ""
$script:AutoSelectFreeLockoutTestIp     = $true

# zentrale Szenario-Isolation (stabile RateLimiter-Keys)
$script:ScenarioIpMap = @{
    unregistered_email     = "198.51.100.10"
    registered_email       = "198.51.100.11"
    security_event_lockout = "198.51.100.12"
    ban_ip                 = "198.51.100.13"
    ban_identity           = "198.51.100.14"
    ban_device             = "198.51.100.15"
}

$script:ScenarioDeviceMap = @{
    unregistered_email     = "ks-audit-unregistered"
    registered_email       = "ks-audit-registered"
    security_event_lockout = "ks-audit-security-event"
    ban_ip                 = "ks-audit-ban-ip"
    ban_identity           = "ks-audit-ban-identity"
    ban_device             = "ks-audit-ban-device"
}

$script:ScenarioIpMap["ban_ip"]       = $script:BanTestData.Ip
$script:ScenarioIpMap["ban_identity"] = $script:BanTestData.Ip
$script:ScenarioIpMap["ban_device"]   = $script:BanTestData.Ip

$script:ScenarioDeviceMap["ban_device"]   = $script:BanTestData.Device
$script:ScenarioDeviceMap["ban_identity"] = $script:BanTestData.Device
$script:ScenarioDeviceMap["ban_ip"]       = $script:BanTestData.Device

# -----------------------------------------------------------------------------
# UI EVIDENCE PATTERNS
# -----------------------------------------------------------------------------
$script:IpBanPattern          = '(?is)(anmeldung\s+aktuell\s+nicht\s+m(ö|oe)glich|zugriff\s+ist\s+aktuell\s+eingeschr(ä|ae)nkt|der\s+zugriff\s+ist\s+aktuell\s+eingeschr(ä|ae)nkt|access\s+is\s+currently\s+restricted)'
$script:IdentityBanPattern    = '(?is)(anmeldung\s+(aktuell|derzeit)\s+nicht\s+m(ö|oe)glich|login\s+currently\s+not\s+possible|sign\s+in\s+is\s+currently\s+not\s+possible)'
$script:DeviceBanPattern      = '(?is)(ger(ä|ae)t\s+ist\s+gesperrt|device\s+is\s+blocked|device\s+blocked)'

# -----------------------------------------------------------------------------
# OPTIONAL DEVICE HEADER
# -----------------------------------------------------------------------------
$script:DeviceHeaderName      = ""
$script:DeviceHeaderValue     = ""

# -----------------------------------------------------------------------------
# SUPPORT FLOW
# -----------------------------------------------------------------------------
$script:CheckSupportContactFlow    = $true
$script:ExpectedTicketCreatePath   = "/support/security"
$script:SupportContactTextPattern  = '(?is)\bsupport\s+kontaktieren\b'

$script:SubmitSupportTicketTest    = $true
$script:SupportTicketGuestName     = "PS Supportcode Test"
$script:SupportTicketGuestEmail    = "audit-supportcode@kiezsingles.local"
$script:SupportTicketSubjectPrefix = "[PS Supportcode Test]"
$script:SupportTicketMessage       = "Automatischer Supportcode-Test aus ks-security-browserfirst-check.ps1"
$script:SupportTicketSourceContext = "security_browserfirst_check_ps"

# -----------------------------------------------------------------------------
# CLIENT IP SIMULATION
# -----------------------------------------------------------------------------
# vollständige IP-Rotation über RFC-Testnetze
$script:SimulateClientIpEnabled = $true
$script:ClientIpHeaderMode      = "standard"
$script:TestIpPool              = @()
$script:IpRotationMode          = "fixed_per_scenario"

# -----------------------------------------------------------------------------
# ABUSE SCENARIOS
# -----------------------------------------------------------------------------
$script:AbuseScenarioDeviceReuseEnabled    = $true
$script:AbuseScenarioAccountSharingEnabled = $true
$script:AbuseScenarioBotPatternEnabled     = $true
$script:AbuseScenarioDeviceClusterEnabled  = $true

# automatische Pools (Rotation)
$script:AbuseFixedDevicePool = @()
$script:AbuseFixedEmailPool  = @(
    "audit-abuse-001@kiezsingles.local",
    "audit-abuse-002@kiezsingles.local",
    "audit-abuse-003@kiezsingles.local",
    "audit-abuse-004@kiezsingles.local",
    "audit-abuse-005@kiezsingles.local",
    "audit-abuse-006@kiezsingles.local",
    "audit-abuse-007@kiezsingles.local",
    "audit-abuse-008@kiezsingles.local",
    "audit-abuse-009@kiezsingles.local",
    "audit-abuse-010@kiezsingles.local"
)
$script:AbuseFixedIpPool     = @(
    "203.0.113.10",
    "203.0.113.11",
    "203.0.113.12",
    "203.0.113.13",
    "203.0.113.14",
    "203.0.113.15",
    "203.0.113.16",
    "203.0.113.17",
    "203.0.113.18",
    "203.0.113.19"
)

$script:AbuseDevicePoolPrefix = "ks-sim-device-audit-"
$script:AbuseEmailPoolPrefix  = "audit-abuse-"
$script:AbuseEmailDomain      = "kiezsingles.local"

$script:AbuseDevicePoolCount = 12
$script:AbuseEmailPoolCount  = 10
$script:AbuseIpPoolCount     = 10

# -----------------------------------------------------------------------------
# ABUSE ADMIN VALIDATION
# -----------------------------------------------------------------------------
$script:AbuseAdminValidationEnabled          = $false
$script:AbuseAdminValidationExpectedSteps    = 115
$script:AbuseAdminValidationTopDevicesLimit  = 10
$script:AbuseAdminValidationTopEmailsLimit   = 10
$script:AbuseAdminValidationTopIpsLimit      = 10

# -----------------------------------------------------------------------------
# ADMIN LOGIN FOR VALIDATION (ISOLATED ACCOUNT)
# -----------------------------------------------------------------------------
$script:AdminValidationEnabled               = $true
$script:AdminValidationLoginEmail            = "audit_superadmin@web.de"
$script:AdminValidationLoginPassword         = 'HundKatzeMaus123$'
$script:AdminValidationEventsPath            = "/admin/security/events"
$script:AdminValidationMaxSamplesPerCheck    = 5
$script:AdminValidationDeviceCookieId        = "ks-admin-validation-device-001"
$script:AdminValidationTestIp                = "198.51.100.210"
$script:AdminValidationClientIpHeaderMode    = "standard"

# -----------------------------------------------------------------------------
# SESSION REUSE TEST LOGIN
# -----------------------------------------------------------------------------
$script:SessionTestLoginEmail    = "audit_session@web.de"
$script:SessionTestLoginPassword = "HundKatzeMaus123$"

# -----------------------------------------------------------------------------
# EXPORT / EVIDENCE
# -----------------------------------------------------------------------------
$script:ExportHtmlEnabled      = $true
$script:ExportHtmlDir          = (Join-Path $PSScriptRoot "output")

$script:SecPattern             = 'SEC-[A-Z0-9]{6,8}'
$script:SnippetRadiusChars     = 80
$script:WrongCredsPattern      = '(?is)(zugangsdaten\s+sind\s+ung(ü|ue)ltig|passwort\s+ist\s+falsch|benutzername\/e-?mail\s+oder\s+passwort\s+ist\s+falsch|these\s+credentials\s+do\s+not\s+match|invalid\s+credentials|ung(ü|ue)ltig)'
$script:LockoutPattern         = '(?is)(zu viele|zu\s+viele|too many|throttle|lockout|locked|versuche).{0,220}?(\d{1,5})\s*(sek|sekunden|second|seconds|min|minute|minuten)\b'

$script:FollowRedirectsEnabled = $true
$script:MaxRedirects           = 5

if (-not (Get-Variable -Name Config -Scope Script -ErrorAction SilentlyContinue)) {
    $script:Config = @{}
}

$script:Config["CredentialStuffing"] = @{
    Enabled              = $true
    UsePersistentSession = $true
    FixedDeviceId        = "ks-audit-cs-device"
    EmailCount           = 15
    IpCount              = 5
    ReuseLoginPage       = $true
}
