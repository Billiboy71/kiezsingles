<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\Admin\WriteAdminAuditLog.php
// Purpose: Persist governance admin-audit events into admin_audit_logs
// Created: 28-02-2026 14:49 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Listeners\Admin;

use App\Events\Admin\AdminAuditEvent;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class WriteAdminAuditLog
{
    public function handle(AdminAuditEvent $event): void
    {
        if (!Schema::hasTable('admin_audit_logs')) {
            return;
        }

        DB::table('admin_audit_logs')->insert([
            'event' => mb_substr((string) $event->event, 0, 64),
            'result' => mb_substr((string) $event->result, 0, 16),
            'actor_user_id' => $event->actorUserId,
            'target_user_id' => $event->targetUserId,
            'ip' => $event->ip !== null ? mb_substr((string) $event->ip, 0, 45) : null,
            'user_agent' => $event->userAgent !== null ? mb_substr((string) $event->userAgent, 0, 255) : null,
            'meta' => $event->meta,
            'created_at' => now(),
        ]);
    }
}