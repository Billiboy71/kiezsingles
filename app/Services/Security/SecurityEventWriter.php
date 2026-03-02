<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\SecurityEventWriter.php
// Purpose: Central writer for security_events (fills ip/email/device_hash/meta consistently)
// Changed: 01-03-2026 23:06 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Services\Security;

use App\Models\SecurityEvent;
use Illuminate\Http\Request;

class SecurityEventWriter
{
    /**
     * Record a security event with consistent fields (ip/email/device_hash/meta).
     *
     * Supported $data keys:
     * - ip (string|null)
     * - user_id (int|null)
     * - email (string|null)
     * - device_hash (string|null)
     * - meta (array|null)
     */
    public function record(string $type, ?Request $request = null, array $data = []): SecurityEvent
    {
        $ip = isset($data['ip']) ? $this->normalizeIp((string) $data['ip']) : null;
        $email = isset($data['email']) ? $this->normalizeEmail((string) $data['email']) : null;
        $deviceHash = isset($data['device_hash']) ? trim((string) $data['device_hash']) : null;

        if ($request !== null) {
            if ($ip === null || $ip === '') {
                $ip = $this->normalizeIp((string) $request->ip());
            }

            if (($email === null || $email === '') && $request->has('email')) {
                $email = $this->normalizeEmail((string) $request->input('email'));
            }

            if ($deviceHash === null || $deviceHash === '') {
                $deviceHash = $this->buildDeviceHash($request, $ip);
            }
        }

        $meta = $data['meta'] ?? null;
        if (!is_array($meta)) {
            $meta = null;
        }

        return SecurityEvent::query()->create([
            'type' => $type,
            'ip' => $ip !== '' ? $ip : null,
            'user_id' => isset($data['user_id']) ? (int) $data['user_id'] : null,
            'email' => $email !== '' ? $email : null,
            'device_hash' => $deviceHash !== '' ? $deviceHash : null,
            'meta' => $meta,
        ]);
    }

    private function normalizeEmail(string $email): string
    {
        return mb_strtolower(trim($email));
    }

    private function normalizeIp(string $ip): string
    {
        return trim($ip);
    }

    private function buildDeviceHash(Request $request, ?string $ip): ?string
    {
        $ua = trim((string) $request->userAgent());
        $acceptLanguage = trim((string) $request->header('Accept-Language', ''));

        // Optional, lightweight stabilization: IPv4 /24 prefix (first 3 octets). For IPv6, do not derive a prefix here.
        $ipPrefix = $this->ipv4Prefix24($ip);

        $payload = implode('|', [
            $this->normalizeDevicePart($ua),
            $this->normalizeDevicePart($acceptLanguage),
            $this->normalizeDevicePart($ipPrefix),
        ]);

        $payload = trim($payload, '|');

        if ($payload === '') {
            return null;
        }

        return hash('sha256', $payload);
    }

    private function normalizeDevicePart(?string $value): string
    {
        $v = trim((string) $value);
        if ($v === '') {
            return '';
        }

        // keep stable, but avoid huge strings
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

        // If it's IPv6 or invalid/unknown format, skip prefixing.
        if ($ip === '' || str_contains($ip, ':')) {
            return '';
        }

        $parts = explode('.', $ip);
        if (count($parts) !== 4) {
            return '';
        }

        return $parts[0] . '.' . $parts[1] . '.' . $parts[2];
    }
}