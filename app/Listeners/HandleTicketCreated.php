<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\HandleTicketCreated.php
// Purpose: Handle TicketCreated event (audit log to DB).
// Changed: 13-02-2026 00:33 (Europe/Berlin)
// Version: 0.3
// ============================================================================

namespace App\Listeners;

use App\Events\TicketCreated;
use Illuminate\Support\Facades\DB;

class HandleTicketCreated
{
    public function handle(TicketCreated $event): void
    {
        DB::table('ticket_audit_logs')->insert([
            'ticket_id' => (int) $event->ticket->id,
            'event' => 'created',
            'actor_type' => (string) $event->actorType,
            'actor_user_id' => (int) $event->actorUserId,
            'meta' => json_encode([
                'ticket_public_id' => (string) ($event->ticket->public_id ?? ''),
                'type' => (string) ($event->ticket->type ?? ''),
                'status' => (string) ($event->ticket->status ?? ''),
            ], JSON_UNESCAPED_UNICODE),
            'created_at' => now(),
        ]);
    }
}
