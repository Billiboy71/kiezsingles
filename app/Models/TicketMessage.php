<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\TicketMessage.php
// Purpose: Ticket message model (user/admin/system thread entries).
// Changed: 11-02-2026 23:41 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TicketMessage extends Model
{
    protected $fillable = [
        'ticket_id',
        'actor_type',
        'actor_user_id',
        'message',
        'is_internal',
    ];

    protected $casts = [
        'is_internal' => 'boolean',
    ];

    /*
    |--------------------------------------------------------------------------
    | Relationships
    |--------------------------------------------------------------------------
    */

    public function ticket(): BelongsTo
    {
        return $this->belongsTo(Ticket::class);
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_user_id');
    }
}
