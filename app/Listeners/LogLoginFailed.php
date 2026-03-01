<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\LogLoginFailed.php
// Purpose: Log failed login attempts (DB SecurityEvent, request IP/UA, no request payload)
// ============================================================================

namespace App\Listeners;

use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use Illuminate\Auth\Events\Failed;

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
        $email = mb_strtolower(trim((string) $request->input('email', '')));

        $this->securityEventLogger->log(
            type: 'login_failed',
            ip: $request->ip(),
            userId: $event->user?->id,
            email: $email !== '' ? $email : null,
            deviceHash: $this->deviceHashService->forRequest($request),
            meta: [
                'guard' => $event->guard,
            ],
        );
    }
}
