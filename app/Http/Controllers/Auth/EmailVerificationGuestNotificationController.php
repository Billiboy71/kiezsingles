<?php
// ============================================================================
// File: app/Http/Controllers/Auth/EmailVerificationGuestNotificationController.php
// Purpose: Resend email verification link for guests (throttled, no enumeration)
// ============================================================================

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;

class EmailVerificationGuestNotificationController extends Controller
{
    public function __invoke(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'string', 'email', 'max:255'],
        ]);

        $email = strtolower($validated['email']);

        // Throttle per email (prevents spam)
        $key = 'verification-resend-guest:' . sha1($email);

        if (RateLimiter::tooManyAttempts($key, 3)) {
            return back()->with('status', 'Bitte warte kurz, bevor du es erneut versuchst.');
        }

        RateLimiter::hit($key, 60);

        // Do NOT reveal whether user exists
        $user = User::where('email', $email)->first();

        if ($user && method_exists($user, 'hasVerifiedEmail') && !$user->hasVerifiedEmail()) {
            if (method_exists($user, 'sendEmailVerificationNotification')) {
                $user->sendEmailVerificationNotification();
            }
        }

        return back()->with('status', 'Wenn die E-Mail-Adresse existiert und noch nicht bestätigt ist, wurde ein Bestätigungslink gesendet.');
    }
}
