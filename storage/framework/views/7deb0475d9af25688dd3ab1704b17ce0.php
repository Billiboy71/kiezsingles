<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\landing.blade.php
// Purpose: Public landing page with maintenance mode indicator + legal links
// Changed: 13-02-2026 01:05 (Europe/Berlin)
// Version: 1.0
// ============================================================================
?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>KiezSingles</title>
</head>
<body style="font-family: system-ui; margin: 40px;">

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
    <div style="margin: 20px 0; padding: 15px; border: 2px solid #c00; background: #fff3f3;">
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
            <div style="margin-top: 14px; padding-top: 12px; border-top: 1px solid rgba(0,0,0,.15);">
                <strong>Benachrichtige mich</strong><br>
                <small>Wenn der Wartungsmodus beendet ist, bekommst du eine E-Mail. Danach wird deine Adresse gelöscht.</small>

                <?php if ($notifyOk): ?>
                    <div style="margin-top: 10px; padding: 10px; border: 1px solid #16a34a; background: #f0fff4;">
                        <strong>Danke.</strong> Du wirst benachrichtigt.
                    </div>
                <?php elseif ($notifyErr !== ''): ?>
                    <div style="margin-top: 10px; padding: 10px; border: 1px solid #c00; background: #fff3f3;">
                        <?= e($notifyErr) ?>
                    </div>
                <?php endif; ?>

                <form method="POST" action="/maintenance-notify" style="margin-top: 10px;">
                    <input type="hidden" name="_token" value="<?= e(csrf_token()) ?>">
                    <input
                        type="email"
                        name="email"
                        required
                        autocomplete="email"
                        inputmode="email"
                        placeholder="E-Mail-Adresse"
                        style="padding: 10px 12px; border: 1px solid #ccc; border-radius: 10px; width: 280px; max-width: 100%;"
                    >
                    <button type="submit" style="padding: 10px 12px; border-radius: 10px; border: 1px solid #cbd5e1; background: #fff; cursor: pointer; margin-left: 8px;">
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

<hr style="margin: 30px 0;">

<p style="font-size: 0.9em;">
    <a href="/contact">Kontakt</a> |
    <a href="/impressum">Impressum</a> |
    <a href="/datenschutz">Datenschutz</a> |
    <a href="/nutzungsbedingungen">Nutzungsbedingungen</a>
</p>

</body>
</html>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views/landing.blade.php ENDPATH**/ ?>