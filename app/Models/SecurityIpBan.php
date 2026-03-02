<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\SecurityIpBan.php
// Purpose: Eloquent model for IP bans
// Changed: 02-03-2026 01:43 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class SecurityIpBan extends Model
{
    protected $fillable = [
        'ip',
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
