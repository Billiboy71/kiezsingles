<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\settings_ajax.php
// Purpose: Admin settings save (AJAX) routes
// Changed: 27-02-2026 20:58 (Europe/Berlin)
// Version: 1.8
// ============================================================================

use App\Mail\MaintenanceEndedMail;
use App\Models\SystemSetting;
use App\Support\KsMaintenance;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

/*
|--------------------------------------------------------------------------
| Save Wartung + Debug (Ebene 2) - AJAX
|--------------------------------------------------------------------------
| Minimal bugfix:
| - Write only keys explicitly present in the request.
| - No implicit resets of unrelated maintenance.* or debug.* settings.
| - No cross-coupling writes between maintenance and debug keys.
*/
Route::post('/settings/save-ajax', function (\Illuminate\Http\Request $request) {
    // Erwartung: Auth/Admin/Section-Guards laufen ausschließlich über Middleware im Admin-Router-Group.
    // (Keine versteckten abort_unless/auth-Guards in Route-Closures.)

    if (!Schema::hasTable('maintenance_settings')) {
        return response()->json(['ok' => false, 'message' => 'maintenance_settings fehlt'], 422);
    }

    if (!Schema::hasTable('debug_settings')) {
        return response()->json(['ok' => false, 'message' => 'debug_settings fehlt'], 422);
    }

    $maintenanceBefore = KsMaintenance::enabled();
    $notifyEnabledBefore = KsMaintenance::notifyEnabled();

    $settingsRowExists = DB::table('maintenance_settings')->select(['id'])->first();
    if (!$settingsRowExists) {
        DB::table('maintenance_settings')->insert([
            'enabled' => 0,
            'show_eta' => 0,
            'eta_at' => null,
            'notify_enabled' => 0,
            'allow_admins' => 0,
            'allow_moderators' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    $maintenanceSettingsUpdate = [];

    $maintenanceEnabledProvided = $request->has('enabled');
    $maintenanceRequested = $maintenanceBefore;

    if ($maintenanceEnabledProvided) {
        $maintenanceRequested = $request->boolean('enabled');
        $maintenanceSettingsUpdate['enabled'] = $maintenanceRequested ? 1 : 0;
    }

    if ($request->has('show_eta')) {
        $maintenanceSettingsUpdate['show_eta'] = $request->boolean('show_eta') ? 1 : 0;
    }

    if ($request->has('maintenance_notify_enabled')) {
        $maintenanceSettingsUpdate['notify_enabled'] = $request->boolean('maintenance_notify_enabled') ? 1 : 0;
    }

    if ($request->has('maintenance_allow_admins')) {
        $maintenanceSettingsUpdate['allow_admins'] = $request->boolean('maintenance_allow_admins') ? 1 : 0;
    }

    if ($request->has('maintenance_allow_moderators')) {
        $maintenanceSettingsUpdate['allow_moderators'] = $request->boolean('maintenance_allow_moderators') ? 1 : 0;
    }

    if (!empty($maintenanceSettingsUpdate)) {
        $maintenanceSettingsUpdate['updated_at'] = now();
        DB::table('maintenance_settings')->update($maintenanceSettingsUpdate);
    }

    // Product rule: leaving maintenance disables debug switches server-side.
    if ($maintenanceEnabledProvided && !$maintenanceRequested) {
        $resetDebugKeys = [
            'debug.ui_enabled',
            'debug.routes_enabled',
            'debug.routes',
            'debug.turnstile_enabled',
            'debug.turnstile',
            'debug.register_errors',
            'debug.register_payload',
            'debug.break_glass',
            'debug.simulate_production',
            'debug.local_banner_enabled',
            'debug.layout_outlines_frontend_enabled',
            'debug.layout_outlines_admin_enabled',
            'debug.layout_outlines_allow_production',
        ];

        foreach ($resetDebugKeys as $k) {
            SystemSetting::updateOrCreate(
                ['key' => $k],
                ['value' => '0', 'group' => 'debug', 'cast' => 'bool']
            );
        }
    }

    if ($request->has('debug_ui_enabled')) {
        SystemSetting::updateOrCreate(
            ['key' => 'debug.ui_enabled'],
            ['value' => $request->boolean('debug_ui_enabled') ? '1' : '0', 'group' => 'debug', 'cast' => 'bool']
        );
    }

    if ($request->has('debug_routes_enabled')) {
        SystemSetting::updateOrCreate(
            ['key' => 'debug.routes_enabled'],
            ['value' => $request->boolean('debug_routes_enabled') ? '1' : '0', 'group' => 'debug', 'cast' => 'bool']
        );
    }

    if ($request->has('simulate_production')) {
        SystemSetting::updateOrCreate(
            ['key' => 'debug.simulate_production'],
            ['value' => $request->boolean('simulate_production') ? '1' : '0', 'group' => 'debug', 'cast' => 'bool']
        );
    }

    if ($request->has('break_glass_enabled')) {
        SystemSetting::updateOrCreate(
            ['key' => 'debug.break_glass'],
            ['value' => $request->boolean('break_glass_enabled') ? '1' : '0', 'group' => 'debug', 'cast' => 'bool']
        );
    }

    if ($request->has('break_glass_totp_secret')) {
        $breakGlassSecret = (string) $request->input('break_glass_totp_secret', '');
        $breakGlassSecret = strtoupper(trim($breakGlassSecret));
        $breakGlassSecret = preg_replace('/\s+/', '', $breakGlassSecret);

        if ($breakGlassSecret !== '' && !preg_match('/^[A-Z2-7]+$/', $breakGlassSecret)) {
            $breakGlassSecret = '';
        }

        SystemSetting::updateOrCreate(
            ['key' => 'debug.break_glass_totp_secret'],
            ['value' => $breakGlassSecret, 'group' => 'debug', 'cast' => 'string']
        );
    }

    if ($request->has('break_glass_ttl_minutes')) {
        $breakGlassTtlInt = (int) trim((string) $request->input('break_glass_ttl_minutes', '15'));
        if ($breakGlassTtlInt < 1) {
            $breakGlassTtlInt = 1;
        }
        if ($breakGlassTtlInt > 120) {
            $breakGlassTtlInt = 120;
        }

        SystemSetting::updateOrCreate(
            ['key' => 'debug.break_glass_ttl_minutes'],
            ['value' => (string) $breakGlassTtlInt, 'group' => 'debug', 'cast' => 'int']
        );
    }

    if ($request->has('layout_outlines_frontend_enabled')) {
        SystemSetting::updateOrCreate(
            ['key' => 'debug.layout_outlines_frontend_enabled'],
            ['value' => $request->boolean('layout_outlines_frontend_enabled') ? '1' : '0', 'group' => 'debug', 'cast' => 'bool']
        );
    }

    if ($request->has('layout_outlines_admin_enabled')) {
        SystemSetting::updateOrCreate(
            ['key' => 'debug.layout_outlines_admin_enabled'],
            ['value' => $request->boolean('layout_outlines_admin_enabled') ? '1' : '0', 'group' => 'debug', 'cast' => 'bool']
        );
    }

    if ($request->has('layout_outlines_allow_production')) {
        SystemSetting::updateOrCreate(
            ['key' => 'debug.layout_outlines_allow_production'],
            ['value' => $request->boolean('layout_outlines_allow_production') ? '1' : '0', 'group' => 'debug', 'cast' => 'bool']
        );
    }

    $maintenanceAfter = KsMaintenance::enabled();

    // Wartungsende-Mails nur beim echten Übergang 1 -> 0 und nur wenn Notify davor aktiv war.
    if ($maintenanceBefore && !$maintenanceAfter && $notifyEnabledBefore) {
        try {
            if (Schema::hasTable('maintenance_notifications')) {
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
                        // Claim zurücknehmen, damit ein späterer Versuch möglich bleibt.
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
                    }
                }
            }
        } catch (\Throwable $e) {
            // bewusst ignorieren
        }
    }

    return response()->json(['ok' => true]);
})->name('settings.save.ajax');
