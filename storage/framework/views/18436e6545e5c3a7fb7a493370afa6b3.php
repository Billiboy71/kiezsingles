

<?php
    $layoutOutlinesIsSuperadmin = auth()->check() && ((string) (auth()->user()->role ?? 'user') === 'superadmin');
    $layoutOutlinesAllowProduction = false;
    $layoutOutlinesFrontendEnabled = false;

    if ($layoutOutlinesIsSuperadmin) {
        try {
            if (\Illuminate\Support\Facades\Schema::hasTable('debug_settings')) {
                $rows = \Illuminate\Support\Facades\DB::table('debug_settings')
                    ->select(['key', 'value'])
                    ->whereIn('key', [
                        'debug.layout_outlines_allow_production',
                        'debug.layout_outlines_frontend_enabled',
                    ])
                    ->get()
                    ->keyBy('key');

                $layoutOutlinesAllowProduction = ((string) ($rows['debug.layout_outlines_allow_production']->value ?? '0') === '1');
                $layoutOutlinesFrontendEnabled = ((string) ($rows['debug.layout_outlines_frontend_enabled']->value ?? '0') === '1');
            }
        } catch (\Throwable $e) {
            $layoutOutlinesAllowProduction = false;
            $layoutOutlinesFrontendEnabled = false;
        }
    }

    $layoutOutlinesEnvOk = app()->environment('local') || $layoutOutlinesAllowProduction;
    $showFrontendOutlines = $layoutOutlinesIsSuperadmin && $layoutOutlinesEnvOk && $layoutOutlinesFrontendEnabled;
?>

<!DOCTYPE html>
<html lang="<?php echo e(str_replace('_', '-', app()->getLocale())); ?>">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="csrf-token" content="<?php echo e(csrf_token()); ?>">

       
        <title><?php echo e(request()->getHost()); ?></title>

        <!-- Fonts -->
        <link rel="preconnect" href="https://fonts.bunny.net">
        <link href="https://fonts.bunny.net/css?family=figtree:400,500,600&display=swap" rel="stylesheet" />

        <!-- Scripts -->
        <?php echo app('Illuminate\Foundation\Vite')(['resources/css/app.css', 'resources/js/app.js']); ?>
    </head>
    <body class="font-sans antialiased">
        <div class="min-h-screen flex flex-col bg-gray-100 <?php echo e($showFrontendOutlines ? 'relative border-2 border-dashed border-indigo-400' : ''); ?>">
            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showFrontendOutlines): ?>
                <div class="absolute -top-3 left-2 bg-indigo-500 text-white text-[10px] leading-none px-2 py-1 rounded">APP</div>
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

            <div class="<?php echo e($showFrontendOutlines ? 'relative border-2 border-dashed border-sky-400 m-2 mt-4' : ''); ?>">
                <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showFrontendOutlines): ?>
                    <div class="absolute -top-3 left-2 bg-sky-500 text-white text-[10px] leading-none px-2 py-1 rounded">HEADER</div>
                <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

                <?php echo $__env->make('layouts.header', [
                    'leader' => $leader ?? null,
                    'header' => $header ?? null,
                ], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>
            </div>

            <!-- Page Content -->
            <main class="flex-1 <?php echo e($showFrontendOutlines ? 'relative border-2 border-dashed border-emerald-400 m-2' : ''); ?>">
                <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showFrontendOutlines): ?>
                    <div class="absolute -top-3 left-2 bg-emerald-500 text-white text-[10px] leading-none px-2 py-1 rounded">MAIN</div>
                <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

                <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                    <div class="bg-white rounded-xl shadow-sm p-6">
                        <?php echo e($slot); ?>

                    </div>
                </div>
            </main>

            <div class="<?php echo e($showFrontendOutlines ? 'relative border-2 border-dashed border-rose-400 m-2 mb-4' : ''); ?>">
                <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showFrontendOutlines): ?>
                    <div class="absolute -top-3 left-2 bg-rose-500 text-white text-[10px] leading-none px-2 py-1 rounded">FOOTER</div>
                <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

                <?php echo $__env->make('layouts.footer', [
                    'footer' => $footer ?? null,
                ], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>
            </div>
        </div>
    </body>
</html>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views/layouts/app.blade.php ENDPATH**/ ?>