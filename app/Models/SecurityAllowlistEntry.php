<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\SecurityAllowlistEntry.php
// Purpose: Eloquent model for security allowlist entries (autoban exclusions)
// Created: 09-03-2026 (Europe/Berlin)
// Changed: 09-03-2026 04:14 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class SecurityAllowlistEntry extends Model
{
    protected $fillable = [
        'type',
        'value',
        'description',
        'is_active',
        'autoban_only',
        'created_by',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'autoban_only' => 'boolean',
        'created_by' => 'integer',
    ];

    public function scopeType(Builder $query, string $type): Builder
    {
        return $query->where('type', $type);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }
}
