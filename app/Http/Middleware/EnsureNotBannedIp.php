<?php

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

        abort(403, 'Your IP is banned.');
    }

    private function normalizedEmail(string $email): ?string
    {
        $value = mb_strtolower(trim($email));

        return $value !== '' ? $value : null;
    }
}
