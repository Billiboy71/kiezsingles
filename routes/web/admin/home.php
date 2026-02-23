<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\home.php
// Purpose: Admin landing routes (GET /admin) – overview only (maintenance moved to its own section routes)
// Changed: 22-02-2026 23:00 (Europe/Berlin)
// Version: 4.7
// ============================================================================

use App\Support\Admin\AdminSectionAccess;
use App\Support\SystemSettingHelper;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;


$buildAdminContext = function (string $adminTab): array {
    // Erwartung: Auth/Staff/Admin-Guards laufen ausschließlich über Middleware im Admin-Router-Group.
    // (Keine versteckten abort_unless/auth-Guards in Context-Buildern.)

    $role = (string) (auth()->user()?->role ?? 'user');
    $roleNormalized = AdminSectionAccess::normalizeRole($role);

    $isSuperadminRole = ($roleNormalized === AdminSectionAccess::ROLE_SUPERADMIN);

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

    // Moderation-Konfiguration läuft in routes/web/admin/moderation.php (separate Section-Route).
    // Diese Context-Werte bleiben hier als leere Defaults, damit Views nicht brechen.
    $moderatorSections = [];
    $moderatorUsers = [];

    // System-Settings (Debug/Noteinstieg) nur für Superadmin in den Context laden
    if ($isSuperadminRole && $hasSystemSettingsTable) {
        $debugUiEnabled = (bool) SystemSettingHelper::get('debug.ui_enabled', false);
        $debugRoutesEnabled = (bool) SystemSettingHelper::get('debug.routes_enabled', false);

        $breakGlassEnabled = (bool) SystemSettingHelper::get('debug.break_glass', false);
        $breakGlassTotpSecret = (string) SystemSettingHelper::get('debug.break_glass_totp_secret', '');
        $breakGlassTtlMinutes = (int) SystemSettingHelper::get('debug.break_glass_ttl_minutes', 15);

        $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);

        $maintenanceNotifyEnabled = (bool) SystemSettingHelper::get('maintenance.notify_enabled', false);

        if ($breakGlassTtlMinutes < 1) {
            $breakGlassTtlMinutes = 1;
        }
        if ($breakGlassTtlMinutes > 120) {
            $breakGlassTtlMinutes = 120;
        }
    }

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

    $adminModuleFallbackUrls = [
        'admin.home' => $adminHomeUrl,
        'admin.maintenance' => $adminMaintenanceUrl,
        'admin.debug' => $adminDebugUrl,
        'admin.tickets.index' => $adminTicketsUrl,
        'admin.moderation' => $adminModerationUrl,
    ];

    // Navigation generiert sich aus zentraler Registry (routes/web/admin.php) + Rollenfilter
    $adminModules = [];

    if (function_exists('ks_admin_modules_for_role')) {
        try {
            $adminModules = (array) ks_admin_modules_for_role($role, $maintenanceEnabled);
        } catch (\Throwable $e) {
            $adminModules = [];
        }
    }

    $adminNavItems = [];

    if (is_array($adminModules) && count($adminModules) > 0) {
        foreach ($adminModules as $key => $module) {
            $keyNormalized = ((string) $key === 'home') ? 'overview' : (string) $key;

            $routeName = (string) ($module['route'] ?? '');
            $fallbackUrl = $adminModuleFallbackUrls[$routeName] ?? url('/admin');

            $url = $fallbackUrl;
            if ($routeName !== '' && Route::has($routeName)) {
                $url = route($routeName);
            }

            $adminNavItems[] = [
                'key' => $keyNormalized,
                'label' => (string) ($module['label'] ?? $keyNormalized),
                'url' => $url,
            ];
        }
    }

    // Fail-safe UI fallback: wenn Registry leer/kaputt ist,
    // wenigstens die Basis-Module anzeigen.
    if (count($adminNavItems) < 1) {
        $adminNavItems[] = [
            'key' => 'overview',
            'label' => 'Übersicht',
            'url' => $adminHomeUrl,
        ];

        $adminNavItems[] = [
            'key' => 'tickets',
            'label' => 'Tickets',
            'url' => $adminTicketsUrl,
        ];

        if ($isSuperadminRole) {
            $adminNavItems[] = [
                'key' => 'maintenance',
                'label' => 'Wartung',
                'url' => $adminMaintenanceUrl,
            ];

            $adminNavItems[] = [
                'key' => 'moderation',
                'label' => 'Moderation',
                'url' => $adminModerationUrl,
            ];

            $adminNavItems[] = [
                'key' => 'debug',
                'label' => 'Debug',
                'url' => $adminDebugUrl,
            ];
        }
    }

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
        // fürs Layout / Active-State
        'adminTab' => $adminTab,

        'hasSettingsTable' => $hasSettingsTable,
        'hasSystemSettingsTable' => $hasSystemSettingsTable,

        'maintenanceEnabled' => $maintenanceEnabled,
        'maintenanceShowEta' => $maintenanceShowEta,
        'etaDateValue' => $etaDateValue,
        'etaTimeValue' => $etaTimeValue,
        'maintenanceNotifyEnabled' => $maintenanceNotifyEnabled,

        'debugUiEnabled' => $debugUiEnabled,
        'debugRoutesEnabled' => $debugRoutesEnabled,
        'simulateProd' => $simulateProd,
        'simulateRowCss' => $simulateRowCss,

        'breakGlassEnabled' => $breakGlassEnabled,
        'breakGlassTotpSecret' => $breakGlassTotpSecret,
        'breakGlassTtlMinutes' => $breakGlassTtlMinutes,

        'moderatorSections' => $moderatorSections,
        'moderatorUsers' => $moderatorUsers,

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

        // explizit fürs Layout (Debug-Sichtbarkeit wird durch /admin/status autoritativ gesteuert)
        'adminShowDebugTab' => ($isSuperadminRole ? true : false),

        'adminNavItems' => $adminNavItems,

        // LOCAL only: debugability for admin header (route name/url/middleware)
        'localRouteDebug' => $localRouteDebug,
    ];
};

/*
|--------------------------------------------------------------------------
| Admin Backend – Landing (Übersicht)
|--------------------------------------------------------------------------
| /admin
*/
Route::get('/', function () use ($buildAdminContext) {
    $tab = 'overview';

    $ctx = $buildAdminContext($tab);

    return view('admin.home', array_merge($ctx, [
        'tab' => $tab,
    ]));
})->name('home');