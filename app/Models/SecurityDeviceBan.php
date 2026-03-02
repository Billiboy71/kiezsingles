<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\SecurityDeviceBan.php
// Purpose: Eloquent model for device bans
// Created: 02-03-2026 (Europe/Berlin)
// Changed: 02-03-2026 14:00 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class SecurityDeviceBan extends Model
{
    protected $fillable = [
        'device_hash',
        'reason',
        'banned_until',
        'revoked_at',
        'is_active',
        'created_by',
    ];

    protected $casts = [
        'banned_until' => 'datetime',
        'revoked_at' => 'datetime',
        'is_active' => 'boolean',
        'created_by' => 'integer',
    ];

    public function scopeActive(Builder $query): Builder
    {
        return $query
            ->where('is_active', true)
            ->whereNull('revoked_at')
            ->where(function (Builder $sub): void {
                $sub->whereNull('banned_until')
                    ->orWhere('banned_until', '>', now());
            });
    }
}
