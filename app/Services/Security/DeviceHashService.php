<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\DeviceHashService.php
// Purpose: Build stable device hash strictly from persistent device cookie
// Changed: 12-03-2026 03:32 (Europe/Berlin)
// Version: 0.6
// ============================================================================

namespace App\Services\Security;

use Illuminate\Http\Request;
use Illuminate\Support\Str;

class DeviceHashService
{
    public const DEVICE_COOKIE_NAME = 'ks_device_id';

    public function forRequest(Request $request): ?string
    {
        $deviceCookieId = $this->normalizedDeviceCookieId(
            (string) $request->cookie(self::DEVICE_COOKIE_NAME, '')
        );

        if ($deviceCookieId === null) {
            $deviceCookieId = $this->normalizedDeviceCookieId(
                $this->extractRawCookieValue(
                    cookieHeader: (string) $request->header('Cookie', ''),
                    cookieName: self::DEVICE_COOKIE_NAME,
                )
            );
        }

        if ($deviceCookieId === null) {
            return null;
        }

        return $this->hashDeviceCookieId($deviceCookieId);
    }

    public function cookieName(): string
    {
        return self::DEVICE_COOKIE_NAME;
    }

    public function ensureDeviceCookieId(?string $value = null): string
    {
        $normalized = $this->normalizedDeviceCookieId((string) ($value ?? ''));

        if ($normalized !== null) {
            return $normalized;
        }

        return (string) Str::uuid();
    }

    public function hashDeviceCookieId(string $deviceCookieId): string
    {
        return hash('sha256', $deviceCookieId);
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