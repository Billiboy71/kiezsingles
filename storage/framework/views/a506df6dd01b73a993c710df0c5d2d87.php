

<?php
    $adminTab = $adminTab ?? 'overview';

    // If not explicitly set by the caller, keep Debug tab visible (when present in adminNavItems).
    $adminShowDebugTab = $adminShowDebugTab ?? null;

    $adminNavItems = $adminNavItems ?? [];

    // Optional render variants:
    // - inline: for embedding (e.g. inside dashboard header). No <nav> wrapper by default.
    $adminNavInline = $adminNavInline ?? false;

    // In inline mode, default: hide profile link (because Breeze header already has Profile/Logout).
    $adminNavShowProfileLink = $adminNavShowProfileLink ?? (!$adminNavInline);

    // Optional: remove keys from nav (e.g. items rendered in top header).
    $adminNavExcludeKeys = $adminNavExcludeKeys ?? [];

    // IMPORTANT:
    // Badges (Wartung/Debug/Env) must be rendered in the top app header (Dashboard bar)
    // next to the profile dropdown. They are intentionally NOT rendered here anymore.
    $adminNavShowBadges = false;

    if ($adminShowDebugTab === null) {
        $adminShowDebugTab = false;
    }

    $adminNavItems = array_values(array_filter($adminNavItems, function ($item) use ($adminShowDebugTab, $adminNavExcludeKeys) {
        $k = (string) ($item['key'] ?? '');
        $k = ($k === 'home') ? 'overview' : $k;

        if (!empty($adminNavExcludeKeys) && in_array($k, $adminNavExcludeKeys, true)) {
            return false;
        }

        if ($k === 'debug') {
            return (bool) $adminShowDebugTab;
        }

        return true;
    }));

    // Enforce canonical order: Übersicht, Wartung, Debug, Tickets, Moderation
    $orderMap = [
        'overview' => 10,
        'maintenance' => 20,
        'debug' => 30,
        'tickets' => 40,
        'moderation' => 50,
    ];

    usort($adminNavItems, function ($a, $b) use ($orderMap) {
        $ka = (string) ($a['key'] ?? '');
        $kb = (string) ($b['key'] ?? '');

        $ka = ($ka === 'home') ? 'overview' : $ka;
        $kb = ($kb === 'home') ? 'overview' : $kb;

        $oa = $orderMap[$ka] ?? 999;
        $ob = $orderMap[$kb] ?? 999;

        if ($oa === $ob) {
            return strcmp((string) $ka, (string) $kb);
        }

        return $oa <=> $ob;
    });
?>

<?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($adminNavInline): ?>

    <div class="flex items-center gap-2 flex-wrap justify-end" data-ks-admin-nav>
        <div class="flex gap-2 flex-wrap">
            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $adminNavItems; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $item): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
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
                    class="inline-flex items-center px-4 py-2 border rounded-md font-semibold text-xs uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2
                        <?php echo e($adminTab === $itemKey ? 'bg-gray-900 text-white border-gray-900' : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'); ?>"
                >
                    <?php echo e($itemLabel); ?>

                </a>
            <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

            <?php if (! empty(trim($__env->yieldContent('adminNavExtra')))): ?>
                <?php echo $__env->yieldContent('adminNavExtra'); ?>
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
        </div>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($adminNavShowProfileLink): ?>
            <a
                href="<?php echo e(route('profile.edit')); ?>"
                class="inline-flex items-center px-4 py-2 bg-white border border-gray-300 rounded-md font-semibold text-xs text-gray-700 uppercase tracking-widest hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            >
                Zurück zum Profil
            </a>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
    </div>

    <?php if (! empty(trim($__env->yieldContent('adminHeader')))): ?>
        <div class="mt-3">
            <?php echo $__env->yieldContent('adminHeader'); ?>
        </div>
    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

<?php else: ?>

    <nav class="bg-white border-b border-gray-200" data-ks-admin-nav>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
            <div class="flex items-center justify-between gap-4 flex-wrap">
                <div class="flex gap-2 flex-wrap">
                    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $adminNavItems; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $item): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
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
                            class="inline-flex items-center px-4 py-2 border rounded-md font-semibold text-xs uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2
                                <?php echo e($adminTab === $itemKey ? 'bg-gray-900 text-white border-gray-900' : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'); ?>"
                        >
                            <?php echo e($itemLabel); ?>

                        </a>
                    <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

                    <?php if (! empty(trim($__env->yieldContent('adminNavExtra')))): ?>
                        <?php echo $__env->yieldContent('adminNavExtra'); ?>
                    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                </div>

                <div class="flex items-center gap-2 flex-wrap justify-end">
                    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($adminNavShowProfileLink): ?>
                        <a
                            href="<?php echo e(route('profile.edit')); ?>"
                            class="inline-flex items-center px-4 py-2 bg-white border border-gray-300 rounded-md font-semibold text-xs text-gray-700 uppercase tracking-widest hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                        >
                            Zurück zum Profil
                        </a>
                    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                </div>
            </div>

            <?php if (! empty(trim($__env->yieldContent('adminHeader')))): ?>
                <div class="mt-3">
                    <?php echo $__env->yieldContent('adminHeader'); ?>
                </div>
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
        </div>
    </nav>

<?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/layouts/navigation.blade.php ENDPATH**/ ?>