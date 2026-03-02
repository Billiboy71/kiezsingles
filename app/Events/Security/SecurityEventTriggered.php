<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\Security\SecurityEventTriggered.php
// Purpose: Internal event DTO for normalized security event logging
// Changed: 02-03-2026 01:43 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events\Security;

use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class SecurityEventTriggered
{
    use Dispatchable;
    use SerializesModels;

    /**
     * @param array<string, mixed> $meta
     */
    public function __construct(
        public readonly string $type,
        public readonly ?string $ip = null,
        public readonly ?int $userId = null,
        public readonly ?string $email = null,
        public readonly ?string $deviceHash = null,
        public readonly array $meta = [],
    ) {}
}
