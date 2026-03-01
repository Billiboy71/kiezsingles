<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\LogPasswordResetCompleted.php
// Purpose: Log completed password resets (DB SecurityEvent, request IP/UA, hardened)
// ============================================================================

namespace App\Listeners;

use App\Services\Security\SecurityEventLogger;
use Illuminate\Auth\Events\PasswordReset;

class LogPasswordResetCompleted
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
    ) {}

    public function handle(PasswordReset $event): void
    {
        if (!app()->bound('request')) {
            return;
        }

        $request = request();
        $ip = $request->ip();

        if (empty($ip)) {
            return;
        }

        $this->securityEventLogger->log(
            type: 'password_reset_completed',
            ip: $ip,
            userId: $event->user?->id,
            email: $event->user?->email,
        );
    }
}
