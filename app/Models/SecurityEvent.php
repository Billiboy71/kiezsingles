<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\SecurityEvent.php
// Purpose: Eloquent model for persisted security incidents.
// Changed: 17-03-2026 01:23 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SecurityEvent extends Model
{
    protected $fillable = [
        'reference',
        'type',
        'ip',
        'user_id',
        'email',
        'device_hash',
        'meta',
    ];

    protected $casts = [
        'user_id' => 'integer',
        'meta' => 'array',
    ];
}
