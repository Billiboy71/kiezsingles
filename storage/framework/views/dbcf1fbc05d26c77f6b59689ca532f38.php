<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\layouts\public.blade.php
// Purpose: Unified public layout (single frame) with growing copyright year
// Changed: 23-02-2026 23:33 (Europe/Berlin)
// Version: 0.1
// ============================================================================
?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?php echo e($title ?? 'KiezSingles'); ?></title>
    <?php echo app('Illuminate\Foundation\Vite')(['resources/css/app.css']); ?>
</head>
<body class="font-sans m-0 bg-gray-100">

    <!-- FIXED PUBLIC FRAME -->
    <div class="max-w-[900px] mx-auto p-10 bg-white min-h-screen">

        <!-- HEADER / BRAND -->
        <header class="mb-8">
            <div class="flex items-center gap-3.5">
                <img
                    src="/images/logo.png"
                    alt="KiezSingles Logo"
                    class="w-11 h-11 object-contain block"
                >
                <div>
                    <h1 class="m-0">KiezSingles</h1>
                    <p class="mt-1 mb-0 text-slate-500">Deine lokale Plattform (Beta)</p>
                </div>
            </div>
        </header>

        <!-- PUBLIC NAV -->
        <nav class="mb-8 text-[0.95em]">
            <a href="/">Home</a> |
            <a href="/contact">Kontakt</a> |
            <a href="/impressum">Impressum</a> |
            <a href="/datenschutz">Datenschutz</a> |
            <a href="/nutzungsbedingungen">Nutzungsbedingungen</a>
        </nav>

        <!-- CONTENT FRAME -->
        <main>
            <?php echo e($slot); ?>

        </main>

        <!-- FOOTER -->
        <footer class="mt-10 text-[0.85em] text-slate-500">
            © 2026–<?php echo e(date('Y')); ?> KiezSingles
        </footer>

    </div>

</body>
</html><?php /**PATH C:\laragon\www\kiezsingles\resources\views\layouts\public.blade.php ENDPATH**/ ?>