<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Auth\RegisteredUserController.php
// Purpose: Register new users (sends verification email, does NOT auto-login)
// Changed: 11-02-2026 03:49 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\SystemSettingHelper;
use App\Support\Turnstile;
use Illuminate\Auth\Events\Registered;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class RegisteredUserController extends Controller
{
    public function create(): View
    {
        // Quelle: Mapping-Tabelle (kein config/kiez.php mehr)
        $districts = DB::table('district_postcodes')
            ->select('district')
            ->distinct()
            ->orderBy('district')
            ->pluck('district');

        return view('auth.register', [
            'districts' => $districts,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        // ===============================
        // DEBUG GATE (SystemSettings)
        // ===============================
        $debugUiAllowed = SystemSettingHelper::debugUiAllowed();

        $debugRegisterErrors = $debugUiAllowed
            && SystemSettingHelper::debugBool('register_errors', false);

        $debugRegisterPayload = $debugUiAllowed
            && SystemSettingHelper::debugBool('register_payload', false);

        // Turnstile Debug: DB (debug.turnstile_enabled neu) ODER (debug.turnstile alt)
        $debugTurnstile = $debugUiAllowed
            && (
                SystemSettingHelper::debugBool('turnstile_enabled', false)
                || SystemSettingHelper::debugBool('turnstile', false)
            );

        // ===============================
        // CAPTCHA FLAGS (Policy, bleibt config/env)
        // ===============================
        $captchaEnabled  = (bool) config('captcha.enabled');
        $captchaRegister = (bool) config('captcha.on_register');

        $captchaActive = $captchaEnabled && $captchaRegister;

        // Debug: Incoming Request (nur wenn Debug-Gate aktiv)
        if ($debugTurnstile) {
            logger()->info('TURNSTILE DEBUG: incoming', [
                'captcha_active' => $captchaActive,
                'has_token'      => $request->filled('cf-turnstile-response'),
                'token_length'   => strlen((string) $request->input('cf-turnstile-response')),
                'token_preview'  => substr((string) $request->input('cf-turnstile-response'), 0, 25),
                'keys'           => array_keys($request->all()),

                // Key-Check (ohne Secrets)
                'site_key_set'   => !empty(config('captcha.site_key')),
                'secret_key_set' => !empty(config('captcha.secret_key')),

                // Umgebung
                'app_env'        => app()->environment(),
                'app_url'        => config('app.url'),
                'request_host'   => $request->getHost(),
            ]);
        }

        // Stichtag: heute minus 18 Jahre (ISO-Format)
        $minDate = now()->subYears(18)->format('Y-m-d');

        // Feature: Postcode
        $postcodeEnabled  = (bool) config('features.postcode.enabled');
        $postcodeRequired = (bool) config('features.postcode.required');

        $postcodeRules = $postcodeEnabled
            ? array_merge(
                $postcodeRequired ? ['required'] : ['nullable'],
                ['bail', 'string', 'regex:/^\d{5}$/']
            )
            : ['nullable'];

        // ===============================
        // 1) VALIDATION mit TRY/CATCH
        // ===============================
        try {
            $validated = $request->validate(
                [
                    // Matching
                    'match_type' => ['required', 'in:f_m,m_f,f_f,m_m'],

                    // Alter / Geburtsdatum
                    'birthdate' => ['required', 'date', 'before_or_equal:' . $minDate],

                    // Stadtbezirk
                    'district' => [
                        'required',
                        'string',
                        'max:80',
                        'exists:district_postcodes,district',
                    ],

                    // Postleitzahl
                    'postcode' => $postcodeRules,

                    // Username
                    'username' => [
                        'required',
                        'string',
                        'min:4',
                        'max:20',
                        'regex:/^[a-zA-Z0-9._-]+$/',
                        'unique:users,username',
                    ],

                    // Login
                    'email' => [
                        'required',
                        'string',
                        'email',
                        'max:255',
                        'unique:users,email',
                    ],

                    // Passwort
                    'password' => [
                        'required',
                        Password::defaults()->uncompromised(),
                    ],

                    // Rechtliches
                    'privacy' => ['required', 'accepted'],

                    // Captcha (nur required wenn aktiv)
                    'cf-turnstile-response' => $captchaActive ? ['required', 'string'] : ['nullable'],
                ],
                [
                    'match_type.required' => 'Bitte wähle „Ich bin / Ich suche“.',
                    'match_type.in'       => 'Ungültige Auswahl.',

                    'birthdate.required'        => 'Bitte gib dein Geburtsdatum an.',
                    'birthdate.date'            => 'Ungültiges Datumsformat.',
                    'birthdate.before_or_equal' => 'Du musst mindestens 18 Jahre alt sein.',

                    'district.required' => 'Bitte wähle einen Stadtbezirk.',
                    'district.exists'   => 'Ungültiger Stadtbezirk.',

                    'postcode.required' => 'Bitte gib eine PLZ an.',
                    'postcode.regex'    => 'PLZ muss aus genau 5 Ziffern bestehen.',

                    'privacy.required' => 'Du musst die Datenschutzrichtlinien akzeptieren.',
                    'privacy.accepted' => 'Du musst die Datenschutzrichtlinien akzeptieren.',

                    'cf-turnstile-response.required' => 'Captcha fehlt. Bitte erneut versuchen.',
                ]
            );
        } catch (ValidationException $e) {
            if ($debugRegisterErrors) {
                logger()->error('REGISTER VALIDATION FAILED', [
                    'errors' => $e->errors(),
                    'keys'   => array_keys($request->all()),
                ]);
            }
            throw $e;
        }

        // DEBUG
        if ($debugRegisterErrors) {
            logger()->info('REGISTER VALIDATION PASSED', [
                'fields' => array_keys($validated),
                'email'  => $validated['email'] ?? null,
            ]);
        }

        if ($debugRegisterPayload) {
            session()->flash('debug_register_payload', [
                'request_keys' => array_keys($request->all()),
                'validated' => collect($validated)->except([
                    'password',
                    'cf-turnstile-response',
                ])->toArray(),
            ]);
        }

        // ===============================
        // 2) CAPTCHA VERIFY
        // ===============================
        if ($captchaActive) {

            if ($debugTurnstile) {
                logger()->info('TURNSTILE CONFIG CHECK', [
                    'captcha_enabled'  => (bool) config('captcha.enabled'),
                    'captcha_register' => (bool) config('captcha.on_register'),
                    'site_key_set'     => !empty(config('captcha.site_key')),
                    'secret_key_set'   => !empty(config('captcha.secret_key')),
                    'app_env'          => app()->environment(),
                    'app_url'          => config('app.url'),
                    'request_host'     => $request->getHost(),
                    'has_token'        => $request->filled('cf-turnstile-response'),
                    'token_length'     => strlen((string) $request->input('cf-turnstile-response')),
                ]);
            }

            try {
                Turnstile::verify($validated['cf-turnstile-response']);
            } catch (\Throwable $e) {

                if ($debugTurnstile) {
                    logger()->error('TURNSTILE VERIFY FAILED', [
                        'message' => $e->getMessage(),
                        'class'   => get_class($e),
                    ]);
                }

                throw ValidationException::withMessages([
                    'cf-turnstile-response' => __('Captcha validation failed. Please try again.'),
                ]);
            }
        }

        // ===============================
        // 3) district + postcode prüfen
        // ===============================
        if ($postcodeEnabled && !empty($validated['postcode'])) {
            $ok = DB::table('district_postcodes')
                ->where('district', $validated['district'])
                ->where('postcode', $validated['postcode'])
                ->exists();

            if (!$ok) {
                return back()
                    ->withErrors([
                        'postcode' => 'Die Postleitzahl passt nicht zum ausgewählten Stadtbezirk.',
                    ])
                    ->withInput();
            }
        }

        // Ableitung aus match_type
        $gender     = str_starts_with($validated['match_type'], 'f') ? 'f' : 'm';
        $lookingFor = str_ends_with($validated['match_type'], 'm') ? 'm' : 'f';

        // Public-ID: serverseitig, url-safe, nicht aus id ableitbar, unique
        do {
            $publicId = Str::lower(Str::random(12)); // a-z0-9, keine / + =
        } while (User::where('public_id', $publicId)->exists());

        $user = User::create([
            'public_id'  => $publicId,

            'match_type'  => $validated['match_type'],
            'gender'      => $gender,
            'looking_for' => $lookingFor,

            'username'   => $validated['username'],

            'email'    => strtolower($validated['email']),
            'password' => Hash::make($validated['password']),

            'birthdate' => $validated['birthdate'],
            'location'  => 'Berlin',

            'district' => $validated['district'],
            'postcode' => $postcodeEnabled ? ($validated['postcode'] ?? null) : null,

            'privacy_accepted_at' => now(),
        ]);

        event(new Registered($user));

        return redirect()
            ->route('login')
            ->withInput(['email' => strtolower($validated['email'])])
            ->with('email_not_verified', true)
            ->with('status', "Registrierung erfolgreich.\nBitte prüfe dein Postfach und bestätige deine E-Mail-Adresse, bevor du dich einloggen kannst.");
    }
}
