<?php $__env->startSection('content'); ?>
    <div class="space-y-4">
        <div class="rounded-xl border border-red-200 bg-red-50 p-4">
            <div class="text-base font-semibold text-red-900">
                Kein Zugriff auf dieses Modul.
            </div>
            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($subtitle)): ?>
                <div class="mt-1 text-sm text-red-800">
                    <?php echo e($subtitle); ?>

                </div>
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
        </div>

        <div>
            <a href="<?php echo e(url('/admin')); ?>" class="inline-flex items-center rounded-lg border px-3 py-2 text-sm font-medium">
                Zurück zur Übersicht
            </a>
        </div>
    </div>
<?php $__env->stopSection(); ?>
<?php echo $__env->make('admin.layouts.admin', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\storage\framework\views/f5a60f04928ec03707d4e2973f224c44.blade.php ENDPATH**/ ?>