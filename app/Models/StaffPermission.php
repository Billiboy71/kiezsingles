<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\StaffPermission.php
// Changed: 27-02-2026 00:18 (Europe/Berlin)
// Version: 0.1
// Purpose: SSOT model for per-user backend module permissions.
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StaffPermission extends Model
{
    protected $table = 'staff_permissions';

    protected $fillable = [
        'user_id',
        'module_key',
        'allowed',
    ];

    protected $casts = [
        'user_id' => 'integer',
        'module_key' => 'string',
        'allowed' => 'boolean',
    ];
}