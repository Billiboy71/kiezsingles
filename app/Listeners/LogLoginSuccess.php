<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\LogLoginSuccess.php
// Purpose: Write security audit event for successful login (config-driven)
// ============================================================================

namespace App\Listeners;

use App\Models\SecurityEvent;
use Illuminate\Auth\Events\Login;

class LogLoginSuccess
{
    public function handle(Login $event): void
    {
        if (!config('security.ip_logging.login')) {
            return;
        }

        SecurityEvent::create([
            'user_id' => $event->user->id ?? null,
            'event_type' => 'login_success',
            'ip' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'metadata' => ['guard' => $event->guard],
        ]);
    }
}
