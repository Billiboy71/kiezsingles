<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\settings_ajax.php
// Purpose: Admin settings save (AJAX) routes
// Changed: 25-02-2026 20:24 (Europe/Berlin)
// Version: 1.4
// ============================================================================

use App\Mail\MaintenanceEndedMail;
use App\Models\SystemSetting;
use App\Support\SystemSettingHelper;
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

    if (!Schema::hasTable('app_settings')) {
        return response()->json(['ok' => false, 'message' => 'app_settings fehlt'], 422);
    }

    if (!Schema::hasTable('system_settings')) {
        return response()->json(['ok' => false, 'message' => 'system_settings fehlt'], 422);
    }

    $beforeRow = DB::table('app_settings')->select(['maintenance_enabled'])->first();
    $maintenanceBefore = $beforeRow ? (bool) ($beforeRow->maintenance_enabled ?? false) : false;
    $notifyEnabledBefore = (bool) SystemSettingHelper::get('maintenance.notify_enabled', false);

    $settingsRowExists = DB::table('app_settings')->select(['id'])->first();
    if (!$settingsRowExists) {
        DB::table('app_settings')->insert([
            'maintenance_enabled' => 0,
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ]);
    }

    $appSettingsUpdate = [];

    $maintenanceEnabledProvided = $request->has('maintenance_enabled');
    $maintenanceRequested = $maintenanceBefore;

    if ($maintenanceEnabledProvided) {
        $maintenanceRequested = $request->boolean('maintenance_enabled');
        $appSettingsUpdate['maintenance_enabled'] = $maintenanceRequested ? 1 : 0;
    }

    if ($request->has('maintenance_show_eta')) {
        $appSettingsUpdate['maintenance_show_eta'] = $request->boolean('maintenance_show_eta') ? 1 : 0;
    }

    if (!empty($appSettingsUpdate)) {
        DB::table('app_settings')->update($appSettingsUpdate);
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
        ];

        foreach ($resetDebugKeys as $k) {
            SystemSetting::updateOrCreate(
                ['key' => $k],
                ['value' => '0', 'group' => 'debug', 'cast' => 'bool']
            );
        }
    }

    if ($request->has('maintenance_notify_enabled')) {
        SystemSetting::updateOrCreate(
            ['key' => 'maintenance.notify_enabled'],
            ['value' => $request->boolean('maintenance_notify_enabled') ? '1' : '0', 'group' => 'maintenance', 'cast' => 'bool']
        );
    }

    if ($request->has('maintenance_allow_admins')) {
        SystemSetting::updateOrCreate(
            ['key' => 'maintenance.allow_admins'],
            ['value' => $request->boolean('maintenance_allow_admins') ? '1' : '0', 'group' => 'maintenance', 'cast' => 'bool']
        );
    }

    if ($request->has('maintenance_allow_moderators')) {
        SystemSetting::updateOrCreate(
            ['key' => 'maintenance.allow_moderators'],
            ['value' => $request->boolean('maintenance_allow_moderators') ? '1' : '0', 'group' => 'maintenance', 'cast' => 'bool']
        );
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

    $afterRow = DB::table('app_settings')->select(['maintenance_enabled'])->first();
    $maintenanceAfter = $afterRow ? (bool) ($afterRow->maintenance_enabled ?? false) : false;

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
