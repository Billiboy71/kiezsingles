<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\debug_system.php
// Purpose: Debug + Noteinstieg + Wartungs-preview + maintenance-notify routes
// Changed: 27-02-2026 19:15 (Europe/Berlin)
// Version: 1.1
// ============================================================================

use App\Support\Admin\AdminSectionAccess;
use App\Mail\MaintenanceEndedMail;
use App\Support\KsMaintenance;
use App\Support\SystemSettingHelper;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

/*
|--------------------------------------------------------------------------
| DEBUG ROUTES (ein Konzept: SystemSettings, wartungsgekoppelt)
|--------------------------------------------------------------------------
| Aktiv nur wenn:
| - SystemSettingHelper::debugUiAllowed() == true
|   (env gate + maintenance_settings.enabled + debug_settings.debug.ui_enabled)
| - debug_settings.debug.routes_enabled == true
*/
$debugRoutesEnabled = SystemSettingHelper::debugUiAllowed()
    && (
        // Primary (documented) key:
        SystemSettingHelper::debugBool('routes_enabled', false)
        // Backward-compat fallback (older key used in earlier iterations):
        || SystemSettingHelper::debugBool('routes', false)
    );

if ($debugRoutesEnabled) {
    Route::get('/__whoami', function () {
        $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);

        return response()->json([
            'app_env' => (string) app()->environment(),
            'is_production' => (bool) app()->environment('production'),
            'simulate_production' => (bool) $simulateProd,
            'is_production_effective' => (bool) (app()->environment('production') || $simulateProd),
            'app_debug' => (bool) config('app.debug'),
            'base_path' => (string) base_path(),
            'timestamp' => (string) now()->toIso8601String(),
        ], 200);
    });

    Route::get('/__web_loaded', function () {
        return response('WEB ROUTES LOADED: ' . base_path(), 200);
    });

    Route::get('/__headers', function (Request $request) {
        // bewusst nur eine kleine Auswahl - alles weitere ggf. später ergänzen
        $keys = [
            'cf-connecting-ip',
            'cf-ray',
            'cf-visitor',
            'x-forwarded-for',
            'x-forwarded-proto',
            'x-real-ip',
            'user-agent',
            'host',
        ];

        $out = [];
        foreach ($keys as $k) {
            $out[$k] = (string) $request->header($k, '');
        }

        return response()->json([
            'ip' => (string) $request->ip(),
            'headers' => $out,
        ], 200);
    });
}

/*
|--------------------------------------------------------------------------
| Noteinstieg (Ebene 3) – separat vom Admin-Backend
|--------------------------------------------------------------------------
| Zugriff nur wenn:
| - maintenance_settings.enabled == true
| - debug_settings.debug.break_glass == true
| - NUR Production ODER simulate_production == true
| Kein Login nötig
*/
Route::get('/noteinstieg', function (Request $request) {
    $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);
    $isProdEffective = app()->environment('production') || $simulateProd;

    if (!$isProdEffective) {
        abort(404);
    }

    if (!KsMaintenance::enabled()) {
        abort(404);
    }

    if (!(bool) SystemSettingHelper::get('debug.break_glass', false)) {
        abort(404);
    }

    $error = (string) session('break_glass_error', '');

    $next = (string) $request->query('next', '');
    $next = trim($next);
    if ($next !== '' && (!str_starts_with($next, '/') || str_starts_with($next, '//'))) {
        $next = '';
    }

    return view('noteinstieg.show', [
        'error' => $error,
        'next' => $next,
    ]);
})->name('noteinstieg.show');

Route::post('/noteinstieg', function (Request $request) {
    $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);
    $isProdEffective = app()->environment('production') || $simulateProd;

    if (!$isProdEffective) {
        abort(404);
    }

    if (!KsMaintenance::enabled()) {
        abort(404);
    }

    if (!(bool) SystemSettingHelper::get('debug.break_glass', false)) {
        abort(404);
    }

    $ttlMinutes = (int) SystemSettingHelper::get('debug.break_glass_ttl_minutes', 15);
    if ($ttlMinutes < 1) {
        $ttlMinutes = 1;
    }
    if ($ttlMinutes > 120) {
        $ttlMinutes = 120;
    }

    $recoveryCode = (string) $request->input('recovery_code', '');
    $recoveryCode = strtoupper(trim($recoveryCode));
    $recoveryCode = preg_replace('/\s+/', '', $recoveryCode);

    $ok = false;
    $via = 'totp';

    // Wenn Recovery-Code gesetzt -> TOTP ignorieren
    if ($recoveryCode !== '') {
        $via = 'recovery';

        if (!Schema::hasTable('noteinstieg_recovery_codes')) {
            return redirect()->route('noteinstieg.show')->with('break_glass_error', 'Noteinstieg ist nicht vollständig konfiguriert.');
        }

        // Format: XXXX-XXXX oder XXXXXXXX
        $normalized = str_replace('-', '', $recoveryCode);

        if (!preg_match('/^[A-Z0-9]{8}$/', $normalized)) {
            return redirect()->route('noteinstieg.show')->with('break_glass_error', 'Ungültiger Notfallcode.');
        }

        $hash = hash_hmac('sha256', $normalized, (string) config('app.key'));

        $row = DB::table('noteinstieg_recovery_codes')
            ->where('hash', $hash)
            ->whereNull('used_at')
            ->first();

        if (!$row) {
            return redirect()->route('noteinstieg.show')->with('break_glass_error', 'Notfallcode falsch oder bereits benutzt.');
        }

        $ip = (string) $request->ip();
        $ua = (string) $request->userAgent();

        DB::table('noteinstieg_recovery_codes')
            ->where('id', (int) $row->id)
            ->update([
                'used_at' => now(),
                'used_ip' => $ip,
                'used_user_agent' => $ua,
                'updated_at' => now(),
            ]);

        $ok = true;
    } else {
        $totp = (string) $request->input('totp', '');
        $totp = trim($totp);

        // nur 6-stellig numerisch
        if (!preg_match('/^\d{6}$/', $totp)) {
            return redirect()->route('noteinstieg.show')->with('break_glass_error', 'Ungültiger Code.');
        }

        $secret = (string) SystemSettingHelper::get('debug.break_glass_totp_secret', '');
        $secret = strtoupper(trim($secret));
        $secret = preg_replace('/\s+/', '', $secret);

        if ($secret === '' || !preg_match('/^[A-Z2-7]+$/', $secret)) {
            return redirect()->route('noteinstieg.show')->with('break_glass_error', 'Noteinstieg ist nicht vollständig konfiguriert.');
        }

        $base32Decode = function (string $b32): string {
            $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
            $b32 = strtoupper($b32);
            $b32 = rtrim($b32, '=');

            $bits = '';
            $out = '';

            $len = strlen($b32);
            for ($i = 0; $i < $len; $i++) {
                $ch = $b32[$i];
                $pos = strpos($alphabet, $ch);
                if ($pos === false) {
                    return '';
                }
                $bits .= str_pad(decbin($pos), 5, '0', STR_PAD_LEFT);
            }

            $bitsLen = strlen($bits);
            for ($i = 0; $i + 8 <= $bitsLen; $i += 8) {
                $byte = substr($bits, $i, 8);
                $out .= chr(bindec($byte));
            }

            return $out;
        };

        $hotp = function (string $key, int $counter): string {
            $binCounter = pack('N*', 0) . pack('N*', $counter);
            $hash = hash_hmac('sha1', $binCounter, $key, true);

            $offset = ord(substr($hash, -1)) & 0x0F;
            $part = substr($hash, $offset, 4);

            $value = unpack('N', $part)[1] & 0x7FFFFFFF;
            $code = $value % 1000000;

            return str_pad((string) $code, 6, '0', STR_PAD_LEFT);
        };

        $key = $base32Decode($secret);
        if ($key === '') {
            return redirect()->route('noteinstieg.show')->with('break_glass_error', 'Noteinstieg ist nicht vollständig konfiguriert.');
        }

        $timeStep = 30;
        $counter = (int) floor(time() / $timeStep);

        // Window: -1, 0, +1 (Clock Drift)
        $ok = false;
        for ($w = -1; $w <= 1; $w++) {
            $calc = $hotp($key, $counter + $w);
            if (hash_equals($calc, $totp)) {
                $ok = true;
                break;
            }
        }

        if (!$ok) {
            return redirect()->route('noteinstieg.show')->with('break_glass_error', 'Code falsch oder abgelaufen.');
        }
    }

    if (!$ok) {
        abort(404);
    }

    $expiresAt = now()->timestamp + ($ttlMinutes * 60);

    $cookie = cookie(
        'kiez_break_glass',
        (string) $expiresAt,
        $ttlMinutes,
        '/',
        null,
        $request->isSecure(),
        true,
        false,
        'lax'
    );

    $cookieVia = cookie(
        'kiez_break_glass_via',
        (string) $via,
        $ttlMinutes,
        '/',
        null,
        $request->isSecure(),
        true,
        false,
        'lax'
    );

    $next = (string) $request->input('next', '');
    $next = trim($next);
    if ($next !== '' && (!str_starts_with($next, '/') || str_starts_with($next, '//'))) {
        $next = '';
    }

    $redirectTo = $next !== '' ? $next : '/noteinstieg-einstieg';

    return redirect($redirectTo)->withCookie($cookie)->withCookie($cookieVia);
})->name('noteinstieg.submit');

/*
|--------------------------------------------------------------------------
| Noteinstieg Entry (Ebene 3) – Einstieg/Hub
|--------------------------------------------------------------------------
| Zugriff nur wenn:
| - maintenance_settings.enabled == true
| - debug_settings.debug.break_glass == true
| - NUR Production ODER simulate_production == true
| - Cookie kiez_break_glass existiert und ist nicht abgelaufen
| Sonst: 404
*/
Route::get('/noteinstieg-einstieg', function (Request $request) {
    $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);
    $isProdEffective = app()->environment('production') || $simulateProd;

    if (!$isProdEffective) {
        abort(404);
    }

    if (!KsMaintenance::enabled()) {
        abort(404);
    }

    if (!(bool) SystemSettingHelper::get('debug.break_glass', false)) {
        abort(404);
    }

    $cookieVal = (string) $request->cookie('kiez_break_glass', '');
    $expiresAt = (int) $cookieVal;

    if ($expiresAt < 1 || $expiresAt <= now()->timestamp) {
        abort(404);
    }

    $via = (string) $request->cookie('kiez_break_glass_via', 'totp');
    $via = strtolower(trim($via));
    if ($via !== 'totp' && $via !== 'recovery') {
        $via = 'totp';
    }

    $remainingSeconds = $expiresAt - now()->timestamp;
    if ($remainingSeconds < 0) {
        $remainingSeconds = 0;
    }

    return view('noteinstieg.entry', [
        'via' => $via,
        'remainingSeconds' => (int) $remainingSeconds,
    ]);
})->name('noteinstieg.entry');

/*
|--------------------------------------------------------------------------
| Noteinstieg Wartungs-Preview (Ebene 3)
|--------------------------------------------------------------------------
| Zeigt die Wartungsseite so wie ein normaler Besucher sie sieht,
| aber erreichbar über Noteinstieg-Cookie (ohne Auth-Redirect auf /profile).
*/
Route::get('/noteinstieg-wartung', function (Request $request) {
    $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);
    $isProdEffective = app()->environment('production') || $simulateProd;

    if (!$isProdEffective) {
        abort(404);
    }

    if (!KsMaintenance::enabled()) {
        abort(404);
    }

    if (!(bool) SystemSettingHelper::get('debug.break_glass', false)) {
        abort(404);
    }

    $cookieVal = (string) $request->cookie('kiez_break_glass', '');
    $expiresAt = (int) $cookieVal;

    if ($expiresAt < 1 || $expiresAt <= now()->timestamp) {
        abort(404);
    }

    if (function_exists('view')) {
        if (view()->exists('home')) {
            return view('home');
        }
        if (view()->exists('maintenance')) {
            return view('maintenance');
        }
        if (view()->exists('errors.503')) {
            return view('errors.503');
        }
    }

    abort(404);
})->name('noteinstieg.maintenance');

/*
|--------------------------------------------------------------------------
| Wartungsmodus Notify (Public POST)
|--------------------------------------------------------------------------
*/
Route::post('/maintenance-notify', function (Request $request) {
    try {
        if (!KsMaintenance::enabled()) {
            return redirect('/')->with('maintenance_notify_error', 'Nicht verfügbar.');
        }
    } catch (\Throwable $e) {
        return redirect('/')->with('maintenance_notify_error', 'Nicht verfügbar.');
    }

    $notifyEnabled = KsMaintenance::notifyEnabled();

    if (!$notifyEnabled) {
        return redirect('/')->with('maintenance_notify_error', 'Nicht verfügbar.');
    }

    if (!Schema::hasTable('maintenance_notifications')) {
        return redirect('/')->with('maintenance_notify_error', 'Nicht verfügbar.');
    }

    $email = (string) $request->input('email', '');
    $email = trim($email);

    if ($email === '' || strlen($email) > 255 || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return redirect('/')->with('maintenance_notify_error', 'Ungültige E-Mail-Adresse.');
    }

    $email = strtolower($email);

    $ip = (string) $request->ip();
    $ua = (string) $request->userAgent();

    try {
        DB::table('maintenance_notifications')->updateOrInsert(
            ['email' => $email],
            [
                'notified_at' => null,
                'created_ip' => $ip !== '' ? substr($ip, 0, 45) : null,
                'created_user_agent' => $ua !== '' ? substr($ua, 0, 2000) : null,
                'updated_at' => now(),
                'created_at' => now(),
            ]
        );
    } catch (\Throwable $e) {
        return redirect('/')->with('maintenance_notify_error', 'Konnte nicht gespeichert werden.');
    }

    return redirect('/')->with('maintenance_notify_ok', true);
})->name('maintenance.notify');
