{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\layouts\admin.blade.php
Purpose: Admin root layout (separate from app layout; dedicated admin header + admin navigation + content)
Changed: 25-02-2026 12:40 (Europe/Berlin)
Version: 5.7
============================================================================ --}}

@php
    $adminTab = $adminTab ?? 'overview';
    $adminShowDebugTab = $adminShowDebugTab ?? null;
    $adminNavItems = $adminNavItems ?? [];

    // Zentraler Layout-Regler: Content-Breite (Tailwind max-w-*)
    $adminMaxWidthClass = $adminMaxWidthClass ?? 'max-w-5xl';

    $maintenanceEnabledFlag = isset($maintenanceEnabled) ? (bool) $maintenanceEnabled : false;

    $currentRoleForFlags = auth()->check() ? (string) (auth()->user()->role ?? 'user') : 'user';
    $currentRoleForFlags = mb_strtolower(trim($currentRoleForFlags));
    $isAdminRoleForFlags = in_array($currentRoleForFlags, ['admin', 'superadmin'], true);

    // Debug-Sichtbarkeit wird ausschließlich serverseitig aus Rolle+Wartung+Section-Access abgeleitet.
    $debugVisibleFlag = false;
    try {
        if (class_exists(\App\Support\Admin\AdminSectionAccess::class)) {
            $debugVisibleFlag = $maintenanceEnabledFlag && \App\Support\Admin\AdminSectionAccess::canAccessSection(
                (string) $currentRoleForFlags,
                (string) \App\Support\Admin\AdminSectionAccess::SECTION_DEBUG,
                (bool) $maintenanceEnabledFlag
            );
        } else {
            $debugVisibleFlag = $maintenanceEnabledFlag && (bool) $isAdminRoleForFlags;
        }
    } catch (\Throwable $e) {
        $debugVisibleFlag = false;
    }

    if ($adminShowDebugTab === null) {
        $adminShowDebugTab = (bool) $debugVisibleFlag;
    }

    // debugEnabled (SystemSetting) bleibt optional als separater Status, steuert aber NICHT die Sichtbarkeit.
    $debugEnabledFlag = isset($debugEnabled)
        ? (bool) $debugEnabled
        : (isset($debug_enabled) ? (bool) $debug_enabled : false);

    // Für Header/UI wird debugActiveFlag als "sichtbar" behandelt (nicht als Setting-Schalter).
    $debugActiveFlag = (bool) $adminShowDebugTab;

    $breakGlassActiveFlag = isset($breakGlassEnabled)
        ? (bool) $breakGlassEnabled
        : (isset($break_glass) ? (bool) $break_glass : (isset($breakGlass) ? (bool) $breakGlass : false));

    $productionSimulationFlag = isset($productionSimulation)
        ? (bool) $productionSimulation
        : (isset($simulateProduction) ? (bool) $simulateProduction : (isset($simulate_production) ? (bool) $simulate_production : false));

    $isLocalEnv = app()->environment('local');

    // NEW: DB-gesteuerter LOCAL-Banner-Schalter (Default: true)
    $localBannerEnabled = true;
    try {
        if (\Illuminate\Support\Facades\Schema::hasTable('system_settings')) {
            $row = \Illuminate\Support\Facades\DB::table('system_settings')
                ->select(['value'])
                ->where('key', 'debug.local_banner_enabled')
                ->first();

            if ($row) {
                $val = trim((string) ($row->value ?? ''));
                $localBannerEnabled = ($val === '1' || strtolower($val) === 'true');
            }
        }
    } catch (\Throwable $e) {
        $localBannerEnabled = true;
    }

    $backToAppUrl = \Illuminate\Support\Facades\Route::has('dashboard')
        ? route('dashboard')
        : url('/');

    $ksLocalDebug = null;
    if ($isLocalEnv) {
        $ksLocalDebug = [
            'role' => auth()->check() ? (string) (auth()->user()->role ?? 'user') : 'guest',
            'adminTab' => (string) $adminTab,
            'path' => (string) request()->path(),
            'fullUrl' => (string) request()->fullUrl(),
            'routeName' => (string) (request()->route() ? (request()->route()->getName() ?? '') : ''),
            'tabQuery' => (string) request()->query('tab', ''),
            'maintenance' => $maintenanceEnabledFlag ? '1' : '0',
            'adminShowDebugTab' => $adminShowDebugTab ? '1' : '0',
            'debugActiveFlag' => $debugActiveFlag ? '1' : '0',
            'debugEnabledFlag' => $debugEnabledFlag ? '1' : '0',
            'breakGlassActiveFlag' => $breakGlassActiveFlag ? '1' : '0',
            'productionSimulationFlag' => $productionSimulationFlag ? '1' : '0',
        ];
    }

    if (empty($adminNavItems)) {
        $currentRole = auth()->check() ? (string) (auth()->user()->role ?? 'user') : 'user';
        $currentRole = mb_strtolower(trim($currentRole));
        $isAdminRole = in_array($currentRole, ['admin', 'superadmin'], true);
        $isSuperadminRole = ($currentRole === 'superadmin');

        $modules = [];

        if (class_exists(\App\Support\Admin\AdminModuleRegistry::class)) {
            $modules = \App\Support\Admin\AdminModuleRegistry::modulesForRole(
                (string) $currentRole,
                (bool) $maintenanceEnabledFlag
            );
        } elseif (function_exists('ks_admin_modules_for_role')) {
            try {
                $modules = (array) ks_admin_modules_for_role((string) $currentRole, (bool) $maintenanceEnabledFlag);
            } catch (\Throwable $e) {
                $modules = [];
            }
        }

        if (!is_array($modules) || count($modules) === 0) {
            $modules = [
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
                $modules['maintenance'] = [
                    'label' => 'Wartung',
                    'route' => 'admin.maintenance',
                    'access' => 'superadmin',
                ];

                $modules['debug'] = [
                    'label' => 'Debug',
                    'route' => 'admin.debug',
                    'access' => 'superadmin',
                ];

                $modules['moderation'] = [
                    'label' => 'Moderation',
                    'route' => 'admin.moderation',
                    'access' => 'superadmin',
                ];
            }
        }

        foreach ($modules as $key => $module) {
            $keyNormalized = ((string) $key === 'home') ? 'overview' : (string) $key;

            $routeName = (string) ($module['route'] ?? '');
            if ($routeName === '') {
                continue;
            }

            if (!\Illuminate\Support\Facades\Route::has($routeName)) {
                continue;
            }

            if (class_exists(\App\Support\Admin\AdminSectionAccess::class)) {
                if (!\App\Support\Admin\AdminSectionAccess::canAccessSection(
                    (string) $currentRole,
                    (string) $keyNormalized,
                    (bool) $maintenanceEnabledFlag
                )) {
                    continue;
                }
            }

            $adminNavItems[] = [
                'key' => (string) $keyNormalized,
                'label' => (string) ($module['label'] ?? ''),
                'url' => route($routeName),
            ];
        }
    }
@endphp

<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">

    <title>{{ request()->getHost() }}</title>

    <base target="_self">

    @vite(['resources/css/admin.css', 'resources/js/admin.js', 'resources/js/admin-header.js'])
</head>
<body class="font-sans antialiased bg-gray-100 min-h-screen flex flex-col">

    @include('admin.layouts.header', [
        'backToAppUrl' => $backToAppUrl,
        'maintenanceEnabledFlag' => $maintenanceEnabledFlag,
        'debugActiveFlag' => $debugActiveFlag,
        'breakGlassActiveFlag' => $breakGlassActiveFlag,
        'productionSimulationFlag' => $productionSimulationFlag,
        'isLocalEnv' => $isLocalEnv,
    ])

    @if($isLocalEnv && $maintenanceEnabledFlag && $localBannerEnabled && is_array($ksLocalDebug))
        <div
            id="ks_local_debug_banner"
            data-ks-local-banner-enabled="{{ $localBannerEnabled ? '1' : '0' }}"
            class="{{ $adminMaxWidthClass }} mx-auto px-4 sm:px-6 lg:px-8 mt-3"
        >
            <div class="bg-yellow-50 border border-yellow-200 rounded-xl px-4 py-3 text-xs text-gray-800">
                <div class="font-semibold">LOCAL DEBUG</div>
                <div class="mt-1 leading-5 break-words">
                    role=<b>{{ $ksLocalDebug['role'] }}</b>
                    · adminTab=<b>{{ $ksLocalDebug['adminTab'] }}</b>
                    · route=<b>{{ $ksLocalDebug['routeName'] !== '' ? $ksLocalDebug['routeName'] : '(none)' }}</b>
                    · path=<b>{{ $ksLocalDebug['path'] }}</b>
                    @if($ksLocalDebug['tabQuery'] !== '')
                        · tabQuery=<b>{{ $ksLocalDebug['tabQuery'] }}</b>
                    @endif
                    · maintenance=<b>{{ $ksLocalDebug['maintenance'] }}</b>
                    · adminShowDebugTab=<b>{{ $ksLocalDebug['adminShowDebugTab'] }}</b>
                    · debugActive=<b>{{ $ksLocalDebug['debugActiveFlag'] }}</b>
                    · breakGlass=<b>{{ $ksLocalDebug['breakGlassActiveFlag'] }}</b>
                    · prodSim=<b>{{ $ksLocalDebug['productionSimulationFlag'] }}</b>
                </div>
                <div class="mt-1 text-gray-600 break-words">
                    {{ $ksLocalDebug['fullUrl'] }}
                </div>
            </div>
        </div>
    @endif

    <main class="flex-1 py-8">
        <div class="{{ $adminMaxWidthClass }} mx-auto px-4 sm:px-6 lg:px-8">
            @yield('content')
        </div>
    </main>

    @include('admin.layouts.footer')

</body>
</html>