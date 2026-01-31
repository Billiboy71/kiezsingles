<?php
// ============================================================================
// File: app/Http/Controllers/Auth/VerifyEmailController.php
// Purpose: Verify email address and redirect to login with success message
// ============================================================================

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Auth\Events\Verified;
use Illuminate\Foundation\Auth\EmailVerificationRequest;
use Illuminate\Http\RedirectResponse;

class VerifyEmailController extends Controller
{
    /**
     * Mark the authenticated user's email address as verified.
     */
    public function __invoke(EmailVerificationRequest $request): RedirectResponse
    {
        if (!$request->user()->hasVerifiedEmail()) {
            if ($request->user()->markEmailAsVerified()) {
                event(new Verified($request->user()));
            }
        }

        return redirect()
            ->route('login')
            ->with('status', 'Deine E-Mail-Adresse wurde erfolgreich bestätigt. Du kannst dich jetzt einloggen.');
    }
}
