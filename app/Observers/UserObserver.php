<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Observers\UserObserver.php
// Purpose: Set registration_ip + registration_ip_at on user creation (server-side)
// ============================================================================

namespace App\Observers;

use App\Models\User;

class UserObserver
{
    public function created(User $user): void
    {
        if (!config('security.ip_logging.registration')) {
            return;
        }

        if (!empty($user->registration_ip)) {
            return;
        }

        if (!app()->bound('request')) {
            return;
        }

        $ip = request()->ip();

        if (empty($ip)) {
            return;
        }

        // forceFill: unabhängig von $fillable (Security!)
        $user->forceFill([
            'registration_ip'    => $ip,
            'registration_ip_at' => now(),
        ])->saveQuietly();
    }
}
