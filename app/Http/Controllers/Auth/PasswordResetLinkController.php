<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Support\Turnstile;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Password;
use Illuminate\View\View;
use Illuminate\Validation\ValidationException;

class PasswordResetLinkController extends Controller
{
    /**
     * Display the password reset link request view.
     */
    public function create(): View
    {
        return view('auth.forgot-password');
    }

    /**
     * Handle an incoming password reset link request.
     */
    public function store(Request $request): RedirectResponse
    {
        // 1) Erst normal validieren
        $request->validate([
            'email' => ['required', 'string', 'email', 'max:255'],
        ]);

        // 2) Dann Captcha prüfen (und als normales Validation-Error zurückgeben)
        if (config('captcha.enabled') && config('captcha.on_reset')) {
            try {
                Turnstile::verify($request->string('cf-turnstile-response')->toString());
            } catch (\Throwable $e) {
                throw ValidationException::withMessages([
                    'cf-turnstile-response' => __('Captcha validation failed. Please try again.'),
                ]);
            }
        }

        // 3) Immer versuchen zu senden – Ergebnis NICHT nach außen auswerten (kein Account-Leak)
        Password::sendResetLink($request->only('email'));

        // 4) Immer gleiche Antwort
        return back()->with('status', 'Wenn die E-Mail existiert, senden wir dir einen Reset-Link.');
    }
}
