<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\HandleTicketReplied.php
// Purpose: Handle TicketReplied event (audit log to DB).
// Changed: 12-02-2026 23:56 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Listeners;

use App\Events\TicketReplied;
use Illuminate\Support\Facades\DB;

class HandleTicketReplied
{
    public function handle(TicketReplied $event): void
    {
        DB::table('ticket_audit_logs')->insert([
            'ticket_id' => (int) $event->ticket->id,
            'event' => 'replied',
            'actor_type' => (string) $event->actorType,
            'actor_user_id' => (int) ($event->message->actor_user_id ?? 0),
            'meta' => json_encode([
                'ticket_public_id' => (string) ($event->ticket->public_id ?? ''),
                'status' => (string) ($event->ticket->status ?? ''),
                'message_id' => (int) ($event->message->id ?? 0),
                'is_internal' => (bool) ($event->message->is_internal ?? false),
            ], JSON_UNESCAPED_UNICODE),
            'created_at' => now(),
        ]);
    }
}
