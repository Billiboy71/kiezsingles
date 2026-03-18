<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureNotBannedIdentity.php
// Purpose: Block requests for active identity bans (email-based)
// Changed: 17-03-2026 12:26 (Europe/Berlin)
// Version: 1.0
// ============================================================================

namespace App\Http\Middleware;

use App\Models\SecurityIdentityBan;
use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use App\Services\Security\SecuritySupportAccessTokenService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureNotBannedIdentity
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
        private readonly SecuritySupportAccessTokenService $securitySupportAccessTokenService,
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

        $caseKey = 'identity_ban:'.(string) $activeBan->id.':email:'.$email;
        $deviceHash = $this->deviceHashService->forRequest($request);

        $this->securityEventLogger->log(
            type: 'identity_blocked',
            ip: $request->ip(),
            email: $email,
            deviceHash: $deviceHash,
            meta: [
                'reason' => 'identity_ban',
                'ban_reason' => $activeBan->reason,
                'banned_until' => $activeBan->banned_until?->toIso8601String(),
                'path' => $request->path(),
            ],
        );

        $supportRef = $this->resolveLatestSecurityReference($request->ip(), $email, $deviceHash);
        $supportAccess = $this->securitySupportAccessTokenService->issueForCase(
            caseKey: $caseKey,
            securityEventType: 'identity_blocked',
            sourceContext: 'security_login_block',
            contactEmail: $email,
            preferredSupportReference: $supportRef,
        );
        $supportAccessToken = (string) $supportAccess['plain_token'];

        if ($request->expectsJson()) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        return redirect()
            ->route('login')
            ->with('security_ban_support_ref', $supportRef)
            ->with('security_ban_support_access_token', $supportAccessToken)
            ->withInput([
                'email' => (string) $request->input('email', ''),
            ]);
    }

    private function normalizedEmail(string $email): ?string
    {
        $value = mb_strtolower(trim($email));

        return $value !== '' ? $value : null;
    }

    private function resolveLatestSecurityReference(?string $ip, ?string $email, ?string $deviceHash): string
    {
        $query = \App\Models\SecurityEvent::query()
            ->where('created_at', '>=', now()->subMinutes(10))
            ->latest('id');

        $ip = $ip !== null ? trim($ip) : null;
        $email = $email !== null ? trim($email) : null;
        $deviceHash = $deviceHash !== null ? trim($deviceHash) : null;

        if ($ip === null || $ip === '') {
            $query->whereNull('ip');
        } else {
            $query->where('ip', $ip);
        }

        if ($email === null || $email === '') {
            $query->whereNull('email');
        } else {
            $query->where('email', $email);
        }

        if ($deviceHash === null || $deviceHash === '') {
            $query->whereNull('device_hash');
        } else {
            $query->where('device_hash', $deviceHash);
        }

        $event = $query->first(['reference']);

        if ($event === null || !is_string($event->reference) || trim($event->reference) === '') {
            abort(403);
        }

        return trim($event->reference);
    }

}
