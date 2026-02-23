<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\Ticket.php
// Purpose: Unified ticket model (report + support).
// Changed: 12-02-2026 00:41 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Ticket extends Model
{
    protected $fillable = [
        'public_id',
        'type',
        'status',
        'category',
        'priority',
        'subject',
        'message',
        'created_by_user_id',
        'reported_user_id',
        'assigned_admin_user_id',
        'closed_at',
    ];

    protected $casts = [
        'priority' => 'integer',
        'closed_at' => 'datetime',
    ];

    /*
    |--------------------------------------------------------------------------
    | Relationships
    |--------------------------------------------------------------------------
    */

    public function messages(): HasMany
    {
        return $this->hasMany(TicketMessage::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by_user_id');
    }

    public function reportedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reported_user_id');
    }

    public function assignedAdmin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_admin_user_id');
    }
}
