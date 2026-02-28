<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\SystemSetting.php
// Version: 0.2
// Purpose: DB-backed system settings model (for admin-toggleable flags)
// Changed: 27-02-2026 19:15 (Europe/Berlin)
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SystemSetting extends Model
{
    protected $table = 'debug_settings';

    protected $fillable = [
        'key',
        'value',
        'group',
        'cast',
    ];
}
