<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\LogLoginFailed.php
// Purpose: Log failed login attempts (DB SecurityEvent, request IP/UA, no request payload)
// Changed: 10-03-2026 21:03 (Europe/Berlin)
// Version: 0.2
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
        $email = $this->normalizedContactEmail((string) $request->input('email', ''));

        // De-dupe: in some flows the Failed event may fire multiple times per single login attempt.
        // Allow only 1 logged row per (ip+email+guard) within a short window.
        $dedupeKey = 'security:login_failed:dedupe:'
            .strtolower($ip)
            .':'.($email !== null ? $email : '-')
            .':'.mb_strtolower((string) $event->guard);

        if (RateLimiter::tooManyAttempts($dedupeKey, 1)) {
            return;
        }

        RateLimiter::hit($dedupeKey, 2);

        $this->securityEventLogger->log(
            type: 'login_failed',
            ip: $ip,
            userId: $event->user?->id,
            email: $email,
            deviceHash: $this->deviceHashService->forRequest($request),
            meta: [
                'guard' => $event->guard,
            ],
        );
    }

    private function normalizedContactEmail(string $value): ?string
    {
        $value = mb_strtolower(trim($value));

        if ($value === '') {
            return null;
        }

        return filter_var($value, FILTER_VALIDATE_EMAIL) !== false ? $value : null;
    }
}