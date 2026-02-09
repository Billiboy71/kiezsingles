<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\SystemSetting.php
// Changed: 08-02-2026 00:47
// Purpose: DB-backed system settings model (for admin-toggleable flags)
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SystemSetting extends Model
{
    protected $table = 'system_settings';

    protected $fillable = [
        'key',
        'value',
        'group',
        'cast',
    ];
}
