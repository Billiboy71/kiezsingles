<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Support\SecurityIncidentType.php
// Purpose: Central mapping for security incident type labels (SSOT)
// Created: 23-03-2026 21:25 (Europe/Berlin)
// Changed: 23-03-2026 21:25 (Europe/Berlin)
// Version: 1.0
// ============================================================================

namespace App\Support;

class SecurityIncidentType
{
    public static function label(string $type): string
    {
        return self::map()[$type] ?? $type;
    }

    public static function map(): array
    {
        return [
            'device_cluster' => 'Geräte-Cluster',
            'bot_pattern' => 'Bot-Muster',
            'credential_stuffing' => 'Credential Stuffing',
            'account_sharing' => 'Account-Sharing',
        ];
    }
}
