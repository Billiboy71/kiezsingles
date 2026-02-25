<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\status.php
// Purpose: Admin live status endpoint (JSON for header auto-refresh)
// Created: 16-02-2026 19:15 (Europe/Berlin)
// Changed: 25-02-2026 15:10 (Europe/Berlin)
// Version: 1.2
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

    // debug_any = irgendein Debug-Schalter aktiv (für Badge)
    $debugAny = false;

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

        // NOTE:
        // "simulate_production" soll NICHT als "Debug aktiv" für das Badge zählen.
        $debugAnyKeys = [
            'debug.ui_enabled',
            'debug.routes_enabled',
            'debug.routes',
            'debug.turnstile_enabled',
            'debug.turnstile',
            'debug.register_errors',
            'debug.register_payload',
            //'debug.break_glass',
            'debug.local_banner_enabled',
        ];

        foreach ($debugAnyKeys as $k) {
            if ((bool) SystemSettingHelper::get($k, false)) {
                $debugAny = true;
                break;
            }
        }
    }

    if (app()->environment('local')) {
        $env = 'local';
    }

    if ($hasSystemSettingsTable && (bool) SystemSettingHelper::get('debug.simulate_production', false)) {
        $env = 'prod-sim';
    }

    // UI-only: Debug-Button anzeigen, sobald Wartung aktiv ist.
    // Serverseitige Autorisierung läuft ausschließlich über Middleware (auth + superadmin + section:debug).
    $debug = (bool) $maintenance;

    return response()->json([
        'maintenance'   => $maintenance,
        'debug'         => $debug,
        'debug_enabled' => $debugEnabled,
        'debug_any'     => $debugAny,
        'break_glass'   => $breakGlass,
        'env'           => $env,
    ]);
})
    ->name('status');