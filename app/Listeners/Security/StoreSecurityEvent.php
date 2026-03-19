<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\Security\StoreSecurityEvent.php
// Purpose: Persist SecurityEventTriggered events into security_events (with minimal de-duplication)
// Changed: 18-03-2026 22:18 (Europe/Berlin)
// Version: 1.1
// ============================================================================

namespace App\Listeners\Security;

use App\Events\Security\SecurityEventTriggered;
use App\Events\Security\SecurityEventStored;
use App\Models\SecurityEvent;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class StoreSecurityEvent
{
    public function handle(SecurityEventTriggered $event): void
    {
        $meta = is_array($event->meta) ? $event->meta : [];
        $runId = $this->resolveRunId($meta);
        $reason = $this->resolveReason($event, $meta);
        $incidentKey = $this->shouldUseIncidentReuse($event->type)
            ? $this->resolveIncidentKey($event)
            : null;

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

        if ($incidentKey !== null) {
            $meta['incident_key'] = $incidentKey;
        }

        $dedupeKey = $this->buildDedupeKey($event, $meta, $runId);
        $dedupeTtlSeconds = $this->dedupeTtlSecondsFor($event->type);
        $existingIncident = $this->findExistingIncident($incidentKey, $dedupeTtlSeconds, $runId);

        if ($existingIncident !== null) {
            $this->updateExistingIncident($existingIncident, $meta, $reason);

            return;
        }

        if (RateLimiter::tooManyAttempts($dedupeKey, 1)) {
            return;
        }

        RateLimiter::hit($dedupeKey, $dedupeTtlSeconds);
        $reference = $this->resolveReference($meta);
        $meta['support_ref'] = $reference;

        $payload = [
            'reference' => $reference,
            'type' => $event->type,
            'ip' => $event->ip,
            'user_id' => $event->userId,
            'email' => $event->email,
            'device_hash' => $event->deviceHash,
            'meta' => $meta,
        ];

        if (Schema::hasColumn('security_events', 'run_id')) {
            $payload['run_id'] = $runId;
        }

        if (Schema::hasColumn('security_events', 'reasons')) {
            $payload['reasons'] = $reason !== null ? [$reason] : [];
        }

        $securityEvent = SecurityEvent::query()->create($payload);

        // EXISTING EVENT DISPATCH
        event(new SecurityEventStored($securityEvent));

        // NEW: DIRECT SYNC CALL (bypasses queue issues)
        app(\App\Listeners\Security\DetectSecurityIncident::class)
            ->handle(new SecurityEventStored($securityEvent));
    }

    /**
     * @param array<string, mixed> $meta
     */
    private function buildDedupeKey(SecurityEventTriggered $event, array $meta, string $runId): string
    {
        $parts = [
            'security:event',
            $this->normalizePart($runId),
            $this->normalizePart($event->type),
            $this->normalizePart($event->ip),
            $event->userId !== null ? (string) (int) $event->userId : '-',
            $this->normalizePart($event->email),
            $this->normalizePart($event->deviceHash),
            $this->normalizePart($this->metaString($meta, 'path')),
            $this->normalizePart($this->metaString($meta, 'incident_key')),
            $this->normalizePart($this->metaString($meta, 'device_cookie_hash')),
            $this->normalizePart($this->metaString($meta, 'ip_source')),
        ];

        return implode(':', $parts);
    }

    private function dedupeTtlSecondsFor(string $type): int
    {
        return match ($type) {
            'ip_blocked', 'email_blocked', 'device_blocked', 'identity_blocked', 'login_lockout' => 600,
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

    private function resolveReason(SecurityEventTriggered $event, array $meta): ?string
    {
        $requestedReason = $this->metaString($meta, 'reason');
        if ($requestedReason !== null && $requestedReason !== '') {
            return $requestedReason;
        }

        return match ($event->type) {
            'ip_blocked' => 'ip_ban',
            'email_blocked' => 'email_ban',
            'identity_blocked' => 'identity_ban',
            'device_blocked' => 'device_ban',
            'login_lockout' => 'lockout',
            default => null,
        };
    }

    private function shouldUseIncidentReuse(string $type): bool
    {
        return in_array($type, [
            'ip_blocked',
            'email_blocked',
            'identity_blocked',
            'device_blocked',
            'login_lockout',
        ], true);
    }

    private function resolveIncidentKey(SecurityEventTriggered $event): ?string
    {
        $email = $event->email !== null ? mb_strtolower(trim($event->email)) : '';
        $ip = $event->ip !== null ? trim($event->ip) : '';
        $deviceHash = $event->deviceHash !== null ? trim($event->deviceHash) : '';

        if ($email === '' && $ip === '' && $deviceHash === '') {
            return null;
        }

        return hash('sha256', implode('|', [
            $email,
            $ip,
            $deviceHash,
        ]));
    }

    private function findExistingIncident(?string $incidentKey, int $dedupeTtlSeconds, string $runId): ?SecurityEvent
    {
        if ($incidentKey === null || $incidentKey === '') {
            return null;
        }

        $query = SecurityEvent::query()
            ->where('meta->incident_key', $incidentKey)
            ->where('created_at', '>=', now()->subSeconds($dedupeTtlSeconds))
            ->latest('id');

        if (Schema::hasColumn('security_events', 'run_id')) {
            $query->where('run_id', $runId);
        }

        return $query->first();
    }

    private function updateExistingIncident(SecurityEvent $existingIncident, array $meta, ?string $reason): void
    {
        $existingMeta = is_array($existingIncident->meta) ? $existingIncident->meta : [];
        $mergedMeta = array_merge($existingMeta, $meta);
        $mergedMeta['support_ref'] = (string) $existingIncident->reference;

        $reasons = is_array($existingIncident->reasons) ? $existingIncident->reasons : [];
        if ($reason !== null && $reason !== '') {
            $reasons[] = $reason;
        }

        $payload = [
            'meta' => $mergedMeta,
        ];

        if (Schema::hasColumn('security_events', 'reasons')) {
            $payload['reasons'] = array_values(array_unique(array_filter(array_map(
                static fn ($value): string => trim((string) $value),
                $reasons
            ), static fn (string $value): bool => $value !== '')));
        }

        $existingIncident->fill($payload)->save();
    }

    /**
     * @param array<string, mixed> $meta
     */
    private function resolveReference(array $meta): string
    {
        do {
            $reference = 'SEC-'.Str::upper(Str::random(8));
        } while ($this->referenceExists($reference));

        return $reference;
    }

    private function referenceExists(string $reference): bool
    {
        if (
            Schema::hasTable('security_events')
            && Schema::hasColumn('security_events', 'reference')
        ) {
            $eventReferenceExists = DB::table('security_events')
                ->where('reference', $reference)
                ->exists();

            if ($eventReferenceExists) {
                return true;
            }
        }

        if (Schema::hasTable('security_support_access_tokens')) {
            return DB::table('security_support_access_tokens')
                ->where('support_reference', $reference)
                ->exists();
        }

        return false;
    }

    /**
     * @param array<string, mixed> $meta
     */
    private function resolveRunId(array $meta): string
    {
        $requestedRunId = $this->metaString($meta, 'run_id');
        if ($requestedRunId !== null && $requestedRunId !== '') {
            return $requestedRunId;
        }

        try {
            if (app()->bound('request')) {
                $request = request();
                $headerRunId = trim((string) $request->header('X-Audit-Run-Id', ''));
                if ($headerRunId !== '') {
                    return $headerRunId;
                }

                $queryRunId = trim((string) $request->query('audit_run_id', $request->query('run_id', '')));
                if ($queryRunId !== '') {
                    return $queryRunId;
                }
            }
        } catch (\Throwable) {
            // no request context
        }

        return '';
    }
}