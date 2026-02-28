<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\status.php
// Purpose: Admin live status endpoint (JSON for header auto-refresh)
// Created: 16-02-2026 19:15 (Europe/Berlin)
// Changed: 27-02-2026 19:15 (Europe/Berlin)
// Version: 1.5
// ============================================================================

use App\Support\KsMaintenance;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Route;

Route::get('/status', function () {
    // Erwartung: Auth/Superadmin/Section-Guards laufen ausschließlich über den Gruppen-Wrapper in routes/web/admin.php.

    // Kurzlebiger Cache, um DB + Middleware-Kosten bei Reloads / Mehrfach-Aufrufen zu senken.
    // TTL bewusst sehr klein, damit Toggles im Admin-UI quasi sofort sichtbar bleiben.
    $cacheKey = 'ks.admin.status.v1';
    $ttlSeconds = 2;

    $payload = Cache::remember($cacheKey, $ttlSeconds, function () {
        $maintenance = false;

        // debug_enabled = tatsächlicher Schalter (SystemSetting)
        $debugEnabled = false;

        // debug = UI-Sichtbarkeit (Wartung aktiv + Debug-UI erlaubt)
        $debug = false;

        // debug_any = irgendein Debug-Schalter aktiv (für Badge)
        $debugAny = false;

        $breakGlass = false;
        $env = 'prod';

        $maintenance = KsMaintenance::enabled();

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

        $requiredKeys = array_values(array_unique(array_merge(
            [
                'debug.ui_enabled',
                'debug.break_glass',
                'debug.simulate_production',
            ],
            $debugAnyKeys
        )));

        $settings = [];
        try {
            $settings = DB::table('debug_settings')
                ->whereIn('key', $requiredKeys)
                ->pluck('value', 'key')
                ->all();
        } catch (\Throwable $e) {
            $settings = [];
        }

        $getBool = function (string $key, bool $default = false) use ($settings): bool {
            if (!array_key_exists($key, $settings)) {
                return $default;
            }

            $v = $settings[$key];

            // project convention: bool values stored as "1" / "0"
            if (is_bool($v)) return $v;
            if (is_int($v)) return $v === 1;

            return ((string) $v) === '1';
        };

        if (!empty($settings)) {
            $debugEnabled = $getBool('debug.ui_enabled', false);
            $breakGlass = $getBool('debug.break_glass', false);

            foreach ($debugAnyKeys as $k) {
                if ($getBool($k, false)) {
                    $debugAny = true;
                    break;
                }
            }
        }

        if (app()->environment('local')) {
            $env = 'local';
        }

        if (!empty($settings) && $getBool('debug.simulate_production', false)) {
            $env = 'prod-sim';
        }

        // UI-only: Debug-Button anzeigen, sobald Wartung aktiv ist.
        // Serverseitige Autorisierung läuft ausschließlich über Middleware (auth + superadmin + section:debug).
        $debug = (bool) $maintenance;

        return [
            'maintenance'   => $maintenance,
            'debug'         => $debug,
            'debug_enabled' => $debugEnabled,
            'debug_any'     => $debugAny,
            'break_glass'   => $breakGlass,
            'env'           => $env,
        ];
    });

    return response()->json($payload);
})
    ->name('status');
