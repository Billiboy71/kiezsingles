<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\Admin\AdminAuditEvent.php
// Purpose: Event payload for governance admin-audit logging
// Created: 28-02-2026 14:49 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events\Admin;

use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class AdminAuditEvent
{
    use Dispatchable;
    use SerializesModels;

    public function __construct(
        public readonly string $event,
        public readonly string $result,
        public readonly ?int $actorUserId,
        public readonly ?int $targetUserId,
        public readonly ?string $ip,
        public readonly ?string $userAgent,
        public readonly ?array $meta,
    ) {}
}