<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\DeviceHashService.php
// Purpose: Build stable device hash from request fingerprint inputs
// Changed: 02-03-2026 01:43 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Services\Security;

use Illuminate\Http\Request;

class DeviceHashService
{
    public function forRequest(Request $request): ?string
    {
        $userAgent = $this->normalizeWhitespace((string) ($request->userAgent() ?? ''));
        $acceptLanguage = $this->normalizeWhitespace((string) $request->header('Accept-Language', ''));
        $ipPrefix = $this->ipPrefix((string) ($request->ip() ?? ''));
        $timezone = $this->normalizeWhitespace((string) $request->input('timezone', ''));

        if ($userAgent === '' && $acceptLanguage === '' && $ipPrefix === '' && $timezone === '') {
            return null;
        }

        $payload = implode('|', [
            strtolower($userAgent),
            strtolower($acceptLanguage),
            $ipPrefix,
            strtolower($timezone),
        ]);

        return hash('sha256', $payload);
    }

    private function normalizeWhitespace(string $value): string
    {
        $value = preg_replace('/\s+/', ' ', trim($value));

        return is_string($value) ? $value : '';
    }

    private function ipPrefix(string $ip): string
    {
        if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            $parts = explode('.', $ip);
            if (count($parts) === 4) {
                return sprintf('%s.%s.%s.0/24', $parts[0], $parts[1], $parts[2]);
            }
        }

        return '';
    }
}
