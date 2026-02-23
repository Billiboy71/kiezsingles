<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\HandleTicketReportUserPermanentlyBanned.php
// Purpose: Handle TicketReportUserPermanentlyBanned event (audit log to DB).
// Changed: 12-02-2026 02:34 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Listeners;

use App\Events\TicketReportUserPermanentlyBanned;
use Illuminate\Support\Facades\DB;

class HandleTicketReportUserPermanentlyBanned
{
    public function handle(TicketReportUserPermanentlyBanned $event): void
    {
        DB::table('ticket_audit_logs')->insert([
            'ticket_id' => (int) $event->ticket->id,
            'event' => 'moderation_perm_banned',
            'actor_type' => 'admin',
            'actor_user_id' => (int) $event->actorUserId,
            'meta' => json_encode([
                'ticket_public_id' => (string) ($event->ticket->public_id ?? ''),
                'type' => (string) ($event->ticket->type ?? ''),
                'reported_user_id' => (int) $event->reportedUserId,
            ], JSON_UNESCAPED_UNICODE),
            'created_at' => now(),
        ]);
    }
}
