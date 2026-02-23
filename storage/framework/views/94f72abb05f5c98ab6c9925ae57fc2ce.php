

<?php
    $backToAppUrl = $backToAppUrl ?? url('/');
    $maintenanceEnabledFlag = $maintenanceEnabledFlag ?? false;
    $debugActiveFlag = $debugActiveFlag ?? false;
    $breakGlassActiveFlag = $breakGlassActiveFlag ?? false;
    $productionSimulationFlag = $productionSimulationFlag ?? false;
    $isLocalEnv = $isLocalEnv ?? false;

    $adminDebugUrl = \Illuminate\Support\Facades\Route::has('admin.debug') ? route('admin.debug') : '';

    $adminStatusUrl = \Illuminate\Support\Facades\Route::has('admin.status') ? route('admin.status') : url('/admin/status');

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
?>

<header class="bg-white border-b border-gray-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
        <div class="flex items-center justify-between gap-4 flex-wrap">
            <div class="min-w-0">
                <div class="text-sm font-semibold text-gray-900">
                    <?php echo e($ksRoleLabel); ?>

                </div>
            </div>

            <div class="flex items-center gap-2 flex-wrap justify-end">
                
                <span
                    id="ks_admin_badge_maintenance"
                    class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white bg-red-500 <?php echo e($maintenanceEnabledFlag ? '' : 'hidden'); ?>"
                >
                    WARTUNG
                </span>

                
                <span
                    id="ks_admin_badge_debug"
                    class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white <?php echo e($debugActiveFlag ? 'bg-red-500' : 'bg-green-600'); ?> <?php echo e($debugActiveFlag ? '' : 'hidden'); ?>"
                    data-active="<?php echo e($debugActiveFlag ? '1' : '0'); ?>"
                >
                    DEBUG
                </span>

                
                <span
                    id="ks_admin_badge_break_glass"
                    class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white bg-amber-500 <?php echo e($breakGlassActiveFlag ? '' : 'hidden'); ?>"
                    data-active="<?php echo e($breakGlassActiveFlag ? '1' : '0'); ?>"
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

        <div class="mt-3" id="ks_admin_nav" data-ks-admin-status-url="<?php echo e($adminStatusUrl); ?>">
            <?php echo $__env->make('admin.layouts.navigation', [
                'adminNavInline' => false,
                'adminNavShowProfileLink' => false,
            ], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>
        </div>
    </div>
</header><?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/layouts/header.blade.php ENDPATH**/ ?>