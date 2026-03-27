<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\SecuritySettingsService.php
// Purpose: Ensure deterministic single-row SSOT for security settings
// Changed: 25-03-2026 01:32 (Europe/Berlin)
// Version: 0.3
// ============================================================================

namespace App\Services\Security;

use App\Models\SecuritySetting;
use App\Support\SystemSettingHelper;
use Illuminate\Support\Facades\DB;

class SecuritySettingsService
{
    public function get(): SecuritySetting
    {
        return DB::transaction(function (): SecuritySetting {
            $first = SecuritySetting::query()->lockForUpdate()->orderBy('id')->first();

            if (!$first) {
                return SecuritySetting::query()->create($this->defaults());
            }

            SecuritySetting::query()
                ->where('id', '!=', $first->id)
                ->delete();

            $changed = false;

            foreach ($this->defaults() as $key => $defaultValue) {
                if ($first->{$key} === null) {
                    $first->{$key} = $defaultValue;
                    $changed = true;
                }
            }

            if ($changed) {
                $first->save();
                $first->refresh();
            }

            return $first;
        });
    }

    /**
     * @return array<string, bool|array<string, int|bool>>
     */
    public function getIncidentDetectionSettings(): array
    {
        return [
            'enabled' => (bool) SystemSettingHelper::get('incidents.enabled', true),
            'credential_stuffing' => [
                'enabled' => (bool) SystemSettingHelper::get('incidents.credential_stuffing.enabled', true),
                'window_minutes' => (int) SystemSettingHelper::get('incidents.credential_stuffing.window_minutes', 15),
                'cooldown_minutes' => (int) SystemSettingHelper::get('incidents.credential_stuffing.cooldown_minutes', 60),
                'min_distinct_emails' => (int) SystemSettingHelper::get('incidents.credential_stuffing.min_distinct_emails', 5),
                'min_distinct_ips' => (int) SystemSettingHelper::get('incidents.credential_stuffing.min_distinct_ips', 3),
                'linked_events_limit' => (int) SystemSettingHelper::get('incidents.credential_stuffing.linked_events_limit', 50),
                'meta_sample_limit' => (int) SystemSettingHelper::get('incidents.credential_stuffing.meta_sample_limit', 10),
                'score_base' => (int) SystemSettingHelper::get('incidents.credential_stuffing.score_base', 50),
                'score_max' => (int) SystemSettingHelper::get('incidents.credential_stuffing.score_max', 100),
            ],
            'account_sharing' => [
                'enabled' => (bool) SystemSettingHelper::get('incidents.account_sharing.enabled', true),
                'window_minutes' => (int) SystemSettingHelper::get('incidents.account_sharing.window_minutes', 60),
                'cooldown_minutes' => (int) SystemSettingHelper::get('incidents.account_sharing.cooldown_minutes', 180),
                'min_distinct_devices' => (int) SystemSettingHelper::get('incidents.account_sharing.min_distinct_devices', 3),
                'min_distinct_ips' => (int) SystemSettingHelper::get('incidents.account_sharing.min_distinct_ips', 3),
                'linked_events_limit' => (int) SystemSettingHelper::get('incidents.account_sharing.linked_events_limit', 50),
                'meta_sample_limit' => (int) SystemSettingHelper::get('incidents.account_sharing.meta_sample_limit', 10),
                'score_base' => (int) SystemSettingHelper::get('incidents.account_sharing.score_base', 40),
                'score_max' => (int) SystemSettingHelper::get('incidents.account_sharing.score_max', 100),
            ],
            'bot_pattern' => [
                'enabled' => (bool) SystemSettingHelper::get('incidents.bot_pattern.enabled', true),
                'window_minutes' => (int) SystemSettingHelper::get('incidents.bot_pattern.window_minutes', 5),
                'cooldown_minutes' => (int) SystemSettingHelper::get('incidents.bot_pattern.cooldown_minutes', 30),
                'min_events' => (int) SystemSettingHelper::get('incidents.bot_pattern.min_events', 110),
                'burst_min_events' => (int) SystemSettingHelper::get('incidents.bot_pattern.burst_min_events', 10),
                'burst_min_distinct_emails' => (int) SystemSettingHelper::get('incidents.bot_pattern.burst_min_distinct_emails', 5),
                'burst_min_distinct_ips' => (int) SystemSettingHelper::get('incidents.bot_pattern.burst_min_distinct_ips', 5),
                'linked_events_limit' => (int) SystemSettingHelper::get('incidents.bot_pattern.linked_events_limit', 50),
                'meta_sample_limit' => (int) SystemSettingHelper::get('incidents.bot_pattern.meta_sample_limit', 10),
                'score_base' => (int) SystemSettingHelper::get('incidents.bot_pattern.score_base', 30),
                'score_max' => (int) SystemSettingHelper::get('incidents.bot_pattern.score_max', 100),
            ],
            'device_cluster' => [
                'enabled' => (bool) SystemSettingHelper::get('incidents.device_cluster.enabled', true),
                'window_minutes' => (int) SystemSettingHelper::get('incidents.device_cluster.window_minutes', 120),
                'cooldown_minutes' => (int) SystemSettingHelper::get('incidents.device_cluster.cooldown_minutes', 240),
                'min_events' => (int) SystemSettingHelper::get('incidents.device_cluster.min_events', 18),
                'min_distinct_devices' => (int) SystemSettingHelper::get('incidents.device_cluster.min_distinct_devices', 7),
                'min_distinct_emails' => (int) SystemSettingHelper::get('incidents.device_cluster.min_distinct_emails', 4),
                'min_distinct_ips' => (int) SystemSettingHelper::get('incidents.device_cluster.min_distinct_ips', 4),
                'linked_events_limit' => (int) SystemSettingHelper::get('incidents.device_cluster.linked_events_limit', 100),
                'meta_sample_limit' => (int) SystemSettingHelper::get('incidents.device_cluster.meta_sample_limit', 10),
                'score_base' => (int) SystemSettingHelper::get('incidents.device_cluster.score_base', 60),
                'score_max' => (int) SystemSettingHelper::get('incidents.device_cluster.score_max', 100),
            ],
        ];
    }

    /**
     * @return array<string, bool|array<string, array<string, bool>>>
     */
    public function getIncidentAutoActionSettings(): array
    {
        return [
            'enabled' => (bool) SystemSettingHelper::get('incidents.auto_actions.enabled', false),
            'update_incident_status' => (bool) SystemSettingHelper::get('incidents.auto_actions.update_incident_status', true),
            'credential_stuffing' => [
                'identity_ban_enabled' => (bool) SystemSettingHelper::get('incidents.auto_actions.credential_stuffing.identity_ban_enabled', false),
            ],
            'bot_pattern' => [
                'ip_ban_enabled' => (bool) SystemSettingHelper::get('incidents.auto_actions.bot_pattern.ip_ban_enabled', false),
            ],
            'device_cluster' => [
                'device_ban_enabled' => (bool) SystemSettingHelper::get('incidents.auto_actions.device_cluster.device_ban_enabled', false),
            ],
        ];
    }

    /**
     * @return array<string, int|bool>
     */
    private function defaults(): array
    {
        return [
            'login_attempt_limit' => 8,
            'lockout_seconds' => 900,
            'ip_autoban_enabled' => false,
            'ip_autoban_fail_threshold' => 100,
            'ip_autoban_seconds' => 3600,
            'device_autoban_enabled' => false,
            'device_autoban_fail_threshold' => 100,
            'device_autoban_seconds' => 3600,
            'admin_stricter_limits_enabled' => true,
            'stepup_required_enabled' => true,
        ];
    }
}
