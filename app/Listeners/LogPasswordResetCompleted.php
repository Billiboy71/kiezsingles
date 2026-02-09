<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\LogPasswordResetCompleted.php
// Purpose: Log completed password resets (DB SecurityEvent, request IP/UA, hardened)
// ============================================================================

namespace App\Listeners;

use App\Models\SecurityEvent;
use Illuminate\Auth\Events\PasswordReset;

class LogPasswordResetCompleted
{
    public function handle(PasswordReset $event): void
    {
        if (!app()->bound('request')) {
            return;
        }

        $ip = request()->ip();

        if (empty($ip)) {
            return;
        }

        SecurityEvent::create([
            'user_id'    => $event->user?->id,
            'event_type' => 'password_reset_completed',
            'ip'         => $ip,
            'user_agent' => request()->userAgent(),
            'metadata'   => [],
        ]);
    }
}
