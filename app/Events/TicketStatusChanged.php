<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\TicketStatusChanged.php
// Purpose: Fired when a ticket status is changed by an admin.
// Changed: 12-02-2026 02:02 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events;

use App\Models\Ticket;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TicketStatusChanged
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public Ticket $ticket,
        public int $actorUserId,
        public string $oldStatus,
        public string $newStatus,
    ) {}
}
