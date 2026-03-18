<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\SecurityEvent.php
// Purpose: Eloquent model for persisted security incidents.
// Changed: 17-03-2026 23:44 (Europe/Berlin)
// Version: 0.3
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SecurityEvent extends Model
{
    protected $fillable = [
        'reference',
        'run_id',
        'type',
        'ip',
        'user_id',
        'email',
        'device_hash',
        'meta',
        'reasons',
    ];

    protected $casts = [
        'user_id' => 'integer',
        'meta' => 'array',
        'reasons' => 'array',
    ];
}
