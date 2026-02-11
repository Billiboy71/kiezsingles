<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web.php
// Purpose: Web routes (public + authenticated)
// Changed: 10-02-2026 22:56
// Version: 1.5
// ============================================================================

use App\Http\Controllers\ContactController;
use App\Http\Controllers\DistrictPostcodeController;
use App\Http\Controllers\ProfileController;
use App\Mail\MaintenanceEndedMail;
use App\Models\SystemSetting;
use App\Support\SystemSettingHelper;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

require __DIR__ . '/auth.php';

/*
|--------------------------------------------------------------------------
| DEBUG ROUTES (ein Konzept: SystemSettings, wartungsgekoppelt)
|--------------------------------------------------------------------------
| Aktiv nur wenn:
| - SystemSettingHelper::debugUiAllowed() == true
|   (env gate + app_settings.maintenance_enabled + system_settings.debug.ui_enabled)
| - system_settings.debug.routes_enabled == true
*/
$debugRoutesEnabled = SystemSettingHelper::debugUiAllowed()
    && SystemSettingHelper::debugBool('routes', false);

if ($debugRoutesEnabled) {
    Route::get('/__whoami', fn () => base_path());

    Route::get('/__web_loaded', fn () => 'WEB ROUTES LOADED: ' . base_path());
}

/*
|--------------------------------------------------------------------------
| Noteinstieg (Ebene 3) – separat vom Admin-Backend
|--------------------------------------------------------------------------
| Zugriff nur wenn:
| - app_settings.maintenance_enabled == true
| - system_settings.debug.break_glass == true
| - NUR Production ODER simulate_production == true
| Kein Login nötig
*/
Route::get('/noteinstieg', function (\Illuminate\Http\Request $request) {
    $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);
    $isProdEffective = app()->environment('production') || $simulateProd;

    if (!$isProdEffective) {
        abort(404);
    }

    if (!Schema::hasTable('app_settings')) {
        abort(404);
    }

    $settings = DB::table('app_settings')->select(['maintenance_enabled'])->first();
    if (!$settings || !(bool) $settings->maintenance_enabled) {
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

    $html = '<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">';
    $html .= '<title>Noteinstieg</title>';
    $html .= '</head><body style="font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; padding:24px; max-width:520px; margin:0 auto;">';

    $html .= '<h1 style="margin:0 0 8px 0;">Noteinstieg</h1>';
    $html .= '<p style="margin:0 0 16px 0; color:#444;">Notfallzugang im Wartungsmodus (Ebene 3).</p>';

    if ($error !== '') {
        $html .= '<div style="padding:12px 14px; border-radius:10px; border:1px solid #fecaca; background:#fff5f5; margin:0 0 16px 0;">' . e($error) . '</div>';
    }

    $html .= '<form id="bg_form" method="POST" action="' . e(url('/noteinstieg')) . '" autocomplete="off">';
    $html .= '<input type="hidden" name="_token" value="' . e(csrf_token()) . '">';

    $html .= '<input type="hidden" name="next" value="' . e($next) . '">';
    $html .= '<input type="hidden" id="totp" name="totp" value="">';

    $html .= '<label style="display:block; margin:0 0 6px 0; font-weight:700;">TOTP-Code</label>';

    $html .= '<div id="bg_otp" style="display:flex; gap:10px;">';
    for ($i = 0; $i < 6; $i++) {
        $html .= '<input type="text" inputmode="numeric" pattern="[0-9]*" maxlength="1" autocomplete="one-time-code" ';
        $html .= 'aria-label="Ziffer ' . ($i + 1) . '" ';
        $html .= 'style="width:54px; height:54px; text-align:center; font-size:22px; border:1px solid #ccc; border-radius:10px;" ';
        $html .= 'data-idx="' . $i . '">';
    }
    $html .= '</div>';

    $html .= '<div style="margin-top:10px; font-size:13px; color:#444; line-height:1.35;">';
    $html .= '<div style="font-weight:700; margin:0 0 4px 0;">Alternativ</div>';
    $html .= '<div>Du kannst auch einen Notfallcode verwenden (einmalig). Format: <code>XXXX-XXXX</code></div>';
    $html .= '<label style="display:block; margin:8px 0 6px 0; font-weight:700;">Notfallcode</label>';
    $html .= '<input type="text" name="recovery_code" inputmode="text" autocomplete="off" placeholder="ABCD-EFGH" ';
    $html .= 'style="width:100%; padding:12px 12px; border-radius:10px; border:1px solid #ccc; font-size:16px;">';
    $html .= '<div style="margin-top:6px; color:#666;">Wenn Notfallcode ausgefüllt ist, wird TOTP ignoriert.</div>';
    $html .= '</div>';
    $html .= '<div style="margin-top:12px;">';
    $html .= '<button type="submit" id="bg_submit" style="padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; cursor:pointer; width:100%;">Freischalten</button>';
    $html .= '</div>';

    $html .= '</form>';

    $html .= '<script>
        (() => {
            const form = document.getElementById("bg_form");
            const wrap = document.getElementById("bg_otp");
            const hidden = document.getElementById("totp");
            const btn = document.getElementById("bg_submit");
            if (!form || !wrap || !hidden || !btn) return;

            const inputs = Array.from(wrap.querySelectorAll("input[data-idx]"));
            if (inputs.length !== 6) return;

            const onlyDigit = (v) => (v || "").toString().replace(/\\D+/g, "");

            const setFromString = (s) => {
                const digits = onlyDigit(s).slice(0, 6).split("");
                for (let i = 0; i < 6; i++) {
                    inputs[i].value = digits[i] || "";
                }
                updateHiddenAndMaybeSubmit();
            };

            const updateHiddenAndMaybeSubmit = () => {
                const code = inputs.map(i => onlyDigit(i.value).slice(0,1)).join("");
                hidden.value = code;

                if (code.length === 6) {
                    // Auto-Submit sobald vollständig
                    form.requestSubmit();
                }
            };

            inputs.forEach((inp, idx) => {
                inp.addEventListener("input", (e) => {
                    const d = onlyDigit(inp.value);
                    if (d.length > 1) {
                        // z.B. Paste in ein Feld
                        setFromString(d);
                        return;
                    }

                    inp.value = d.slice(0, 1);

                    if (inp.value !== "" && idx < 5) {
                        inputs[idx + 1].focus();
                        inputs[idx + 1].select();
                    }

                    updateHiddenAndMaybeSubmit();
                });

                inp.addEventListener("keydown", (e) => {
                    if (e.key === "Backspace") {
                        if (inp.value === "" && idx > 0) {
                            inputs[idx - 1].focus();
                            inputs[idx - 1].select();
                        }
                        return;
                    }

                    if (e.key === "ArrowLeft" && idx > 0) {
                        e.preventDefault();
                        inputs[idx - 1].focus();
                        inputs[idx - 1].select();
                        return;
                    }

                    if (e.key === "ArrowRight" && idx < 5) {
                        e.preventDefault();
                        inputs[idx + 1].focus();
                        inputs[idx + 1].select();
                        return;
                    }
                });

                inp.addEventListener("paste", (e) => {
                    e.preventDefault();
                    const t = (e.clipboardData || window.clipboardData).getData("text");
                    setFromString(t);
                });

                inp.addEventListener("focus", () => {
                    inp.select();
                });
            });

            // Initial focus
            inputs[0].focus();
        })();
    </script>';

    $html .= '</body></html>';

    return response($html, 200);
})->name('noteinstieg.show');

Route::post('/noteinstieg', function (\Illuminate\Http\Request $request) {
    $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);
    $isProdEffective = app()->environment('production') || $simulateProd;

    if (!$isProdEffective) {
        abort(404);
    }

    if (!Schema::hasTable('app_settings')) {
        abort(404);
    }

    $settings = DB::table('app_settings')->select(['maintenance_enabled'])->first();
    if (!$settings || !(bool) $settings->maintenance_enabled) {
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
| - app_settings.maintenance_enabled == true
| - system_settings.debug.break_glass == true
| - NUR Production ODER simulate_production == true
| - Cookie kiez_break_glass existiert und ist nicht abgelaufen
| Sonst: 404
*/
Route::get('/noteinstieg-einstieg', function (\Illuminate\Http\Request $request) {
    $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);
    $isProdEffective = app()->environment('production') || $simulateProd;

    if (!$isProdEffective) {
        abort(404);
    }

    if (!Schema::hasTable('app_settings')) {
        abort(404);
    }

    $settings = DB::table('app_settings')->select(['maintenance_enabled'])->first();
    if (!$settings || !(bool) $settings->maintenance_enabled) {
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

    $html = '<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">';
    $html .= '<title>Noteinstieg</title>';
    $html .= '</head><body style="font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; padding:24px; max-width:520px; margin:0 auto;">';

    $html .= '<h1 style="margin:0 0 8px 0;">Noteinstieg</h1>';
    $html .= '<p style="margin:0 0 10px 0; color:#444;">Einstiegsseite (nur mit gültigem Noteinstieg-Cookie).</p>';

    if ($via === 'totp') {
        $html .= '<div style="margin:0 0 16px 0; padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff;">';
        $html .= '<div style="font-weight:700; margin:0 0 4px 0;">Countdown</div>';
        $html .= '<div style="color:#111;">läuft ab in <span id="bg_countdown" style="font-weight:800;">--:--</span></div>';
        $html .= '</div>';
    }

    $html .= '<div style="display:flex; flex-direction:column; gap:10px;">';
    $html .= '<a id="bg_login" href="' . e(url('/login')) . '" style="display:block; text-align:center; padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; text-decoration:none; color:#111;">Login</a>';
    $html .= '<a id="bg_register" href="' . e(url('/register')) . '" style="display:block; text-align:center; padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; text-decoration:none; color:#111;">Registrieren</a>';
    $html .= '<a id="bg_maintenance" href="' . e(url('/noteinstieg-wartung')) . '" style="display:block; text-align:center; padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; text-decoration:none; color:#111;">Wartungsseite ansehen</a>';
    $html .= '<a id="bg_reopen" href="' . e(url('/noteinstieg?next=/noteinstieg-einstieg')) . '" style="display:block; text-align:center; padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; text-decoration:none; color:#111;">Noteinstieg erneut öffnen</a>';
    $html .= '</div>';

    if ($via === 'totp') {
        $html .= '<script>
        (() => {
            let remaining = ' . (int) $remainingSeconds . ';
            const el = document.getElementById("bg_countdown");
            const aLogin = document.getElementById("bg_login");
            const aRegister = document.getElementById("bg_register");
            const aReopen = document.getElementById("bg_reopen");

            const pad2 = (n) => String(n).padStart(2, "0");

            const render = () => {
                if (!el) return;

                const sec = Math.max(0, remaining);
                const m = Math.floor(sec / 60);
                const s = sec % 60;

                el.textContent = pad2(m) + ":" + pad2(s);

                if (sec <= 0) {
                    if (aLogin) aLogin.setAttribute("aria-disabled", "true");
                    if (aRegister) aRegister.setAttribute("aria-disabled", "true");
                    if (aReopen) aReopen.setAttribute("aria-disabled", "true");
                }
            };

            render();

            const t = window.setInterval(() => {
                remaining -= 1;
                render();

                if (remaining <= 0) {
                    window.clearInterval(t);
                }
            }, 1000);
        })();
    </script>';
    }

    $html .= '</body></html>';

    return response($html, 200);
})->name('noteinstieg.entry');

/*
|--------------------------------------------------------------------------
| Noteinstieg Wartungs-Preview (Ebene 3)
|--------------------------------------------------------------------------
| Zeigt die Wartungsseite so wie ein normaler Besucher sie sieht,
| aber erreichbar über Noteinstieg-Cookie (ohne Auth-Redirect auf /profile).
*/
Route::get('/noteinstieg-wartung', function (\Illuminate\Http\Request $request) {
    $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);
    $isProdEffective = app()->environment('production') || $simulateProd;

    if (!$isProdEffective) {
        abort(404);
    }

    if (!Schema::hasTable('app_settings')) {
        abort(404);
    }

    $settings = DB::table('app_settings')->select(['maintenance_enabled'])->first();
    if (!$settings || !(bool) $settings->maintenance_enabled) {
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

    return view('home');
})->name('noteinstieg.maintenance');

/*
|--------------------------------------------------------------------------
| Wartungsmodus Preview (Admin-only, nur View)
|--------------------------------------------------------------------------
| Zeigt die Wartungsseite so wie ein normaler Besucher sie sieht,
| ohne Redirect auf /profile.
| Kein Einfluss auf Noteinstieg.
*/
Route::get('/maintenance-preview', function () {
    abort_unless(auth()->check() && (string) auth()->user()->role === 'admin', 403);

    return view('home');
})->name('maintenance.preview');

/*
|--------------------------------------------------------------------------
| Wartungsmodus Notify (Public POST)
|--------------------------------------------------------------------------
*/
Route::post('/maintenance-notify', function (\Illuminate\Http\Request $request) {
    try {
        if (!Schema::hasTable('app_settings')) {
            return redirect('/')->with('maintenance_notify_error', 'Nicht verfügbar.');
        }

        $settings = DB::table('app_settings')->select(['maintenance_enabled'])->first();
        if (!$settings || !(bool) $settings->maintenance_enabled) {
            return redirect('/')->with('maintenance_notify_error', 'Nicht verfügbar.');
        }
    } catch (\Throwable $e) {
        return redirect('/')->with('maintenance_notify_error', 'Nicht verfügbar.');
    }

    $notifyEnabled = false;

    try {
        if (Schema::hasTable('system_settings')) {
            $row = DB::table('system_settings')
                ->select(['value'])
                ->where('key', 'maintenance.notify_enabled')
                ->first();

            $val = $row ? (string) ($row->value ?? '') : '';
            $val = trim($val);

            $notifyEnabled = ($val === '1' || strtolower($val) === 'true');
        }
    } catch (\Throwable $e) {
        $notifyEnabled = false;
    }

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

/*
|--------------------------------------------------------------------------
| Public Routes
|--------------------------------------------------------------------------
*/
Route::get('/', function () {
    if (auth()->check()) {
        return redirect('/profile');
    }

    return view('home');
})->name('home');

/*
|--------------------------------------------------------------------------
| User Profile (über public_id) – NUR für eingeloggte + verifizierte Nutzer
|--------------------------------------------------------------------------
*/
Route::get('/u/{user}', [ProfileController::class, 'show'])
    ->middleware(['auth', 'verified'])
    ->name('profile.show');

Route::get('/dashboard', function () {
    return view('dashboard');
})->middleware(['auth', 'verified'])->name('dashboard');

/*
|--------------------------------------------------------------------------
| Contact (öffentlich)
|--------------------------------------------------------------------------
*/
Route::get('/contact', [ContactController::class, 'create'])->name('contact.create');
Route::post('/contact', [ContactController::class, 'store'])->name('contact.store');

/*
|--------------------------------------------------------------------------
| AJAX: District → Postcodes
|--------------------------------------------------------------------------
*/
Route::get('/districts/{district}/postcodes', [DistrictPostcodeController::class, 'index'])
    ->name('district.postcodes');

/*
|--------------------------------------------------------------------------
| Authenticated Routes
|--------------------------------------------------------------------------
*/
Route::middleware('auth')->group(function () {
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

    /*
    |--------------------------------------------------------------------------
    | Admin Backend – Wartungsmodus (minimal)
    |--------------------------------------------------------------------------
    */
    Route::get('/admin', function () {
        abort_unless(auth()->check() && (string) auth()->user()->role === 'admin', 403);

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

        if ($hasSystemSettingsTable) {
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

        $html = '<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">';
        $html .= '<title>Admin – Wartungsmodus</title>';

        // CSS: Toggles + Badge + Toast + Mini-Button
        $html .= '<style>
            .ks-row { display:flex; align-items:center; justify-content:space-between; gap:12px; }
            .ks-label { display:flex; flex-direction:column; gap:2px; min-width:0; }
            .ks-label strong { font-weight:700; }
            .ks-sub { color:#555; font-size:12px; line-height:1.2; }
            .ks-info { cursor:help; user-select:none; color:#111; opacity:.7; margin-left:6px; }
            .ks-toggle { position:relative; width:46px; height:26px; flex:0 0 auto; }
            .ks-toggle input { opacity:0; width:0; height:0; }
            .ks-slider { position:absolute; cursor:pointer; top:0; left:0; right:0; bottom:0; background:#dc2626; border-radius:999px; transition: .15s; }
            .ks-slider:before { position:absolute; content:""; height:20px; width:20px; left:3px; top:3px; background:white; border-radius:50%; transition: .15s; box-shadow:0 1px 2px rgba(0,0,0,.18); }
            .ks-toggle input:checked + .ks-slider { background:#16a34a; }
            .ks-toggle input:checked + .ks-slider:before { transform: translateX(20px); }
            .ks-toggle input:disabled + .ks-slider { opacity:.45; cursor:not-allowed; }
            .ks-badge { display:inline-flex; align-items:center; justify-content:center; padding:6px 10px; border-radius:999px; font-weight:800; font-size:12px; letter-spacing:.4px; color:#fff; }
            .ks-toast { display:none; margin:0 0 16px 0; padding:12px 16px; border-radius:8px; border:1px solid #b6e0b6; background:#eef7ee; }
            .ks-toast.is-error { border-color:#fecaca; background:#fff5f5; }

            /* Mini-Button in Toggle-Größe */
            .ks-mini-btn {
                width:46px;
                height:26px;
                border-radius:999px;
                border:1px solid #cbd5e1;
                background:#fff;
                cursor:pointer;
                display:inline-flex;
                align-items:center;
                justify-content:center;
                padding:0;
                line-height:1;
                user-select:none;
            }
            .ks-mini-btn:hover { background:#f8fafc; }
            .ks-mini-btn:active { background:#f1f5f9; }
            .ks-mini-btn:disabled { opacity:.45; cursor:not-allowed; }
            .ks-mini-icon { font-size:14px; transform: translateY(-.5px); }

            .ks-btn {
                padding:10px 12px;
                border-radius:10px;
                border:1px solid #cbd5e1;
                background:#fff;
                cursor:pointer;
                user-select:none;
            }
            .ks-btn:hover { background:#f8fafc; }
            .ks-btn:active { background:#f1f5f9; }
            .ks-btn:disabled { opacity:.45; cursor:not-allowed; }

            /* Modal */
            .ks-modal {
                display:none;
                position:fixed;
                inset:0;
                background: rgba(0,0,0,.55);
                z-index: 9999;
                align-items:center;
                justify-content:center;
                padding: 24px;
            }
            .ks-modal-box {
                width: 100%;
                max-width: 360px;
                background:#fff;
                border-radius:12px;
                border:1px solid #e5e7eb;
                box-shadow: 0 10px 25px rgba(0,0,0,.25);
                padding: 14px 14px 16px 14px;
            }
            .ks-modal-head {
                display:flex;
                align-items:center;
                justify-content:space-between;
                gap: 12px;
                margin: 0 0 10px 0;
            }
            .ks-modal-title { font-weight:700; }
            .ks-modal-close {
                width:34px;
                height:34px;
                border-radius:10px;
                border:1px solid #cbd5e1;
                background:#fff;
                cursor:pointer;
                display:inline-flex;
                align-items:center;
                justify-content:center;
                padding:0;
                line-height:1;
                user-select:none;
            }
            .ks-modal-close:hover { background:#f8fafc; }
            .ks-modal-close:active { background:#f1f5f9; }

            .ks-codes {
                display:none;
                margin-top:10px;
                padding:12px 12px;
                border-radius:10px;
                border:1px solid #e5e7eb;
                background:#fff;
            }
            .ks-codes h3 { margin:0 0 8px 0; font-size:14px; }
            .ks-code-item {
                font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
                font-weight:800;
                letter-spacing:.8px;
                padding:8px 10px;
                border:1px solid #e5e7eb;
                border-radius:10px;
                background:#fafafa;
                margin:8px 0;
                text-align:center;
                font-size:16px;
            }
            .ks-code-item.is-used {
                text-decoration: line-through;
                opacity: .55;
            }
            .ks-code-actions { display:flex; gap:10px; flex-wrap:wrap; margin-top:8px; }
        </style>';

        $html .= '</head><body style="font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; padding:24px; max-width:900px; margin:0 auto;">';

        $html .= '<h1 style="margin:0 0 8px 0;">Admin – Wartung</h1>';
        $html .= '<p style="margin:0 0 16px 0; color:#444;">Minimal-Backend (nur Admin). Änderungen werden automatisch gespeichert.</p>';

        if ($notice) {
            $html .= '<div style="padding:12px 16px; background:#eef7ee; border:1px solid #b6e0b6; border-radius:8px; margin:0 0 16px 0;">' . e($notice) . '</div>';
        }

        $html .= '<div id="ks_toast" class="ks-toast"></div>';

        $html .= '<div id="ks_status_box" style="padding:16px; border:1px solid ' . $statusBorder . '; background:' . $statusBg . '; border-radius:10px; margin:0 0 16px 0;">';
        $html .= '<div style="display:flex; align-items:center; justify-content:space-between; gap:12px; margin:0 0 12px 0;">';
        $html .= '<h2 style="margin:0; font-size:18px;">Wartung & Debug</h2>';
        $html .= '<div style="display:flex; align-items:center; gap:10px;">';
        $html .= '<span class="ks-badge" id="ks_badge" style="background:' . $statusBadgeBg . ';">' . $statusBadgeText . '</span>';
        $html .= '<span class="ks-badge" id="ks_env_badge" style="background:' . $envBadgeBg . ';">' . $envBadgeText . '</span>';
        $html .= '</div>';
        $html .= '</div>';

        if (!$hasSettingsTable) {
            $html .= '<p style="margin:0; color:#a00;">Hinweis: Tabelle <code>app_settings</code> existiert nicht. Wartung kann hier nicht geschaltet werden.</p>';
        }

        if (!$hasSystemSettingsTable) {
            $html .= '<p style="margin:10px 0 0 0; color:#a00;">Hinweis: Tabelle <code>system_settings</code> existiert nicht. Debug-Schalter können nicht gespeichert werden.</p>';
        }

        $html .= '<input type="hidden" id="ks_csrf" value="' . e(csrf_token()) . '">';

        $maintenanceDisabled = (!$hasSettingsTable) ? ' disabled' : '';
        $systemSettingsDisabled = (!$hasSystemSettingsTable) ? ' disabled' : '';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>Wartungsmodus aktiv</strong>';
        $html .= '<span class="ks-info" title="Schaltet den Wartungsmodus ein.">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Blockiert normale Nutzung, bis du Wartung wieder ausschaltest.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="maintenance_enabled" value="1"' . ($maintenanceEnabled ? ' checked' : '') . $maintenanceDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div><strong>Wartungsende anzeigen</strong></div>';
        $html .= '<div class="ks-sub">Zeigt das Wartungsende im Wartungshinweis an.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="maintenance_show_eta" value="1"' . ($maintenanceShowEta ? ' checked' : '') . $maintenanceDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<label style="display:block; margin:0 0 6px 0; font-weight:600;">Wartung endet am</label>';

        $html .= '<div style="display:flex; gap:10px; flex-wrap:wrap; margin:0 0 10px 0; align-items:center;">';
        $html .= '<input type="date" id="maintenance_eta_date" value="' . e($etaDateValue) . '" style="padding:10px 12px; border:1px solid #ccc; border-radius:10px; width:170px;"' . $maintenanceDisabled . '>';
        $html .= '<input type="time" id="maintenance_eta_time" value="' . e($etaTimeValue) . '" style="padding:10px 12px; border:1px solid #ccc; border-radius:10px; width:120px;"' . $maintenanceDisabled . '>';
        $html .= '<button type="button" id="maintenance_eta_clear" class="ks-mini-btn" title="Zurücksetzen"' . $maintenanceDisabled . '>';
        $html .= '<span class="ks-mini-icon">↺</span>';
        $html .= '</button>';
        $html .= '</div>';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>E-Mail-Notify im Wartungsmodus</strong> <span style="color:#555;">(<code>maintenance.notify_enabled</code>)</span>';
        $html .= '<span class="ks-info" title="Zeigt im Wartungsmodus ein E-Mail-Feld. Beim Ausschalten der Wartung werden die gespeicherten Adressen benachrichtigt und danach gelöscht.">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Nur relevant, solange Wartung aktiv ist.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="maintenance_notify_enabled" value="1"' . ($maintenanceNotifyEnabled ? ' checked' : '') . $systemSettingsDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<hr style="border:0; border-top:1px solid #e5e7eb; margin:14px 0;">';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>Debug freigeben</strong> <span style="color:#555;">(<code>debug.ui_enabled</code>)</span>';
        $html .= '<span class="ks-info" title="Haupt-Freigabe für Debug im Wartungsmodus.">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Erlaubt Debug-Funktionen nur während Wartung aktiv ist.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="debug_ui_enabled" value="1"' . ($debugUiEnabled ? ' checked' : '') . $systemSettingsDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>Debug-Routen aktivieren</strong> <span style="color:#555;">(<code>debug.routes_enabled</code>)</span>';
        $html .= '<span class="ks-info" title="Aktiviert interne Debug-Routen wie /__whoami und /__web_loaded.">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Schaltet zusätzliche Debug-URLs frei (nur bei Debug-Freigabe).</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="debug_routes_enabled" value="1"' . ($debugRoutesEnabled ? ' checked' : '') . $systemSettingsDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<hr style="border:0; border-top:1px solid #e5e7eb; margin:14px 0;">';

        // Live-Modus simulieren (direkt über Noteinstieg)
        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>Live-Modus simulieren</strong> <span style="color:#555;">(<code>debug.simulate_production</code>)</span>';
        $html .= '<span class="ks-info" title="Nur bei aktiver Wartung: schaltet lokal in einen Live-Simulationsmodus (für Noteinstieg Tests).">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Nur bei aktiver Wartung. In Production hat dieser Schalter keine Wirkung.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="debug_simulate_production" value="1"' . ($simulateProd ? ' checked' : '') . $systemSettingsDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>Noteinstieg aktiv</strong> <span style="color:#555;">(<code>debug.break_glass</code>)</span>';
        $html .= '<span class="ks-info" title="Notfallzugang (Ebene 3).">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Schaltet Noteinstieg frei.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="debug_break_glass" value="1"' . ($breakGlassEnabled ? ' checked' : '') . $systemSettingsDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        // Link: nur anzeigen, wenn Noteinstieg aktiv ist
        $html .= '<div id="break_glass_link_wrap" style="display:none; margin:-6px 0 12px 0;">';
        $html .= '<div class="ks-sub">Link zum Testen (öffnet Noteinstieg Eingabe):</div>';
        $html .= '<a id="break_glass_link" href="' . e(url('/noteinstieg?next=/noteinstieg-einstieg')) . '" target="_blank" rel="noopener noreferrer" style="word-break:break-all; color:#0ea5e9; text-decoration:underline;" title="Privates Fenster kann nicht erzwungen werden (Browser-Funktion).">' . e(url('/noteinstieg?next=/noteinstieg-einstieg')) . '</a>';
        $html .= '</div>';

        $html .= '<label style="display:block; margin:12px 0 6px 0; font-weight:600;">Noteinstieg TTL (Minuten)</label>';

        $html .= '<div style="display:flex; align-items:center; gap:10px; flex-wrap:wrap; margin-top:0;">';
        $html .= '<input type="number" id="debug_break_glass_ttl_minutes" min="1" max="120" value="' . e((string) $breakGlassTtlMinutes) . '" style="padding:10px 12px; border:1px solid #ccc; border-radius:10px; width:160px;"' . $systemSettingsDisabled . '>';
        $html .= '<button type="button" id="break_glass_qr_btn" class="ks-btn" style="display:none;"' . $systemSettingsDisabled . '>QR-Code anzeigen</button>';
        $html .= '<button type="button" id="noteinstieg_recovery_show_btn" class="ks-btn" style="display:none;"' . $systemSettingsDisabled . '>Notfallcodes anzeigen</button>';
        $html .= '</div>';

        $html .= '<div id="noteinstieg_codes" class="ks-codes">';
        $html .= '<h3>Notfallcodes (einmalig)</h3>';
        $html .= '<div id="noteinstieg_codes_list"></div>';
        $html .= '<div class="ks-code-actions" style="justify-content:center;">';
        $html .= '<button type="button" id="noteinstieg_recovery_generate_btn" class="ks-btn">5 Notfallcodes erzeugen</button>';
        $html .= '<button type="button" id="noteinstieg_print_btn" class="ks-btn">Drucken</button>';
        $html .= '</div>';
        $html .= '</div>';

        $html .= '<input type="hidden" id="debug_break_glass_totp_secret" value="' . e($breakGlassTotpSecret) . '"' . $systemSettingsDisabled . '>';

        $html .= '<div id="break_glass_qr_modal" class="ks-modal" aria-hidden="true">';
        $html .= '<div class="ks-modal-box" role="dialog" aria-modal="true" aria-label="Google Authenticator QR-Code">';
        $html .= '<div class="ks-modal-head">';
        $html .= '<div class="ks-modal-title">Google Authenticator</div>';
        $html .= '<button type="button" id="break_glass_qr_close" class="ks-modal-close" aria-label="Schließen">✕</button>';
        $html .= '</div>';
        $html .= '<img id="break_glass_qr_img" alt="Break-Glass QR" width="320" height="320" style="display:block; width:100%; height:auto; border-radius:10px; border:1px solid #e5e7eb;">';
        $html .= '</div>';
        $html .= '</div>';

        $html .= '<script>
            (() => {
                const hasSettingsTable = ' . ($hasSettingsTable ? 'true' : 'false') . ';
                const hasSystemSettingsTable = ' . ($hasSystemSettingsTable ? 'true' : 'false') . ';
                const isProd = ' . (app()->environment('production') ? 'true' : 'false') . ';

                const csrf = document.getElementById("ks_csrf")?.value || "";
                const toast = document.getElementById("ks_toast");
                const badge = document.getElementById("ks_badge");
                const envBadge = document.getElementById("ks_env_badge");

                const m = document.getElementById("maintenance_enabled");
                const etaShow = document.getElementById("maintenance_show_eta");
                const etaDate = document.getElementById("maintenance_eta_date");
                const etaTime = document.getElementById("maintenance_eta_time");
                const etaClear = document.getElementById("maintenance_eta_clear");
                const notify = document.getElementById("maintenance_notify_enabled");

                const ui = document.getElementById("debug_ui_enabled");
                const r = document.getElementById("debug_routes_enabled");

                const sim = document.getElementById("debug_simulate_production");

                const bg = document.getElementById("debug_break_glass");
                const bgSecret = document.getElementById("debug_break_glass_totp_secret");
                const bgTtl = document.getElementById("debug_break_glass_ttl_minutes");

                const bgLinkWrap = document.getElementById("break_glass_link_wrap");
                const bgLink = document.getElementById("break_glass_link");

                const bgQrBtn = document.getElementById("break_glass_qr_btn");
                const bgQrModal = document.getElementById("break_glass_qr_modal");
                const bgQrClose = document.getElementById("break_glass_qr_close");
                const bgQrImg = document.getElementById("break_glass_qr_img");

                const showBtn = document.getElementById("noteinstieg_recovery_show_btn");
                const genBtn = document.getElementById("noteinstieg_recovery_generate_btn");

                const codesWrap = document.getElementById("noteinstieg_codes");
                const codesList = document.getElementById("noteinstieg_codes_list");
                const printBtn = document.getElementById("noteinstieg_print_btn");

                if (!sim || !m || !ui || !r || !bg || !bgSecret || !bgTtl || !etaShow || !etaDate || !etaTime || !etaClear || !bgLinkWrap || !bgLink || !bgQrBtn || !bgQrModal || !bgQrClose || !bgQrImg || !envBadge || !showBtn || !genBtn || !codesWrap || !codesList || !printBtn || !notify) return;

                let saveTimer = null;
                let saving = false;
                let codesPollTimer = null;
                const CODES_POLL_MS = 5000;

                const stopCodesPolling = () => {
                    if (codesPollTimer) {
                        window.clearInterval(codesPollTimer);
                        codesPollTimer = null;
                    }
                };

                const startCodesPolling = () => {
                    if (codesPollTimer) return;
                    codesPollTimer = window.setInterval(() => {
                        // ohne Clear, ohne Toast-Spam
                        loadCodes({ clear: false, toast: false });
                    }, CODES_POLL_MS);
                };

                const showToast = (msg, isError=false) => {
                    if (!toast) return;
                    toast.textContent = msg;
                    toast.classList.toggle("is-error", !!isError);
                    toast.style.display = "block";
                    window.clearTimeout(toast.__t);
                    toast.__t = window.setTimeout(() => {
                        toast.style.display = "none";
                    }, 2000);
                };

                const setStatusBox = (maintenanceOn) => {
                    const box = document.getElementById("ks_status_box");
                    if (!box) return;

                    if (maintenanceOn) {
                        box.style.background = "#fff5f5";
                        box.style.borderColor = "#fecaca";
                    } else {
                        box.style.background = "#f0fff4";
                        box.style.borderColor = "#bbf7d0";
                    }
                };

                const setBadge = (maintenanceOn) => {
                    if (!badge) return;
                    if (maintenanceOn) {
                        badge.textContent = "WARTUNG AKTIV";
                        badge.style.background = "#dc2626";
                    } else {
                        badge.textContent = "LIVE";
                        badge.style.background = "#16a34a";
                    }
                };

                const setEnvBadge = (maintenanceOn) => {
                    if (!envBadge) return;

                    if (isProd) {
                        envBadge.textContent = "PRODUCTION";
                        envBadge.style.background = "#7c3aed";
                        return;
                    }

                    if (maintenanceOn && !!sim.checked) {
                        envBadge.textContent = "PROD-SIM";
                        envBadge.style.background = "#f59e0b";
                        return;
                    }

                    envBadge.textContent = "LOCAL";
                    envBadge.style.background = "#0ea5e9";
                };

                const closeQrModal = () => {
                    bgQrModal.style.display = "none";
                    bgQrModal.setAttribute("aria-hidden", "true");
                };

                const openQrModal = () => {
                    bgQrModal.style.display = "flex";
                    bgQrModal.setAttribute("aria-hidden", "false");
                };

                bgQrImg.addEventListener("error", () => {
                    showToast("QR-Code konnte nicht geladen werden.", true);
                });

                const genBase32 = (len) => {
                    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
                    let out = "";
                    const bytes = new Uint8Array(len);
                    crypto.getRandomValues(bytes);
                    for (let i = 0; i < len; i++) {
                        out += alphabet[bytes[i] % alphabet.length];
                    }
                    return out;
                };

                const normalizeBase32 = (s) => {
                    return (s || "").toString().trim().toUpperCase().replace(/\\s+/g, "");
                };

                const isValidBase32 = (s) => {
                    return /^[A-Z2-7]+$/.test(s) && s.length >= 16;
                };

                const ensureSecret = () => {
                    const breakGlassOn = !!bg.checked;
                    if (!breakGlassOn) return false;

                    const current = normalizeBase32(bgSecret.value);

                    if (current !== "" && isValidBase32(current)) {
                        if (bgSecret.value !== current) {
                            bgSecret.value = current;
                            return true;
                        }
                        return false;
                    }

                    const generated = genBase32(32);
                    bgSecret.value = generated;
                    return true;
                };

                const buildOtpAuthUri = () => {
                    const secret = normalizeBase32(bgSecret.value);
                    const issuer = "KiezSingles";
                    const label = "noteinstieg";
                    return "otpauth://totp/" + issuer + ":" + label
                        + "?secret=" + secret
                        + "&issuer=" + issuer
                        + "&digits=6&period=30";
                };

                const prepareQr = () => {
                    const breakGlassOn = !!bg.checked;
                    const secret = normalizeBase32(bgSecret.value);

                    if (!breakGlassOn || secret === "" || !isValidBase32(secret)) {
                        bgQrBtn.style.display = "none";
                        bgQrBtn.disabled = true;
                        bgQrImg.removeAttribute("src");
                        closeQrModal();
                        return;
                    }

                    const uri = buildOtpAuthUri();
                    const qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=320x320&ecc=H&data=" + encodeURIComponent(uri);

                    bgQrImg.setAttribute("src", qrUrl);
                    bgQrBtn.style.display = "inline-block";
                    bgQrBtn.disabled = false;
                };

                const clearCodes = () => {
                    stopCodesPolling();
                    codesList.innerHTML = "";
                    codesWrap.style.display = "none";
                    codesWrap.__codes = null;
                };

                const renderCodes = (codes) => {
                    clearCodes();
                    if (!Array.isArray(codes) || codes.length < 1) return;

                    codesWrap.__codes = codes.slice();

                    for (const c of codes) {
                        if (!c || typeof c.code !== "string") continue;

                        const div = document.createElement("div");
                        div.className = "ks-code-item" + (c.used ? " is-used" : "");
                        div.textContent = c.code;
                        codesList.appendChild(div);
                    }

                    codesWrap.style.display = "block";
                };

                const postJson = async (url, payload) => {
                    const res = await fetch(url, {
                        method: "POST",
                        headers: {
                            "Content-Type": "application/json",
                            "X-CSRF-TOKEN": csrf,
                            "Accept": "application/json"
                        },
                        body: JSON.stringify(payload)
                    });

                    if (!res.ok) {
                        let t = "";
                        try { t = await res.text(); } catch (e) {}
                        throw new Error("HTTP " + res.status + (t ? (": " + t) : ""));
                    }

                    return await res.json();
                };

                const scheduleSave = () => {
                    window.clearTimeout(saveTimer);
                    saveTimer = window.setTimeout(saveAll, 200);
                };

                const saveAll = async () => {
                    if (saving) return;
                    saving = true;

                    try {
                        await postJson("' . e(route('admin.settings.save.ajax')) . '", {
                            simulate_production: !!sim.checked,

                            maintenance_enabled: !!m.checked,
                            maintenance_notify_enabled: !!notify.checked,

                            debug_ui_enabled: !!ui.checked,
                            debug_routes_enabled: !!r.checked,

                            break_glass_enabled: !!bg.checked,
                            break_glass_totp_secret: (bgSecret.value || ""),
                            break_glass_ttl_minutes: (bgTtl.value || "")
                        });

                        await postJson("' . e(route('admin.maintenance.eta.ajax')) . '", {
                            maintenance_show_eta: !!etaShow.checked,
                            maintenance_eta_date: (etaDate.value || ""),
                            maintenance_eta_time: (etaTime.value || "")
                        });

                        showToast("Gespeichert.");
                    } catch (e) {
                        showToast("Fehler beim Speichern.", true);
                    } finally {
                        saving = false;
                    }
                };

                const apply = () => {
                    if (!hasSettingsTable) {
                        m.disabled = true;
                    }
                    if (!hasSystemSettingsTable) {
                        ui.disabled = true;
                        r.disabled = true;
                        sim.disabled = true;
                        bg.disabled = true;
                        bgSecret.disabled = true;
                        bgTtl.disabled = true;
                        bgQrBtn.disabled = true;
                        bgQrBtn.style.display = "none";
                        bgLinkWrap.style.display = "none";
                        showBtn.disabled = true;
                        showBtn.style.display = "none";
                        genBtn.disabled = true;
                        clearCodes();

                        notify.disabled = true;
                    }

                    const maintenanceOn = !!m.checked;

                    setStatusBox(maintenanceOn);
                    setBadge(maintenanceOn);

                    etaShow.disabled = (!hasSettingsTable) || (!maintenanceOn);
                    etaDate.disabled = (!hasSettingsTable) || (!maintenanceOn);
                    etaTime.disabled = (!hasSettingsTable) || (!maintenanceOn);
                    etaClear.disabled = (!hasSettingsTable) || (!maintenanceOn);

                    notify.disabled = (!hasSystemSettingsTable) || (!maintenanceOn);

                    if (hasSystemSettingsTable) {
                        const simShouldBeDisabled = isProd || !maintenanceOn;
                        sim.disabled = simShouldBeDisabled;
                        if (simShouldBeDisabled) {
                            sim.checked = false;
                        }
                    } else {
                        sim.checked = false;
                    }

                    setEnvBadge(maintenanceOn);

                    if (!maintenanceOn) {
                        etaShow.checked = false;
                        etaDate.value = "";
                        etaTime.value = "";
                        notify.checked = false;

                        ui.checked = false;
                        r.checked = false;

                        bgTtl.value = "15";
                        bg.checked = false;

                        bgLinkWrap.style.display = "none";

                        bgQrBtn.disabled = true;
                        bgQrBtn.style.display = "none";
                        bgQrImg.removeAttribute("src");
                        closeQrModal();

                        showBtn.disabled = true;
                        showBtn.style.display = "none";
                        genBtn.disabled = true;
                        clearCodes();
                    }

                    if (hasSystemSettingsTable) {
                        ui.disabled = !maintenanceOn;

                        const debugOn = maintenanceOn && !!ui.checked;
                        r.disabled = !debugOn;

                        if (!debugOn) {
                            r.checked = false;
                        }
                    } else {
                        ui.checked = false;
                        r.checked = false;
                    }

                    const prodEffective = isProd || (maintenanceOn && !!sim.checked);

                    const breakGlassUiAllowed = maintenanceOn && prodEffective;

                    bg.disabled = !breakGlassUiAllowed;
                    bgTtl.disabled = !breakGlassUiAllowed;
                    bgSecret.disabled = !breakGlassUiAllowed;

                    if (!breakGlassUiAllowed) {
                        bg.checked = false;
                        bgLinkWrap.style.display = "none";
                        bgQrBtn.disabled = true;
                        bgQrBtn.style.display = "none";
                        bgQrImg.removeAttribute("src");
                        closeQrModal();

                        showBtn.disabled = true;
                        showBtn.style.display = "none";
                        genBtn.disabled = true;
                        clearCodes();
                        return;
                    }

                    bgLinkWrap.style.display = (!!bg.checked) ? "block" : "none";

                    if (!!bg.checked) {
                        showBtn.style.display = "inline-block";
                        showBtn.disabled = false;

                        genBtn.disabled = false;
                    } else {
                        showBtn.style.display = "none";
                        showBtn.disabled = true;

                        genBtn.disabled = true;
                        clearCodes();
                    }

                    const secretWasGeneratedOrNormalized = ensureSecret();
                    prepareQr();

                    if (secretWasGeneratedOrNormalized) {
                        scheduleSave();
                    }
                };

                bgQrBtn.addEventListener("click", () => {
                    prepareQr();
                    const src = bgQrImg.getAttribute("src") || "";
                    if (src === "") {
                        showToast("Kein QR-Code verfügbar.", true);
                        return;
                    }
                    openQrModal();
                });

                bgQrClose.addEventListener("click", () => {
                    closeQrModal();
                });

                bgQrModal.addEventListener("click", (ev) => {
                    if (ev.target === bgQrModal) {
                        closeQrModal();
                    }
                });

                const loadCodes = async ({ clear = true, toast = true } = {}) => {
                    try {
                        if (clear) {
                            clearCodes();
                        }

                        showBtn.disabled = true;

                        const out = await postJson("' . e(route('admin.noteinstieg.recovery.list.ajax')) . '", {});

                        if (!out || out.ok !== true || !Array.isArray(out.codes)) {
                            if (toast) showToast("Notfallcodes konnten nicht geladen werden.", true);
                            showBtn.disabled = false;
                            return;
                        }

                        renderCodes(out.codes);

                        if (toast) showToast("Notfallcodes geladen.");

                        // Polling nur wenn Liste sichtbar ist (nach renderCodes ist sie sichtbar)
                        startCodesPolling();

                        showBtn.disabled = false;
                    } catch (e) {
                        if (toast) showToast("Fehler beim Laden der Notfallcodes.", true);
                        showBtn.disabled = false;
                    }
                };

                showBtn.addEventListener("click", async () => {
                    await loadCodes();
                });

                genBtn.addEventListener("click", async () => {
                    try {
                        genBtn.disabled = true;

                        const out = await postJson("' . e(route('admin.noteinstieg.recovery.generate.ajax')) . '", {});

                        if (!out || out.ok !== true || !Array.isArray(out.codes) || out.codes.length !== 5) {
                            const msg = (out && typeof out.message === "string" && out.message !== "") ? out.message : "Notfallcodes konnten nicht erzeugt werden.";
                            showToast(msg, true);
                            genBtn.disabled = false;
                            return;
                        }

                        await loadCodes();
                        showToast("Notfallcodes erzeugt.");

                        genBtn.disabled = false;
                    } catch (e) {
                        showToast("Fehler beim Erzeugen der Notfallcodes.", true);
                        genBtn.disabled = false;
                    }
                });

                printBtn.addEventListener("click", () => {
                    const codes = codesWrap.__codes;
                    if (!Array.isArray(codes) || codes.length < 1) {
                        showToast("Keine Notfallcodes zum Drucken.", true);
                        return;
                    }

                    const esc = (s) => (s || "").toString()
                        .replace(/&/g, "&amp;")
                        .replace(/</g, "&lt;")
                        .replace(/>/g, "&gt;")
                        .replace(/"/g, "&quot;");

                    const today = new Date();
                    const pad2 = (n) => String(n).padStart(2, "0");
                    const stamp = pad2(today.getDate()) + "." + pad2(today.getMonth() + 1) + "." + today.getFullYear();

                    let html = "<!doctype html><html lang=\\"de\\"><head><meta charset=\\"utf-8\\">";
                    html += "<meta name=\\"viewport\\" content=\\"width=device-width, initial-scale=1\\">";
                    html += "<title>KiezSingles – Noteinstieg Notfallcodes</title>";
                    html += "<style>";
                    html += "@page { size: A4; margin: 18mm; }";
                    html += "body { font-family: system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; }";
                    html += "h1 { margin:0 0 6px 0; font-size:18px; }";
                    html += ".meta { color:#444; font-size:12px; margin:0 0 14px 0; }";
                    html += ".grid { display:grid; grid-template-columns: 1fr 1fr; gap:10px; }";
                    html += ".code { border:1px solid #ddd; border-radius:10px; padding:14px 10px; text-align:center; font-size:18px; font-weight:800; letter-spacing:1px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, \\"Liberation Mono\\", \\"Courier New\\", monospace; }";
                    html += ".code.used { text-decoration: line-through; opacity:.55; }";
                    html += ".hint { margin-top:14px; font-size:12px; color:#444; }";
                    html += "</style></head><body>";
                    html += "<h1>KiezSingles – Noteinstieg Notfallcodes</h1>";
                    html += "<p class=\\"meta\\">Stand " + esc(stamp) + " (durchgestrichen = bereits benutzt)</p>";
                    html += "<div class=\\"grid\\">";
                    for (const c of codes) {
                        if (!c || typeof c.code !== "string") continue;
                        html += "<div class=\\"code" + (c.used ? " used" : "") + "\\">" + esc(c.code) + "</div>";
                    }
                    html += "</div>";
                    html += "<div class=\\"hint\\">Hinweis: Notfallcodes funktionieren nur im Wartungsmodus bei aktivem Noteinstieg.</div>";
                    html += "<script>window.onload=()=>{ window.print(); };</" + "script>";
                    html += "</body></html>";

                    const w = window.open("about:blank", "_blank");
                    if (!w) {
                        showToast("Popup blockiert (Drucken nicht möglich).", true);
                        return;
                    }

                    try {
                        w.document.open();
                        w.document.write(html);
                        w.document.close();
                        w.focus();
                    } catch (e) {
                        showToast("Druckansicht konnte nicht geöffnet werden.", true);
                    }
                });

                sim.addEventListener("change", () => { apply(); scheduleSave(); });

                m.addEventListener("change", () => { apply(); scheduleSave(); });

                etaShow.addEventListener("change", () => { scheduleSave(); });
                etaDate.addEventListener("change", () => { scheduleSave(); });
                etaTime.addEventListener("change", () => { scheduleSave(); });

                etaClear.addEventListener("click", () => {
                    etaShow.checked = false;
                    etaDate.value = "";
                    etaTime.value = "";
                    scheduleSave();
                });

                notify.addEventListener("change", () => { scheduleSave(); });

                ui.addEventListener("change", () => { apply(); scheduleSave(); });
                r.addEventListener("change", () => { apply(); scheduleSave(); });

                bg.addEventListener("change", () => { apply(); scheduleSave(); });
                bgTtl.addEventListener("input", () => { scheduleSave(); });

                apply();
            })();
        </script>';

        $html .= '</div>';

        $html .= '<p style="margin:0;"><a href="' . e(route('profile.edit')) . '">Zurück zum Profil</a></p>';

        $html .= '</body></html>';

        return response($html, 200);
    })->name('admin.home');

    /*
    |--------------------------------------------------------------------------
    | Save Wartung + Debug (Ebene 2) – AJAX
    |--------------------------------------------------------------------------
    */
    Route::post('/admin/settings/save-ajax', function (\Illuminate\Http\Request $request) {
        abort_unless(auth()->check() && (string) auth()->user()->role === 'admin', 403);

        if (!Schema::hasTable('app_settings')) {
            return response()->json(['ok' => false, 'message' => 'app_settings fehlt'], 422);
        }

        if (!Schema::hasTable('system_settings')) {
            return response()->json(['ok' => false, 'message' => 'system_settings fehlt'], 422);
        }

        $maintenanceRequested = (bool) $request->input('maintenance_enabled', false);

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
                $notifyEnabled = false;

                if (Schema::hasTable('system_settings')) {
                    $row = DB::table('system_settings')
                        ->select(['value'])
                        ->where('key', 'maintenance.notify_enabled')
                        ->first();

                    $val = $row ? (string) ($row->value ?? '') : '';
                    $val = trim($val);

                    $notifyEnabled = ($val === '1' || strtolower($val) === 'true');
                }

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
    })->name('admin.settings.save.ajax');

    /*
    |--------------------------------------------------------------------------
    | Noteinstieg Notfallcodes – AJAX (Admin) LIST
    |--------------------------------------------------------------------------
    | Listet alle Codes (auch verwendete), used=true => durchgestrichen.
    */
    Route::post('/admin/noteinstieg/recovery-codes-list-ajax', function () {
        abort_unless(auth()->check() && (string) auth()->user()->role === 'admin', 403);

        if (!Schema::hasTable('system_settings')) {
            return response()->json(['ok' => false, 'message' => 'system_settings fehlt'], 422);
        }

        if (!Schema::hasTable('noteinstieg_recovery_codes')) {
            return response()->json(['ok' => false, 'message' => 'noteinstieg_recovery_codes fehlt'], 422);
        }

        // Optional: nur sinnvoll bei Wartung an
        if (Schema::hasTable('app_settings')) {
            $s = DB::table('app_settings')->select(['maintenance_enabled'])->first();
            if (!$s || !(bool) $s->maintenance_enabled) {
                return response()->json(['ok' => false, 'message' => 'wartung aus'], 422);
            }
        }

        if (!(bool) SystemSettingHelper::get('debug.break_glass', false)) {
            return response()->json(['ok' => false, 'message' => 'noteinstieg aus'], 422);
        }

        $rows = DB::table('noteinstieg_recovery_codes')
            ->select(['code_encrypted', 'used_at', 'created_at', 'id'])
            ->orderByRaw('CASE WHEN used_at IS NULL THEN 0 ELSE 1 END ASC')
            ->orderBy('created_at', 'desc')
            ->orderBy('id', 'desc')
            ->limit(200)
            ->get();

        $out = [];
        foreach ($rows as $row) {
            $plain = '';
            if (isset($row->code_encrypted) && $row->code_encrypted !== null && (string) $row->code_encrypted !== '') {
                try {
                    $plain = (string) decrypt((string) $row->code_encrypted);
                } catch (\Throwable $e) {
                    $plain = '';
                }
            }

            if ($plain === '') {
                continue;
            }

            $out[] = [
                'code' => $plain,
                'used' => $row->used_at !== null,
            ];
        }

        return response()->json(['ok' => true, 'codes' => $out]);
    })->name('admin.noteinstieg.recovery.list.ajax');

    /*
    |--------------------------------------------------------------------------
    | Noteinstieg Notfallcodes – AJAX (Admin) GENERATE
    |--------------------------------------------------------------------------
    | Erzeugt 5 Codes (XXXX-XXXX), speichert Hash + code_encrypted (einmalig),
    | gibt Klartext nur als Bestätigung zurück (UI lädt danach Liste).
    |
    | Regel:
    | - Wenn noch unbenutzte Codes existieren: NICHT neu generieren.
    | - Wenn nur benutzte Codes existieren: Tabelle leeren und 5 neue erzeugen.
    */
    Route::post('/admin/noteinstieg/recovery-codes-generate-ajax', function (\Illuminate\Http\Request $request) {
        abort_unless(auth()->check() && (string) auth()->user()->role === 'admin', 403);

        if (!Schema::hasTable('system_settings')) {
            return response()->json(['ok' => false, 'message' => 'system_settings fehlt'], 422);
        }

        if (!Schema::hasTable('noteinstieg_recovery_codes')) {
            return response()->json(['ok' => false, 'message' => 'noteinstieg_recovery_codes fehlt'], 422);
        }

        // Optional: nur sinnvoll bei Wartung an
        if (Schema::hasTable('app_settings')) {
            $s = DB::table('app_settings')->select(['maintenance_enabled'])->first();
            if (!$s || !(bool) $s->maintenance_enabled) {
                return response()->json(['ok' => false, 'message' => 'wartung aus'], 422);
            }
        }

        if (!(bool) SystemSettingHelper::get('debug.break_glass', false)) {
            return response()->json(['ok' => false, 'message' => 'noteinstieg aus'], 422);
        }

        $hasUnused = (int) DB::table('noteinstieg_recovery_codes')->whereNull('used_at')->count();
        if ($hasUnused > 0) {
            return response()->json(['ok' => false, 'message' => 'Es sind bereits unbenutzte Notfallcodes vorhanden.'], 422);
        }

        $total = (int) DB::table('noteinstieg_recovery_codes')->count();
        if ($total > 0) {
            // alle sind benutzt -> hart auf 5 begrenzen: alte Codes entfernen
            DB::table('noteinstieg_recovery_codes')->delete();
        }

        $targetUnused = 5;
        $maxTotal = 10;

        DB::beginTransaction();
        try {
            $unusedCount = (int) DB::table('noteinstieg_recovery_codes')
                ->whereNull('used_at')
                ->count();

            $missing = $targetUnused - $unusedCount;
            if ($missing < 0) {
                $missing = 0;
            }

            $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
            $make = function () use ($alphabet): string {
                $out = '';
                $max = strlen($alphabet) - 1;
                for ($i = 0; $i < 8; $i++) {
                    $out .= $alphabet[random_int(0, $max)];
                }
                return substr($out, 0, 4) . '-' . substr($out, 4, 4);
            };

            $now = now();
            $rows = [];

            for ($i = 0; $i < $missing; $i++) {
                $c = $make();

                $normalized = str_replace('-', '', $c);
                $hash = hash_hmac('sha256', $normalized, (string) config('app.key'));

                // Bei extrem unwahrscheinlichem Hash-Collision: neu versuchen
                $exists = DB::table('noteinstieg_recovery_codes')->where('hash', $hash)->exists();
                if ($exists) {
                    $i--;
                    continue;
                }

                $rows[] = [
                    'hash' => $hash,
                    'code_encrypted' => encrypt($c),
                    'used_at' => null,
                    'used_ip' => null,
                    'used_user_agent' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }

            if (!empty($rows)) {
                DB::table('noteinstieg_recovery_codes')->insert($rows);
            }

            // Hard cap: max 10 Datensätze (zuerst alte benutzte löschen)
            $total = (int) DB::table('noteinstieg_recovery_codes')->count();
            if ($total > $maxTotal) {
                $toDelete = $total - $maxTotal;

                $ids = DB::table('noteinstieg_recovery_codes')
                    ->whereNotNull('used_at')
                    ->orderBy('used_at', 'asc')
                    ->orderBy('id', 'asc')
                    ->limit($toDelete)
                    ->pluck('id')
                    ->all();

                if (!empty($ids)) {
                    DB::table('noteinstieg_recovery_codes')->whereIn('id', $ids)->delete();
                }

                // Falls immer noch > maxTotal (z.B. zu viele unbenutzte): älteste unbenutzte löschen
                $total = (int) DB::table('noteinstieg_recovery_codes')->count();
                if ($total > $maxTotal) {
                    $toDelete = $total - $maxTotal;

                    $ids2 = DB::table('noteinstieg_recovery_codes')
                        ->whereNull('used_at')
                        ->orderBy('created_at', 'asc')
                        ->orderBy('id', 'asc')
                        ->limit($toDelete)
                        ->pluck('id')
                        ->all();

                    if (!empty($ids2)) {
                        DB::table('noteinstieg_recovery_codes')->whereIn('id', $ids2)->delete();
                    }
                }
            }

            // Immer 5 Codes zurückgeben (für dein bestehendes JS)
            $rowsOut = DB::table('noteinstieg_recovery_codes')
                ->select(['code_encrypted', 'used_at', 'created_at', 'id'])
                ->orderByRaw('CASE WHEN used_at IS NULL THEN 0 ELSE 1 END ASC')
                ->orderBy('created_at', 'desc')
                ->orderBy('id', 'desc')
                ->limit(2000)
                ->get();

            $out = [];
            foreach ($rowsOut as $row) {
                $plain = '';
                if (isset($row->code_encrypted) && $row->code_encrypted !== null && (string) $row->code_encrypted !== '') {
                    try {
                        $plain = (string) decrypt((string) $row->code_encrypted);
                    } catch (\Throwable $e) {
                        $plain = '';
                    }
                }
                if ($plain === '') {
                    continue;
                }
                $out[] = $plain;
                if (count($out) >= 5) {
                    break;
                }
            }

            // Safety: wenn durch alte Daten <5 da sind -> fehlende nachziehen
            while (count($out) < 5) {
                $c = $make();
                $normalized = str_replace('-', '', $c);
                $hash = hash_hmac('sha256', $normalized, (string) config('app.key'));
                $exists = DB::table('noteinstieg_recovery_codes')->where('hash', $hash)->exists();
                if ($exists) {
                    continue;
                }

                DB::table('noteinstieg_recovery_codes')->insert([
                    'hash' => $hash,
                    'code_encrypted' => encrypt($c),
                    'used_at' => null,
                    'used_ip' => null,
                    'used_user_agent' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $out[] = $c;
            }

            DB::commit();

            return response()->json(['ok' => true, 'codes' => $out]);
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json(['ok' => false, 'message' => 'generate failed'], 500);
        }
    })->name('admin.noteinstieg.recovery.generate.ajax');

    /*
    |--------------------------------------------------------------------------
    | Wartungsende (Anzeige) – AJAX
    |--------------------------------------------------------------------------
    */
    Route::post('/admin/maintenance/eta-ajax', function (\Illuminate\Http\Request $request) {
        abort_unless(auth()->check() && (string) auth()->user()->role === 'admin', 403);

        if (!Schema::hasTable('app_settings')) {
            return response()->json(['ok' => false, 'message' => 'app_settings fehlt'], 422);
        }

        $settings = DB::table('app_settings')->select([
            'maintenance_enabled',
            'maintenance_show_eta',
            'maintenance_eta_at',
        ])->first();

        if (!$settings) {
            DB::table('app_settings')->insert([
                'maintenance_enabled' => 0,
                'maintenance_show_eta' => 0,
                'maintenance_eta_at' => null,
            ]);
        }

        $showEta = (bool) $request->input('maintenance_show_eta', false);

        $etaDate = (string) $request->input('maintenance_eta_date', '');
        $etaDate = trim($etaDate);

        $etaTime = (string) $request->input('maintenance_eta_time', '');
        $etaTime = trim($etaTime);

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

        DB::table('app_settings')->update([
            'maintenance_show_eta' => $showEta ? 1 : 0,
            'maintenance_eta_at' => $etaDbValue,
        ]);

        return response()->json(['ok' => true]);
    })->name('admin.maintenance.eta.ajax');

    /*
    |--------------------------------------------------------------------------
    | Wartung-ETA (Anzeige) – unverändert
    |--------------------------------------------------------------------------
    */
    Route::post('/admin/maintenance/eta', function (\Illuminate\Http\Request $request) {
        abort_unless(auth()->check() && (string) auth()->user()->role === 'admin', 403);

        if (!Schema::hasTable('app_settings')) {
            return redirect()->route('admin.home')->with('admin_notice', 'app_settings fehlt – Speichern nicht möglich.');
        }

        $settings = DB::table('app_settings')->select([
            'maintenance_enabled',
            'maintenance_show_eta',
            'maintenance_eta_at',
        ])->first();

        if (!$settings) {
            DB::table('app_settings')->insert([
                'maintenance_enabled' => 0,
                'maintenance_show_eta' => 0,
                'maintenance_eta_at' => null,
            ]);
        }

        $showEta = (bool) $request->boolean('maintenance_show_eta');

        $etaDate = (string) $request->input('maintenance_eta_date', '');
        $etaDate = trim($etaDate);

        $etaTime = (string) $request->input('maintenance_eta_time', '');
        $etaTime = trim($etaTime);

        $etaDbValue = null;

        if ($etaDate !== '' && $etaTime !== '') {
            $etaRaw = $etaDate . ' ' . $etaTime;

            try {
                $dt = \Illuminate\Support\Carbon::createFromFormat('Y-m-d H:i', $etaRaw, config('app.timezone'));
                $etaDbValue = $dt->format('Y-m-d H:i:s');
            } catch (\Throwable $e) {
                return redirect()->route('admin.home')->with('admin_notice', 'Ungültiges Datum/Uhrzeit-Format. Bitte erneut versuchen.');
            }
        }

        DB::table('app_settings')->update([
            'maintenance_show_eta' => $showEta ? 1 : 0,
            'maintenance_eta_at' => $etaDbValue,
        ]);

        return redirect()->route('admin.home')->with('admin_notice', 'Wartung-ETA gespeichert.');
    })->name('admin.maintenance.eta');

    Route::post('/admin/maintenance/eta/clear', function () {
        abort_unless(auth()->check() && (string) auth()->user()->role === 'admin', 403);

        if (!Schema::hasTable('app_settings')) {
            return redirect()->route('admin.home')->with('admin_notice', 'app_settings fehlt – Löschen nicht möglich.');
        }

        $settings = DB::table('app_settings')->select([
            'maintenance_enabled',
            'maintenance_show_eta',
            'maintenance_eta_at',
        ])->first();

        if (!$settings) {
            DB::table('app_settings')->insert([
                'maintenance_enabled' => 0,
                'maintenance_show_eta' => 0,
                'maintenance_eta_at' => null,
            ]);

            return redirect()->route('admin.home')->with('admin_notice', 'Wartung-ETA gelöscht.');
        }

        DB::table('app_settings')->update([
            'maintenance_show_eta' => 0,
            'maintenance_eta_at' => null,
        ]);

        return redirect()->route('admin.home')->with('admin_notice', 'Wartung-ETA gelöscht.');
    })->name('admin.maintenance.eta.clear');
});
