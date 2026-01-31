<?php
// ============================================================================
// File: app/Http/Controllers/Auth/AuthenticatedSessionController.php
// Purpose: Login controller (blocks login until email is verified; NO auto resend)
// ============================================================================

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

class AuthenticatedSessionController extends Controller
{
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
        // Kein Captcha beim Login (Throttle reicht)
        $request->authenticate();

        // HARD GATE: ohne verifizierte E-Mail kein Login
        $user = Auth::user();

        if ($user && method_exists($user, 'hasVerifiedEmail') && !$user->hasVerifiedEmail()) {
            Auth::guard('web')->logout();

            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return back()
                ->withErrors([
                    'email' => 'Bitte bestätige zuerst deine E-Mail-Adresse. Ohne Bestätigung ist kein Login möglich.',
                ])
                ->with('email_not_verified', true)
                ->onlyInput('email');
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
