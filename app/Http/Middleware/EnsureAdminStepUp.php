<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureAdminStepUp.php
// Purpose: Require recent password confirmation for critical admin actions
// Changed: 02-03-2026 01:43 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Http\Middleware;

use App\Services\Security\SecurityEventLogger;
use App\Services\Security\SecuritySettingsService;
use App\Services\Security\DeviceHashService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAdminStepUp
{
    public function __construct(
        private readonly SecuritySettingsService $securitySettingsService,
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $settings = $this->securitySettingsService->get();

        if (!(bool) $settings->stepup_required_enabled) {
            return $next($request);
        }

        if (!$request->user()) {
            return redirect()->route('login');
        }

        $confirmedAt = (int) $request->session()->get('auth.password_confirmed_at', 0);
        $timeout = (int) config('auth.password_timeout', 10800);

        if ($confirmedAt > 0 && (time() - $confirmedAt) < $timeout) {
            return $next($request);
        }

        $this->securityEventLogger->log(
            type: 'stepup_required',
            ip: $request->ip(),
            userId: (int) $request->user()->id,
            email: $request->user()->email,
            deviceHash: $this->deviceHashService->forRequest($request),
            meta: [
                'path' => $request->path(),
                'method' => $request->method(),
            ],
        );

        return redirect()->guest(route('password.confirm'));
    }
}
