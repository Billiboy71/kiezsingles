<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\Security\DetectSecurityIncident.php
// Purpose: Passive pattern detection from security_events into security_incidents.
// Created: 18-03-2026 12:18 (Europe/Berlin)
// Changed: 19-03-2026 00:18 (Europe/Berlin)
// Version: 0.5
// ============================================================================

namespace App\Listeners\Security;

use App\Enums\SecurityIncidentType;
use App\Events\Security\SecurityEventStored;
use App\Models\SecurityEvent;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class DetectSecurityIncident
{
    public function handle(SecurityEventStored $event): void
    {
        if (!config('security_incidents.enabled', true)) {
            return;
        }

        if (!Schema::hasTable('security_incidents') || !Schema::hasTable('security_incident_events')) {
            return;
        }

        $securityEvent = $event->securityEvent;
        $runId = $event->securityEvent->run_id ?? null;

        if (!$runId) {
            return;
        }

        if (!($securityEvent->exists) || $securityEvent->getKey() === null) {
            return;
        }

        $this->detectCredentialStuffing($securityEvent, $runId);
        $this->detectAccountSharing($securityEvent, $runId);
        $this->detectBotPattern($securityEvent, $runId);
        $this->detectDeviceCluster($securityEvent, $runId);
    }

    private function detectCredentialStuffing(SecurityEvent $securityEvent, string $runId): void
    {
        $config = config('security_incidents.types.credential_stuffing', []);
        $deviceHash = $this->normalizeNullableString($securityEvent->device_hash);

        if (!$this->isDetectionEnabled($config) || $deviceHash === null) {
            return;
        }

        $query = SecurityEvent::query()
            ->where('run_id', $runId)
            ->where('device_hash', $deviceHash)
            ->where('created_at', '>=', now()->subMinutes($this->intConfig($config, 'window_minutes')));

        $stats = $this->aggregateStats($query, [
            'distinct_emails' => 'email',
            'distinct_ips' => 'ip',
        ]);

        $minDistinctEmails = $this->intConfig($config, 'min_distinct_emails');
        $minDistinctIps = $this->intConfig($config, 'min_distinct_ips');

        if (
            $stats['distinct_emails'] < $minDistinctEmails
            || $stats['distinct_ips'] < $minDistinctIps
        ) {
            return;
        }

        $eventIds = $this->eventIds($query, $this->intConfig($config, 'linked_events_limit'));
        $score = $this->scoreFromStats($config, [
            'total_events' => $stats['total_events'],
            'distinct_emails' => $stats['distinct_emails'],
            'distinct_ips' => $stats['distinct_ips'],
        ], [
            'distinct_emails' => $minDistinctEmails,
            'distinct_ips' => $minDistinctIps,
        ]);

        $meta = [
            'window_minutes' => $this->intConfig($config, 'window_minutes'),
            'thresholds' => [
                'min_distinct_emails' => $minDistinctEmails,
                'min_distinct_ips' => $minDistinctIps,
            ],
            'matched_on' => [
                'device_hash' => $deviceHash,
            ],
            'stats' => [
                'total_events' => $stats['total_events'],
                'distinct_emails' => $stats['distinct_emails'],
                'distinct_ips' => $stats['distinct_ips'],
            ],
            'samples' => [
                'emails' => $this->sampleDistinctValues($query, 'email', $this->intConfig($config, 'meta_sample_limit')),
                'ips' => $this->sampleDistinctValues($query, 'ip', $this->intConfig($config, 'meta_sample_limit')),
            ],
        ];

        $this->storeIncident(
            SecurityIncidentType::CredentialStuffing,
            $deviceHash,
            null,
            null,
            $score,
            $meta,
            $eventIds,
            $this->intConfig($config, 'cooldown_minutes')
        );
    }

    private function detectAccountSharing(SecurityEvent $securityEvent, string $runId): void
    {
        $config = config('security_incidents.types.account_sharing', []);
        $contactEmail = $this->normalizeEmail($securityEvent->email);

        if (!$this->isDetectionEnabled($config) || $contactEmail === null) {
            return;
        }

        $query = SecurityEvent::query()
            ->where('run_id', $runId)
            ->where('email', $contactEmail)
            ->where('created_at', '>=', now()->subMinutes($this->intConfig($config, 'window_minutes')));

        $stats = $this->aggregateStats($query, [
            'distinct_devices' => 'device_hash',
            'distinct_ips' => 'ip',
        ]);

        $minDistinctDevices = $this->intConfig($config, 'min_distinct_devices');
        $minDistinctIps = $this->intConfig($config, 'min_distinct_ips');

        if (
            $stats['distinct_devices'] < $minDistinctDevices
            || $stats['distinct_ips'] < $minDistinctIps
        ) {
            return;
        }

        $eventIds = $this->eventIds($query, $this->intConfig($config, 'linked_events_limit'));
        $score = $this->scoreFromStats($config, [
            'total_events' => $stats['total_events'],
            'distinct_devices' => $stats['distinct_devices'],
            'distinct_ips' => $stats['distinct_ips'],
        ], [
            'distinct_devices' => $minDistinctDevices,
            'distinct_ips' => $minDistinctIps,
        ]);

        $meta = [
            'window_minutes' => $this->intConfig($config, 'window_minutes'),
            'thresholds' => [
                'min_distinct_devices' => $minDistinctDevices,
                'min_distinct_ips' => $minDistinctIps,
            ],
            'matched_on' => [
                'contact_email' => $contactEmail,
            ],
            'stats' => [
                'total_events' => $stats['total_events'],
                'distinct_devices' => $stats['distinct_devices'],
                'distinct_ips' => $stats['distinct_ips'],
            ],
            'samples' => [
                'device_hashes' => $this->sampleDistinctValues($query, 'device_hash', $this->intConfig($config, 'meta_sample_limit')),
                'ips' => $this->sampleDistinctValues($query, 'ip', $this->intConfig($config, 'meta_sample_limit')),
            ],
        ];

        $this->storeIncident(
            SecurityIncidentType::AccountSharing,
            null,
            $contactEmail,
            null,
            $score,
            $meta,
            $eventIds,
            $this->intConfig($config, 'cooldown_minutes')
        );
    }

    private function detectBotPattern(SecurityEvent $securityEvent, string $runId): void
    {
        $config = config('security_incidents.types.bot_pattern', []);
        $deviceHash = $this->normalizeNullableString($securityEvent->device_hash);
        $ip = $this->normalizeNullableString($securityEvent->ip);

        if (!$this->isDetectionEnabled($config) || ($deviceHash === null && $ip === null)) {
            return;
        }

        $query = SecurityEvent::query()
            ->where('run_id', $runId)
            ->where('created_at', '>=', now()->subMinutes($this->intConfig($config, 'window_minutes')));

        $minEvents = $this->intConfig($config, 'min_events');

        if ($deviceHash !== null) {
            $query->where('device_hash', $deviceHash);

            $deviceStats = $this->aggregateStats($query, [
                'distinct_types' => 'type',
            ]);

            if ($deviceStats['total_events'] < $minEvents && $ip !== null) {
                $query = SecurityEvent::query()
                    ->where('run_id', $runId)
                    ->where('created_at', '>=', now()->subMinutes($this->intConfig($config, 'window_minutes')))
                    ->where('ip', $ip);
            }
        } else {
            $query->where('ip', $ip);
        }

        $stats = $this->aggregateStats($query, [
            'distinct_types' => 'type',
        ]);

        if ($stats['total_events'] < $minEvents) {
            return;
        }

        $eventIds = $this->eventIds($query, $this->intConfig($config, 'linked_events_limit'));
        $score = $this->scoreFromStats($config, [
            'total_events' => $stats['total_events'],
            'distinct_types' => $stats['distinct_types'],
        ], [
            'total_events' => $minEvents,
        ]);

        $meta = [
            'window_minutes' => $this->intConfig($config, 'window_minutes'),
            'thresholds' => [
                'min_events' => $minEvents,
            ],
            'matched_on' => [
                'device_hash' => $deviceHash,
                'ip' => $ip,
            ],
            'stats' => [
                'total_events' => $stats['total_events'],
                'distinct_types' => $stats['distinct_types'],
            ],
            'samples' => [
                'types' => $this->sampleDistinctValues($query, 'type', $this->intConfig($config, 'meta_sample_limit')),
            ],
        ];

        $this->storeIncident(
            SecurityIncidentType::BotPattern,
            $deviceHash,
            null,
            $ip,
            $score,
            $meta,
            $eventIds,
            $this->intConfig($config, 'cooldown_minutes')
        );
    }

    private function detectDeviceCluster(SecurityEvent $securityEvent, string $runId): void
    {
        $config = config('security_incidents.types.device_cluster', []);
        $deviceHash = $this->normalizeNullableString($securityEvent->device_hash);
        $contactEmail = $this->normalizeEmail($securityEvent->email);
        $ip = $this->normalizeNullableString($securityEvent->ip);

        if (
            !$this->isDetectionEnabled($config)
            || ($deviceHash === null && $contactEmail === null && $ip === null)
        ) {
            return;
        }

        $query = SecurityEvent::query()
            ->where('run_id', $runId)
            ->where('created_at', '>=', now()->subMinutes($this->intConfig($config, 'window_minutes')))
            ->where(function ($builder) use ($deviceHash, $contactEmail, $ip): void {
                if ($deviceHash !== null) {
                    $builder->orWhere('device_hash', $deviceHash);
                }

                if ($contactEmail !== null) {
                    $builder->orWhere('email', $contactEmail);
                }

                if ($ip !== null) {
                    $builder->orWhere('ip', $ip);
                }
            });

        $stats = $this->aggregateStats($query, [
            'distinct_devices' => 'device_hash',
            'distinct_emails' => 'email',
            'distinct_ips' => 'ip',
        ]);

        $minDistinctDevices = $this->intConfig($config, 'min_distinct_devices');
        $minDistinctEmails = $this->intConfig($config, 'min_distinct_emails');
        $minDistinctIps = $this->intConfig($config, 'min_distinct_ips');
        $minEvents = $this->intConfig($config, 'min_events');
        $eventsPerDevice = $stats['distinct_devices'] > 0
            ? ((float) $stats['total_events'] / (float) $stats['distinct_devices'])
            : 0.0;

        if (
            $stats['distinct_devices'] < $minDistinctDevices
            || $stats['distinct_emails'] < $minDistinctEmails
            || $stats['distinct_ips'] < $minDistinctIps
            || $stats['total_events'] < $minEvents
            || $eventsPerDevice < 3.0
        ) {
            return;
        }

        $eventIds = $this->eventIds($query, $this->intConfig($config, 'linked_events_limit'));
        $score = $this->scoreFromStats($config, [
            'total_events' => $stats['total_events'],
            'distinct_devices' => $stats['distinct_devices'],
            'distinct_emails' => $stats['distinct_emails'],
            'distinct_ips' => $stats['distinct_ips'],
        ], [
            'total_events' => $minEvents,
            'distinct_devices' => $minDistinctDevices,
            'distinct_emails' => $minDistinctEmails,
            'distinct_ips' => $minDistinctIps,
        ]);

        $meta = [
            'window_minutes' => $this->intConfig($config, 'window_minutes'),
            'thresholds' => [
                'min_events' => $minEvents,
                'min_distinct_devices' => $minDistinctDevices,
                'min_distinct_emails' => $minDistinctEmails,
                'min_distinct_ips' => $minDistinctIps,
                'min_events_per_device' => 3.0,
            ],
            'matched_on' => [
                'device_hash' => $deviceHash,
                'contact_email' => $contactEmail,
                'ip' => $ip,
            ],
            'stats' => [
                'total_events' => $stats['total_events'],
                'distinct_devices' => $stats['distinct_devices'],
                'distinct_emails' => $stats['distinct_emails'],
                'distinct_ips' => $stats['distinct_ips'],
                'events_per_device' => $eventsPerDevice,
            ],
            'samples' => [
                'device_hashes' => $this->sampleDistinctValues($query, 'device_hash', $this->intConfig($config, 'meta_sample_limit')),
                'emails' => $this->sampleDistinctValues($query, 'email', $this->intConfig($config, 'meta_sample_limit')),
                'ips' => $this->sampleDistinctValues($query, 'ip', $this->intConfig($config, 'meta_sample_limit')),
            ],
        ];

        $this->storeIncident(
            SecurityIncidentType::DeviceCluster,
            $deviceHash,
            $contactEmail,
            $ip,
            $score,
            $meta,
            $eventIds,
            $this->intConfig($config, 'cooldown_minutes')
        );
    }

    /**
     * @param array<string, mixed> $config
     */
    private function isDetectionEnabled(array $config): bool
    {
        return (bool) ($config['enabled'] ?? true);
    }

    /**
     * @param array<string, mixed> $config
     */
    private function intConfig(array $config, string $key): int
    {
        return max(0, (int) ($config[$key] ?? 0));
    }

    /**
     * @param array<string, string> $distinctColumns
     * @return array<string, int>
     */
    private function aggregateStats($query, array $distinctColumns): array
    {
        $stats = [
            'total_events' => (clone $query)->count(),
        ];

        foreach ($distinctColumns as $label => $column) {
            $stats[$label] = (clone $query)
                ->whereNotNull($column)
                ->where($column, '!=', '')
                ->distinct($column)
                ->count($column);
        }

        return $stats;
    }

    /**
     * @param array<string, int> $stats
     * @param array<string, int> $thresholds
     */
    private function scoreFromStats(array $config, array $stats, array $thresholds): int
    {
        $score = $this->intConfig($config, 'score_base');

        foreach ($stats as $key => $value) {
            $score += max(0, $value - (int) ($thresholds[$key] ?? 0));
        }

        $maxScore = $this->intConfig($config, 'score_max');

        if ($maxScore > 0) {
            return min($score, $maxScore);
        }

        return $score;
    }

    /**
     * @return list<int>
     */
    private function eventIds($query, int $limit): array
    {
        return (clone $query)
            ->orderByDesc('id')
            ->limit(max(1, $limit))
            ->pluck('id')
            ->map(static fn ($value): int => (int) $value)
            ->filter(static fn (int $value): bool => $value > 0)
            ->unique()
            ->values()
            ->all();
    }

    /**
     * @return list<string>
     */
    private function sampleDistinctValues($query, string $column, int $limit): array
    {
        return (clone $query)
            ->whereNotNull($column)
            ->where($column, '!=', '')
            ->distinct()
            ->orderBy($column)
            ->limit(max(1, $limit))
            ->pluck($column)
            ->map(function ($value) use ($column): ?string {
                if (!is_scalar($value)) {
                    return null;
                }

                if ($column === 'email') {
                    return $this->normalizeEmail((string) $value);
                }

                return $this->normalizeNullableString((string) $value);
            })
            ->filter(static fn (?string $value): bool => $value !== null)
            ->values()
            ->all();
    }

    /**
     * @param array<string, mixed> $meta
     * @param list<int> $eventIds
     */
    private function storeIncident(
        SecurityIncidentType $type,
        ?string $deviceHash,
        ?string $contactEmail,
        ?string $ip,
        int $score,
        array $meta,
        array $eventIds,
        int $cooldownMinutes,
    ): void {
        if ($eventIds === []) {
            return;
        }

        $existingIncidentId = $this->recentIncidentId(
            $type,
            $deviceHash,
            $contactEmail,
            $ip,
            $cooldownMinutes
        );

        if ($existingIncidentId !== null) {
            $this->attachIncidentEvents($existingIncidentId, $eventIds);

            return;
        }

        $incidentId = DB::table('security_incidents')->insertGetId([
            'type' => $type->value,
            'device_hash' => $deviceHash,
            'contact_email' => $contactEmail,
            'ip' => $ip,
            'score' => $score,
            'meta' => $this->encodeMeta($meta),
            'created_at' => now(),
        ]);

        $this->attachIncidentEvents((int) $incidentId, $eventIds);
    }

    private function recentIncidentId(
        SecurityIncidentType $type,
        ?string $deviceHash,
        ?string $contactEmail,
        ?string $ip,
        int $cooldownMinutes,
    ): ?int {
        $query = DB::table('security_incidents')
            ->where('type', $type->value)
            ->where('created_at', '>=', now()->subMinutes(max(1, $cooldownMinutes)));

        if ($deviceHash === null) {
            $query->whereNull('device_hash');
        } else {
            $query->where('device_hash', $deviceHash);
        }

        if ($contactEmail === null) {
            $query->whereNull('contact_email');
        } else {
            $query->where('contact_email', $contactEmail);
        }

        if ($ip === null) {
            $query->whereNull('ip');
        } else {
            $query->where('ip', $ip);
        }

        $incidentId = $query->orderByDesc('id')->value('id');

        return $incidentId !== null ? (int) $incidentId : null;
    }

    /**
     * @param list<int> $eventIds
     */
    private function attachIncidentEvents(int $incidentId, array $eventIds): void
    {
        $rows = [];

        foreach ($eventIds as $eventId) {
            $rows[] = [
                'incident_id' => $incidentId,
                'security_event_id' => $eventId,
            ];
        }

        if ($rows !== []) {
            DB::table('security_incident_events')->insertOrIgnore($rows);
        }
    }

    /**
     * @param array<string, mixed> $meta
     */
    private function encodeMeta(array $meta): string
    {
        $encoded = json_encode($meta, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        return is_string($encoded) ? $encoded : '{}';
    }

    private function normalizeNullableString(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $normalized = trim($value);

        return $normalized !== '' ? $normalized : null;
    }

    private function normalizeEmail(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $normalized = mb_strtolower(trim($value));

        return $normalized !== '' ? $normalized : null;
    }
}
