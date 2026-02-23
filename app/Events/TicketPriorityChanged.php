<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\TicketPriorityChanged.php
// Purpose: Fired when a ticket priority is changed by an admin.
// Changed: 12-02-2026 01:59 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events;

use App\Models\Ticket;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TicketPriorityChanged
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public Ticket $ticket,
        public int $actorUserId,
        public ?string $oldPriority,
        public ?string $newPriority,
    ) {}
}
