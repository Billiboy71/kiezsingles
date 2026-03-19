<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Enums\SecurityIncidentType.php
// Purpose: Fixed incident types for passive security incident detection.
// Created: 18-03-2026 12:18 (Europe/Berlin)
// Changed: 18-03-2026 12:18 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Enums;

enum SecurityIncidentType: string
{
    case CredentialStuffing = 'credential_stuffing';
    case AccountSharing = 'account_sharing';
    case BotPattern = 'bot_pattern';
    case DeviceCluster = 'device_cluster';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(
            static fn (self $type): string => $type->value,
            self::cases()
        );
    }
}
