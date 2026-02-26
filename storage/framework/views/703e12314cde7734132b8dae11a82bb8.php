





<?php
    $layoutRole = auth()->check() ? mb_strtolower(trim((string) (auth()->user()->role ?? 'user'))) : 'user';
    $layoutOutlinesIsSuperadmin = ($layoutRole === 'superadmin');
    $layoutOutlinesAllowProduction = false;
    $layoutOutlinesFrontendEnabled = false;

    if ($layoutOutlinesIsSuperadmin) {
        try {
            if (\Illuminate\Support\Facades\Schema::hasTable('system_settings')) {
                $rows = \Illuminate\Support\Facades\DB::table('system_settings')
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

    <title><?php echo e(config('app.name', 'Laravel')); ?></title>

    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.bunny.net">
    <link href="https://fonts.bunny.net/css?family=figtree:400,500,600&display=swap" rel="stylesheet" />

    <!-- App -->
    <?php echo app('Illuminate\Foundation\Vite')(['resources/css/app.css', 'resources/js/app.js']); ?>

    
    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(config('captcha.enabled')): ?>
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
</head>

<body class="font-sans text-gray-900 antialiased">
    <div class="min-h-screen flex flex-col sm:justify-center items-center pt-6 sm:pt-0 bg-gray-100 <?php echo e($showFrontendOutlines ? 'relative border-2 border-dashed border-indigo-400 m-2' : ''); ?>">
        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showFrontendOutlines): ?>
            <div class="absolute -top-3 left-2 bg-indigo-500 text-white text-[10px] leading-none px-2 py-1 rounded">GUEST</div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <div class="<?php echo e($showFrontendOutlines ? 'relative border-2 border-dashed border-sky-400 m-2 p-2' : ''); ?>">
            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showFrontendOutlines): ?>
                <div class="absolute -top-3 left-2 bg-sky-500 text-white text-[10px] leading-none px-2 py-1 rounded">HEADER</div>
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

            <div>
                <a href="/">
                    <?php if (isset($component)) { $__componentOriginal8892e718f3d0d7a916180885c6f012e7 = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal8892e718f3d0d7a916180885c6f012e7 = $attributes; } ?>
<?php $component = Illuminate\View\AnonymousComponent::resolve(['view' => 'components.application-logo','data' => ['class' => 'w-20 h-20 fill-current text-gray-500']] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('application-logo'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\Illuminate\View\AnonymousComponent::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes(['class' => 'w-20 h-20 fill-current text-gray-500']); ?>
<?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal8892e718f3d0d7a916180885c6f012e7)): ?>
<?php $attributes = $__attributesOriginal8892e718f3d0d7a916180885c6f012e7; ?>
<?php unset($__attributesOriginal8892e718f3d0d7a916180885c6f012e7); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal8892e718f3d0d7a916180885c6f012e7)): ?>
<?php $component = $__componentOriginal8892e718f3d0d7a916180885c6f012e7; ?>
<?php unset($__componentOriginal8892e718f3d0d7a916180885c6f012e7); ?>
<?php endif; ?>
                </a>
            </div>
        </div>

        <div class="<?php echo e($showFrontendOutlines ? 'relative border-2 border-dashed border-emerald-400 m-2 p-2 w-full sm:max-w-md' : 'w-full sm:max-w-md'); ?> mt-6">
            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($showFrontendOutlines): ?>
                <div class="absolute -top-3 left-2 bg-emerald-500 text-white text-[10px] leading-none px-2 py-1 rounded">MAIN</div>
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

            <div class="px-6 py-4 bg-white shadow-md overflow-hidden sm:rounded-lg">
                <?php echo $slot; ?>

            </div>
        </div>
    </div>
</body>
</html>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views/layouts/guest.blade.php ENDPATH**/ ?>