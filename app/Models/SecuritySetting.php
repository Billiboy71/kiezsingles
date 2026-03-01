<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SecuritySetting extends Model
{
    protected $fillable = [
        'login_attempt_limit',
        'lockout_seconds',
        'ip_autoban_enabled',
        'ip_autoban_fail_threshold',
        'ip_autoban_seconds',
        'admin_stricter_limits_enabled',
        'stepup_required_enabled',
    ];

    protected $casts = [
        'login_attempt_limit' => 'integer',
        'lockout_seconds' => 'integer',
        'ip_autoban_enabled' => 'boolean',
        'ip_autoban_fail_threshold' => 'integer',
        'ip_autoban_seconds' => 'integer',
        'admin_stricter_limits_enabled' => 'boolean',
        'stepup_required_enabled' => 'boolean',
    ];
}
