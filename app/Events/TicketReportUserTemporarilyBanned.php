<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\TicketReportUserTemporarilyBanned.php
// Purpose: Fired when a reported user is temporarily banned via a report ticket.
// Changed: 12-02-2026 02:06 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events;

use App\Models\Ticket;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TicketReportUserTemporarilyBanned
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public Ticket $ticket,
        public int $actorUserId,
        public int $reportedUserId,
        public int $days,
    ) {}
}

