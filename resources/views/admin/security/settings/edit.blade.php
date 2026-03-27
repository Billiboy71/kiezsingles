<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\settings\edit.blade.php
// Purpose: Admin Security - Security settings (SSOT configuration)
// Changed: 25-03-2026 01:32 (Europe/Berlin)
// Version: 0.4
// ============================================================================

?>
@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    @if(session('admin_notice'))
        <div class="ks-notice p-3 rounded-lg border mb-3">{{ session('admin_notice') }}</div>
    @endif

    <form method="POST" action="{{ route('admin.security.settings.update') }}" class="ks-card grid grid-cols-1 md:grid-cols-2 gap-3">
        @csrf
        @method('PUT')
        <div class="md:col-span-2 flex items-start justify-between gap-3">
            <h3>Sicherheits-Einstellungen</h3>
            <x-ui.help-popover id="security-settings-help" title="Hilfe: Einstellungen">
                <ul>
                    <li>Max. Fehlversuche (Login): zulässige Fehlversuche pro Kombination aus IP und E-Mail.</li>
                    <li>Sperrdauer (Sekunden): Dauer der Sperre, nachdem das Limit erreicht wurde.</li>
                    <li>Automatische IP-Sperre aktiv / Fehlversuche bis IP-Sperre / Dauer der IP-Sperre (Sekunden): Steuerung der Auto-Sperre bei Missbrauch.</li>
                    <li>Automatische Geräte-Sperre aktiv / Fehlversuche bis Geräte-Sperre / Dauer der Geräte-Sperre (Sekunden): Auto-Sperre auf Geräte-Hash-Basis.</li>
                    <li>Strengere Regeln für Admins aktiv: schärfere Limits für sensible Admin-Pfade.</li>
                    <li>Zusätzliche Bestätigung erforderlich (Step-Up): Passwort-Bestätigung für kritische Admin-Aktionen.</li>
                    <li>Alle Änderungen wirken serverseitig sofort und löschen keine bestehenden Ereignisse oder Sperren.</li>
                </ul>
            </x-ui.help-popover>
        </div>

        <div>
            <label>Max. Fehlversuche (Login)</label>
            <input class="w-full" type="number" min="1" name="login_attempt_limit"
                   value="{{ old('login_attempt_limit', $settings->login_attempt_limit) }}" required>
        </div>

        <div>
            <label>Sperrdauer (Sekunden)</label>
            <input class="w-full" type="number" min="10" name="lockout_seconds"
                   value="{{ old('lockout_seconds', $settings->lockout_seconds) }}" required>
        </div>

        <div>
            <label>Fehlversuche bis IP-Sperre</label>
            <input class="w-full" type="number" min="1" name="ip_autoban_fail_threshold"
                   value="{{ old('ip_autoban_fail_threshold', $settings->ip_autoban_fail_threshold) }}" required>
        </div>

        <div>
            <label>Dauer der IP-Sperre (Sekunden)</label>
            <input class="w-full" type="number" min="60" name="ip_autoban_seconds"
                   value="{{ old('ip_autoban_seconds', $settings->ip_autoban_seconds) }}" required>
        </div>

        <div>
            <label>Fehlversuche bis Geräte-Sperre</label>
            <input class="w-full" type="number" min="1" name="device_autoban_fail_threshold"
                   value="{{ old('device_autoban_fail_threshold', $settings->device_autoban_fail_threshold) }}" required>
        </div>

        <div>
            <label>Dauer der Geräte-Sperre (Sekunden)</label>
            <input class="w-full" type="number" min="60" name="device_autoban_seconds"
                   value="{{ old('device_autoban_seconds', $settings->device_autoban_seconds) }}" required>
        </div>

        <label>
            <input type="checkbox" name="ip_autoban_enabled" value="1"
                {{ old('ip_autoban_enabled', $settings->ip_autoban_enabled) ? 'checked' : '' }}>
            Automatische IP-Sperre aktiv
        </label>

        <label>
            <input type="checkbox" name="device_autoban_enabled" value="1"
                {{ old('device_autoban_enabled', $settings->device_autoban_enabled) ? 'checked' : '' }}>
            Automatische Geräte-Sperre aktiv
        </label>

        <label>
            <input type="checkbox" name="admin_stricter_limits_enabled" value="1"
                {{ old('admin_stricter_limits_enabled', $settings->admin_stricter_limits_enabled) ? 'checked' : '' }}>
            Strengere Regeln für Admins aktiv
        </label>

        <label>
            <input type="checkbox" name="stepup_required_enabled" value="1"
                {{ old('stepup_required_enabled', $settings->stepup_required_enabled) ? 'checked' : '' }}>
            Zusätzliche Bestätigung erforderlich (Step-Up)
        </label>

        <div class="md:col-span-2 mt-4">
            <h4>Incident Detection</h4>
        </div>

        <label class="md:col-span-2">
            <input type="checkbox" name="incidents_enabled" value="1"
                {{ old('incidents_enabled', $incidentDetectionSettings['enabled']) ? 'checked' : '' }}>
            Incident Detection aktiv
        </label>

        <div class="md:col-span-2 font-semibold">Credential Stuffing</div>
        <label>
            <input type="checkbox" name="incident_credential_stuffing_enabled" value="1"
                {{ old('incident_credential_stuffing_enabled', $incidentDetectionSettings['credential_stuffing']['enabled']) ? 'checked' : '' }}>
            Aktiv
        </label>
        <div>
            <label>Fenster (Minuten)</label>
            <input class="w-full" type="number" min="1" name="incident_credential_stuffing_window_minutes" value="{{ old('incident_credential_stuffing_window_minutes', $incidentDetectionSettings['credential_stuffing']['window_minutes']) }}" required>
        </div>
        <div>
            <label>Cooldown (Minuten)</label>
            <input class="w-full" type="number" min="1" name="incident_credential_stuffing_cooldown_minutes" value="{{ old('incident_credential_stuffing_cooldown_minutes', $incidentDetectionSettings['credential_stuffing']['cooldown_minutes']) }}" required>
        </div>
        <div>
            <label>Min. unterschiedliche E-Mails</label>
            <input class="w-full" type="number" min="1" name="incident_credential_stuffing_min_distinct_emails" value="{{ old('incident_credential_stuffing_min_distinct_emails', $incidentDetectionSettings['credential_stuffing']['min_distinct_emails']) }}" required>
        </div>
        <div>
            <label>Min. unterschiedliche IPs</label>
            <input class="w-full" type="number" min="1" name="incident_credential_stuffing_min_distinct_ips" value="{{ old('incident_credential_stuffing_min_distinct_ips', $incidentDetectionSettings['credential_stuffing']['min_distinct_ips']) }}" required>
        </div>
        <div>
            <label>Linked Events Limit</label>
            <input class="w-full" type="number" min="1" name="incident_credential_stuffing_linked_events_limit" value="{{ old('incident_credential_stuffing_linked_events_limit', $incidentDetectionSettings['credential_stuffing']['linked_events_limit']) }}" required>
        </div>
        <div>
            <label>Meta Sample Limit</label>
            <input class="w-full" type="number" min="1" name="incident_credential_stuffing_meta_sample_limit" value="{{ old('incident_credential_stuffing_meta_sample_limit', $incidentDetectionSettings['credential_stuffing']['meta_sample_limit']) }}" required>
        </div>
        <div>
            <label>Score Base</label>
            <input class="w-full" type="number" min="0" name="incident_credential_stuffing_score_base" value="{{ old('incident_credential_stuffing_score_base', $incidentDetectionSettings['credential_stuffing']['score_base']) }}" required>
        </div>
        <div>
            <label>Score Max</label>
            <input class="w-full" type="number" min="0" name="incident_credential_stuffing_score_max" value="{{ old('incident_credential_stuffing_score_max', $incidentDetectionSettings['credential_stuffing']['score_max']) }}" required>
        </div>

        <div class="md:col-span-2 font-semibold">Account Sharing</div>
        <label>
            <input type="checkbox" name="incident_account_sharing_enabled" value="1"
                {{ old('incident_account_sharing_enabled', $incidentDetectionSettings['account_sharing']['enabled']) ? 'checked' : '' }}>
            Aktiv
        </label>
        <div>
            <label>Fenster (Minuten)</label>
            <input class="w-full" type="number" min="1" name="incident_account_sharing_window_minutes" value="{{ old('incident_account_sharing_window_minutes', $incidentDetectionSettings['account_sharing']['window_minutes']) }}" required>
        </div>
        <div>
            <label>Cooldown (Minuten)</label>
            <input class="w-full" type="number" min="1" name="incident_account_sharing_cooldown_minutes" value="{{ old('incident_account_sharing_cooldown_minutes', $incidentDetectionSettings['account_sharing']['cooldown_minutes']) }}" required>
        </div>
        <div>
            <label>Min. unterschiedliche Geräte</label>
            <input class="w-full" type="number" min="1" name="incident_account_sharing_min_distinct_devices" value="{{ old('incident_account_sharing_min_distinct_devices', $incidentDetectionSettings['account_sharing']['min_distinct_devices']) }}" required>
        </div>
        <div>
            <label>Min. unterschiedliche IPs</label>
            <input class="w-full" type="number" min="1" name="incident_account_sharing_min_distinct_ips" value="{{ old('incident_account_sharing_min_distinct_ips', $incidentDetectionSettings['account_sharing']['min_distinct_ips']) }}" required>
        </div>
        <div>
            <label>Linked Events Limit</label>
            <input class="w-full" type="number" min="1" name="incident_account_sharing_linked_events_limit" value="{{ old('incident_account_sharing_linked_events_limit', $incidentDetectionSettings['account_sharing']['linked_events_limit']) }}" required>
        </div>
        <div>
            <label>Meta Sample Limit</label>
            <input class="w-full" type="number" min="1" name="incident_account_sharing_meta_sample_limit" value="{{ old('incident_account_sharing_meta_sample_limit', $incidentDetectionSettings['account_sharing']['meta_sample_limit']) }}" required>
        </div>
        <div>
            <label>Score Base</label>
            <input class="w-full" type="number" min="0" name="incident_account_sharing_score_base" value="{{ old('incident_account_sharing_score_base', $incidentDetectionSettings['account_sharing']['score_base']) }}" required>
        </div>
        <div>
            <label>Score Max</label>
            <input class="w-full" type="number" min="0" name="incident_account_sharing_score_max" value="{{ old('incident_account_sharing_score_max', $incidentDetectionSettings['account_sharing']['score_max']) }}" required>
        </div>

        <div class="md:col-span-2 font-semibold">Bot Pattern</div>
        <label>
            <input type="checkbox" name="incident_bot_pattern_enabled" value="1"
                {{ old('incident_bot_pattern_enabled', $incidentDetectionSettings['bot_pattern']['enabled']) ? 'checked' : '' }}>
            Aktiv
        </label>
        <div>
            <label>Fenster (Minuten)</label>
            <input class="w-full" type="number" min="1" name="incident_bot_pattern_window_minutes" value="{{ old('incident_bot_pattern_window_minutes', $incidentDetectionSettings['bot_pattern']['window_minutes']) }}" required>
        </div>
        <div>
            <label>Cooldown (Minuten)</label>
            <input class="w-full" type="number" min="1" name="incident_bot_pattern_cooldown_minutes" value="{{ old('incident_bot_pattern_cooldown_minutes', $incidentDetectionSettings['bot_pattern']['cooldown_minutes']) }}" required>
        </div>
        <div>
            <label>Min. Events</label>
            <input class="w-full" type="number" min="1" name="incident_bot_pattern_min_events" value="{{ old('incident_bot_pattern_min_events', $incidentDetectionSettings['bot_pattern']['min_events']) }}" required>
        </div>
        <div>
            <label>Burst Min. Events</label>
            <input class="w-full" type="number" min="1" name="incident_bot_pattern_burst_min_events" value="{{ old('incident_bot_pattern_burst_min_events', $incidentDetectionSettings['bot_pattern']['burst_min_events']) }}" required>
        </div>
        <div>
            <label>Burst Min. unterschiedliche E-Mails</label>
            <input class="w-full" type="number" min="1" name="incident_bot_pattern_burst_min_distinct_emails" value="{{ old('incident_bot_pattern_burst_min_distinct_emails', $incidentDetectionSettings['bot_pattern']['burst_min_distinct_emails']) }}" required>
        </div>
        <div>
            <label>Burst Min. unterschiedliche IPs</label>
            <input class="w-full" type="number" min="1" name="incident_bot_pattern_burst_min_distinct_ips" value="{{ old('incident_bot_pattern_burst_min_distinct_ips', $incidentDetectionSettings['bot_pattern']['burst_min_distinct_ips']) }}" required>
        </div>
        <div>
            <label>Linked Events Limit</label>
            <input class="w-full" type="number" min="1" name="incident_bot_pattern_linked_events_limit" value="{{ old('incident_bot_pattern_linked_events_limit', $incidentDetectionSettings['bot_pattern']['linked_events_limit']) }}" required>
        </div>
        <div>
            <label>Meta Sample Limit</label>
            <input class="w-full" type="number" min="1" name="incident_bot_pattern_meta_sample_limit" value="{{ old('incident_bot_pattern_meta_sample_limit', $incidentDetectionSettings['bot_pattern']['meta_sample_limit']) }}" required>
        </div>
        <div>
            <label>Score Base</label>
            <input class="w-full" type="number" min="0" name="incident_bot_pattern_score_base" value="{{ old('incident_bot_pattern_score_base', $incidentDetectionSettings['bot_pattern']['score_base']) }}" required>
        </div>
        <div>
            <label>Score Max</label>
            <input class="w-full" type="number" min="0" name="incident_bot_pattern_score_max" value="{{ old('incident_bot_pattern_score_max', $incidentDetectionSettings['bot_pattern']['score_max']) }}" required>
        </div>

        <div class="md:col-span-2 font-semibold">Device Cluster</div>
        <label>
            <input type="checkbox" name="incident_device_cluster_enabled" value="1"
                {{ old('incident_device_cluster_enabled', $incidentDetectionSettings['device_cluster']['enabled']) ? 'checked' : '' }}>
            Aktiv
        </label>
        <div>
            <label>Fenster (Minuten)</label>
            <input class="w-full" type="number" min="1" name="incident_device_cluster_window_minutes" value="{{ old('incident_device_cluster_window_minutes', $incidentDetectionSettings['device_cluster']['window_minutes']) }}" required>
        </div>
        <div>
            <label>Cooldown (Minuten)</label>
            <input class="w-full" type="number" min="1" name="incident_device_cluster_cooldown_minutes" value="{{ old('incident_device_cluster_cooldown_minutes', $incidentDetectionSettings['device_cluster']['cooldown_minutes']) }}" required>
        </div>
        <div>
            <label>Min. Events</label>
            <input class="w-full" type="number" min="1" name="incident_device_cluster_min_events" value="{{ old('incident_device_cluster_min_events', $incidentDetectionSettings['device_cluster']['min_events']) }}" required>
        </div>
        <div>
            <label>Min. unterschiedliche Geräte</label>
            <input class="w-full" type="number" min="1" name="incident_device_cluster_min_distinct_devices" value="{{ old('incident_device_cluster_min_distinct_devices', $incidentDetectionSettings['device_cluster']['min_distinct_devices']) }}" required>
        </div>
        <div>
            <label>Min. unterschiedliche E-Mails</label>
            <input class="w-full" type="number" min="1" name="incident_device_cluster_min_distinct_emails" value="{{ old('incident_device_cluster_min_distinct_emails', $incidentDetectionSettings['device_cluster']['min_distinct_emails']) }}" required>
        </div>
        <div>
            <label>Min. unterschiedliche IPs</label>
            <input class="w-full" type="number" min="1" name="incident_device_cluster_min_distinct_ips" value="{{ old('incident_device_cluster_min_distinct_ips', $incidentDetectionSettings['device_cluster']['min_distinct_ips']) }}" required>
        </div>
        <div>
            <label>Linked Events Limit</label>
            <input class="w-full" type="number" min="1" name="incident_device_cluster_linked_events_limit" value="{{ old('incident_device_cluster_linked_events_limit', $incidentDetectionSettings['device_cluster']['linked_events_limit']) }}" required>
        </div>
        <div>
            <label>Meta Sample Limit</label>
            <input class="w-full" type="number" min="1" name="incident_device_cluster_meta_sample_limit" value="{{ old('incident_device_cluster_meta_sample_limit', $incidentDetectionSettings['device_cluster']['meta_sample_limit']) }}" required>
        </div>
        <div>
            <label>Score Base</label>
            <input class="w-full" type="number" min="0" name="incident_device_cluster_score_base" value="{{ old('incident_device_cluster_score_base', $incidentDetectionSettings['device_cluster']['score_base']) }}" required>
        </div>
        <div>
            <label>Score Max</label>
            <input class="w-full" type="number" min="0" name="incident_device_cluster_score_max" value="{{ old('incident_device_cluster_score_max', $incidentDetectionSettings['device_cluster']['score_max']) }}" required>
        </div>

        <div class="md:col-span-2 mt-4">
            <h4>Automatische Maßnahmen</h4>
        </div>

        <label>
            <input type="checkbox" name="incident_auto_actions_enabled" value="1"
                {{ old('incident_auto_actions_enabled', $incidentAutoActionSettings['enabled']) ? 'checked' : '' }}>
            Auto Actions aktiv
        </label>

        <label>
            <input type="checkbox" name="incident_auto_actions_update_incident_status" value="1"
                {{ old('incident_auto_actions_update_incident_status', $incidentAutoActionSettings['update_incident_status']) ? 'checked' : '' }}>
            Incident-Status automatisch auf "Maßnahme ergriffen" setzen
        </label>

        <label>
            <input type="checkbox" name="incident_auto_action_credential_stuffing_identity_ban_enabled" value="1"
                {{ old('incident_auto_action_credential_stuffing_identity_ban_enabled', $incidentAutoActionSettings['credential_stuffing']['identity_ban_enabled']) ? 'checked' : '' }}>
            Credential Stuffing: automatische Identity-Sperre
        </label>

        <label>
            <input type="checkbox" name="incident_auto_action_bot_pattern_ip_ban_enabled" value="1"
                {{ old('incident_auto_action_bot_pattern_ip_ban_enabled', $incidentAutoActionSettings['bot_pattern']['ip_ban_enabled']) ? 'checked' : '' }}>
            Bot Pattern: automatische IP-Sperre
        </label>

        <label class="md:col-span-2">
            <input type="checkbox" name="incident_auto_action_device_cluster_device_ban_enabled" value="1"
                {{ old('incident_auto_action_device_cluster_device_ban_enabled', $incidentAutoActionSettings['device_cluster']['device_ban_enabled']) ? 'checked' : '' }}>
            Device Cluster: automatische Geräte-Sperre
        </label>

        <div>
            <button class="ks-btn" type="submit">Einstellungen speichern</button>
        </div>
    </form>
@endsection
