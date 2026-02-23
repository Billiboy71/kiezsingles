<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\HandleTicketReportMarkedUnfounded.php
// Purpose: Handle TicketReportMarkedUnfounded event (audit log to DB).
// Changed: 12-02-2026 02:36 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Listeners;

use App\Events\TicketReportMarkedUnfounded;
use Illuminate\Support\Facades\DB;

class HandleTicketReportMarkedUnfounded
{
    public function handle(TicketReportMarkedUnfounded $event): void
    {
        DB::table('ticket_audit_logs')->insert([
            'ticket_id' => (int) $event->ticket->id,
            'event' => 'moderation_unfounded',
            'actor_type' => 'admin',
            'actor_user_id' => (int) $event->actorUserId,
            'meta' => json_encode([
                'ticket_public_id' => (string) ($event->ticket->public_id ?? ''),
                'type' => (string) ($event->ticket->type ?? ''),
            ], JSON_UNESCAPED_UNICODE),
            'created_at' => now(),
        ]);
    }
}
