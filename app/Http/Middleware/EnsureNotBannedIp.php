<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureNotBannedIp.php
// Purpose: Block requests for active IP bans and log blocking events
// Changed: 02-03-2026 01:49 (Europe/Berlin)
// Version: 0.3
// ============================================================================

namespace App\Http\Middleware;

use App\Models\SecurityIpBan;
use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureNotBannedIp
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $ip = (string) ($request->ip() ?? '');

        if ($ip === '') {
            return $next($request);
        }

        $activeBan = SecurityIpBan::query()
            ->where('ip', $ip)
            ->active()
            ->latest('id')
            ->first();

        if (!$activeBan) {
            return $next($request);
        }

        $this->securityEventLogger->log(
            type: 'ip_blocked',
            ip: $ip,
            email: $this->normalizedEmail((string) $request->input('email', '')),
            deviceHash: $this->deviceHashService->forRequest($request),
            meta: [
                'reason' => $activeBan->reason,
                'banned_until' => $activeBan->banned_until?->toIso8601String(),
                'path' => $request->path(),
            ],
        );

        if ($request->expectsJson()) {
            return response()->json([
                'message' => 'Your IP is banned.',
            ], 403);
        }

        return redirect()
            ->route('login')
            ->withErrors([
                'email' => __('auth.ip_banned'),
            ])
            ->withInput([
                'email' => (string) $request->input('email', ''),
            ]);
    }

    private function normalizedEmail(string $email): ?string
    {
        $value = mb_strtolower(trim($email));

        return $value !== '' ? $value : null;
    }
}