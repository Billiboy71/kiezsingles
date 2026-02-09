<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\LogLoginIp.php
// Purpose: Set last_login_ip + last_login_ip_at on successful login (config-driven, hardened)
// ============================================================================

namespace App\Listeners;

use Illuminate\Auth\Events\Login;

class LogLoginIp
{
    public function handle(Login $event): void
    {
        if (!config('security.ip_logging.login')) {
            return;
        }

        if (!app()->bound('request')) {
            return;
        }

        $ip = request()->ip();

        if (empty($ip)) {
            return;
        }

        $user = $event->user;

        $user->forceFill([
            'last_login_ip'    => $ip,
            'last_login_ip_at' => now(),
        ])->saveQuietly();
    }
}
