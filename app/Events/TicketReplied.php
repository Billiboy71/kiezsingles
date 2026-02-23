<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\TicketReplied.php
// Purpose: Fired when a ticket receives a new reply.
// Changed: 12-02-2026 23:44 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events;

use App\Models\Ticket;
use App\Models\TicketMessage;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TicketReplied
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public Ticket $ticket,
        public TicketMessage $message,
        public string $actorType // 'user' | 'admin'
    ) {}
}
