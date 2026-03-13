<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\Security\StoreSecurityEvent.php
// Purpose: Persist SecurityEventTriggered events into security_events (with minimal de-duplication)
// Changed: 10-03-2026 20:49 (Europe/Berlin)
// Version: 0.4
// ============================================================================

namespace App\Listeners\Security;

use App\Events\Security\SecurityEventTriggered;
use App\Models\SecurityEvent;
use Illuminate\Support\Facades\RateLimiter;

class StoreSecurityEvent
{
    public function handle(SecurityEventTriggered $event): void
    {
        $meta = is_array($event->meta) ? $event->meta : [];

        if ($event->deviceHash !== null && trim($event->deviceHash) !== '') {
            if (!array_key_exists('device_hash', $meta)) {
                $meta['device_hash'] = $event->deviceHash;
            }

            if (!array_key_exists('device_correlation_key', $meta)) {
                $meta['device_correlation_key'] = 'device:'.$event->deviceHash;
            }
        }

        if (array_key_exists('path', $meta)) {
            $meta['path'] = $this->normalizeMetaPath($meta['path']);
        }

        $dedupeKey = $this->buildDedupeKey($event, $meta);
        $dedupeTtlSeconds = $this->dedupeTtlSecondsFor($event->type);

        if (RateLimiter::tooManyAttempts($dedupeKey, 1)) {
            return;
        }

        RateLimiter::hit($dedupeKey, $dedupeTtlSeconds);

        SecurityEvent::query()->create([
            'type' => $event->type,
            'ip' => $event->ip,
            'user_id' => $event->userId,
            'email' => $event->email,
            'device_hash' => $event->deviceHash,
            'meta' => $meta,
        ]);
    }

    /**
     * @param array<string, mixed> $meta
     */
    private function buildDedupeKey(SecurityEventTriggered $event, array $meta): string
    {
        $parts = [
            'security:event',
            $this->normalizePart($event->type),
            $this->normalizePart($event->ip),
            $event->userId !== null ? (string) (int) $event->userId : '-',
            $this->normalizePart($event->email),
            $this->normalizePart($event->deviceHash),
            $this->normalizePart($this->metaString($meta, 'path')),
            $this->normalizePart($this->metaString($meta, 'support_ref')),
            $this->normalizePart($this->metaString($meta, 'reason')),
            $this->normalizePart($this->metaString($meta, 'device_cookie_hash')),
            $this->normalizePart($this->metaString($meta, 'ip_source')),
        ];

        return implode(':', $parts);
    }

    private function dedupeTtlSecondsFor(string $type): int
    {
        return match ($type) {
            'ip_blocked', 'device_blocked', 'identity_blocked', 'login_lockout' => 60,
            'login_failed' => 2,
            default => 5,
        };
    }

    /**
     * @param array<string, mixed> $meta
     */
    private function metaString(array $meta, string $key): ?string
    {
        if (!array_key_exists($key, $meta) || $meta[$key] === null) {
            return null;
        }

        $value = $meta[$key];

        if (is_scalar($value)) {
            return trim((string) $value);
        }

        return null;
    }

    private function normalizePart(?string $value): string
    {
        $value = $value !== null ? mb_strtolower(trim($value)) : '';

        return $value !== '' ? $value : '-';
    }

    private function normalizeMetaPath(mixed $value): mixed
    {
        if (!is_scalar($value)) {
            return $value;
        }

        $path = trim((string) $value);

        if ($path === '') {
            return null;
        }

        $path = trim($path, '/');

        return $path !== '' ? $path : '/';
    }
}