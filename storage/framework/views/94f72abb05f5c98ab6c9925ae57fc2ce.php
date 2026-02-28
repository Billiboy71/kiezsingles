

<?php
    $backToAppUrl = $backToAppUrl ?? url('/');
    $maintenanceEnabledFlag = $maintenanceEnabledFlag ?? false;
    $debugActiveFlag = $debugActiveFlag ?? false;
    $breakGlassActiveFlag = $breakGlassActiveFlag ?? false;
    $productionSimulationFlag = $productionSimulationFlag ?? false;
    $isLocalEnv = $isLocalEnv ?? false;
    $showAdminOutlines = $showAdminOutlines ?? false;

    $adminDebugUrl = \Illuminate\Support\Facades\Route::has('admin.debug') ? route('admin.debug') : '';

    $adminStatusUrl = \Illuminate\Support\Facades\Route::has('admin.status') ? route('admin.status') : url('/admin/status');
    $breakGlassRouteEnabled = \Illuminate\Support\Facades\Route::has('noteinstieg.show');

    $adminTab = $adminTab ?? 'overview';
    $adminNavItems = $adminNavItems ?? [];
    $adminTopNavKeys = ['maintenance', 'develop', 'debug', 'moderation'];
    $adminNavItemsByKey = [];
    foreach ($adminNavItems as $item) {
        $key = (string) ($item['key'] ?? '');
        $key = ($key === 'home') ? 'overview' : $key;
        if ($key === '') {
            continue;
        }
        $adminNavItemsByKey[$key] = $item;
    }

    $currentRoleNormalized = auth()->check()
        ? mb_strtolower(trim((string) (auth()->user()->role ?? 'user')))
        : 'user';

    $adminTopNavFallback = [
        'maintenance' => ['label' => 'Wartung', 'route' => 'admin.maintenance', 'url' => url('/admin/maintenance')],
        'develop' => ['label' => 'Develop', 'route' => 'admin.develop', 'url' => url('/admin/develop')],
        'debug' => ['label' => 'Debug', 'route' => 'admin.debug', 'url' => url('/admin/debug')],
        'moderation' => ['label' => 'Moderation', 'route' => 'admin.moderation', 'url' => url('/admin/moderation')],
    ];

    $adminTopNavItems = [];
    foreach ($adminTopNavKeys as $key) {
        if (!$maintenanceEnabledFlag && ($key === 'debug' || $key === 'develop')) {
            continue;
        }

        $allowed = false;
        if (class_exists(\App\Support\Admin\AdminSectionAccess::class)) {
            $allowed = \App\Support\Admin\AdminSectionAccess::canAccessSection(
                (string) $currentRoleNormalized,
                (string) $key,
                (bool) $maintenanceEnabledFlag
            );
        } else {
            $allowed = ($currentRoleNormalized === 'superadmin');
        }

        if (!$allowed) {
            continue;
        }

        $item = $adminNavItemsByKey[$key] ?? null;
        $fallback = $adminTopNavFallback[$key] ?? ['label' => ucfirst($key), 'route' => '', 'url' => '#'];

        $label = (string) ($item['label'] ?? $fallback['label']);
        $url = (string) ($item['url'] ?? '');
        if ($url === '') {
            $routeName = (string) ($fallback['route'] ?? '');
            if ($routeName !== '' && \Illuminate\Support\Facades\Route::has($routeName)) {
                $url = route($routeName);
            } else {
                $url = (string) ($fallback['url'] ?? '#');
            }
        }

        $adminTopNavItems[] = [
            'key' => $key,
            'label' => $label,
            'url' => $url,
        ];
    }
    $adminTopNavOrder = [
        'maintenance' => 10,
        'debug' => 20,
        'develop' => 30,
        'moderation' => 40,
    ];
    usort($adminTopNavItems, function ($a, $b) use ($adminTopNavOrder) {
        $ka = (string) ($a['key'] ?? '');
        $kb = (string) ($b['key'] ?? '');

        $ka = ($ka === 'home') ? 'overview' : $ka;
        $kb = ($kb === 'home') ? 'overview' : $kb;

        $oa = $adminTopNavOrder[$ka] ?? 999;
        $ob = $adminTopNavOrder[$kb] ?? 999;

        if ($oa === $ob) {
            return strcmp((string) $ka, (string) $kb);
        }

        return $oa <=> $ob;
    });

    // ---- ROLE LABEL (server-side) ----
    $ksRoleLabel = 'Admin';
    if (auth()->check()) {
        $ksRole = mb_strtolower(trim((string) (auth()->user()->role ?? '')));
        if ($ksRole === 'superadmin') {
            $ksRoleLabel = 'Super-Admin';
        } elseif ($ksRole === 'moderator') {
            $ksRoleLabel = 'Moderator';
        } elseif ($ksRole === 'admin') {
            $ksRoleLabel = 'Admin';
        }
    }

    // ---- ENV MODE SAFELY PRECOMPUTED ----
    if ($productionSimulationFlag) {
        $envMode = 'prod-sim';
        $envLabel = 'PROD-SIM';
        $envBadgeClass = 'bg-violet-500';
    } elseif ($isLocalEnv) {
        $envMode = 'local';
        $envLabel = 'LOCAL';
        $envBadgeClass = 'bg-sky-500';
    } else {
        $envMode = 'prod';
        $envLabel = 'PROD';
        $envBadgeClass = 'bg-slate-500';
    }

    // NOTE:
    // Do not compute debug badge state via DB reads during render.
    // The client-side /admin/status endpoint updates the badge on page load.
    $debugBadgeActiveFlag = false;
?>

<header class="bg-white border-b border-gray-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
        <div class="<?php echo e($showAdminOutlines ? 'relative border-2 border-dashed border-lime-400' : ''); ?>">
            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showAdminOutlines): ?>
                <div class="absolute -top-3 left-2 bg-lime-500 text-white text-[10px] leading-none px-2 py-1 rounded">ADMIN-STATUSHEADER</div>
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

            <div class="flex items-center justify-between gap-4 flex-wrap">
                <div class="min-w-0">
                    <div class="text-sm font-semibold text-gray-900">
                        <?php echo e($ksRoleLabel); ?>

                    </div>
                </div>

                <div class="flex items-center justify-end gap-2 flex-wrap ml-auto">
                    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($currentRoleNormalized === 'superadmin'): ?>
                        
                        <span
                            id="ks_admin_badge_break_glass"
                            class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white bg-amber-500 <?php echo e(($breakGlassActiveFlag && $breakGlassRouteEnabled) ? '' : 'hidden'); ?>"
                            data-active="<?php echo e(($breakGlassActiveFlag && $breakGlassRouteEnabled) ? '1' : '0'); ?>"
                        >
                            BREAK-GLASS
                        </span>

                        
                        <span
                            id="ks_admin_badge_env"
                            class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white <?php echo e($envBadgeClass); ?>"
                            data-env="<?php echo e($envMode); ?>"
                        >
                            <?php echo e($envLabel); ?>

                        </span>

                        
                        <span
                            id="ks_admin_badge_debug"
                            class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white bg-red-500 <?php echo e(($debugBadgeActiveFlag && $maintenanceEnabledFlag) ? '' : 'hidden'); ?>"
                            data-active="<?php echo e(($debugBadgeActiveFlag && $maintenanceEnabledFlag) ? '1' : '0'); ?>"
                        >
                            DEBUG
                        </span>
                    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

                    
                    <span
                        id="ks_admin_badge_maintenance"
                        class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white bg-red-500 <?php echo e($maintenanceEnabledFlag ? '' : 'hidden'); ?>"
                    >
                        WARTUNG
                    </span>
                </div>
            </div>
        </div>

        <div class="mt-3 <?php echo e($showAdminOutlines ? 'relative border-2 border-dashed border-cyan-400' : ''); ?>">
            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showAdminOutlines): ?>
                <div class="absolute -top-3 left-2 bg-cyan-500 text-white text-[10px] leading-none px-2 py-1 rounded">ADMIN-TOPHEADER</div>
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

            <div class="flex items-center justify-between gap-4 flex-wrap">
                <div class="min-w-0 flex items-center gap-3 flex-wrap">
                    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(count($adminTopNavItems) > 0): ?>
                        <div class="flex gap-2 flex-wrap">
                            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $adminTopNavItems; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $item): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                                <?php
                                    $itemKey = (string) ($item['key'] ?? '');
                                    $itemKey = ($itemKey === 'home') ? 'overview' : $itemKey;

                                    $itemLabel = (string) ($item['label'] ?? '');
                                    $itemUrl = (string) ($item['url'] ?? '#');

                                    if ($itemKey === '' || $itemLabel === '') {
                                        continue;
                                    }
                                ?>

                                <a
                                    href="<?php echo e($itemUrl); ?>"
                                    data-ks-admin-nav-key="<?php echo e($itemKey); ?>"
                                    class="inline-flex items-center px-4 py-2 border rounded-md font-semibold text-xs uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2
                                        <?php echo e($adminTab === $itemKey ? 'bg-gray-900 text-white border-gray-900' : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'); ?>

                                        <?php echo e(($itemKey === 'debug' && !$debugActiveFlag) ? 'hidden' : ''); ?>"
                                >
                                    <?php echo e($itemLabel); ?>

                                </a>
                            <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                        </div>
                    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                </div>

                <div class="flex items-center gap-2 flex-wrap justify-end">
                    <a
                        href="<?php echo e($backToAppUrl); ?>"
                        class="inline-flex items-center px-4 py-2 bg-white border border-gray-300 rounded-md font-semibold text-xs text-gray-700 uppercase tracking-widest hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    >
                        Dashboard
                    </a>

                    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(\Illuminate\Support\Facades\Route::has('logout')): ?>
                        <form method="POST" action="<?php echo e(route('logout')); ?>">
                            <?php echo csrf_field(); ?>
                            <button
                                type="submit"
                                class="inline-flex items-center px-4 py-2 bg-gray-900 border border-gray-900 rounded-md font-semibold text-xs text-white uppercase tracking-widest hover:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                            >
                                Abmelden
                            </button>
                        </form>
                    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                </div>
            </div>
        </div>

        <div class="mt-3 <?php echo e($showAdminOutlines ? 'relative border-2 border-dashed border-amber-400' : ''); ?>" id="ks_admin_nav" data-ks-admin-status-url="<?php echo e($adminStatusUrl); ?>">
            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showAdminOutlines): ?>
                <div class="absolute -top-3 left-2 bg-amber-500 text-white text-[10px] leading-none px-2 py-1 rounded">ADMIN-NAVHEADER</div>
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

            <?php echo $__env->make('admin.layouts.navigation', [
                'adminNavInline' => false,
                'adminNavShowProfileLink' => false,
                'adminNavExcludeKeys' => $adminTopNavKeys,
            ], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>
        </div>
    </div>
</header>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/layouts/header.blade.php ENDPATH**/ ?>