<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\TicketReportUserWarned.php
// Purpose: Fired when a reported user is warned via a report ticket.
// Changed: 12-02-2026 02:04 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events;

use App\Models\Ticket;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TicketReportUserWarned
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public Ticket $ticket,
        public int $actorUserId,
        public int $reportedUserId,
    ) {}
}
