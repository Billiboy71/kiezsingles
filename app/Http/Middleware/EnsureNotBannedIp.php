<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureNotBannedIp.php
// Purpose: Block requests for active IP bans and log blocking events
// Changed: 05-03-2026 23:01 (Europe/Berlin)
// Version: 0.6
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
                }
            } catch (\Throwable $ignore) {
                // ignore
            }

            return $next($request);
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

    /**
     * Local-only helper: allow tests to simulate client IP via common proxy headers
     * even if proxy-trust config is not effective in the current environment.
     *
     * Returns: ['ip' => string, 'source' => string]
     */
    private function resolveClientIp(Request $request): array
    {
        $baseIp = (string) ($request->ip() ?? '');
        $baseIp = trim($baseIp);

        $isLocal = false;
        try {
            if (function_exists('app')) {
                $isLocal = app()->environment('local');
            }
        } catch (\Throwable $ignore) {
            $isLocal = false;
        }

        if (!$isLocal) {
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