<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\HandleTicketStatusChanged.php
// Purpose: Handle TicketStatusChanged event (audit log to DB).
// Changed: 12-02-2026 02:28 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Listeners;

use App\Events\TicketStatusChanged;
use Illuminate\Support\Facades\DB;

class HandleTicketStatusChanged
{
    public function handle(TicketStatusChanged $event): void
    {
        DB::table('ticket_audit_logs')->insert([
            'ticket_id' => (int) $event->ticket->id,
            'event' => 'status_changed',
            'actor_type' => 'admin',
            'actor_user_id' => (int) $event->actorUserId,
            'meta' => json_encode([
                'ticket_public_id' => (string) ($event->ticket->public_id ?? ''),
                'type' => (string) ($event->ticket->type ?? ''),
                'old_status' => $event->oldStatus,
                'new_status' => $event->newStatus,
            ], JSON_UNESCAPED_UNICODE),
            'created_at' => now(),
        ]);
    }
}
