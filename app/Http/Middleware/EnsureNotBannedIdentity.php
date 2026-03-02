<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureNotBannedIdentity.php
// Purpose: Block requests for active identity bans (email-based)
// Changed: 02-03-2026 14:00 (Europe/Berlin)
// Version: 0.3
// ============================================================================

namespace App\Http\Middleware;

use App\Models\SecurityIdentityBan;
use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
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

        $supportRef = $this->generateSupportReference();

        $this->securityEventLogger->log(
            type: 'identity_blocked',
            ip: $request->ip(),
            email: $email,
            deviceHash: $this->deviceHashService->forRequest($request),
            meta: [
                'support_ref' => $supportRef,
                'reason' => $activeBan->reason,
                'banned_until' => $activeBan->banned_until?->toIso8601String(),
                'path' => $request->path(),
            ],
        );

        if ($request->expectsJson()) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        return redirect()
            ->route('login')
            ->with('security_ban_support_ref', $supportRef)
            ->withInput([
                'email' => (string) $request->input('email', ''),
            ]);
    }

    private function normalizedEmail(string $email): ?string
    {
        $value = mb_strtolower(trim($email));

        return $value !== '' ? $value : null;
    }

    private function generateSupportReference(): string
    {
        return 'SEC-'.Str::upper(Str::random(random_int(6, 8)));
    }
}
