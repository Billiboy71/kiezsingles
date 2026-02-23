<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\HandleTicketCategoryChanged.php
// Purpose: Handle TicketCategoryChanged event (audit log to DB).
// Changed: 12-02-2026 02:25 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Listeners;

use App\Events\TicketCategoryChanged;
use Illuminate\Support\Facades\DB;

class HandleTicketCategoryChanged
{
    public function handle(TicketCategoryChanged $event): void
    {
        DB::table('ticket_audit_logs')->insert([
            'ticket_id' => (int) $event->ticket->id,
            'event' => 'category_changed',
            'actor_type' => 'admin',
            'actor_user_id' => (int) $event->actorUserId,
            'meta' => json_encode([
                'ticket_public_id' => (string) ($event->ticket->public_id ?? ''),
                'type' => (string) ($event->ticket->type ?? ''),
                'status' => (string) ($event->ticket->status ?? ''),
                'old_category' => $event->oldCategory,
                'new_category' => $event->newCategory,
            ], JSON_UNESCAPED_UNICODE),
            'created_at' => now(),
        ]);
    }
}
