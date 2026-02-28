

<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Noteinstieg</title>

    
    <?php echo app('Illuminate\Foundation\Vite')(['resources/css/app.css', 'resources/js/app.js']); ?>
</head>
<body class="font-sans px-6 py-6 max-w-[520px] mx-auto">

    <?php
        $viaMode = (string) ($via ?? 'totp');
        $remaining = (int) ($remainingSeconds ?? 0);
    ?>

    <div
        id="ks_noteinstieg_entry"
        data-ks-noteinstieg-entry="1"
        data-via="<?php echo e($viaMode); ?>"
        data-remaining-seconds="<?php echo e($remaining); ?>"
    >
        <h1 class="m-0 mb-2">Noteinstieg</h1>
        <p class="m-0 mb-2.5 text-slate-700">Einstiegsseite (nur mit gültigem Noteinstieg-Cookie).</p>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($viaMode === 'totp'): ?>
            <div class="mb-4 p-3.5 rounded-xl border border-slate-300 bg-white">
                <div class="font-bold mb-1">Countdown</div>
                <div class="text-slate-900">läuft ab in <span id="bg_countdown" class="font-extrabold">--:--</span></div>
            </div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <div class="flex flex-col gap-2.5">
            <a id="bg_login" href="<?php echo e(url('/login')); ?>" class="block text-center px-3.5 py-3 rounded-xl border border-slate-300 bg-white no-underline text-slate-900">Login</a>
            <a id="bg_register" href="<?php echo e(url('/register')); ?>" class="block text-center px-3.5 py-3 rounded-xl border border-slate-300 bg-white no-underline text-slate-900">Registrieren</a>
            <a id="bg_maintenance" href="<?php echo e(url('/noteinstieg-wartung')); ?>" class="block text-center px-3.5 py-3 rounded-xl border border-slate-300 bg-white no-underline text-slate-900">Wartungsseite ansehen</a>
            <a id="bg_reopen" href="<?php echo e(url('/noteinstieg?next=/noteinstieg-einstieg')); ?>" class="block text-center px-3.5 py-3 rounded-xl border border-slate-300 bg-white no-underline text-slate-900">Noteinstieg erneut öffnen</a>
        </div>
    </div>

</body>
</html><?php /**PATH C:\laragon\www\kiezsingles\resources\views\noteinstieg\entry.blade.php ENDPATH**/ ?>