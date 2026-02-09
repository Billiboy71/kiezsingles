<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\LogRegistrationIp.php
// Purpose: Deprecated. Registration IP is handled by UserObserver@created.
// ============================================================================

namespace App\Listeners;

use Illuminate\Auth\Events\Registered;

class LogRegistrationIp
{
    public function handle(Registered $event): void
    {
        // Registration IP is handled server-side in App\Observers\UserObserver::created().
        // This listener is intentionally a no-op to avoid duplicate mechanisms.
        return;
    }
}
