{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\contact.blade.php
Changed: 23-02-2026 22:06 (Europe/Berlin)
Version: 0.1
Purpose: Public contact form (guest layout) with optional Turnstile captcha
============================================================================ --}}

<x-guest-layout>
    @php
        $captchaEnabled = (bool) (config('captcha.enabled') && config('captcha.on_contact'));
    @endphp

    <div class="max-w-xl mx-auto">
        <h1 class="text-xl font-semibold text-gray-900">Kontakt</h1>

        @if (session('status'))
            <div class="mt-4 text-sm text-green-600">
                {{ session('status') }}
            </div>
        @endif

        <form
            method="POST"
            action="{{ route('contact.store') }}"
            class="mt-6 space-y-4"
            data-ks-contact="1"
            data-captcha-enabled="{{ $captchaEnabled ? '1' : '0' }}"
        >
            @csrf

            <div>
                <x-input-label for="name" value="Name" />
                <x-text-input id="name" name="name" class="block mt-1 w-full" :value="old('name')" required />
                <x-input-error :messages="$errors->get('name')" class="mt-2" />
            </div>

            <div>
                <x-input-label for="email" value="E-Mail" />
                <x-text-input id="email" name="email" type="email" class="block mt-1 w-full" :value="old('email')" required />
                <x-input-error :messages="$errors->get('email')" class="mt-2" />
            </div>

            <div>
                <x-input-label for="message" value="Nachricht" />
                <textarea
                    id="message"
                    name="message"
                    class="block mt-1 w-full rounded-md border-gray-300"
                    rows="6"
                    required
                >{{ old('message') }}</textarea>
                <x-input-error :messages="$errors->get('message')" class="mt-2" />
            </div>

            @if ($captchaEnabled)
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

            <div class="flex justify-end">
                <x-primary-button
                    id="contactBtn"
                    :disabled="$captchaEnabled"
                    :class="$captchaEnabled ? 'opacity-50 cursor-not-allowed' : ''"
                >
                    Senden
                </x-primary-button>
            </div>
        </form>
    </div>
</x-guest-layout>