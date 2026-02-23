<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Events\TicketCategoryChanged.php
// Purpose: Fired when a ticket category is changed by an admin.
// Changed: 12-02-2026 01:58 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Events;

use App\Models\Ticket;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TicketCategoryChanged
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public Ticket $ticket,
        public int $actorUserId,
        public ?string $oldCategory,
        public ?string $newCategory,
    ) {}
}
