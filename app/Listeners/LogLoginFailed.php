<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\LogLoginFailed.php
// Purpose: Log failed login attempts (DB SecurityEvent, request IP/UA, no request payload)
// ============================================================================

namespace App\Listeners;

use App\Models\SecurityEvent;
use Illuminate\Auth\Events\Failed;

class LogLoginFailed
{
    public function handle(Failed $event): void
    {
        SecurityEvent::create([
            'user_id'     => $event->user?->id,
            'event_type'  => 'login_failed',
            'ip'          => request()->ip(),
            'user_agent'  => request()->userAgent(),
            'metadata'    => [
                'guard' => $event->guard,
            ],
        ]);
    }
}
