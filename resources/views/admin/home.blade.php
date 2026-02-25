{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\home.blade.php
Purpose: Admin landing (overview) – section-based navigation (no maintenance content)
Changed: 25-02-2026 20:23 (Europe/Berlin)
Version: 2.5
============================================================================ --}}

@extends('admin.layouts.admin')

@php
    $adminTitle = 'Backend';
    $adminSubtitle = 'Übersicht (section-basiert).';

    $currentRole = auth()->check() ? (string) (auth()->user()->role ?? 'user') : 'user';
    $currentRoleNormalized = class_exists(\App\Support\Admin\AdminSectionAccess::class)
        ? \App\Support\Admin\AdminSectionAccess::normalizeRole((string) $currentRole)
        : mb_strtolower(trim((string) $currentRole));

    $isSuperadminRole = ($currentRoleNormalized === 'superadmin');
    $isAdminRole = in_array($currentRoleNormalized, ['admin', 'superadmin'], true);

    $maintenanceActive = (bool) ($maintenanceEnabled ?? false);

    // Modules registry (prefer class if present; fallback to global registry function; else minimal fallback)
    $adminModules = [];

    if (class_exists(\App\Support\Admin\AdminModuleRegistry::class)) {
        $adminModules = \App\Support\Admin\AdminModuleRegistry::modulesForRole(
            (string) $currentRoleNormalized,
            (bool) $maintenanceActive
        );
    } elseif (function_exists('ks_admin_modules_for_role')) {
        try {
            $adminModules = (array) ks_admin_modules_for_role((string) $currentRoleNormalized, (bool) $maintenanceActive);
        } catch (\Throwable $e) {
            $adminModules = [];
        }
    }

    if (!is_array($adminModules) || count($adminModules) === 0) {
        $adminModules = [
            'overview' => [
                'label' => 'Übersicht',
                'route' => 'admin.home',
                'access' => 'staff',
            ],
            'tickets' => [
                'label' => 'Tickets',
                'route' => 'admin.tickets.index',
                'access' => 'staff',
            ],
        ];

        if ($isSuperadminRole) {
            $adminModules['maintenance'] = [
                'label' => 'Wartung',
                'route' => 'admin.maintenance',
                'access' => 'superadmin',
            ];

            if ($maintenanceActive) {
                $adminModules['debug'] = [
                    'label' => 'Debug',
                    'route' => 'admin.debug',
                    'access' => 'superadmin',
                ];
            }

            $adminModules['moderation'] = [
                'label' => 'Moderation',
                'route' => 'admin.moderation',
                'access' => 'superadmin',
            ];
        }
    }

    // Section-Keys (Whitelist) – Mapping auf bestehende Module (minimal, ohne DB/Queries)
    $sectionToModuleKey = [
        'overview'     => 'overview',
        'tickets'      => 'tickets',
        'maintenance'  => 'maintenance',
        'debug'        => 'debug',
        'moderation'   => 'moderation',
    ];

    $canAccessSection = function (string $sectionKey) use ($adminModules, $sectionToModuleKey, $currentRoleNormalized, $maintenanceActive): bool {
        if (!isset($sectionToModuleKey[$sectionKey])) {
            return false;
        }

        // Debug bleibt bewusst an Wartung gekoppelt (UI-Kopplung).
        if ($sectionKey === 'debug' && !$maintenanceActive) {
            return false;
        }

        $moduleKey = $sectionToModuleKey[$sectionKey];

        if (!isset($adminModules[$moduleKey])) {
            return false;
        }

        if (class_exists(\App\Support\Admin\AdminSectionAccess::class)) {
            return \App\Support\Admin\AdminSectionAccess::canAccessSection(
                (string) $currentRoleNormalized,
                (string) $sectionKey,
                (bool) $maintenanceActive
            );
        }

        return true;
    };

    // Layout/Navigation-Context
    $adminTab = $adminTab ?? 'overview';
    $adminShowDebugTab = ($maintenanceActive && (bool) ($adminShowDebugTab ?? $isSuperadminRole));

    $statusBadgeText = $statusBadgeText ?? '';
    $statusBadgeBg = $statusBadgeBg ?? '#16a34a';

    $envBadgeText = $envBadgeText ?? '';
    $envBadgeBg = $envBadgeBg ?? '#0ea5e9';

    // URLs (ohne DB/Queries)
    $adminOverviewUrl = (\Illuminate\Support\Facades\Route::has('admin.home'))
        ? route('admin.home')
        : url('/admin');

    $adminTicketsUrl = (isset($adminModules['tickets']['route']) && \Illuminate\Support\Facades\Route::has((string) $adminModules['tickets']['route']))
        ? route((string) $adminModules['tickets']['route'])
        : url('/admin/tickets');

    $adminMaintenanceUrl = (isset($adminModules['maintenance']['route']) && \Illuminate\Support\Facades\Route::has((string) $adminModules['maintenance']['route']))
        ? route((string) $adminModules['maintenance']['route'])
        : url('/admin/maintenance');

    $adminDebugUrl = (isset($adminModules['debug']['route']) && \Illuminate\Support\Facades\Route::has((string) $adminModules['debug']['route']))
        ? route((string) $adminModules['debug']['route'])
        : url('/admin/debug');

    $adminModerationUrl = (isset($adminModules['moderation']['route']) && \Illuminate\Support\Facades\Route::has((string) $adminModules['moderation']['route']))
        ? route((string) $adminModules['moderation']['route'])
        : url('/admin/moderation');

@endphp

@section('content')
    @if(!empty($notice))
        <div class="ks-notice p-3 rounded-lg border mb-3">
            {{ $notice }}
        </div>
    @endif

    <div class="ks-card ks-status-card mb-4 {{ $maintenanceActive ? 'ks-status-card--maintenance' : 'ks-status-card--live' }}">
        <div class="flex items-center justify-between gap-3 flex-wrap">
            <div>
                <h2 class="m-0 text-lg font-semibold">Backend-Übersicht</h2>
                <div class="text-sm ks-muted">
                    Status: <strong>{{ $statusBadgeText }}</strong> — Env: <strong>{{ $envBadgeText }}</strong>
                </div>
            </div>

            <div class="flex items-center gap-2 flex-wrap">
                @if($canAccessSection('overview'))
                    <a class="ks-btn" href="{{ $adminOverviewUrl }}" target="_self">Übersicht</a>
                @endif

                @if($canAccessSection('tickets'))
                    <a class="ks-btn" href="{{ $adminTicketsUrl }}" target="_self">Tickets</a>
                @endif

                @if($canAccessSection('maintenance'))
                    <a class="ks-btn" href="{{ $adminMaintenanceUrl }}" target="_self">Wartung</a>
                @endif

                @if($canAccessSection('debug'))
                    <a class="ks-btn" href="{{ $adminDebugUrl }}" target="_self">Debug</a>
                @endif

                @if($canAccessSection('moderation'))
                    <a class="ks-btn" href="{{ $adminModerationUrl }}" target="_self">Moderation</a>
                @endif
            </div>
        </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        @if($canAccessSection('tickets'))
            <div class="ks-card">
                <h3>Tickets</h3>
                <p>Ticket-Inbox, Details, Aktionen.</p>
                <a href="{{ $adminTicketsUrl }}" target="_self">Öffnen</a>
            </div>
        @endif

        @if($canAccessSection('maintenance'))
            <div class="ks-card">
                <h3>Wartung</h3>
                <p>Wartungsmodus, ETA, Notify und Debug-Schalter.</p>
                <a href="{{ $adminMaintenanceUrl }}" target="_self">Öffnen</a>
            </div>
        @endif

        @if($isSuperadminRole && $canAccessSection('debug'))
            <div class="ks-card">
                <h3>Debug</h3>
                <p>Debug-UI (nur während Wartung aktiv).</p>
                <a href="{{ $adminDebugUrl }}" target="_self">Öffnen</a>
            </div>
        @endif

        @if($canAccessSection('moderation'))
            <div class="ks-card">
                <h3>Moderation</h3>
                <p>Moderator-Rechteverwaltung (Sections an/aus).</p>
                <a href="{{ $adminModerationUrl }}" target="_self">Öffnen</a>
            </div>
        @endif
    </div>

@endsection
