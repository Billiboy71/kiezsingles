<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\TicketClosed.php
// Purpose: Fired when a ticket is closed.
// Changed: 13-02-2026 00:14 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Events;

use App\Models\Ticket;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TicketClosed
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public Ticket $ticket,
        public string $actorType, // 'admin'
        public int $actorUserId
    ) {}
}
