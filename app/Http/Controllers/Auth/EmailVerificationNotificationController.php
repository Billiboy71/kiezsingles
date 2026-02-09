<?php

// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Auth\EmailVerificationNotificationController.php
// Purpose: Send a new email verification notification.
// Changed: 07-02-2026 02:24
// ============================================================================

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Support\Turnstile;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class EmailVerificationNotificationController extends Controller
{
    /**
     * Send a new email verification notification.
     */
    public function store(Request $request): RedirectResponse
    {
        if ($request->user()->hasVerifiedEmail()) {
            return redirect()->intended('/profile');
        }

        // Captcha: nur wenn Feature aktiv
        if (config('captcha.enabled') && config('captcha.on_verify')) {
            // 1) Feld muss überhaupt vorhanden sein (sauberer Validation-Flow)
            $request->validate([
                'cf-turnstile-response' => ['required', 'string'],
            ], [
                'cf-turnstile-response.required' => __('Please complete the captcha.'),
            ]);

            // 2) Serverseitige Prüfung (bei Fail als ValidationError zurück)
            try {
                Turnstile::verify($request->string('cf-turnstile-response')->toString());
            } catch (\Throwable $e) {
                throw ValidationException::withMessages([
                    'cf-turnstile-response' => __('Captcha validation failed. Please try again.'),
                ]);
            }
        }

        $request->user()->sendEmailVerificationNotification();

        // Abgeleitet: 07-02-2026 02:24
        // Translation-Key statt Status-Code, Ausgabe erfolgt via __() in auth-session-status.blade.php
        return back()->with(
            'status',
            'A new verification link has been sent to the email address you provided during registration.'
        );
    }
}
