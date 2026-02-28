<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\develop.php
// Purpose: Admin Develop page route (layout outlines controls)
// Created: 25-02-2026 23:06 (Europe/Berlin)
// Changed: 27-02-2026 19:15 (Europe/Berlin)
// Version: 0.4
// ============================================================================

use App\Support\KsMaintenance;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

Route::get('/develop', function () {
    $hasSystemSettingsTable = Schema::hasTable('debug_settings');

    $maintenanceEnabled = KsMaintenance::enabled();

    $layoutOutlinesFrontendEnabled = false;
    $layoutOutlinesAdminEnabled = false;
    $layoutOutlinesAllowProductionStored = false;
    $layoutOutlinesAllowProductionEffective = false;

    if ($hasSystemSettingsTable) {
        try {
            $rows = DB::table('debug_settings')
                ->select(['key', 'value'])
                ->whereIn('key', [
                    'debug.layout_outlines_frontend_enabled',
                    'debug.layout_outlines_admin_enabled',
                    'debug.layout_outlines_allow_production',
                ])
                ->get()
                ->keyBy('key');

            $layoutOutlinesFrontendEnabled = ((string) ($rows['debug.layout_outlines_frontend_enabled']->value ?? '0') === '1');
            $layoutOutlinesAdminEnabled = ((string) ($rows['debug.layout_outlines_admin_enabled']->value ?? '0') === '1');
            $layoutOutlinesAllowProductionStored = ((string) ($rows['debug.layout_outlines_allow_production']->value ?? '0') === '1');
        } catch (\Throwable $e) {
            $layoutOutlinesFrontendEnabled = false;
            $layoutOutlinesAdminEnabled = false;
            $layoutOutlinesAllowProductionStored = false;
        }
    }

    // fail-closed (UI): AllowProduction wird nur als "aktiv" angezeigt, wenn Wartungsmodus aktiv ist.
    $layoutOutlinesAllowProductionEffective = ($maintenanceEnabled && $layoutOutlinesAllowProductionStored);

    return view('admin.develop', [
        'adminTab' => 'develop',
        'hasSystemSettingsTable' => $hasSystemSettingsTable,
        'maintenanceEnabled' => $maintenanceEnabled,
        'layoutOutlinesFrontendEnabled' => $layoutOutlinesFrontendEnabled,
        'layoutOutlinesAdminEnabled' => $layoutOutlinesAdminEnabled,
        'layoutOutlinesAllowProduction' => $layoutOutlinesAllowProductionEffective,
        'notice' => session('admin_notice'),
    ]);
})->name('develop');
