<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\TicketCreated.php
// Purpose: Fired when a new ticket is created (support or report).
// Changed: 13-02-2026 00:27 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Events;

use App\Models\Ticket;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TicketCreated
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public Ticket $ticket,
        public string $actorType, // 'user' | 'admin'
        public int $actorUserId
    ) {}
}
