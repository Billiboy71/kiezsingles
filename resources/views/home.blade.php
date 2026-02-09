<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\home.blade.php
// Changed: 08-02-2026 01:33
// Purpose: Public landing page with maintenance mode indicator + legal links
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
