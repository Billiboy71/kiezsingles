<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Auth\VerifyEmailController.php
// Purpose: Verify email address (guest-safe) and redirect to login with success message
// ============================================================================

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Auth\Events\Verified;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

class VerifyEmailController extends Controller
{
    /**
     * Mark the user's email address as verified (guest-safe via signed URL).
     */
    public function __invoke(Request $request, string $id, string $hash): RedirectResponse
    {
        $user = User::query()->findOrFail($id);

        // Ensure the hash matches the user's email for verification.
        // The route is signed, but we still validate the expected hash.
        if (!hash_equals($hash, sha1($user->getEmailForVerification()))) {
            abort(403);
        }

        if (!$user->hasVerifiedEmail()) {
            if ($user->markEmailAsVerified()) {
                event(new Verified($user));
            }
        }

        return redirect()
            ->route('login')
            ->with('status', 'Deine E-Mail-Adresse wurde erfolgreich bestätigt. Du kannst dich jetzt einloggen.');
    }
}
