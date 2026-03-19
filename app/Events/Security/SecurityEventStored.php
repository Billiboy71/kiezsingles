<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\Security\SecurityEventStored.php
// Purpose: Internal event emitted after a security event was persisted.
// Created: 18-03-2026 12:18 (Europe/Berlin)
// Changed: 18-03-2026 12:18 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events\Security;

use App\Models\SecurityEvent;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class SecurityEventStored
{
    use Dispatchable;
    use SerializesModels;

    public function __construct(
        public readonly SecurityEvent $securityEvent,
    ) {}
}
