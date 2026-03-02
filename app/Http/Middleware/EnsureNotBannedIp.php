<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureNotBannedIp.php
// Purpose: Block requests for active IP bans and log blocking events
// Changed: 02-03-2026 17:35 (Europe/Berlin)
// Version: 0.4
// ============================================================================

namespace App\Http\Middleware;

use App\Models\SecurityIpBan;
use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
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

        $supportRef = $this->generateSupportReference();

        $this->securityEventLogger->log(
            type: 'ip_blocked',
            ip: $ip,
            email: $this->normalizedEmail((string) $request->input('email', '')),
            deviceHash: $this->deviceHashService->forRequest($request),
            meta: [
                'support_ref' => $supportRef,
                'reason' => $activeBan->reason,
                'banned_until' => $activeBan->banned_until?->toIso8601String(),
                'path' => $request->path(),
            ],
        );

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
