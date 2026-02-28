

<?php
    $path = request()->path();
    $isAdmin = $path === 'admin' || str_starts_with($path, 'admin/');
?>

<?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($isAdmin): ?>


<?php $__env->startSection('content'); ?>
<div class="space-y-4">
    <div class="rounded-xl border border-red-200 bg-red-50 p-6">
        <div class="text-lg font-semibold text-red-900">
            Interner Serverfehler.
        </div>
        <div class="mt-2 text-sm text-red-800">
            Unerwarteter Fehler im Backend.
        </div>
    </div>
</div>
<?php $__env->stopSection(); ?>
<?php else: ?>
<!DOCTYPE html>
<html lang="<?php echo e(app()->getLocale()); ?>">
<head>
    <meta charset="utf-8">
    <title>500</title>
    <?php echo app('Illuminate\Foundation\Vite')(['resources/css/app.css']); ?>
</head>
<body class="bg-gray-100 min-h-screen flex items-center justify-center">
    <div class="bg-white p-6 rounded-xl border max-w-md w-full">
        <div class="text-lg font-semibold">Interner Serverfehler.</div>
    </div>
</body>
</html>
<?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
<?php echo $__env->make('admin.layouts.admin', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\resources\views\errors\500.blade.php ENDPATH**/ ?>