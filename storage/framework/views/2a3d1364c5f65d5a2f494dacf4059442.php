

<?php
    $showFrontendOutlines = $showFrontendOutlines ?? false;
?>

<div class="<?php echo e($showFrontendOutlines ? 'relative border-2 border-dashed border-cyan-400 max-w-7xl mx-auto' : ''); ?>">
    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showFrontendOutlines): ?>
        <div class="absolute -top-3 left-2 bg-cyan-500 text-white text-[10px] leading-none px-2 py-1 rounded">FRONTEND-TOP-HEADER</div>
    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

    <?php echo $__env->make('layouts.navigation', [
        'showBackendButton' => (auth()->check() && in_array((string) (auth()->user()->role ?? 'user'), ['superadmin', 'admin', 'moderator'], true)),
        'showFrontendOutlines' => false,
    ], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>
</div>

<!-- Page Leader (optional) -->
<div class="<?php echo e($showFrontendOutlines ? 'relative border-2 border-dashed border-amber-400 max-w-7xl mx-auto' : ''); ?>">
    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showFrontendOutlines): ?>
        <div class="absolute -top-3 left-2 bg-amber-500 text-white text-[10px] leading-none px-2 py-1 rounded">FRONTEND-NAV</div>
    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($leader)): ?>
        <div class="bg-gray-100">
            <div class="max-w-7xl mx-auto py-4 px-4 sm:px-6 lg:px-8">
                <?php echo e($leader); ?>

            </div>
        </div>
    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

    <!-- Page Heading -->
    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($header)): ?>
        <div class="bg-white border-b border-gray-200">
            <div class="max-w-7xl mx-auto py-3 px-4 sm:px-6 lg:px-8">
                <?php echo e($header); ?>

            </div>
        </div>
    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
</div>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views/layouts/header.blade.php ENDPATH**/ ?>