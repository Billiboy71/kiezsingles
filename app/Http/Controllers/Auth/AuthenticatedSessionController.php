<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Auth\AuthenticatedSessionController.php
// Purpose: Login controller (blocks login until email is verified; auto resend on unverified login)
//          + supports login via email OR username (entered in the same "email" field)
// Changed: 20-03-2026 21:58 (Europe/Berlin)
// Version: 1.0
// ============================================================================

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Models\SecurityIdentityBan;
use App\Models\User;
use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use App\Services\Security\SecuritySupportAccessTokenService;
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
        private readonly SecuritySupportAccessTokenService $securitySupportAccessTokenService,
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
                $caseKey = 'identity_ban:'.(string) $activeIdentityBan->id.':email:'.$normalizedEmail;
                $deviceHash = $this->deviceHashService->forRequest($request);

                $this->securityEventLogger->log(
                    type: 'identity_blocked',
                    ip: $request->ip(),
                    email: $normalizedEmail,
                    deviceHash: $deviceHash,
                    meta: [
                        'reason' => 'identity_ban',
                        'ban_reason' => $activeIdentityBan->reason,
                        'banned_until' => $activeIdentityBan->banned_until?->toIso8601String(),
                        'path' => $request->path(),
                    ],
                );

                $supportRef = $this->resolveLatestSecurityReference($request->ip(), $normalizedEmail, $deviceHash);
                $supportAccess = $this->securitySupportAccessTokenService->issueForCase(
                    caseKey: $caseKey,
                    securityEventType: 'identity_blocked',
                    sourceContext: 'security_login_block',
                    contactEmail: $normalizedEmail,
                    preferredSupportReference: $supportRef,
                );
                $supportAccessToken = (string) $supportAccess['plain_token'];

                $request->session()->flash('security_ban_support_ref', $supportRef);
                $request->session()->flash('security_ban_support_reference', $supportRef);
                $request->session()->flash('security_support_reference', $supportRef);
                $request->session()->flash('security_ban_support_access_token', $supportAccessToken);

                throw ValidationException::withMessages([
                    'email' => trans('auth.failed'),
                ]);
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

            throw ValidationException::withMessages([
                'email' => trans('auth.failed'),
            ]);
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

                throw ValidationException::withMessages([
                    'email' => trans('auth.failed'),
                ]);
            }
        }

        // HARD GATE: ohne verifizierte E-Mail kein Login
        $user = Auth::user();

        if ($user && method_exists($user, 'hasVerifiedEmail') && !$user->hasVerifiedEmail()) {
            Auth::logout();

            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return redirect()
                ->route('login')
                ->withInput(['email' => (string) $user->email])
                ->with('email_not_verified', true)
                ->with('status', 'Sie haben Ihre E-Mail-Adresse noch nicht bestätigt. Bitte bestätigen Sie diese.');
        }

        $request->session()->regenerate();
        $request->session()->put('session_login_ip', (string) ($request->ip() ?? ''));

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

    private function resolveLatestSecurityReference(?string $ip, ?string $email, ?string $deviceHash): string
    {
        $query = \App\Models\SecurityEvent::query()
            ->where('created_at', '>=', now()->subMinutes(10))
            ->latest('id');

        $ip = $ip !== null ? trim($ip) : null;
        $email = $email !== null ? trim($email) : null;
        $deviceHash = $deviceHash !== null ? trim($deviceHash) : null;

        if ($ip === null || $ip === '') {
            $query->whereNull('ip');
        } else {
            $query->where('ip', $ip);
        }

        if ($email === null || $email === '') {
            $query->whereNull('email');
        } else {
            $query->where('email', $email);
        }

        if ($deviceHash === null || $deviceHash === '') {
            $query->whereNull('device_hash');
        } else {
            $query->where('device_hash', $deviceHash);
        }

        $event = $query->first(['reference']);

        if ($event === null || !is_string($event->reference) || trim($event->reference) === '') {
            throw ValidationException::withMessages([
                'email' => trans('auth.failed'),
            ]);
        }

        return trim($event->reference);
    }
}
