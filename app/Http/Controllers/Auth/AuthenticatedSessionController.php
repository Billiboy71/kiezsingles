<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Auth\AuthenticatedSessionController.php
// Purpose: Login controller (blocks login until email is verified; auto resend on unverified login)
//          + supports login via email OR username (entered in the same "email" field)
// Changed: 28-02-2026 14:49 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Models\SecurityIdentityBan;
use App\Models\User;
use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use App\Support\KsMaintenance;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class AuthenticatedSessionController extends Controller
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
    ) {}

    /**
     * Display the login view.
     */
    public function create(): View
    {
        return view('auth.login');
    }

    /**
     * Handle an incoming authentication request.
     */
    public function store(LoginRequest $request): RedirectResponse
    {
        // Login kann per E-Mail ODER Username erfolgen (Eingabe kommt im Feld "email" an)
        $originalLogin = (string) $request->input('email', '');
        $mappedFromUsername = false;

        $resolvedUser = null;

        // Wenn kein '@' drin ist, behandeln wir es als Username und mappen auf die echte E-Mail
        if ($originalLogin !== '' && !str_contains($originalLogin, '@')) {
            $u = User::query()
                ->select(['id', 'email', 'is_frozen'])
                ->where('username', $originalLogin)
                ->first();

            if ($u && is_string($u->email) && $u->email !== '') {
                $request->merge(['email' => $u->email]);
                $mappedFromUsername = true;
                $resolvedUser = $u;
            }
        }

        $normalizedEmail = mb_strtolower(trim((string) $request->input('email', '')));

        if ($normalizedEmail !== '') {
            $activeIdentityBan = SecurityIdentityBan::query()
                ->where('email', $normalizedEmail)
                ->active()
                ->latest('id')
                ->first();

            if ($activeIdentityBan) {
                $this->securityEventLogger->log(
                    type: 'identity_blocked',
                    ip: $request->ip(),
                    email: $normalizedEmail,
                    deviceHash: $this->deviceHashService->forRequest($request),
                    meta: [
                        'reason' => $activeIdentityBan->reason,
                        'banned_until' => $activeIdentityBan->banned_until?->toIso8601String(),
                        'path' => $request->path(),
                    ],
                );

                abort(403, 'This identity is banned.');
            }
        }

        if (!$resolvedUser && $normalizedEmail !== '') {
            $resolvedUser = User::query()
                ->select(['id', 'is_frozen', 'email'])
                ->where('email', $normalizedEmail)
                ->first();
        }

        if ($resolvedUser && (bool) $resolvedUser->is_frozen) {
            $this->securityEventLogger->log(
                type: 'account_frozen_blocked',
                ip: $request->ip(),
                userId: (int) $resolvedUser->id,
                email: $resolvedUser->email,
                deviceHash: $this->deviceHashService->forRequest($request),
                meta: [
                    'path' => $request->path(),
                ],
            );

            abort(403, 'This account is frozen.');
        }

        // Kein Captcha beim Login (Throttle reicht)
        try {
            $request->authenticate();
        } catch (ValidationException $e) {
            // Bei Login-Fail das ursprüngliche Eingabefeld wiederherstellen,
            // damit im Formular Username/E-Mail so angezeigt wird, wie der User es eingegeben hat.
            if ($mappedFromUsername) {
                $request->merge(['email' => $originalLogin]);
            }
            throw $e;
        }

        // Wartung: erst NACH erfolgreichem Auth prüfen (keine Rollen-Erkennung via E-Mail vor dem Login).
        // Fail-closed: nur Superadmin immer erlaubt, Admin/Moderator nur wenn allow_* aktiv.
        $user = Auth::user();

        if ($user && KsMaintenance::enabled()) {
            $allowed =
                $user->hasRole('superadmin')
                || ($user->hasRole('admin') && KsMaintenance::allowAdmins())
                || ($user->hasRole('moderator') && KsMaintenance::allowModerators());

            if (!$allowed) {
                Auth::guard('web')->logout();

                $request->session()->invalidate();
                $request->session()->regenerateToken();

                return back()
                    ->withErrors([
                        'email' => 'Login ist aktuell nicht erlaubt.',
                    ])
                    ->with('maintenance_login_blocked', true)
                    ->withInput(['email' => $originalLogin]);
            }
        }

        // HARD GATE: ohne verifizierte E-Mail kein Login
        $user = Auth::user();

        if ($user && method_exists($user, 'hasVerifiedEmail') && !$user->hasVerifiedEmail()) {
            // Auto-Resend: nur nachdem Credentials korrekt waren (keine Enumeration)
            if (method_exists($user, 'sendEmailVerificationNotification')) {
                $user->sendEmailVerificationNotification();
            }

            Auth::guard('web')->logout();

            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return back()
                ->withErrors([
                    'email' => __('auth.login.email_not_verified_error'),
                ])
                ->with('status', __('auth.login.email_not_verified_status'))
                ->with('email_not_verified', true)
                ->withInput(['email' => $originalLogin]);
        }

        $request->session()->regenerate();

        return redirect()->intended(route('dashboard', absolute: false));
    }

    /**
     * Destroy an authenticated session.
     */
    public function destroy(Request $request): RedirectResponse
    {
        Auth::guard('web')->logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect('/');
    }
}
