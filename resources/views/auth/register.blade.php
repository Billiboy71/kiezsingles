{{-- ========================================================================= --}}
{{-- File: C:\laragon\www\kiezsingles\resources\views\auth\register.blade.php  --}}
{{-- Changed: 23-02-2026 23:28 (Europe/Berlin)                                 --}}
{{-- Version: 0.4                                                              --}}
{{-- Purpose: Register view (user registration with Turnstile & feature flags) --}}
{{-- ========================================================================= --}}
<x-guest-layout>
    @php
        $captchaEnabled = (bool) (config('captcha.enabled') && config('captcha.on_register'));
        $turnstileSiteKey = (string) config('captcha.site_key');
    @endphp

    <form method="POST" action="{{ route('register') }}" autocomplete="off">
        @csrf

        {{-- Autofill-Fänger --}}
        <input type="text" name="username" autocomplete="username" class="hidden">
        <input type="password" name="password_fake" autocomplete="current-password" class="hidden">

        <!-- Ich bin / Ich suche -->
        <div class="mt-4">
            <x-input-label for="match_type" value="Ich bin / Ich suche" />

            <select
                id="match_type"
                name="match_type"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            >
                <option value="" disabled {{ old('match_type') ? '' : 'selected' }}>Bitte wählen…</option>
                <option value="f_m" @selected(old('match_type') === 'f_m')>Ich bin eine Frau und suche einen Mann</option>
                <option value="m_f" @selected(old('match_type') === 'm_f')>Ich bin ein Mann und suche eine Frau</option>
                <option value="f_f" @selected(old('match_type') === 'f_f')>Ich bin eine Frau und suche eine Frau</option>
                <option value="m_m" @selected(old('match_type') === 'm_m')>Ich bin ein Mann und suche einen Mann</option>
            </select>

            <x-input-error :messages="$errors->get('match_type')" class="mt-2" />
        </div>

        <!-- Pseudonym -->
        <div class="mt-4">
            <x-input-label for="username" value="Pseudonym (4–14 Zeichen)" />
            <x-text-input
                id="username"
                class="block mt-1 w-full"
                type="text"
                name="username"
                value="{{ old('username') }}"
                required
                minlength="4"
                maxlength="14"
            />
            <x-input-error :messages="$errors->get('username')" class="mt-2" />
        </div>

        <div class="mt-4 flex gap-3 items-end">
            <!-- Geburtsdatum -->
            <div class="flex-1 basis-0">
                <x-input-label for="birthdate" value="Geburtsdatum" />
                <x-text-input
                    id="birthdate"
                    class="block mt-1 w-full"
                    type="date"
                    name="birthdate"
                    value="{{ old('birthdate') }}"
                    max="{{ now()->subYears(18)->format('Y-m-d') }}"
                    required
                />
                <x-input-error :messages="$errors->get('birthdate')" class="mt-2" />
            </div>

            <!-- Alter (immer 50% Platz; zeigt serverseitig old()-Alter oder –) -->
            <div class="flex-1 basis-0 whitespace-nowrap">
                <!-- Spacer statt "Alter"-Überschrift (damit die Zeile auf Input-Höhe sitzt) -->
                <div class="h-5"></div>

                <!-- Zeile mittig auf der Höhe des Date-Inputs -->
                <div class="h-[42px] flex items-center text-[18px] text-gray-600 pl-2.5">
                    <span id="ageLine"></span>
                </div>
            </div>
        </div>

        <!-- Wohnort -->
        <div class="mt-4">
            <x-input-label for="location" value="Wohnort" />
            <x-text-input
                id="location"
                class="block mt-1 w-full bg-gray-100 text-gray-500 cursor-not-allowed"
                type="text"
                value="Berlin"
                disabled
            />
        </div>

        <!-- Stadtbezirk -->
        <div class="mt-4">
            <x-input-label for="district" value="Stadtbezirk" />
            <select
                id="district"
                name="district"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            >
                <option value="" disabled {{ old('district') ? '' : 'selected' }}>Bitte wählen…</option>
                @foreach($districts as $d)
                    <option value="{{ $d }}" @selected(old('district') === $d)>{{ $d }}</option>
                @endforeach
            </select>
            <x-input-error :messages="$errors->get('district')" class="mt-2" />
        </div>

        {{-- Postcode (Feature) --}}
        @if (config('features.postcode.enabled'))
            <div class="mt-4">
                <x-input-label for="postcode" value="Postleitzahl" />

                <select
                    id="postcode"
                    name="postcode"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                    @if(config('features.postcode.required')) required @endif
                    disabled
                    data-postcode-required="{{ (bool) config('features.postcode.required') ? '1' : '0' }}"
                    data-old-district="{{ (string) old('district') }}"
                    data-old-postcode="{{ (string) old('postcode') }}"
                    data-postcodes-url-template="{{ route('district.postcodes', ['district' => '___D___']) }}"
                >
                    <option value="" selected>Bitte zuerst Stadtbezirk wählen…</option>
                </select>

                <p class="mt-1 text-xs text-gray-600">
                    Wird nur für die interne Entfernungssuche benötigt.
                </p>

                <x-input-error :messages="$errors->get('postcode')" class="mt-2" />
            </div>
        @endif

        <!-- Email -->
        <div class="mt-4">
            <x-input-label for="email" value="E-Mail" />
            <x-text-input
                id="email"
                class="block mt-1 w-full"
                type="email"
                name="email"
                value="{{ old('email') }}"
                placeholder="...@..."
                required
                autocomplete="email"
                inputmode="email"
            />
            <x-input-error :messages="$errors->get('email')" class="mt-2" />

            <p id="emailHint" class="mt-1 text-sm text-red-600 hidden">
                Bitte gib eine gültige E-Mail-Adresse ein (z. B. name@example.de).
            </p>
        </div>

        <!-- Passwort -->
        <div class="mt-4">
            <x-input-label for="password" value="Passwort" />

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
                <li data-rule="length"  class="text-red-600">⛔ Mindestens 10 Zeichen</li>
                <li data-rule="upper"   class="text-red-600">⛔ Mindestens ein Großbuchstabe</li>
                <li data-rule="lower"   class="text-red-600">⛔ Mindestens ein Kleinbuchstabe</li>
                <li data-rule="number"  class="text-red-600">⛔ Mindestens eine Zahl</li>
                <li data-rule="special" class="text-red-600">⛔ Mindestens ein Sonderzeichen</li>
            </ul>
        </div>

        <!-- Datenschutz -->
        <div class="mt-4">
            <label class="inline-flex items-center">
                <input
                    type="checkbox"
                    name="privacy"
                    value="1"
                    class="rounded border-gray-300"
                    required
                    {{ old('privacy') ? 'checked' : '' }}
                >
                <span class="ms-2 text-sm text-gray-600">
                    Ich akzeptiere die Datenschutzrichtlinien.
                </span>
            </label>
            <x-input-error :messages="$errors->get('privacy')" class="mt-2" />
        </div>

        {{-- Captcha Token --}}
        @if ($captchaEnabled && $turnstileSiteKey !== '')
            <input type="hidden" name="cf-turnstile-response" id="cf-turnstile-response" value="">
        @endif

        {{-- Captcha (Turnstile auto-render) --}}
        @if ($captchaEnabled && $turnstileSiteKey !== '')
            <div class="mt-4">
                <div
                    class="cf-turnstile"
                    data-sitekey="{{ $turnstileSiteKey }}"
                    data-callback="onTurnstileSuccess"
                    data-expired-callback="onTurnstileExpired"
                    data-error-callback="onTurnstileError"
                ></div>
            </div>
        @endif

        <!-- Actions -->
        <div class="flex items-center justify-end mt-4">
            <a
                class="underline text-sm text-gray-600 hover:text-gray-900 rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                href="{{ route('login') }}"
            >
                {{ __('Already registered?') }}
            </a>

            <x-primary-button
                id="registerBtn"
                class="ms-4"
            >
                {{ __('Register') }}
            </x-primary-button>
        </div>
    </form>
</x-guest-layout>