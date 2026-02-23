<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\HandleTicketAssignedAdmin.php
// Purpose: Handle TicketAssignedAdmin event (audit log to DB).
// Changed: 12-02-2026 02:23 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Listeners;

use App\Events\TicketAssignedAdmin;
use Illuminate\Support\Facades\DB;

class HandleTicketAssignedAdmin
{
    public function handle(TicketAssignedAdmin $event): void
    {
        DB::table('ticket_audit_logs')->insert([
            'ticket_id' => (int) $event->ticket->id,
            'event' => 'assigned_admin',
            'actor_type' => 'admin',
            'actor_user_id' => (int) $event->actorUserId,
            'meta' => json_encode([
                'ticket_public_id' => (string) ($event->ticket->public_id ?? ''),
                'type' => (string) ($event->ticket->type ?? ''),
                'status' => (string) ($event->ticket->status ?? ''),
                'old_assigned_admin_user_id' => $event->oldAssignedAdminUserId !== null ? (int) $event->oldAssignedAdminUserId : null,
                'new_assigned_admin_user_id' => $event->newAssignedAdminUserId !== null ? (int) $event->newAssignedAdminUserId : null,
            ], JSON_UNESCAPED_UNICODE),
            'created_at' => now(),
        ]);
    }
}
