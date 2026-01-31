<?php
// ============================================================================
// File: app/Listeners/LogLoginIp.php
// Purpose: Set last_login_ip + last_login_ip_at on successful login (config-driven)
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

        $user = $event->user;

        $user->forceFill([
            'last_login_ip'    => request()->ip(),
            'last_login_ip_at' => now(),
        ])->save();
    }
}
