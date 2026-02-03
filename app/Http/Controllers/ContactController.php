<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\ContactController.php
// Purpose: Contact form controller (validation + optional Turnstile)
// ============================================================================

namespace App\Http\Controllers;

use App\Support\Turnstile;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class ContactController extends Controller
{
    public function create(): View
    {
        return view('contact');
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:80'],
            'email' => ['required', 'string', 'email', 'max:255'],
            'message' => ['required', 'string', 'min:10', 'max:5000'],
            'cf-turnstile-response' => ['nullable', 'string'],
        ]);

        if (config('captcha.enabled') && config('captcha.on_contact')) {
            try {
                Turnstile::verify($request->string('cf-turnstile-response')->toString());
            } catch (\Throwable $e) {
                throw ValidationException::withMessages([
                    'cf-turnstile-response' => __('Captcha validation failed. Please try again.'),
                ]);
            }
        }

        // Minimal: Mail an deine From-Adresse, Reply-To = Absender
        $to = config('mail.from.address');

        Mail::raw(
            "Name: {$validated['name']}\nE-Mail: {$validated['email']}\n\n{$validated['message']}",
            function ($msg) use ($validated, $to) {
                $msg->to($to)
                    ->replyTo($validated['email'], $validated['name'])
                    ->subject('Kontaktformular: Neue Nachricht');
            }
        );

        return back()->with('status', 'Danke! Nachricht wurde gesendet.');
    }
}
