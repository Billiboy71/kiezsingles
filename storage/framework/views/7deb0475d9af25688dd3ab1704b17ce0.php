<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\landing.blade.php
// Purpose: Public landing page with maintenance mode indicator + legal links
// Changed: 27-02-2026 18:44 (Europe/Berlin)
// Version: 1.4
// ============================================================================
?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>KiezSingles</title>
    <?php echo app('Illuminate\Foundation\Vite')(['resources/css/app.css']); ?>
</head>
<body class="font-sans m-10">

<?php
    $maintenanceEnabled = \App\Support\KsMaintenance::enabled();
    $notifyEnabled = \App\Support\KsMaintenance::notifyEnabled();

    $notifyOk = (bool) session('maintenance_notify_ok', false);
    $notifyErr = (string) session('maintenance_notify_error', '');

    $maintenanceShowEta = (bool) ($maintenanceShowEta ?? false);
    $etaDateValue = (string) ($etaDateValue ?? '');
    $etaTimeValue = (string) ($etaTimeValue ?? '');

    $showEta = $maintenanceEnabled && $maintenanceShowEta && $etaDateValue !== '';

    $etaText = '';
    if ($showEta) {
        if ($etaTimeValue === '') {
            try {
                $etaText = \Illuminate\Support\Carbon::createFromFormat('Y-m-d', $etaDateValue)
                    ->format('d.m.Y');
            } catch (\Throwable $e) {
                $etaText = '';
            }
        } else {
            $etaText = $etaDateValue . ' ' . $etaTimeValue . ' Uhr';
        }
    }
?>

<h1>KiezSingles</h1>
<p>Deine lokale Plattform.</p>
<p>(Beta).</p>

<?php if ($maintenanceEnabled): ?>
    <div class="my-5 p-4 border-2 border-red-600 bg-red-50">
        <strong>Wartungsmodus</strong><br>
        Die Plattform ist aktuell im Wartungsmodus.
        <?php if ($etaText !== ''): ?>
            <br>
            <small>
                Voraussichtlich bis:
                <?= e($etaText) ?>
            </small>
        <?php endif; ?>

        <?php if ($notifyEnabled): ?>
            <div class="mt-4 pt-3 border-t border-black/15">
                <strong>Benachrichtige mich</strong><br>
                <small>Wenn der Wartungsmodus beendet ist, bekommst du eine E-Mail. Danach wird deine Adresse gelöscht.</small>

                <?php if ($notifyOk): ?>
                    <div class="mt-2.5 p-2.5 border border-green-600 bg-green-50">
                        <strong>Danke.</strong> Du wirst benachrichtigt.
                    </div>
                <?php elseif ($notifyErr !== ''): ?>
                    <div class="mt-2.5 p-2.5 border border-red-600 bg-red-50">
                        <?= e($notifyErr) ?>
                    </div>
                <?php endif; ?>

                <form method="POST" action="/maintenance-notify" class="mt-2.5">
                    <input type="hidden" name="_token" value="<?= e(csrf_token()) ?>">
                    <input
                        type="email"
                        name="email"
                        required
                        autocomplete="email"
                        inputmode="email"
                        placeholder="E-Mail-Adresse"
                        class="px-3 py-2.5 border border-gray-300 rounded-xl w-72 max-w-full"
                    >
                    <button type="submit" class="px-3 py-2.5 rounded-xl border border-slate-300 bg-white cursor-pointer ml-2">
                        Benachrichtigen
                    </button>
                </form>
            </div>
        <?php endif; ?>
    </div>
<?php endif; ?>

<p>
    <a href="/login">Login</a>
    <?php if (!$maintenanceEnabled): ?>
        | <a href="/register">Registrieren</a>
    <?php endif; ?>
</p>

<hr class="my-8">

<p class="text-sm">
    <a href="/contact">Kontakt</a> |
    <a href="/impressum">Impressum</a> |
    <a href="/datenschutz">Datenschutz</a> |
    <a href="/nutzungsbedingungen">Nutzungsbedingungen</a>
</p>

</body>
</html>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views/landing.blade.php ENDPATH**/ ?>