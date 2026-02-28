

<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>User melden</title>
    <?php echo app('Illuminate\Foundation\Vite')('resources/css/app.css'); ?>
</head>
<body class="ks-fe-support-body">

<h1>User melden</h1>
<p>Gemeldeter User: #<?php echo e((string) ($user->id ?? '')); ?></p>

<?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($sent)): ?>
    <div class="ks-fe-notice">Meldung wurde erstellt.</div>
<?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

<div class="ks-fe-card">
    <form method="POST" action="<?php echo e(url('/report/' . (string) ($user->public_id ?? ''))); ?>">
        <?php echo csrf_field(); ?>
        <textarea class="ks-fe-input" name="message" placeholder="Beschreibe das Problem..." required maxlength="5000"></textarea>
        <button type="submit" class="ks-fe-btn">Melden</button>
    </form>
</div>

</body>
</html><?php /**PATH C:\laragon\www\kiezsingles\resources\views\tickets\report.blade.php ENDPATH**/ ?>