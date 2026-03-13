<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\allowlist\_tabs.blade.php
// Purpose: Admin Security Allowlist - Subtabs for type-specific allowlist pages
// Created: 09-03-2026 (Europe/Berlin)
// Changed: 09-03-2026 04:14 (Europe/Berlin)
// Version: 0.1
// ============================================================================

$route = request()->route()?->getName();
?>

<div class="mb-4 flex flex-wrap gap-2">
    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.allowlist.ip.index' ? 'ks-btn--active' : '' }}"
       href="{{ route('admin.security.allowlist.ip.index') }}">
        IP-Allowlist
    </a>

    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.allowlist.device.index' ? 'ks-btn--active' : '' }}"
       href="{{ route('admin.security.allowlist.device.index') }}">
        Device-Allowlist
    </a>

    <a class="ks-btn ks-btn--tab {{ $route === 'admin.security.allowlist.identity.index' ? 'ks-btn--active' : '' }}"
       href="{{ route('admin.security.allowlist.identity.index') }}">
        Identity-Allowlist
    </a>
</div>
