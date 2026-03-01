<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\Admin\WriteAdminAuditLog.php
// Purpose: Persist governance admin-audit events into admin_audit_logs
// Created: 28-02-2026 14:49 (Europe/Berlin)
// Changed: 01-03-2026 00:50 (Europe/Berlin)
// Version: 0.2
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

        $meta = $event->meta;
        if (is_array($meta) || is_object($meta)) {
            $encodedMeta = json_encode($meta, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            $meta = $encodedMeta !== false ? $encodedMeta : null;
        } elseif ($meta !== null && !is_string($meta)) {
            $meta = is_scalar($meta) ? (string) $meta : null;
        }

        DB::table('admin_audit_logs')->insert([
            'event' => mb_substr((string) $event->event, 0, 64),
            'result' => mb_substr((string) $event->result, 0, 16),
            'actor_user_id' => $event->actorUserId,
            'target_user_id' => $event->targetUserId,
            'ip' => $event->ip !== null ? mb_substr((string) $event->ip, 0, 45) : null,
            'user_agent' => $event->userAgent !== null ? mb_substr((string) $event->userAgent, 0, 255) : null,
            'meta' => $meta,
            'created_at' => now(),
        ]);
    }
}
