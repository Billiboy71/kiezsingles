<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\settings_ajax.php
// Purpose: Admin settings save (AJAX) routes
// Changed: 20-02-2026 12:08 (Europe/Berlin)
// Version: 1.1
// ============================================================================

use App\Mail\MaintenanceEndedMail;
use App\Models\SystemSetting;
use App\Support\Admin\AdminSectionAccess;
use App\Support\SystemSettingHelper;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

/*
|--------------------------------------------------------------------------
| Save Wartung + Debug (Ebene 2) – AJAX
|--------------------------------------------------------------------------
*/
Route::post('/settings/save-ajax', function (\Illuminate\Http\Request $request) {
    // Erwartung: Auth/Admin/Section-Guards laufen ausschließlich über Middleware im Admin-Router-Group.
    // (Keine versteckten abort_unless/auth-Guards in Route-Closures.)

    if (!Schema::hasTable('app_settings')) {
        return response()->json(['ok' => false, 'message' => 'app_settings fehlt'], 422);
    }

    if (!Schema::hasTable('system_settings')) {
        return response()->json(['ok' => false, 'message' => 'system_settings fehlt'], 422);
    }

    $maintenanceRequested = (bool) $request->input('maintenance_enabled', false);

    // Wartungs-Login-Ausnahmen (serverseitig) – werden als SystemSettings gespeichert
    // WICHTIG: nur speichern, wenn Wartung AN ist (sonst Zustand behalten).
    if ($maintenanceRequested) {
        $allowAdminsRequested = (bool) $request->input('maintenance_allow_admins', false);
        $allowModeratorsRequested = (bool) $request->input('maintenance_allow_moderators', false);

        SystemSetting::updateOrCreate(
            ['key' => 'maintenance.allow_admins'],
            ['value' => $allowAdminsRequested ? '1' : '0', 'group' => 'maintenance', 'cast' => 'bool']
        );

        SystemSetting::updateOrCreate(
            ['key' => 'maintenance.allow_moderators'],
            ['value' => $allowModeratorsRequested ? '1' : '0', 'group' => 'maintenance', 'cast' => 'bool']
        );
    }

    // wichtig: Zustand VOR dem Update merken (für Wartungsende-Mailversand)
    $notifyEnabledBefore = (bool) SystemSettingHelper::get('maintenance.notify_enabled', false);

    $maintenanceNotifyRequested = (bool) $request->input('maintenance_notify_enabled', false);

    SystemSetting::updateOrCreate(
        ['key' => 'maintenance.notify_enabled'],
        ['value' => $maintenanceNotifyRequested ? '1' : '0', 'group' => 'maintenance', 'cast' => 'bool']
    );

    // simulate_production ist NUR im Wartungsmodus zulässig
    $simulateRequested = $maintenanceRequested
        ? (bool) $request->input('simulate_production', false)
        : false;

    SystemSetting::updateOrCreate(
        ['key' => 'debug.simulate_production'],
        ['value' => $simulateRequested ? '1' : '0', 'group' => 'debug', 'cast' => 'bool']
    );

    $settings = DB::table('app_settings')->select(['id'])->first();
    if (!$settings) {
        DB::table('app_settings')->insert([
            'maintenance_enabled' => 0,
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ]);
    }

    DB::table('app_settings')->update([
        'maintenance_enabled' => $maintenanceRequested ? 1 : 0,
    ]);

    $breakGlassRequested = (bool) $request->input('break_glass_enabled', false);

    $breakGlassSecret = (string) $request->input('break_glass_totp_secret', '');
    $breakGlassSecret = strtoupper(trim($breakGlassSecret));
    $breakGlassSecret = preg_replace('/\s+/', '', $breakGlassSecret);

    if ($breakGlassSecret !== '' && !preg_match('/^[A-Z2-7]+$/', $breakGlassSecret)) {
        $breakGlassSecret = '';
    }

    $breakGlassTtl = (string) $request->input('break_glass_ttl_minutes', '');
    $breakGlassTtl = trim($breakGlassTtl);
    $breakGlassTtlInt = (int) $breakGlassTtl;

    if ($breakGlassTtlInt < 1) {
        $breakGlassTtlInt = 1;
    }
    if ($breakGlassTtlInt > 120) {
        $breakGlassTtlInt = 120;
    }

    SystemSetting::updateOrCreate(
        ['key' => 'debug.break_glass'],
        ['value' => $breakGlassRequested ? '1' : '0', 'group' => 'debug', 'cast' => 'bool']
    );

    SystemSetting::updateOrCreate(
        ['key' => 'debug.break_glass_totp_secret'],
        ['value' => $breakGlassSecret, 'group' => 'debug', 'cast' => 'string']
    );

    SystemSetting::updateOrCreate(
        ['key' => 'debug.break_glass_ttl_minutes'],
        ['value' => (string) $breakGlassTtlInt, 'group' => 'debug', 'cast' => 'int']
    );

    if (!$maintenanceRequested) {
        DB::table('app_settings')->update([
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ]);

        SystemSetting::updateOrCreate(
            ['key' => 'maintenance.notify_enabled'],
            ['value' => '0', 'group' => 'maintenance', 'cast' => 'bool']
        );

        SystemSetting::updateOrCreate(
            ['key' => 'debug.ui_enabled'],
            ['value' => '0', 'group' => 'debug', 'cast' => 'bool']
        );

        SystemSetting::updateOrCreate(
            ['key' => 'debug.routes_enabled'],
            ['value' => '0', 'group' => 'debug', 'cast' => 'bool']
        );

        SystemSetting::updateOrCreate(
            ['key' => 'debug.break_glass'],
            ['value' => '0', 'group' => 'debug', 'cast' => 'bool']
        );

        SystemSetting::updateOrCreate(
            ['key' => 'debug.break_glass_ttl_minutes'],
            ['value' => '15', 'group' => 'debug', 'cast' => 'int']
        );

        // simulate_production beim Verlassen der Wartung hart AUS
        SystemSetting::updateOrCreate(
            ['key' => 'debug.simulate_production'],
            ['value' => '0', 'group' => 'debug', 'cast' => 'bool']
        );

        try {
            // wichtig: nicht DB lesen (wurde oben bereits auf 0 gesetzt), sondern Zustand von davor verwenden
            $notifyEnabled = (bool) $notifyEnabledBefore;

            if ($notifyEnabled && Schema::hasTable('maintenance_notifications')) {
                $batch = DB::table('maintenance_notifications')
                    ->select(['id', 'email'])
                    ->whereNull('notified_at')
                    ->orderBy('id', 'asc')
                    ->limit(2000)
                    ->get();

                foreach ($batch as $row) {
                    $id = isset($row->id) ? (int) $row->id : 0;
                    if ($id < 1) {
                        continue;
                    }

                    $email = isset($row->email) ? (string) $row->email : '';
                    $email = trim($email);

                    if ($email === '' || strlen($email) > 255 || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
                        continue;
                    }

                    // Claim: verhindert Doppel-Sends (auch bei parallelen Requests)
                    $claimed = DB::table('maintenance_notifications')
                        ->where('id', $id)
                        ->whereNull('notified_at')
                        ->update([
                            'notified_at' => now(),
                            'updated_at' => now(),
                        ]);

                    if ((int) $claimed !== 1) {
                        continue;
                    }

                    try {
                        Mail::to($email)->send(new MaintenanceEndedMail());

                        DB::table('maintenance_notifications')->where('id', $id)->delete();
                    } catch (\Throwable $e) {
                        // bewusst: claim zurücknehmen, damit später erneut versucht werden kann
                        try {
                            DB::table('maintenance_notifications')
                                ->where('id', $id)
                                ->update([
                                    'notified_at' => null,
                                    'updated_at' => now(),
                                ]);
                        } catch (\Throwable $e2) {
                            // bewusst ignorieren
                        }
                        continue;
                    }
                }
            }
        } catch (\Throwable $e) {
            // bewusst ignorieren
        }

        return response()->json(['ok' => true]);
    }

    $requestedUi = (bool) $request->input('debug_ui_enabled', false);
    $requestedRoutes = (bool) $request->input('debug_routes_enabled', false);

    $finalUi = $requestedUi ? '1' : '0';
    $finalRoutes = ($requestedUi && $requestedRoutes) ? '1' : '0';

    SystemSetting::updateOrCreate(
        ['key' => 'debug.ui_enabled'],
        ['value' => $finalUi, 'group' => 'debug', 'cast' => 'bool']
    );

    SystemSetting::updateOrCreate(
        ['key' => 'debug.routes_enabled'],
        ['value' => $finalRoutes, 'group' => 'debug', 'cast' => 'bool']
    );

    return response()->json(['ok' => true]);
})->name('settings.save.ajax');