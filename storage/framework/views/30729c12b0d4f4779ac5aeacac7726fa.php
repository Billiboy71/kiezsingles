

<?php
    $p = '';
    try {
        $p = (string) request()->path();
    } catch (\Throwable $e) {
        $p = '';
    }

    $isAdminPath = ($p === 'admin') || str_starts_with($p, 'admin/');

    $module = '';
    try {
        $module = (string) (request()->segment(2) ?? '');
    } catch (\Throwable $e) {
        $module = '';
    }

    $adminTitle = 'Kein Zugriff';
    $adminSubtitle = $module !== '' ? ('Modul: '.$module) : null;
?>

<?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($isAdminPath): ?>
    

    <?php $__env->startSection('content'); ?>
        <div class="space-y-4">
            <div class="rounded-xl border border-red-200 bg-red-50 p-4">
                <div class="text-base font-semibold text-red-900">
                    Kein Zugriff auf dieses Modul.
                </div>

                <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($adminSubtitle)): ?>
                    <div class="mt-1 text-sm text-red-800">
                        <?php echo e($adminSubtitle); ?>

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
<?php else: ?>
    
    <!DOCTYPE html>
    <html lang="<?php echo e(str_replace('_', '-', app()->getLocale())); ?>">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title><?php echo e(__('Forbidden')); ?></title>
        <?php echo app('Illuminate\Foundation\Vite')(['resources/css/app.css']); ?>
    </head>
    <body class="font-sans antialiased bg-gray-100 min-h-screen">
        <div class="min-h-screen flex items-center justify-center px-6">
            <div class="max-w-lg w-full bg-white border rounded-xl p-6">
                <div class="text-lg font-semibold text-gray-900"><?php echo e(__('Forbidden')); ?></div>
                <div class="mt-2 text-sm text-gray-700">
                    <?php echo e(__($exception->getMessage() ?: 'Forbidden')); ?>

                </div>
            </div>
        </div>
    </body>
    </html>
<?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
<?php echo $__env->make('admin.layouts.admin', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\resources\views\errors\403.blade.php ENDPATH**/ ?>