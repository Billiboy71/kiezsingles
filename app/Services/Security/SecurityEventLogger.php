<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\SecurityEventLogger.php
// Purpose: Dispatch security events with consistent context (ip/email/deviceHash) and device correlation meta when available
// Changed: 19-03-2026 22:06 (Europe/Berlin)
// Version: 0.7
// ============================================================================

namespace App\Services\Security;

use App\Events\Security\SecurityEventTriggered;
use Illuminate\Http\Request;

class SecurityEventLogger
{
    public function __construct(
        private readonly DeviceHashService $deviceHashService,
    ) {}

    /**
     * @param array<string, mixed> $meta
     */
    public function log(
        string $type,
        ?string $ip = null,
        ?int $userId = null,
        ?string $email = null,
        ?string $deviceHash = null,
        array $meta = [],
    ): void {
        $request = $this->currentRequest();
        $resolvedIpInfo = $request !== null ? $this->resolveClientIp($request) : ['ip' => null, 'source' => null];

        $ipFinal = $ip !== null ? trim($ip) : null;
        if (($ipFinal === null || $ipFinal === '') && $request !== null) {
            $ipFinal = $resolvedIpInfo['ip'];
        }
        $ipFinal = $ipFinal !== null ? trim($ipFinal) : null;
        if ($ipFinal === '') {
            $ipFinal = null;
        }

        $emailFinal = $email;
        if (($emailFinal === null || trim($emailFinal) === '') && $request !== null && $request->has('email')) {
            $emailFinal = $this->normalizedEmail((string) $request->input('email'));
        } else {
            $emailFinal = $this->normalizedLooseEmail($emailFinal);
        }

        $deviceHashFinal = $deviceHash;
        if (($deviceHashFinal === null || trim($deviceHashFinal) === '') && $request !== null) {
            $deviceHashFinal = $this->resolveDeviceHash($request);
        }
        $deviceHashFinal = $deviceHashFinal !== null ? trim($deviceHashFinal) : null;
        if ($deviceHashFinal === '') {
            $deviceHashFinal = null;
        }

        $metaFinal = $meta;

        if (!array_key_exists('path', $metaFinal) && $request !== null) {
            $path = trim((string) $request->path());
            $metaFinal['path'] = $path !== '' ? $path : '/';
        }

        if (!array_key_exists('ip_source', $metaFinal) && $resolvedIpInfo['source'] !== null) {
            $metaFinal['ip_source'] = $resolvedIpInfo['source'];
        }

        if ($deviceHashFinal !== null) {
            if (!array_key_exists('device_hash', $metaFinal)) {
                $metaFinal['device_hash'] = $deviceHashFinal;
            }

            if (!array_key_exists('device_correlation_key', $metaFinal)) {
                $metaFinal['device_correlation_key'] = 'device:'.$deviceHashFinal;
            }

            if ($request !== null) {
                $deviceHashSource = $this->resolveDeviceHashSource($request, $deviceHashFinal);

                if ($deviceHashSource !== null && !array_key_exists('device_hash_source', $metaFinal)) {
                    $metaFinal['device_hash_source'] = $deviceHashSource;
                }

                $deviceCookieId = $this->resolveDeviceCookieId($request);
                if ($deviceCookieId !== null) {
                    if (!array_key_exists('device_cookie_name', $metaFinal)) {
                        $metaFinal['device_cookie_name'] = $this->deviceHashService->cookieName();
                    }

                    if (!array_key_exists('device_cookie_hash', $metaFinal)) {
                        $metaFinal['device_cookie_hash'] = $this->deviceHashService->hashDeviceCookieId($deviceCookieId);
                    }
                }
            }
        }

        // ============================================================
        // MINIMAL DEDUPE FIX (verhindert doppelte Dispatches pro Request)
        // ============================================================

        static $dispatched = [];

        $dedupeKey = implode('|', [
            $type,
            $ipFinal ?? '-',
            $userId ?? '-',
            $emailFinal ?? '-',
            $deviceHashFinal ?? '-',
            $metaFinal['path'] ?? '-',
        ]);

        if (isset($dispatched[$dedupeKey])) {
            return;
        }

        $dispatched[$dedupeKey] = true;

        // ============================================================

        event(new SecurityEventTriggered(
            type: $type,
            ip: $ipFinal,
            userId: $userId,
            email: $emailFinal,
            deviceHash: $deviceHashFinal,
            meta: $metaFinal,
        ));
    }

    private function currentRequest(): ?Request
    {
        try {
            $r = request();
            if ($r instanceof Request) {
                return $r;
            }
        } catch (\Throwable) {
            // no request context (CLI, jobs, etc.)
        }

        return null;
    }

    /**
     * @return array{ip:?string,source:?string}
     */
    private function resolveClientIp(Request $request): array
    {
        $baseIp = trim((string) ($request->ip() ?? ''));

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
                'ip' => $baseIp !== '' ? $baseIp : null,
                'source' => 'request_ip',
            ];
        }

        $cfIp = $this->firstValidIpFromHeaderValue(trim((string) ($request->headers->get('CF-Connecting-IP') ?? '')));
        if ($cfIp !== '') {
            return [
                'ip' => $cfIp,
                'source' => 'cf_connecting_ip',
            ];
        }

        $xRealIp = $this->firstValidIpFromHeaderValue(trim((string) ($request->headers->get('X-Real-IP') ?? '')));
        if ($xRealIp !== '') {
            return [
                'ip' => $xRealIp,
                'source' => 'x_real_ip',
            ];
        }

        $xffIp = $this->firstValidIpFromHeaderValue(trim((string) ($request->headers->get('X-Forwarded-For') ?? '')));
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
            'ip' => $baseIp !== '' ? $baseIp : null,
            'source' => 'request_ip',
        ];
    }

    private function resolveDeviceHash(Request $request): ?string
    {
        $deviceHash = $this->deviceHashService->forRequest($request);

        if ($deviceHash === null) {
            return null;
        }

        $deviceHash = trim($deviceHash);

        return $deviceHash !== '' ? $deviceHash : null;
    }

    private function resolveDeviceHashSource(Request $request, string $deviceHash): ?string
    {
        $deviceCookieId = $this->resolveDeviceCookieId($request);

        if ($deviceCookieId !== null) {
            $cookieHash = $this->deviceHashService->hashDeviceCookieId($deviceCookieId);

            if (hash_equals($cookieHash, $deviceHash)) {
                return 'device_cookie';
            }
        }

        return 'fingerprint_fallback';
    }

    private function resolveDeviceCookieId(Request $request): ?string
    {
        $cookieName = $this->deviceHashService->cookieName();

        $deviceCookieId = $this->normalizedDeviceCookieId((string) $request->cookie($cookieName, ''));

        if ($deviceCookieId !== null) {
            return $deviceCookieId;
        }

        $rawCookieValue = $this->extractRawCookieValue(
            cookieHeader: (string) $request->header('Cookie', ''),
            cookieName: $cookieName,
        );

        return $this->normalizedDeviceCookieId($rawCookieValue);
    }

    private function normalizedDeviceCookieId(string $value): ?string
    {
        $value = trim($value);

        if ($value === '') {
            return null;
        }

        if (!preg_match('/^[A-Za-z0-9\-]{16,128}$/', $value)) {
            return null;
        }

        return $value;
    }

    private function normalizedEmail(string $value): ?string
    {
        $value = mb_strtolower(trim($value));

        if ($value === '') {
            return null;
        }

        return filter_var($value, FILTER_VALIDATE_EMAIL) !== false ? $value : null;
    }

    private function normalizedLooseEmail(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $value = mb_strtolower(trim($value));

        return $value !== '' ? $value : null;
    }

    private function firstValidIpFromHeaderValue(string $value): string
    {
        $v = trim($value);
        if ($v === '') {
            return '';
        }

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

    private function extractRawCookieValue(string $cookieHeader, string $cookieName): string
    {
        $cookieHeader = trim($cookieHeader);
        $cookieName = trim($cookieName);

        if ($cookieHeader === '' || $cookieName === '') {
            return '';
        }

        foreach (explode(';', $cookieHeader) as $part) {
            $pair = explode('=', trim($part), 2);

            if (count($pair) !== 2) {
                continue;
            }

            $name = trim((string) $pair[0]);
            $value = trim((string) $pair[1]);

            if ($name !== $cookieName) {
                continue;
            }

            return urldecode($value);
        }

        return '';
    }
}