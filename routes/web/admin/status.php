<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\status.php
// Purpose: Admin live status endpoint (JSON for header auto-refresh)
// Created: 16-02-2026 19:15 (Europe/Berlin)
// Changed: 20-02-2026 16:31 (Europe/Berlin)
// Version: 1.1
// ============================================================================

use App\Support\SystemSettingHelper;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

Route::get('/status', function () {
    // Erwartung: Auth/Superadmin/Section-Guards laufen ausschließlich über den Gruppen-Wrapper in routes/web/admin.php.

    $maintenance = false;

    // debug_enabled = tatsächlicher Schalter (SystemSetting)
    $debugEnabled = false;

    // debug = UI-Sichtbarkeit (Wartung aktiv + Debug-UI erlaubt)
    $debug = false;

    $breakGlass = false;
    $env = 'prod';

    $hasSettingsTable = Schema::hasTable('app_settings');
    $hasSystemSettingsTable = Schema::hasTable('system_settings');

    if ($hasSettingsTable) {
        $row = \DB::table('app_settings')
            ->select('maintenance_enabled')
            ->first();

        $maintenance = $row ? (bool) $row->maintenance_enabled : false;
    }

    if ($hasSystemSettingsTable) {
        $debugEnabled = (bool) SystemSettingHelper::get('debug.ui_enabled', false);
        $breakGlass = (bool) SystemSettingHelper::get('debug.break_glass', false);
    }

    if (app()->environment('local')) {
        $env = 'local';
    }

    if ($hasSystemSettingsTable && (bool) SystemSettingHelper::get('debug.simulate_production', false)) {
        $env = 'prod-sim';
    }

    // UI-only: Debug-Button anzeigen, wenn Wartung aktiv und Debug-UI grundsätzlich erlaubt ist.
    // Serverseitige Autorisierung läuft ausschließlich über Middleware (auth + superadmin + section:debug).
    if ($maintenance && $hasSystemSettingsTable) {
        $debug = (bool) SystemSettingHelper::debugUiAllowed();
    } else {
        $debug = false;
    }

    return response()->json([
        'maintenance'   => $maintenance,
        'debug'         => $debug,
        'debug_enabled' => $debugEnabled,
        'break_glass'   => $breakGlass,
        'env'           => $env,
    ]);
})
    ->name('status');