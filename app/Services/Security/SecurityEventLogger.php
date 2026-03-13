<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\SecurityEventLogger.php
// Purpose: Dispatch security events with consistent context (ip/email/deviceHash) and device correlation meta when available
// Changed: 10-03-2026 21:00 (Europe/Berlin)
// Version: 0.4
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

        $ipFinal = $ip;
        if (($ipFinal === null || trim($ipFinal) === '') && $request !== null) {
            $ipFinal = (string) $request->ip();
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