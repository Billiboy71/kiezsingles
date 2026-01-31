<?php
// ============================================================================
// File: config/security.php
// Purpose: Zentrale Leseschicht für Security-Features (Input: .env)
// Notes: .env = Input, diese Datei = Defaults + Auswertung
// ============================================================================

$enabled = (bool) env('SECURITY_ENABLED', true);

$logRegistrationIp = (bool) env('SECURITY_LOG_REGISTRATION_IP', false);
$logLoginIp        = (bool) env('SECURITY_LOG_LOGIN_IP', false);

$retentionDays = (int) env('SECURITY_IP_RETENTION_DAYS', 14);

/**
 * Retention ist Pflicht, sobald IP-Logging aktiv ist.
 */
$ipLoggingActive = $logRegistrationIp || $logLoginIp;

if ($ipLoggingActive && $retentionDays <= 0) {
    throw new RuntimeException(
        'SECURITY_IP_RETENTION_DAYS must be > 0 when IP logging is enabled.'
    );
}

return [
    'enabled' => $enabled,

    'ip_logging' => [
        'registration'   => $enabled ? $logRegistrationIp : false,
        'login'          => $enabled ? $logLoginIp : false,
        'retention_days' => $enabled ? $retentionDays : 0,
    ],
];
