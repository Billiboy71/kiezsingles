<?php
// ============================================================================
// File: app/Listeners/LogRegistrationIp.php
// Purpose: Set registration_ip + registration_ip_at on user registration (config-driven)
// ============================================================================

namespace App\Listeners;

use Illuminate\Auth\Events\Registered;

class LogRegistrationIp
{
    public function handle(Registered $event): void
    {
        if (!config('security.ip_logging.registration')) {
            return;
        }

        $user = $event->user;

        if (!empty($user->registration_ip)) {
            return;
        }

        $user->forceFill([
            'registration_ip'    => request()->ip(),
            'registration_ip_at' => now(),
        ])->save();
    }
}
