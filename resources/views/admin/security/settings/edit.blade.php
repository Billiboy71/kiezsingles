<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\settings\edit.blade.php
// Purpose: Admin Security - Security settings (SSOT configuration)
// Changed: 02-03-2026 14:57 (Europe/Berlin)
// Version: 0.3
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

        <div>
            <button class="ks-btn" type="submit">Einstellungen speichern</button>
        </div>
    </form>
@endsection
