# Run-Audit-SecurityDetails.ps1
# Zweck: Audit-CLI direkt starten (ohne GUI) und NUR für security_abuse + security_e2e
#        PerCheckDetails/PerCheckExport erzwingen, damit die Detail-Logs geschrieben werden.

$ErrorActionPreference = 'Stop'

$ProjectRoot  = 'C:\laragon\www\kiezsingles'
$AuditRoot    = Join-Path $ProjectRoot 'tools\audit'
$AuditCli     = Join-Path $AuditRoot  'ks-admin-audit.ps1'
$PathsConfig  = Join-Path $AuditRoot  'ks-admin-audit-paths.json'
$ExportFolder = Join-Path $AuditRoot  'output'

$BaseUrl      = 'http://kiezsingles.test'

# --- PerCheckDetails / PerCheckExport: alle Keys wie im Tool, nur security_abuse + security_e2e auf true
$perCheck = @{
  cache_clear                 = $false
  routes                      = $false
  route_list_option_scan      = $false
  http_probe                  = $false
  login_csrf_probe            = $false
  role_smoke_test             = $false
  governance_superadmin       = $false
  session_csrf_baseline       = $false
  security_abuse              = $true
  security_e2e                = $true
  routes_verbose              = $false
  routes_findstr_admin        = $false
  log_snapshot                = $false
  tail_log                    = $false
  log_clear_before            = $false
  log_clear_after             = $false
}

$PerCheckDetailsJson = ($perCheck | ConvertTo-Json -Compress)
$PerCheckExportJson  = ($perCheck | ConvertTo-Json -Compress)

# --- Security-Parameter
$SecurityLoginAttempts   = 8
$SecurityE2EAttempts     = 10
$SecurityE2EThreshold    = 3
$SecurityE2ESeconds      = 300
$SecurityE2ELogin        = 'audit-test@kiezsingles.local'
$SecurityE2EPassword     = '<DEIN_PASSWORT_HIER>'

$SecurityLockoutKeywords = @(
  'too many attempts','throttle','locked','lockout','zu viele','versuche'
)

# --- Start
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AuditCli `
  -BaseUrl $BaseUrl `
  -PathsConfigFile $PathsConfig `
  -ProbePaths '/admin','/admin/status','/admin/moderation','/admin/maintenance','/admin/debug','/admin/users','/admin/tickets','/admin/develop' `
  -SecurityProbe `
  -SecurityCheckIpBan `
  -SecurityCheckRegister `
  -SecurityExpect429 `
  -SecurityLoginAttempts $SecurityLoginAttempts `
  -SecurityLockoutKeywords $SecurityLockoutKeywords `
  -SecurityE2E `
  -SecurityE2ELockout `
  -SecurityE2EIpAutoban `
  -SecurityE2EDeviceAutoban `
  -SecurityE2EIdentityBan `
  -SecurityE2ESupportRef `
  -SecurityE2EEventsCheck `
  -SecurityE2EAttempts $SecurityE2EAttempts `
  -SecurityE2EThreshold $SecurityE2EThreshold `
  -SecurityE2ESeconds $SecurityE2ESeconds `
  -SecurityE2ELogin $SecurityE2ELogin `
  -SecurityE2EPassword $SecurityE2EPassword `
  -SecurityE2ECleanup $true `
  -SecurityE2EDryRun $false `
  -SecurityE2EEnvGate $true `
  -ShowCheckDetails $true `
  -ExportLogs $true `
  -ExportLogsLines 200 `
  -ExportFolder $ExportFolder `
  -AutoOpenExportFolder $true `
  -PerCheckDetails $PerCheckDetailsJson `
  -PerCheckExport $PerCheckExportJson

# Danach prüfen:
# Get-ChildItem $ExportFolder | sort LastWriteTime -desc | select -First 10 Name,LastWriteTime,Length