<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\maintenance_eta.php
// Purpose: Admin maintenance (GET /admin/maintenance) + ETA routes (AJAX + form)
// Changed: 20-02-2026 11:53 (Europe/Berlin)
// Version: 1.2
// ============================================================================

use App\Support\SystemSettingHelper;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

$buildMaintenanceContext = function (): array {
    // Erwartung: Auth/Admin/Section-Guards laufen ausschließlich über Middleware im Admin-Router-Group.
    // (Keine versteckten abort_unless/auth-Guards in Context-Buildern.)

    $hasSettingsTable = Schema::hasTable('app_settings');
    $settings = null;

    if ($hasSettingsTable) {
        $settings = DB::table('app_settings')->select([
            'maintenance_enabled',
            'maintenance_show_eta',
            'maintenance_eta_at',
        ])->first();
    }

    $maintenanceEnabled  = $settings ? (bool) $settings->maintenance_enabled : false;
    $maintenanceShowEta  = $settings ? (bool) $settings->maintenance_show_eta : false;
    $maintenanceEtaAt    = (string) ($settings->maintenance_eta_at ?? '');

    $etaDateValue = '';
    $etaTimeValue = '';

    if ($maintenanceEtaAt !== '') {
        try {
            $dt = \Illuminate\Support\Carbon::parse($maintenanceEtaAt);
            $etaDateValue = $dt->format('Y-m-d');
            $etaTimeValue = $dt->format('H:i');
        } catch (\Throwable $e) {
            $etaDateValue = '';
            $etaTimeValue = '';
        }
    }

    $hasSystemSettingsTable = Schema::hasTable('system_settings');

    $debugUiEnabled = false;
    $debugRoutesEnabled = false;

    $breakGlassEnabled = false;
    $breakGlassTotpSecret = '';
    $breakGlassTtlMinutes = 15;

    $simulateProd = false;
    $maintenanceNotifyEnabled = false;

    $maintenanceAllowAdmins = false;
    $maintenanceAllowModerators = false;

    if ($hasSystemSettingsTable) {
        $debugUiEnabled = (bool) SystemSettingHelper::get('debug.ui_enabled', false);
        $debugRoutesEnabled = (bool) SystemSettingHelper::get('debug.routes_enabled', false);

        $breakGlassEnabled = (bool) SystemSettingHelper::get('debug.break_glass', false);
        $breakGlassTotpSecret = (string) SystemSettingHelper::get('debug.break_glass_totp_secret', '');
        $breakGlassTtlMinutes = (int) SystemSettingHelper::get('debug.break_glass_ttl_minutes', 15);

        $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);

        $maintenanceNotifyEnabled = (bool) SystemSettingHelper::get('maintenance.notify_enabled', false);

        $maintenanceAllowAdmins = (bool) SystemSettingHelper::get('maintenance.allow_admins', false);
        $maintenanceAllowModerators = (bool) SystemSettingHelper::get('maintenance.allow_moderators', false);

        if ($breakGlassTtlMinutes < 1) {
            $breakGlassTtlMinutes = 1;
        }
        if ($breakGlassTtlMinutes > 120) {
            $breakGlassTtlMinutes = 120;
        }
    }

    // Debug gilt als "aktiv", sobald irgendein Debug-Teil eingeschaltet ist.
    $debugEnabledFlag = (
        (bool) $debugUiEnabled
        || (bool) $debugRoutesEnabled
        || (bool) $breakGlassEnabled
        || (bool) $simulateProd
    );

    // Fix: Debug-Tab soll während aktivem Wartungsmodus sichtbar sein (wie in anderen Admin-Seiten).
    $debugTabVisibleFlag = ((bool) $maintenanceEnabled) || ((bool) $debugEnabledFlag);

    $notice = session('admin_notice');

    $statusBg = $maintenanceEnabled ? '#fff5f5' : '#f0fff4';
    $statusBorder = $maintenanceEnabled ? '#fecaca' : '#bbf7d0';
    $statusBadgeBg = $maintenanceEnabled ? '#dc2626' : '#16a34a';
    $statusBadgeText = $maintenanceEnabled ? 'WARTUNG AKTIV' : 'LIVE';

    $isProd = app()->environment('production');

    $envBadgeText = $isProd ? 'PRODUCTION' : 'LOCAL';
    $envBadgeBg = $isProd ? '#7c3aed' : '#0ea5e9';

    if (!$isProd && $simulateProd) {
        $envBadgeText = 'PROD-SIM';
        $envBadgeBg = '#f59e0b';
    }

    $simulateRowCss = $isProd ? 'display:none;' : '';

    $adminHomeUrl = url('/admin');
    $adminMaintenanceUrl = url('/admin/maintenance');
    $adminDebugUrl = url('/admin/debug');
    $adminTicketsUrl = url('/admin/tickets');
    $adminModerationUrl = url('/admin/moderation');

    // Canonical order: Übersicht, Wartung, Debug, Tickets, Moderation
    $adminNavItems = [
        [
            'key' => 'overview',
            'label' => 'Übersicht',
            'url' => $adminHomeUrl,
        ],
        [
            'key' => 'maintenance',
            'label' => 'Wartung',
            'url' => $adminMaintenanceUrl,
        ],
    ];

    if ($debugTabVisibleFlag) {
        $adminNavItems[] = [
            'key' => 'debug',
            'label' => 'Debug',
            'url' => $adminDebugUrl,
        ];
    }

    $adminNavItems[] = [
        'key' => 'tickets',
        'label' => 'Tickets',
        'url' => $adminTicketsUrl,
    ];

    $adminNavItems[] = [
        'key' => 'moderation',
        'label' => 'Moderation',
        'url' => $adminModerationUrl,
    ];

    $localRouteDebug = null;
    if (app()->isLocal()) {
        $current = Route::current();
        $localRouteDebug = [
            'route_name' => Route::currentRouteName(),
            'url' => url()->current(),
            'middleware' => $current ? (array) ($current->gatherMiddleware() ?? []) : [],
        ];
    }

    return [
        'adminTab' => 'maintenance',

        'hasSettingsTable' => $hasSettingsTable,
        'hasSystemSettingsTable' => $hasSystemSettingsTable,

        'maintenanceEnabled' => $maintenanceEnabled,
        'maintenanceShowEta' => $maintenanceShowEta,
        'etaDateValue' => $etaDateValue,
        'etaTimeValue' => $etaTimeValue,
        'maintenanceNotifyEnabled' => $maintenanceNotifyEnabled,

        'maintenanceAllowAdmins' => $maintenanceAllowAdmins,
        'maintenanceAllowModerators' => $maintenanceAllowModerators,

        'debugUiEnabled' => $debugUiEnabled,
        'debugRoutesEnabled' => $debugRoutesEnabled,
        'simulateProd' => $simulateProd,
        'simulateRowCss' => $simulateRowCss,

        'breakGlassEnabled' => $breakGlassEnabled,
        'breakGlassTotpSecret' => $breakGlassTotpSecret,
        'breakGlassTtlMinutes' => $breakGlassTtlMinutes,

        // defensive flag used by admin layout/header
        'debugEnabled' => $debugTabVisibleFlag,

        'notice' => $notice,

        'statusBg' => $statusBg,
        'statusBorder' => $statusBorder,
        'statusBadgeBg' => $statusBadgeBg,
        'statusBadgeText' => $statusBadgeText,

        'isProd' => $isProd,
        'envBadgeText' => $envBadgeText,
        'envBadgeBg' => $envBadgeBg,

        'adminHomeUrl' => $adminHomeUrl,
        'adminMaintenanceUrl' => $adminMaintenanceUrl,
        'adminDebugUrl' => $adminDebugUrl,
        'adminTicketsUrl' => $adminTicketsUrl,
        'adminModerationUrl' => $adminModerationUrl,

        'adminShowDebugTab' => $debugTabVisibleFlag,

        'adminNavItems' => $adminNavItems,

        // LOCAL only: debugability for admin header (route name/url/middleware)
        'localRouteDebug' => $localRouteDebug,
    ];
};

/*
|--------------------------------------------------------------------------
| Admin Backend – Wartung (eigene Route)
|--------------------------------------------------------------------------
| /admin/maintenance
|
| Hinweis: admin.maintenance View existiert aktuell nicht -> wir nutzen admin.home
| mit tab=maintenance als Übergang, ohne den Wartungsinhalt "in /admin" zu quetschen.
*/
Route::get('/maintenance', function () use ($buildMaintenanceContext) {
    $ctx = $buildMaintenanceContext();

    if (view()->exists('admin.maintenance')) {
        return view('admin.maintenance', $ctx);
    }

    return view('admin.home', array_merge($ctx, [
        'tab' => 'maintenance',
    ]));
})
    ->defaults('adminTab', 'maintenance')
    ->name('maintenance');

/*
|--------------------------------------------------------------------------
| Wartungsende (Anzeige) – AJAX
|--------------------------------------------------------------------------
*/
Route::post('/maintenance/eta-ajax', function (\Illuminate\Http\Request $request) {
    // Erwartung: Auth/Admin/Section-Guards laufen ausschließlich über Middleware im Admin-Router-Group.

    if (!Schema::hasTable('app_settings')) {
        return response()->json(['ok' => false, 'message' => 'app_settings fehlt'], 422);
    }

    $settings = DB::table('app_settings')->select([
        'maintenance_enabled',
        'maintenance_show_eta',
        'maintenance_eta_at',
    ])->first();

    if (!$settings) {
        $insert = [
            'maintenance_enabled' => 0,
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ];

        $now = \Illuminate\Support\Carbon::now();
        if (Schema::hasColumn('app_settings', 'created_at') && !array_key_exists('created_at', $insert)) {
            $insert['created_at'] = $now;
        }
        if (Schema::hasColumn('app_settings', 'updated_at') && !array_key_exists('updated_at', $insert)) {
            $insert['updated_at'] = $now;
        }

        DB::table('app_settings')->insert($insert);

        $settings = (object) [
            'maintenance_enabled' => 0,
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ];
    }

    $maintenanceEnabled = (bool) ($settings->maintenance_enabled ?? false);

    $showEta = (bool) $request->input('maintenance_show_eta', false);

    $etaDate = (string) $request->input('maintenance_eta_date', '');
    $etaDate = trim($etaDate);

    $etaTime = (string) $request->input('maintenance_eta_time', '');
    $etaTime = trim($etaTime);

    // Wenn Wartung aus: ETA immer hart aus (UI sollte das zwar verhindern, aber serverseitig stabilisieren)
    if (!$maintenanceEnabled) {
        DB::table('app_settings')->update([
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ]);

        return response()->json(['ok' => true]);
    }

    $etaDbValue = null;

    if ($etaDate !== '' && $etaTime !== '') {
        $etaRaw = $etaDate . ' ' . $etaTime;

        try {
            $dt = \Illuminate\Support\Carbon::createFromFormat('Y-m-d H:i', $etaRaw, config('app.timezone'));
            $etaDbValue = $dt->format('Y-m-d H:i:s');
        } catch (\Throwable $e) {
            return response()->json(['ok' => false, 'message' => 'Ungültiges Datum/Uhrzeit-Format'], 422);
        }
    }

    // Stabil: Wenn kein Datum/Zeit gesetzt ist -> Anzeige immer aus
    if ($etaDbValue === null) {
        $showEta = false;
    }

    DB::table('app_settings')->update([
        'maintenance_show_eta' => $showEta ? 1 : 0,
        'maintenance_eta_at' => $etaDbValue,
    ]);

    return response()->json(['ok' => true]);
})
    ->defaults('adminTab', 'maintenance')
    ->name('maintenance.eta.ajax');

/*
|--------------------------------------------------------------------------
| Wartung-ETA (Anzeige) – unverändert
|--------------------------------------------------------------------------
*/
Route::post('/maintenance/eta', function (\Illuminate\Http\Request $request) {
    // Erwartung: Auth/Admin/Section-Guards laufen ausschließlich über Middleware im Admin-Router-Group.

    if (!Schema::hasTable('app_settings')) {
        return redirect()->route('admin.maintenance')->with('admin_notice', 'app_settings fehlt – Speichern nicht möglich.');
    }

    $settings = DB::table('app_settings')->select([
        'maintenance_enabled',
        'maintenance_show_eta',
        'maintenance_eta_at',
    ])->first();

    if (!$settings) {
        $insert = [
            'maintenance_enabled' => 0,
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ];

        $now = \Illuminate\Support\Carbon::now();
        if (Schema::hasColumn('app_settings', 'created_at') && !array_key_exists('created_at', $insert)) {
            $insert['created_at'] = $now;
        }
        if (Schema::hasColumn('app_settings', 'updated_at') && !array_key_exists('updated_at', $insert)) {
            $insert['updated_at'] = $now;
        }

        DB::table('app_settings')->insert($insert);

        $settings = (object) [
            'maintenance_enabled' => 0,
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ];
    }

    $maintenanceEnabled = (bool) ($settings->maintenance_enabled ?? false);

    $showEta = (bool) $request->boolean('maintenance_show_eta');

    $etaDate = (string) $request->input('maintenance_eta_date', '');
    $etaDate = trim($etaDate);

    $etaTime = (string) $request->input('maintenance_eta_time', '');
    $etaTime = trim($etaTime);

    // Wenn Wartung aus: ETA hart löschen und zurück
    if (!$maintenanceEnabled) {
        DB::table('app_settings')->update([
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ]);

        return redirect()->route('admin.maintenance')->with('admin_notice', 'Wartung ist aus – ETA wurde zurückgesetzt.');
    }

    $etaDbValue = null;

    if ($etaDate !== '' && $etaTime !== '') {
        $etaRaw = $etaDate . ' ' . $etaTime;

        try {
            $dt = \Illuminate\Support\Carbon::createFromFormat('Y-m-d H:i', $etaRaw, config('app.timezone'));
            $etaDbValue = $dt->format('Y-m-d H:i:s');
        } catch (\Throwable $e) {
            return redirect()->route('admin.maintenance')->with('admin_notice', 'Ungültiges Datum/Uhrzeit-Format. Bitte erneut versuchen.');
        }
    }

    // Stabil: Wenn kein Datum/Zeit gesetzt ist -> Anzeige immer aus
    if ($etaDbValue === null) {
        $showEta = false;
    }

    DB::table('app_settings')->update([
        'maintenance_show_eta' => $showEta ? 1 : 0,
        'maintenance_eta_at' => $etaDbValue,
    ]);

    return redirect()->route('admin.maintenance')->with('admin_notice', 'Wartung-ETA gespeichert.');
})
    ->defaults('adminTab', 'maintenance')
    ->name('maintenance.eta');

Route::post('/maintenance/eta/clear', function () {
    // Erwartung: Auth/Admin/Section-Guards laufen ausschließlich über Middleware im Admin-Router-Group.

    if (!Schema::hasTable('app_settings')) {
        return redirect()->route('admin.maintenance')->with('admin_notice', 'app_settings fehlt – Löschen nicht möglich.');
    }

    $settings = DB::table('app_settings')->select([
        'maintenance_enabled',
        'maintenance_show_eta',
        'maintenance_eta_at',
    ])->first();

    if (!$settings) {
        $insert = [
            'maintenance_enabled' => 0,
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ];

        $now = \Illuminate\Support\Carbon::now();
        if (Schema::hasColumn('app_settings', 'created_at') && !array_key_exists('created_at', $insert)) {
            $insert['created_at'] = $now;
        }
        if (Schema::hasColumn('app_settings', 'updated_at') && !array_key_exists('updated_at', $insert)) {
            $insert['updated_at'] = $now;
        }

        DB::table('app_settings')->insert($insert);

        return redirect()->route('admin.maintenance')->with('admin_notice', 'Wartung-ETA gelöscht.');
    }

    DB::table('app_settings')->update([
        'maintenance_show_eta' => 0,
        'maintenance_eta_at' => null,
    ]);

    return redirect()->route('admin.maintenance')->with('admin_notice', 'Wartung-ETA gelöscht.');
})
    ->defaults('adminTab', 'maintenance')
    ->name('maintenance.eta.clear');