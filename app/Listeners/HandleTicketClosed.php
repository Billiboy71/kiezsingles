<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\HandleTicketClosed.php
// Purpose: Handle TicketClosed event (audit log to DB).
// Changed: 13-02-2026 00:22 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Listeners;

use App\Events\TicketClosed;
use Illuminate\Support\Facades\DB;

class HandleTicketClosed
{
    public function handle(TicketClosed $event): void
    {
        DB::table('ticket_audit_logs')->insert([
            'ticket_id' => (int) $event->ticket->id,
            'event' => 'closed',
            'actor_type' => (string) $event->actorType,
            'actor_user_id' => (int) $event->actorUserId,
            'meta' => json_encode([
                'ticket_public_id' => (string) ($event->ticket->public_id ?? ''),
                'status' => (string) ($event->ticket->status ?? ''),
                'closed_at' => (string) ($event->ticket->closed_at ?? ''),
            ], JSON_UNESCAPED_UNICODE),
            'created_at' => now(),
        ]);
    }
}
