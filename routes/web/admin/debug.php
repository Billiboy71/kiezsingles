<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\debug.php
// Purpose: Admin Debug & Bugs (DB/SystemSettings toggles + diagnostics)
// Changed: 23-02-2026 16:06 (Europe/Berlin)
// Version: 2.0
// ============================================================================

use App\Support\Admin\AdminSectionAccess;
use App\Support\SystemSettingHelper;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Blade;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

/*
|--------------------------------------------------------------------------
| Admin: Debug & Bugs (DB/SystemSettings toggles + diagnostics)
|--------------------------------------------------------------------------
| Erwartung: Diese Datei wird innerhalb von routes/web/admin.php in einer
| Route::prefix('admin')->name('admin.')->group(...)
| eingebunden, und dort über Middleware serverseitig geschützt:
|   - auth + superadmin
|   - section:debug
|
| Zusätzlich (Kopplung):
| - Debug-Routen sind serverseitig nur verfügbar, wenn Wartung aktiv ist.
| - Fail-safe: Wenn Wartungsstatus nicht sicher bestimmbar ist (keine Tabelle / kein Datensatz),
|   wird NICHT geblockt (damit Debug nicht “tot” ist in frischen/ungefüllten DBs).
|
*/

$getMaintenanceEnabledTriState = function (): ?bool {
    try {
        if (!Schema::hasTable('app_settings')) {
            return null;
        }

        $row = DB::table('app_settings')->select(['maintenance_enabled'])->first();
        if (!$row) {
            return null;
        }

        return (bool) ($row->maintenance_enabled ?? false);
    } catch (\Throwable $e) {
        return null;
    }
};

$enforceMaintenanceCoupling = function () use ($getMaintenanceEnabledTriState) {
    // Fail-closed nur, wenn Wartungsstatus sicher "aus" ist.
    $maintenanceEnabled = $getMaintenanceEnabledTriState();

    if ($maintenanceEnabled === false) {
        return redirect('/admin/maintenance');
    }

    return null;
};

Route::get('/debug', function (Request $request) use ($enforceMaintenanceCoupling) {
    $gate = $enforceMaintenanceCoupling();
    if ($gate !== null) {
        return $gate;
    }

    $maintenanceEnabled = null;
    try {
        if (Schema::hasTable('app_settings')) {
            $row = DB::table('app_settings')->select(['maintenance_enabled'])->first();
            if ($row) {
                $maintenanceEnabled = (bool) ($row->maintenance_enabled ?? false);
            }
        }
    } catch (\Throwable $e) {
        $maintenanceEnabled = null;
    }

    $getBool = function (string $key, bool $default = false): bool {
        try {
            if (!Schema::hasTable('system_settings')) {
                return $default;
            }
            $row = DB::table('system_settings')->select(['value'])->where('key', $key)->first();
            if (!$row) {
                return $default;
            }
            $val = trim((string) ($row->value ?? ''));
            return ($val === '1' || strtolower($val) === 'true');
        } catch (\Throwable $e) {
            return $default;
        }
    };

    $simulateProd = $getBool('debug.simulate_production', false);
    $isProd = app()->environment('production');

    $envBadgeText = $isProd ? 'PRODUCTION' : 'LOCAL';
    $envBadgeBg = $isProd ? '#7c3aed' : '#0ea5e9';

    if (!$isProd && $simulateProd) {
        $envBadgeText = 'PROD-SIM';
        $envBadgeBg = '#f59e0b';
    }

    $simulateRowCss = $isProd ? 'display:none;' : '';

    $isProdEffective = $isProd || $simulateProd;

    $debugUiAllowed = SystemSettingHelper::debugUiAllowed();

    $debugUiEnabled = $getBool('debug.ui_enabled', false);
    $debugRoutesEnabledKey = $getBool('debug.routes_enabled', false) || $getBool('debug.routes', false);
    $debugRoutesEnabledEffective = $debugUiAllowed && $debugRoutesEnabledKey;

    $debugTurnstile = $getBool('debug.turnstile_enabled', false) || $getBool('debug.turnstile', false);
    $debugRegisterErrors = $getBool('debug.register_errors', false);
    $debugRegisterPayload = $getBool('debug.register_payload', false);

    // NEW: Toggle für gelbes LOCAL DEBUG Banner im Admin-Layout
    $debugLocalBannerEnabled = $getBool('debug.local_banner_enabled', true);

    $logLines = (array) session('admin_debug_log_tail', []);
    session()->forget('admin_debug_log_tail');

    $localRouteDebug = null;
    if (app()->isLocal()) {
        $current = Route::current();
        $localRouteDebug = [
            'route_name' => Route::currentRouteName(),
            'url' => url()->current(),
            'middleware' => $current ? (array) ($current->gatherMiddleware() ?? []) : [],
        ];
    }

    $badge = $isProdEffective ? 'PRODUCTION (effective)' : 'LOCAL/STAGING (effective)';

    $statusBg = '#fff5f5';
    $statusBorder = '#fecaca';
    $statusBadgeBg = '#dc2626';
    $statusBadgeText = 'WARTUNG AKTIV';

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
        [
            'key' => 'debug',
            'label' => 'Debug',
            'url' => $adminDebugUrl,
        ],
        [
            'key' => 'tickets',
            'label' => 'Tickets',
            'url' => $adminTicketsUrl,
        ],
        [
            'key' => 'moderation',
            'label' => 'Moderation',
            'url' => $adminModerationUrl,
        ],
    ];

    $data = [
        'adminTab' => 'debug',

        'maintenanceEnabled' => $maintenanceEnabled,

        'simulateProd' => $simulateProd,
        'simulateRowCss' => $simulateRowCss,

        'isProd' => $isProd,
        'envBadgeText' => $envBadgeText,
        'envBadgeBg' => $envBadgeBg,

        'debugUiAllowed' => $debugUiAllowed,
        'debugUiEnabled' => $debugUiEnabled,
        'debugRoutesEnabledKey' => $debugRoutesEnabledKey,
        'debugRoutesEnabledEffective' => $debugRoutesEnabledEffective,

        'debugTurnstile' => $debugTurnstile,
        'debugRegisterErrors' => $debugRegisterErrors,
        'debugRegisterPayload' => $debugRegisterPayload,

        'debugLocalBannerEnabled' => $debugLocalBannerEnabled,

        'logLines' => $logLines,
        'localRouteDebug' => $localRouteDebug,

        'badge' => $badge,

        'statusBg' => $statusBg,
        'statusBorder' => $statusBorder,
        'statusBadgeBg' => $statusBadgeBg,
        'statusBadgeText' => $statusBadgeText,

        'adminHomeUrl' => $adminHomeUrl,
        'adminMaintenanceUrl' => $adminMaintenanceUrl,
        'adminDebugUrl' => $adminDebugUrl,
        'adminTicketsUrl' => $adminTicketsUrl,
        'adminModerationUrl' => $adminModerationUrl,

        'adminShowDebugTab' => true,
        'adminNavItems' => $adminNavItems,

        'getBool' => $getBool,
    ];

    return view('admin.debug', $data);
})
    ->defaults('adminTab', 'debug')
    ->name('debug');

Route::post('/debug/toggle', function (Request $request) use ($enforceMaintenanceCoupling) {
    $gate = $enforceMaintenanceCoupling();
    if ($gate !== null) {
        return $gate;
    }

    $key = (string) $request->input('key', '');
    $val = (string) $request->input('value', '');

    $key = trim($key);
    $val = trim($val);

    if ($key === '' || strlen($key) > 190) {
        return redirect('/admin/debug');
    }

    if (!str_starts_with($key, 'debug.')) {
        return redirect('/admin/debug');
    }

    $bool = ($val === '1' || strtolower($val) === 'true');

    try {
        if (!Schema::hasTable('system_settings')) {
            return redirect('/admin/debug');
        }

        DB::table('system_settings')->updateOrInsert(
            ['key' => $key],
            [
                'value' => $bool ? '1' : '0',
                'cast' => 'bool',
                'updated_at' => now(),
                'created_at' => now(),
            ]
        );

        // Keep legacy aliases in sync to avoid key drift in DB diagnostics.
        if ($key === 'debug.routes_enabled') {
            DB::table('system_settings')->updateOrInsert(
                ['key' => 'debug.routes'],
                [
                    'value' => $bool ? '1' : '0',
                    'cast' => 'bool',
                    'updated_at' => now(),
                    'created_at' => now(),
                ]
            );
        }

        if ($key === 'debug.turnstile_enabled') {
            DB::table('system_settings')->updateOrInsert(
                ['key' => 'debug.turnstile'],
                [
                    'value' => $bool ? '1' : '0',
                    'cast' => 'bool',
                    'updated_at' => now(),
                    'created_at' => now(),
                ]
            );
        }
    } catch (\Throwable $e) {
        // still redirect back silently
    }

    return redirect('/admin/debug');
})
    ->defaults('adminTab', 'debug')
    ->name('debug.toggle');

Route::post('/debug/log-tail', function () use ($enforceMaintenanceCoupling) {
    $gate = $enforceMaintenanceCoupling();
    if ($gate !== null) {
        return $gate;
    }

    $lines = [];
    $path = storage_path('logs/laravel.log');

    try {
        if (is_file($path) && is_readable($path)) {
            $maxLines = 200;

            $fp = fopen($path, 'rb');
            if ($fp !== false) {
                $buffer = '';
                $pos = -1;
                $lineCount = 0;

                fseek($fp, 0, SEEK_END);
                $fileSize = ftell($fp);

                if ($fileSize === 0) {
                    fclose($fp);
                    session()->flash('admin_debug_log_tail', []);
                    return redirect('/admin/debug');
                }

                while ($lineCount < $maxLines && -$pos <= $fileSize) {
                    fseek($fp, $pos, SEEK_END);
                    $char = fgetc($fp);

                    if ($char === "\n") {
                        $lineCount++;
                        if ($buffer !== '') {
                            $lines[] = strrev($buffer);
                            $buffer = '';
                        }
                    } elseif ($char !== false) {
                        $buffer .= $char;
                    }

                    $pos--;
                }

                if ($buffer !== '') {
                    $lines[] = strrev($buffer);
                }

                fclose($fp);

                $lines = array_reverse($lines);
            }
        }
    } catch (\Throwable $e) {
        $lines = [];
    }

    session()->flash('admin_debug_log_tail', $lines);

    return redirect('/admin/debug');
})
    ->defaults('adminTab', 'debug')
    ->name('debug.log_tail');
