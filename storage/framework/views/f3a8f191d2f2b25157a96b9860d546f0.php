

<?php
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
?>

<!DOCTYPE html>
<html lang="<?php echo e(str_replace('_', '-', app()->getLocale())); ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="<?php echo e(csrf_token()); ?>">

    <title><?php echo e(request()->getHost()); ?></title>

    <base target="_self">

    <?php echo app('Illuminate\Foundation\Vite')(['resources/css/admin.css', 'resources/js/app.js']); ?>
</head>
<body class="font-sans antialiased bg-gray-100 min-h-screen flex flex-col">

    <?php echo $__env->make('admin.layouts.header', [
        'backToAppUrl' => $backToAppUrl,
        'maintenanceEnabledFlag' => $maintenanceEnabledFlag,
        'debugActiveFlag' => $debugActiveFlag,
        'breakGlassActiveFlag' => $breakGlassActiveFlag,
        'productionSimulationFlag' => $productionSimulationFlag,
        'isLocalEnv' => $isLocalEnv,
    ], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>

    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($isLocalEnv && $localBannerEnabled && is_array($ksLocalDebug)): ?>
        <div class="<?php echo e($adminMaxWidthClass); ?> mx-auto px-4 sm:px-6 lg:px-8 mt-3">
            <div class="bg-yellow-50 border border-yellow-200 rounded-xl px-4 py-3 text-xs text-gray-800">
                <div class="font-semibold">LOCAL DEBUG</div>
                <div class="mt-1 leading-5" style="word-break:break-word;">
                    role=<b><?php echo e($ksLocalDebug['role']); ?></b>
                    · adminTab=<b><?php echo e($ksLocalDebug['adminTab']); ?></b>
                    · route=<b><?php echo e($ksLocalDebug['routeName'] !== '' ? $ksLocalDebug['routeName'] : '(none)'); ?></b>
                    · path=<b><?php echo e($ksLocalDebug['path']); ?></b>
                    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($ksLocalDebug['tabQuery'] !== ''): ?>
                        · tabQuery=<b><?php echo e($ksLocalDebug['tabQuery']); ?></b>
                    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                    · maintenance=<b><?php echo e($ksLocalDebug['maintenance']); ?></b>
                    · adminShowDebugTab=<b><?php echo e($ksLocalDebug['adminShowDebugTab']); ?></b>
                    · debugActive=<b><?php echo e($ksLocalDebug['debugActiveFlag']); ?></b>
                    · breakGlass=<b><?php echo e($ksLocalDebug['breakGlassActiveFlag']); ?></b>
                    · prodSim=<b><?php echo e($ksLocalDebug['productionSimulationFlag']); ?></b>
                </div>
                <div class="mt-1 text-gray-600" style="word-break:break-word;">
                    <?php echo e($ksLocalDebug['fullUrl']); ?>

                </div>
            </div>
        </div>
    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

    <main class="flex-1 py-8">
        <div class="<?php echo e($adminMaxWidthClass); ?> mx-auto px-4 sm:px-6 lg:px-8">
            <?php echo $__env->yieldContent('content'); ?>
        </div>
    </main>

    <?php echo $__env->make('admin.layouts.footer', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>

</body>
</html><?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/layouts/admin.blade.php ENDPATH**/ ?>