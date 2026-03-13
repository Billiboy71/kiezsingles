# =============================================================================
# File: C:\laragon\www\kiezsingles\tools\audit\ps\ks-security-browserfirst-check.config.ps1
# Purpose: Central config for browser-first Security Login/Ban/Abuse audit checks
# Created: 08-03-2026 00:12 (Europe/Berlin)
# Changed: 11-03-2026 00:10 (Europe/Berlin)
# Version: 1.6
# =============================================================================

# -----------------------------------------------------------------------------
# BASE
# -----------------------------------------------------------------------------
$script:BaseUrl               = "http://kiezsingles.test"
$script:RegisteredEmail       = "admin@web.de"
$script:UnregisteredEmail     = "audit-test1@kiezsingles.local"
$script:IdentityBanEmail      = "banned-mail@web.de"
$script:WrongPassword         = "falschespasswort"
$script:LockoutAttempts       = 7

# -----------------------------------------------------------------------------
# MODE
# -----------------------------------------------------------------------------
# Reiner Abuse-/Korrelations-Testlauf
$script:CheckIpBan            = $false
$script:CheckIdentityBan      = $false
$script:CheckDeviceBan        = $false

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
$script:PinnedIpBanTestIp               = ""
$script:PinnedLockoutTestIp             = ""
$script:AutoSelectFreeLockoutTestIp     = $true

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
$script:CheckSupportContactFlow    = $false
$script:ExpectedTicketCreatePath   = "/support/security"
$script:SupportContactTextPattern  = '(?is)\bsupport\s+kontaktieren\b'

$script:SubmitSupportTicketTest    = $false
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
$script:IpRotationMode          = "per_step"

# -----------------------------------------------------------------------------
# ABUSE SCENARIOS
# -----------------------------------------------------------------------------
$script:AbuseScenarioDeviceReuseEnabled    = $true
$script:AbuseScenarioAccountSharingEnabled = $true
$script:AbuseScenarioBotPatternEnabled     = $true
$script:AbuseScenarioDeviceClusterEnabled  = $true

# automatische Pools (Rotation)
$script:AbuseFixedDevicePool = @()
$script:AbuseFixedEmailPool  = @()
$script:AbuseFixedIpPool     = @()

$script:AbuseDevicePoolPrefix = "ks-sim-device-audit-"
$script:AbuseEmailPoolPrefix  = "audit-abuse-"
$script:AbuseEmailDomain      = "kiezsingles.local"

$script:AbuseDevicePoolCount = 12
$script:AbuseEmailPoolCount  = 40
$script:AbuseIpPoolCount     = 50

# -----------------------------------------------------------------------------
# ABUSE ADMIN VALIDATION
# -----------------------------------------------------------------------------
$script:AbuseAdminValidationEnabled          = $true
$script:AbuseAdminValidationExpectedSteps    = 115
$script:AbuseAdminValidationTopDevicesLimit  = 10
$script:AbuseAdminValidationTopEmailsLimit   = 10
$script:AbuseAdminValidationTopIpsLimit      = 10

# -----------------------------------------------------------------------------
# ADMIN LOGIN FOR VALIDATION (ISOLATED ACCOUNT)
# -----------------------------------------------------------------------------
$script:AdminValidationEnabled               = $true
$script:AdminValidationLoginEmail            = "testadmin@web.de"
$script:AdminValidationLoginPassword         = 'HundKatzeMaus123$'
$script:AdminValidationEventsPath            = "/admin/security/events"
$script:AdminValidationMaxSamplesPerCheck    = 5
$script:AdminValidationDeviceCookieId        = "ks-admin-validation-device-001"
$script:AdminValidationTestIp                = "198.51.100.210"
$script:AdminValidationClientIpHeaderMode    = "standard"

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