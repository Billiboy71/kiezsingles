<?php

namespace App\Http\Middleware;

use App\Models\SecurityIdentityBan;
use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureNotBannedIdentity
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $email = $this->normalizedEmail((string) $request->input('email', ''));

        if ($email === null) {
            return $next($request);
        }

        $activeBan = SecurityIdentityBan::query()
            ->where('email', $email)
            ->active()
            ->latest('id')
            ->first();

        if (!$activeBan) {
            return $next($request);
        }

        $this->securityEventLogger->log(
            type: 'identity_blocked',
            ip: $request->ip(),
            email: $email,
            deviceHash: $this->deviceHashService->forRequest($request),
            meta: [
                'reason' => $activeBan->reason,
                'banned_until' => $activeBan->banned_until?->toIso8601String(),
                'path' => $request->path(),
            ],
        );

        if ($request->expectsJson()) {
            return response()->json(['message' => 'This identity is banned.'], 403);
        }

        abort(403, 'This identity is banned.');
    }

    private function normalizedEmail(string $email): ?string
    {
        $value = mb_strtolower(trim($email));

        return $value !== '' ? $value : null;
    }
}
