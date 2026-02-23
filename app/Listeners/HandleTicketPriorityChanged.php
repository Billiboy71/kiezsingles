<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\HandleTicketPriorityChanged.php
// Purpose: Handle TicketPriorityChanged event (audit log to DB).
// Changed: 12-02-2026 02:26 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Listeners;

use App\Events\TicketPriorityChanged;
use Illuminate\Support\Facades\DB;

class HandleTicketPriorityChanged
{
    public function handle(TicketPriorityChanged $event): void
    {
        DB::table('ticket_audit_logs')->insert([
            'ticket_id' => (int) $event->ticket->id,
            'event' => 'priority_changed',
            'actor_type' => 'admin',
            'actor_user_id' => (int) $event->actorUserId,
            'meta' => json_encode([
                'ticket_public_id' => (string) ($event->ticket->public_id ?? ''),
                'type' => (string) ($event->ticket->type ?? ''),
                'status' => (string) ($event->ticket->status ?? ''),
                'old_priority' => $event->oldPriority,
                'new_priority' => $event->newPriority,
            ], JSON_UNESCAPED_UNICODE),
            'created_at' => now(),
        ]);
    }
}
