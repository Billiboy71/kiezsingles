<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\SecurityIdentityBan.php
// Purpose: Eloquent model for email/identity bans
// Changed: 02-03-2026 01:43 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class SecurityIdentityBan extends Model
{
    protected $fillable = [
        'email',
        'reason',
        'banned_until',
        'created_by',
    ];

    protected $casts = [
        'banned_until' => 'datetime',
        'created_by' => 'integer',
    ];

    public function scopeActive(Builder $query): Builder
    {
        return $query->where(function (Builder $sub): void {
            $sub->whereNull('banned_until')
                ->orWhere('banned_until', '>', now());
        });
    }
}
