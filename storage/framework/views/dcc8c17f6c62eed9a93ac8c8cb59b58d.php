

<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Support</title>
    <?php echo app('Illuminate\Foundation\Vite')(['resources/css/app.css']); ?>
</head>
<body class="font-sans px-6 py-6 max-w-[720px] mx-auto">

<h1>Support</h1>

<?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($sent)): ?>
    <div class="p-2.5 bg-green-50 border border-green-200 rounded-xl mb-3">
        Support-Ticket wurde erstellt.
    </div>
<?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

<div class="border border-slate-200 rounded-xl bg-white p-4">
    <form method="POST" action="<?php echo e(url('/support')); ?>">
        <?php echo csrf_field(); ?>
        <input
            type="text"
            name="subject"
            placeholder="Betreff"
            required
            maxlength="200"
            class="w-full p-2.5 rounded-xl border border-slate-300 mb-3"
        >

        <textarea
            name="message"
            placeholder="Nachricht..."
            required
            maxlength="5000"
            class="w-full p-2.5 rounded-xl border border-slate-300 mb-3"
        ></textarea>

        <button
            type="submit"
            class="px-3.5 py-2.5 rounded-xl border border-slate-300 bg-white cursor-pointer"
        >
            Senden
        </button>
    </form>
</div>

</body>
</html><?php /**PATH C:\laragon\www\kiezsingles\resources\views\tickets\support.blade.php ENDPATH**/ ?>