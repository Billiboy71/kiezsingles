<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\LogLoginFailed.php
// Purpose: Log failed login attempts (DB SecurityEvent, request IP/UA, no request payload)
// Changed: 01-03-2026 23:15 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Listeners;

use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use Illuminate\Auth\Events\Failed;
use Illuminate\Support\Facades\RateLimiter;

class LogLoginFailed
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
    ) {}

    public function handle(Failed $event): void
    {
        if (!app()->bound('request')) {
            return;
        }

        $request = request();
        $ip = (string) $request->ip();
        $email = mb_strtolower(trim((string) $request->input('email', '')));

        // De-dupe: in some flows the Failed event may fire multiple times per single login attempt.
        // Allow only 1 logged row per (ip+email+guard) within a short window.
        $dedupeKey = 'security:login_failed:dedupe:'
            .strtolower($ip)
            .':'.($email !== '' ? $email : '-')
            .':'.mb_strtolower((string) $event->guard);

        if (RateLimiter::tooManyAttempts($dedupeKey, 1)) {
            return;
        }

        RateLimiter::hit($dedupeKey, 2);

        $this->securityEventLogger->log(
            type: 'login_failed',
            ip: $ip,
            userId: $event->user?->id,
            email: $email !== '' ? $email : null,
            deviceHash: $this->deviceHashService->forRequest($request),
            meta: [
                'guard' => $event->guard,
            ],
        );
    }
}