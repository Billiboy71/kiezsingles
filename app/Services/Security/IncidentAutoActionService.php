<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\IncidentAutoActionService.php
// Purpose: Store optional automatic action suggestions for detected security incidents
// Changed: 25-03-2026 02:01 (Europe/Berlin)
// Version: 0.4
// ============================================================================

namespace App\Services\Security;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class IncidentAutoActionService
{
    public function __construct(
        private readonly SecuritySettingsService $securitySettingsService,
    ) {}

    public function handle(int $incidentId): void
    {
        if (!Schema::hasTable('security_incidents')) {
            return;
        }

        $settings = $this->securitySettingsService->getIncidentAutoActionSettings();

        if (!($settings['enabled'] ?? false)) {
            return;
        }

        $incident = DB::table('security_incidents')->where('id', $incidentId)->first();

        if ($incident === null) {
            return;
        }

        $details = [];

        if (
            $incident->type === 'credential_stuffing'
            && ($settings['credential_stuffing']['identity_ban_enabled'] ?? false)
            && Schema::hasTable('security_identity_bans')
        ) {
            $email = $this->topIncidentEmail($incidentId);

            if ($email !== null && !$this->hasActiveIdentityBan($email)) {
                $details[] = 'identity';
            }
        }

        if (
            $incident->type === 'bot_pattern'
            && ($settings['bot_pattern']['ip_ban_enabled'] ?? false)
            && Schema::hasTable('security_ip_bans')
        ) {
            $ip = $this->topIncidentIp($incidentId);

            if ($ip !== null && !$this->hasActiveIpBan($ip)) {
                $details[] = 'ip';
            }
        }

        if (
            $incident->type === 'device_cluster'
            && ($settings['device_cluster']['device_ban_enabled'] ?? false)
            && Schema::hasTable('security_device_bans')
        ) {
            $deviceHash = $this->topIncidentDeviceHash($incidentId);

            if ($deviceHash !== null && !$this->hasActiveDeviceBan($deviceHash)) {
                $details[] = 'device';
            }
        }

        $incidentUpdatePayload = [];

        if (Schema::hasColumn('security_incidents', 'auto_action_executed')) {
            $incidentUpdatePayload['auto_action_executed'] = false;
        }

        if (Schema::hasColumn('security_incidents', 'auto_action_details')) {
            $normalizedDetails = array_values(array_unique($details));
            $incidentUpdatePayload['auto_action_details'] = $normalizedDetails === []
                ? null
                : json_encode($normalizedDetails, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }

        if ($incidentUpdatePayload !== []) {
            DB::table('security_incidents')
                ->where('id', $incidentId)
                ->update($incidentUpdatePayload);
        }
    }

    private function topIncidentEmail(int $incidentId): ?string
    {
        $value = DB::table('security_incident_events')
            ->join('security_events', 'security_events.id', '=', 'security_incident_events.security_event_id')
            ->where('security_incident_events.incident_id', $incidentId)
            ->whereNotNull('security_events.email')
            ->where('security_events.email', '!=', '')
            ->select('security_events.email', DB::raw('COUNT(*) as count'))
            ->groupBy('security_events.email')
            ->orderByDesc('count')
            ->value('security_events.email');

        return is_string($value) && trim($value) !== '' ? trim($value) : null;
    }

    private function topIncidentIp(int $incidentId): ?string
    {
        $value = DB::table('security_incident_events')
            ->join('security_events', 'security_events.id', '=', 'security_incident_events.security_event_id')
            ->where('security_incident_events.incident_id', $incidentId)
            ->whereNotNull('security_events.ip')
            ->where('security_events.ip', '!=', '')
            ->select('security_events.ip', DB::raw('COUNT(*) as count'))
            ->groupBy('security_events.ip')
            ->orderByDesc('count')
            ->value('security_events.ip');

        return is_string($value) && trim($value) !== '' ? trim($value) : null;
    }

    private function topIncidentDeviceHash(int $incidentId): ?string
    {
        $value = DB::table('security_incident_events')
            ->join('security_events', 'security_events.id', '=', 'security_incident_events.security_event_id')
            ->where('security_incident_events.incident_id', $incidentId)
            ->whereNotNull('security_events.device_hash')
            ->where('security_events.device_hash', '!=', '')
            ->select('security_events.device_hash', DB::raw('COUNT(*) as count'))
            ->groupBy('security_events.device_hash')
            ->orderByDesc('count')
            ->value('security_events.device_hash');

        return is_string($value) && trim($value) !== '' ? trim($value) : null;
    }

    private function hasActiveIdentityBan(string $email): bool
    {
        return DB::table('security_identity_bans')
            ->where('email', mb_strtolower(trim($email)))
            ->where(function ($query): void {
                $query->whereNull('banned_until')
                    ->orWhere('banned_until', '>=', now());
            })
            ->exists();
    }

    private function hasActiveIpBan(string $ip): bool
    {
        return DB::table('security_ip_bans')
            ->where('ip', trim($ip))
            ->where(function ($query): void {
                $query->whereNull('banned_until')
                    ->orWhere('banned_until', '>=', now());
            })
            ->exists();
    }

    private function hasActiveDeviceBan(string $deviceHash): bool
    {
        return DB::table('security_device_bans')
            ->where('device_hash', trim($deviceHash))
            ->where('is_active', true)
            ->whereNull('revoked_at')
            ->where(function ($query): void {
                $query->whereNull('banned_until')
                    ->orWhere('banned_until', '>=', now());
            })
            ->exists();
    }
}
