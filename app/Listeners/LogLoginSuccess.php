<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\LogLoginSuccess.php
// Purpose: Write security audit event for successful login (config-driven)
// Changed: 10-03-2026 21:05 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Listeners;

use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use Illuminate\Auth\Events\Login;

class LogLoginSuccess
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
    ) {}

    public function handle(Login $event): void
    {
        if (!app()->bound('request')) {
            return;
        }

        $request = request();

        $this->securityEventLogger->log(
            type: 'login_success',
            ip: $request->ip(),
            userId: $event->user->id ?? null,
            email: $event->user->email ?? null,
            deviceHash: $this->deviceHashService->forRequest($request),
            meta: ['guard' => $event->guard],
        );
    }
}