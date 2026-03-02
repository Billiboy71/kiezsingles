<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\SecurityEventLogger.php
// Purpose: Dispatch security events with consistent context (ip/email/deviceHash) when available
// Changed: 01-03-2026 23:12 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Services\Security;

use App\Events\Security\SecurityEventTriggered;
use Illuminate\Http\Request;

class SecurityEventLogger
{
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
            $emailFinal = (string) $request->input('email');
        }
        $emailFinal = $emailFinal !== null ? mb_strtolower(trim($emailFinal)) : null;
        if ($emailFinal === '') {
            $emailFinal = null;
        }

        $deviceHashFinal = $deviceHash;
        if (($deviceHashFinal === null || trim($deviceHashFinal) === '') && $request !== null) {
            $deviceHashFinal = $this->buildDeviceHash($request, $ipFinal);
        }
        $deviceHashFinal = $deviceHashFinal !== null ? trim($deviceHashFinal) : null;
        if ($deviceHashFinal === '') {
            $deviceHashFinal = null;
        }

        event(new SecurityEventTriggered(
            type: $type,
            ip: $ipFinal,
            userId: $userId,
            email: $emailFinal,
            deviceHash: $deviceHashFinal,
            meta: $meta,
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

    private function buildDeviceHash(Request $request, ?string $ip): ?string
    {
        $ua = $this->normalizeDevicePart((string) $request->userAgent());
        $acceptLanguage = $this->normalizeDevicePart((string) $request->header('Accept-Language', ''));

        $ipPrefix = $this->ipv4Prefix24($ip);

        $payload = implode('|', [
            $ua,
            $acceptLanguage,
            $this->normalizeDevicePart($ipPrefix),
        ]);

        $payload = trim($payload, '|');
        if ($payload === '') {
            return null;
        }

        return hash('sha256', $payload);
    }

    private function normalizeDevicePart(string $value): string
    {
        $v = trim($value);
        if ($v === '') {
            return '';
        }

        if (strlen($v) > 512) {
            $v = substr($v, 0, 512);
        }

        return $v;
    }

    private function ipv4Prefix24(?string $ip): string
    {
        if ($ip === null) {
            return '';
        }

        $ip = trim($ip);
        if ($ip === '' || str_contains($ip, ':')) {
            return '';
        }

        $parts = explode('.', $ip);
        if (count($parts) !== 4) {
            return '';
        }

        return $parts[0].'.'.$parts[1].'.'.$parts[2];
    }
}