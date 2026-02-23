<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\landing.blade.php
// Purpose: Public landing page with maintenance mode indicator + legal links
// Changed: 23-02-2026 23:19 (Europe/Berlin)
// Version: 1.1
// ============================================================================
?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>KiezSingles</title>
    @vite(['resources/css/app.css'])
</head>
<body class="font-sans m-10">

<?php
    // Minimal, direkte DB-Abfrage – bewusst ohne Helper/Magie
    $maintenance = null;

    try {
        if (\Illuminate\Support\Facades\Schema::hasTable('app_settings')) {
            $maintenance = \Illuminate\Support\Facades\DB::table('app_settings')->first();
        }
    } catch (\Throwable $e) {
        $maintenance = null;
    }

    $maintenanceEnabled = $maintenance && (bool) $maintenance->maintenance_enabled;
    $showEta = $maintenanceEnabled
        && (bool) ($maintenance->maintenance_show_eta ?? false)
        && !empty($maintenance->maintenance_eta_at);

    $notifyEnabled = false;

    try {
        if (\Illuminate\Support\Facades\Schema::hasTable('system_settings')) {
            $row = \Illuminate\Support\Facades\DB::table('system_settings')
                ->select(['value'])
                ->where('key', 'maintenance.notify_enabled')
                ->first();

            $val = $row ? (string) ($row->value ?? '') : '';
            $val = trim($val);

            $notifyEnabled = ($val === '1' || strtolower($val) === 'true');
        }
    } catch (\Throwable $e) {
        $notifyEnabled = false;
    }

    $notifyOk = (bool) session('maintenance_notify_ok', false);
    $notifyErr = (string) session('maintenance_notify_error', '');
?>

<h1>KiezSingles</h1>
<p>Deine lokale Plattform.</p>
<p>(Beta).</p>

<?php if ($maintenanceEnabled): ?>
    <div class="my-5 p-4 border-2 border-red-600 bg-red-50">
        <strong>Wartungsmodus</strong><br>
        Die Plattform ist aktuell im Wartungsmodus.
        <?php if ($showEta): ?>
            <br>
            <small>
                Voraussichtlich bis:
                <?= \Illuminate\Support\Carbon::parse($maintenance->maintenance_eta_at)
                    ->timezone('Europe/Berlin')
                    ->format('d.m.Y H:i') ?>
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