<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\TicketReportMarkedUnfounded.php
// Purpose: Fired when a report ticket is marked as unfounded by an admin.
// Changed: 12-02-2026 02:10 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events;

use App\Models\Ticket;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TicketReportMarkedUnfounded
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public Ticket $ticket,
        public int $actorUserId,
    ) {}
}
