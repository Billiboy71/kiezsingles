<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\TicketAssignedAdmin.php
// Purpose: Fired when a ticket is assigned to an admin.
// Changed: 12-02-2026 02:18 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events;

use App\Models\Ticket;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TicketAssignedAdmin
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public Ticket $ticket,
        public int $actorUserId,
        public ?int $oldAssignedAdminUserId,
        public ?int $newAssignedAdminUserId,
    ) {}
}
