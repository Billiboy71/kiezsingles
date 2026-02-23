{{-- ========================================================================= --}}
{{-- File: C:\laragon\www\kiezsingles\resources\views\auth\reset-password.blade.php --}}
{{-- Changed: 23-02-2026 23:39 (Europe/Berlin)                                     --}}
{{-- Version: 0.4                                                                   --}}
{{-- Purpose: Password reset form (email + new password + confirmation)             --}}
{{-- ========================================================================= --}}

<x-guest-layout>
    <form method="POST" action="{{ route('password.store') }}" data-ks-reset="1" data-captcha-enabled="{{ (bool) (config('captcha.enabled') && config('captcha.on_reset')) ? '1' : '0' }}">
        @csrf

        {{-- Autofill-Fänger (Browser füllt gern hier rein statt in echte Felder) --}}
        <input type="text" name="fake_username" autocomplete="username" class="hidden">
        <input type="password" name="fake_password" autocomplete="current-password" class="hidden">

        <!-- Password Reset Token -->
        <input type="hidden" name="token" value="{{ $request->route('token') }}">

        <!-- Email Address -->
        <div>
            <x-input-label for="email" :value="__('Email')" />
            <x-text-input
                id="email"
                class="block mt-1 w-full"
                type="email"
                name="email"
                placeholder="...@..."
                :value="old('email', $request->email)"
                required
                autofocus
                autocomplete="email"
                inputmode="email"
                autocapitalize="none"
                spellcheck="false"
                readonly
                data-ks-remove-readonly-on-interaction="1"
            />
            <x-input-error :messages="$errors->get('email')" class="mt-2" />
        </div>

        <!-- Password -->
        <div class="mt-4">
            <x-input-label for="password" :value="__('New Password')" />

            <div class="mt-1 flex">
                <x-text-input
                    id="password"
                    class="block w-full rounded-r-none"
                    type="password"
                    name="password"
                    required
                    autocomplete="new-password"
                />

                <button
                    type="button"
                    class="inline-flex items-center px-3 border border-l-0 rounded-l-none text-gray-600"
                    aria-label="Passwort anzeigen oder verbergen"
                    data-ks-toggle-password="1"
                    data-ks-target="password"
                    aria-controls="password"
                >
                    🔒
                </button>
            </div>

            <x-input-error :messages="$errors->get('password')" class="mt-2" />

            <p class="mt-2 text-sm font-semibold text-gray-700">
                Passwort-Anforderungen:
            </p>
            <ul id="password-rules" class="mt-1 text-xs leading-tight space-y-1">
                <li data-rule="length"  class="text-red-600">❌ Mindestens 10 Zeichen</li>
                <li data-rule="upper"   class="text-red-600">❌ Mindestens ein Großbuchstabe</li>
                <li data-rule="lower"   class="text-red-600">❌ Mindestens ein Kleinbuchstabe</li>
                <li data-rule="number"  class="text-red-600">❌ Mindestens eine Zahl</li>
                <li data-rule="special" class="text-red-600">❌ Mindestens ein Sonderzeichen</li>
            </ul>
        </div>

        <!-- Confirm Password -->
        <div class="mt-4">
            <x-input-label for="password_confirmation" :value="__('Confirm New Password')" />

            <div class="mt-1 flex">
                <x-text-input
                    id="password_confirmation"
                    class="block w-full rounded-r-none"
                    type="password"
                    name="password_confirmation"
                    required
                    autocomplete="new-password"
                />

                <button
                    type="button"
                    class="inline-flex items-center px-3 border border-l-0 rounded-l-none text-gray-600"
                    aria-label="Passwort anzeigen oder verbergen"
                    data-ks-toggle-password="1"
                    data-ks-target="password_confirmation"
                    aria-controls="password_confirmation"
                >
                    🔒
                </button>
            </div>

            <x-input-error :messages="$errors->get('password_confirmation')" class="mt-2" />

            <p id="pw-match" class="mt-2 text-xs text-red-600">
                ❌ Passwörter stimmen nicht überein
            </p>
        </div>

        {{-- Captcha (Auto-Render) --}}
        @if (config('captcha.enabled') && config('captcha.on_reset'))
            <div class="mt-4">
                <div
                    class="cf-turnstile"
                    data-sitekey="{{ config('captcha.site_key') }}"
                    data-callback="onTurnstileSuccess"
                    data-expired-callback="onTurnstileExpired"
                    data-error-callback="onTurnstileError"
                ></div>

                <x-input-error :messages="$errors->get('cf-turnstile-response')" class="mt-2" />
            </div>
        @endif

        <div class="flex items-center justify-end mt-4">
            <x-primary-button
                id="resetBtn"
                class="opacity-50 cursor-not-allowed"
                disabled
            >
                {{ __('Reset Password') }}
            </x-primary-button>
        </div>
    </form>
</x-guest-layout>