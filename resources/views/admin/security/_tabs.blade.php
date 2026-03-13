<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\_tabs.blade.php
// Purpose: Admin Security - Tabs navigation (active tab styled like header)
// Changed: 12-03-2026 16:31 (Europe/Berlin)
// Version: 0.5
// ============================================================================

$route = request()->route()?->getName();
?>

<div class="mb-4 flex flex-wrap gap-2">

    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.overview' ? 'ks-btn--active' : '' }}"
       href="{{ route('admin.security.overview') }}">
        Security Overview
    </a>

    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.events.index' ? 'ks-btn--active' : '' }}"
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
