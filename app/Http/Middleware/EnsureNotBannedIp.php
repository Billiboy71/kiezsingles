<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureNotBannedIp.php
// Purpose: Block requests for active IP bans and log blocking events
// Changed: 09-03-2026 15:43 (Europe/Berlin)
// Version: 1.2
// ============================================================================

namespace App\Http\Middleware;

use App\Models\SecurityIpBan;
use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use App\Services\Security\SecuritySupportAccessTokenService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureNotBannedIp
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
        private readonly SecuritySupportAccessTokenService $securitySupportAccessTokenService,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $ipInfo = $this->resolveClientIp($request);
        $ip = $ipInfo['ip'];

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

        $caseKey = 'ip_ban:'.(string) $activeBan->id.':ip:'.$ip;
        $supportAccess = $this->securitySupportAccessTokenService->issueForCase(
            caseKey: $caseKey,
            securityEventType: 'ip_blocked',
            sourceContext: 'security_login_block',
            contactEmail: $this->normalizedEmail((string) $request->input('email', '')),
        );
        $supportRef = (string) $supportAccess['support_reference'];
        $supportAccessToken = (string) $supportAccess['plain_token'];

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
                'ip_source' => $ipInfo['source'],
            ],
        );

        // IMPORTANT:
        // - Avoid redirect-loops on GET /login (would break CSRF extraction and cause 419 in PS tests).
        // - Still block actual login attempts (POST /login) by redirecting back with support ref.
        $isLoginPath = false;
        try {
            $isLoginPath = $request->path() === 'login';
        } catch (\Throwable $ignore) {
            $isLoginPath = false;
        }

        $isGet = false;
        try {
            $isGet = $request->isMethod('GET');
        } catch (\Throwable $ignore) {
            $isGet = false;
        }

        if ($isLoginPath && $isGet) {
            try {
                if (method_exists($request, 'session') && $request->hasSession()) {
                    $request->session()->flash('security_ban_support_ref', $supportRef);
                    $request->session()->flash('security_ban_support_reference', $supportRef);
                    $request->session()->flash('security_support_reference', $supportRef);
                    $request->session()->flash('security_ban_support_access_token', $supportAccessToken);
                }
            } catch (\Throwable $ignore) {
                // ignore
            }

            return $next($request);
        }

        return redirect()
            ->route('login')
            ->with('security_ban_support_ref', $supportRef)
            ->with('security_ban_support_reference', $supportRef)
            ->with('security_support_reference', $supportRef)
            ->with('security_ban_support_access_token', $supportAccessToken)
            ->withInput([
                'email' => (string) $request->input('email', ''),
            ]);
    }

    private function normalizedEmail(string $email): ?string
    {
        $value = mb_strtolower(trim($email));

        if ($value === '') {
            return null;
        }

        return filter_var($value, FILTER_VALIDATE_EMAIL) !== false ? $value : null;
    }

    /**
     * Local/testing helper: allow simulated client IP via common proxy headers.
     * In testing, never fall back to the real local request IP; use a dedicated
     * deterministic test IP when no rotated header IP is present.
     *
     * Returns: ['ip' => string, 'source' => string]
     */
    private function resolveClientIp(Request $request): array
    {
        $baseIp = (string) ($request->ip() ?? '');
        $baseIp = trim($baseIp);

        $isLocal = false;
        $isTesting = false;

        try {
            if (function_exists('app')) {
                $isLocal = app()->environment('local');
                $isTesting = app()->environment('testing');
            }
        } catch (\Throwable $ignore) {
            $isLocal = false;
            $isTesting = false;
        }

        if (! $isLocal && ! $isTesting) {
            return [
                'ip' => $baseIp,
                'source' => 'request_ip',
            ];
        }

        // Prefer Cloudflare-style header first if present (common in deployments/tests).
        $cf = trim((string) ($request->headers->get('CF-Connecting-IP') ?? ''));
        $cfIp = $this->firstValidIpFromHeaderValue($cf);
        if ($cfIp !== '') {
            return [
                'ip' => $cfIp,
                'source' => 'cf_connecting_ip',
            ];
        }

        $xReal = trim((string) ($request->headers->get('X-Real-IP') ?? ''));
        $xRealIp = $this->firstValidIpFromHeaderValue($xReal);
        if ($xRealIp !== '') {
            return [
                'ip' => $xRealIp,
                'source' => 'x_real_ip',
            ];
        }

        $xff = trim((string) ($request->headers->get('X-Forwarded-For') ?? ''));
        $xffIp = $this->firstValidIpFromHeaderValue($xff);
        if ($xffIp !== '') {
            return [
                'ip' => $xffIp,
                'source' => 'x_forwarded_for',
            ];
        }

        if ($isTesting) {
            return [
                'ip' => '198.51.100.10',
                'source' => 'testing_fallback_ip',
            ];
        }

        return [
            'ip' => $baseIp,
            'source' => 'request_ip',
        ];
    }

    private function firstValidIpFromHeaderValue(string $value): string
    {
        $v = trim($value);
        if ($v === '') {
            return '';
        }

        // X-Forwarded-For may be a comma-separated chain -> take the left-most.
        $first = $v;
        $parts = explode(',', $v);
        if (count($parts) > 0) {
            $first = trim((string) $parts[0]);
        }

        if ($first === '') {
            return '';
        }

        $ok = false;
        try {
            $ok = filter_var($first, FILTER_VALIDATE_IP) !== false;
        } catch (\Throwable $ignore) {
            $ok = false;
        }

        return $ok ? $first : '';
    }
}