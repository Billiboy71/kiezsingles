<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureNotBannedIdentity.php
// Purpose: Block requests for active identity bans (email-based)
// Changed: 17-03-2026 12:26 (Europe/Berlin)
// Version: 0.9
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
        $incidentKey = $this->buildSecurityIncidentKey(
            path: $request->path(),
            ip: $request->ip(),
            email: $email,
            deviceHash: $deviceHash,
        );

        $this->securityEventLogger->log(
            type: 'identity_blocked',
            ip: $request->ip(),
            email: $email,
            deviceHash: $deviceHash,
            meta: [
                'reason' => 'identity_ban',
                'incident_key' => $incidentKey,
                'ban_reason' => $activeBan->reason,
                'banned_until' => $activeBan->banned_until?->toIso8601String(),
                'path' => $request->path(),
            ],
        );

        $supportRef = $this->resolveLatestSecurityReference($incidentKey);
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

    private function resolveLatestSecurityReference(string $incidentKey): string
    {
        $query = \App\Models\SecurityEvent::query()
            ->where('meta->incident_key', $incidentKey)
            ->latest('id');

        $event = $query->first(['reference']);

        if ($event === null || !is_string($event->reference) || trim($event->reference) === '') {
            abort(403);
        }

        return trim($event->reference);
    }

    private function buildSecurityIncidentKey(
        string $path,
        ?string $ip,
        ?string $email,
        ?string $deviceHash,
    ): string {
        $normalizedPath = trim($path, '/');
        $normalizedPath = $normalizedPath !== '' ? $normalizedPath : '/';
        $normalizedIp = $ip !== null ? trim($ip) : '';
        $normalizedEmail = $email !== null ? trim($email) : '';
        $normalizedDeviceHash = $deviceHash !== null ? trim($deviceHash) : '';

        if ($normalizedDeviceHash !== '') {
            return 'security_login_block:path:'.$normalizedPath.':device:'.$normalizedDeviceHash;
        }

        if ($normalizedEmail !== '') {
            return 'security_login_block:path:'.$normalizedPath.':email:'.$normalizedEmail;
        }

        return 'security_login_block:path:'.$normalizedPath.':ip:'.$normalizedIp;
    }

}
