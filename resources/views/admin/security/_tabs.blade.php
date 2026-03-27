<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\_tabs.blade.php
// Purpose: Admin Security - Tabs navigation (clean alert separation)
// Changed: 27-03-2026 00:35 (Europe/Berlin)
// Version: 1.8
// ============================================================================

$route = request()->route()?->getName();

// Default
$securityAlertClass = '';
$incidentAlertClass = '';
$eventAnalysisAlertClass = '';

// INCIDENTS Alert
if ($hasCriticalSecurityAlert ?? false) {
    $incidentAlertClass = 'bg-red-700 text-white hover:bg-red-700 hover:text-white';
} elseif ($hasSecurityAlert ?? false) {
    $incidentAlertClass = 'bg-orange-500 text-white hover:bg-orange-500 hover:text-white';
}

// EVENT ANALYSIS Alert (nur Events/Korrelation)
if (($hasEventAnalysisAlert ?? false) || ($hasEventAlert ?? false)) {
    $eventAnalysisAlertClass = 'bg-red-700 text-white hover:bg-red-700 hover:text-white';
}

// ❌ WICHTIG: Security Overview bleibt neutral
// (kein globales Rot mehr)

?>

<div class="mb-4 flex flex-wrap gap-2">

    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.overview' ? 'ks-btn--active bg-gray-900 text-white hover:bg-gray-800 hover:text-white' : $securityAlertClass }}"
       href="{{ route('admin.security.overview') }}">
        Security Overview
    </a>

    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.incidents.index' ? 'ks-btn--active bg-gray-900 text-white hover:bg-gray-800 hover:text-white' : $incidentAlertClass }}"
       href="{{ route('admin.security.incidents.index') }}">
        INCIDENTS
    </a>

    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.events.index' ? 'ks-btn--active bg-gray-900 text-white hover:bg-gray-800 hover:text-white' : $eventAnalysisAlertClass }}"
       href="{{ route('admin.security.events.index') }}">
        Event Analysis
    </a>

    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.ip_bans.index' ? 'ks-btn--active' : '' }}"
       href="{{ route('admin.security.ip_bans.index') }}">
        IP-Sperren
    </a>

    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.identity_bans.index' ? 'ks-btn--active' : '' }}"
       href="{{ route('admin.security.identity_bans.index') }}">
        Identitäts-Sperren
    </a>

    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.device_bans.index' ? 'ks-btn--active' : '' }}"
       href="{{ route('admin.security.device_bans.index') }}">
        Geräte-Sperren
    </a>

    <a class="ks-btn ks-btn--tab {{ str_starts_with((string) $route, 'admin.security.allowlist.') ? 'ks-btn--active' : '' }}"
       href="{{ route('admin.security.allowlist.ip.index') }}">
        Allowlist
    </a>

    <a class="ks-btn ks-btn--tab {{ in_array($route, ['admin.security.settings.edit', 'admin.security.settings.update'], true) ? 'ks-btn--active' : '' }}"
       href="{{ route('admin.security.settings.edit') }}">
        Einstellungen
    </a>

</div>
