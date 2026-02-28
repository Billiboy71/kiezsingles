<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Admin\AdminMaintenanceController.php
// Purpose: Admin – Wartungsmodus UI (aus routes/web.php ausgelagert, Logik unverändert)
// Changed: 27-02-2026 19:15 (Europe/Berlin)
// Version: 0.8
// ============================================================================

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Support\KsMaintenance;
use App\Support\SystemSettingHelper;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

class AdminMaintenanceController extends Controller
{
    public function home(Request $request)
    {
        $hasSettingsTable = Schema::hasTable('maintenance_settings');

        $maintenanceEnabled  = KsMaintenance::enabled();
        $maintenanceShowEta  = KsMaintenance::showEta();
        $maintenanceEtaAt    = (string) (KsMaintenance::etaAt() ?? '');

        $etaDateValue = '';
        $etaTimeValue = '';

        if ($maintenanceEtaAt !== '') {
            try {
                $dt = Carbon::parse($maintenanceEtaAt);
                $etaDateValue = $dt->format('Y-m-d');
                $etaTimeValue = $dt->format('H:i');
            } catch (\Throwable $e) {
                $etaDateValue = '';
                $etaTimeValue = '';
            }
        }

        $hasSystemSettingsTable = Schema::hasTable('debug_settings');

        $debugUiEnabled = false;
        $debugRoutesEnabled = false;

        $breakGlassEnabled = false;
        $breakGlassTotpSecret = '';
        $breakGlassTtlMinutes = 15;

        $simulateProd = false;

        $maintenanceNotifyEnabled = false;

        $role = (string) (auth()->user()?->role ?? 'user');
        $role = mb_strtolower(trim($role));

        if ($hasSystemSettingsTable) {
            $debugUiEnabled = (bool) SystemSettingHelper::get('debug.ui_enabled', false);
            $debugRoutesEnabled = (bool) SystemSettingHelper::get('debug.routes_enabled', false);

            $breakGlassEnabled = (bool) SystemSettingHelper::get('debug.break_glass', false);
            $breakGlassTotpSecret = (string) SystemSettingHelper::get('debug.break_glass_totp_secret', '');
            $breakGlassTtlMinutes = (int) SystemSettingHelper::get('debug.break_glass_ttl_minutes', 15);

            $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);

            $maintenanceNotifyEnabled = KsMaintenance::notifyEnabled();

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

        $modules = [];
        if (function_exists('ks_admin_modules_for_role')) {
            try {
                $modules = (array) ks_admin_modules_for_role($role, $maintenanceEnabled);
            } catch (\Throwable $e) {
                $modules = [];
            }
        }

        if (!is_array($modules) || count($modules) === 0) {
            $modules = [
                'home' => [
                    'label' => 'Übersicht',
                    'route' => 'admin.home',
                    'access' => 'staff',
                ],
                'tickets' => [
                    'label' => 'Tickets',
                    'route' => 'admin.tickets.index',
                    'access' => 'staff',
                ],
                'maintenance' => [
                    'label' => 'Wartung',
                    'route' => 'admin.maintenance',
                    'access' => 'superadmin',
                ],
            ];

            if ($maintenanceEnabled) {
                $modules['debug'] = [
                    'label' => 'Debug',
                    'route' => 'admin.debug',
                    'access' => 'superadmin',
                ];
            }
        }

        $fallbackUrls = [
            'admin.home' => url('/admin'),
            'admin.tickets.index' => url('/admin/tickets'),
            'admin.maintenance' => url('/admin/maintenance'),
            'admin.debug' => url('/admin/debug'),
        ];

        $adminNavItems = [];
        foreach ($modules as $key => $module) {
            if ((string) $key === 'debug' && !$maintenanceEnabled) {
                continue;
            }

            $routeName = (string) ($module['route'] ?? '');
            $fallbackUrl = $fallbackUrls[$routeName] ?? url('/admin');

            $url = $fallbackUrl;
            if ($routeName !== '' && Route::has($routeName)) {
                $url = route($routeName);
            }

            $adminNavItems[] = [
                'key' => (string) $key,
                'label' => (string) ($module['label'] ?? $key),
                'url' => (string) $url,
            ];
        }

        $simulateRowCss = '';
        if ($isProd) {
            $simulateRowCss = 'display:none;';
        }

        return view('admin.maintenance', [
            'adminTab' => 'maintenance',
            'adminNavItems' => $adminNavItems,
            'adminShowDebugTab' => (bool) $maintenanceEnabled,

            'notice' => $notice,

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
            'isProd' => $isProd,
            'simulateRowCss' => $simulateRowCss,

            'breakGlassEnabled' => $breakGlassEnabled,
            'breakGlassTotpSecret' => $breakGlassTotpSecret,
            'breakGlassTtlMinutes' => $breakGlassTtlMinutes,

            'statusBg' => $statusBg,
            'statusBorder' => $statusBorder,
            'statusBadgeBg' => $statusBadgeBg,
            'statusBadgeText' => $statusBadgeText,

            'envBadgeText' => $envBadgeText,
            'envBadgeBg' => $envBadgeBg,
        ]);
    }
}
