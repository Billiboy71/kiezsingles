{{-- ========================================================================= --}}
{{-- File: C:\laragon\www\kiezsingles\resources\views\auth\login.blade.php       --}}
{{-- Changed: 28-02-2026 02:40 (Europe/Berlin)                                 --}}
{{-- Version: 0.4                                                              --}}
{{-- Purpose: Login view (status banner + email-not-verified warning with resend) --}}
{{-- ========================================================================= --}}

<x-guest-layout>
    <!-- Session Status (BLEIBT) -->
    <x-auth-session-status class="mb-4" :status="session('status')" />

    @if (session('maintenance_login_blocked'))
        <div class="mb-4 rounded-md border border-red-300 bg-red-50 p-4 text-sm text-red-800">
            <div class="font-medium text-center">
                Wartungsmodus aktiv
            </div>
            <div class="mt-1 text-center">
                {{ $errors->first('email') }}
            </div>
        </div>
    @endif

    @if (session('email_not_verified'))
        <div class="mb-4 rounded-md border border-yellow-300 bg-yellow-50 p-4 text-sm text-yellow-800">
            <div class="font-medium text-center">
                {{ __('auth.registered.email_not_verified_title') }}
            </div>

            <div class="mt-1">
                <p class="text-center">
                    {{ __('auth.registered.email_not_verified_text') }}
                </p>
            </div>

            @if (Route::has('verification.send.guest'))
                <form
                    method="POST"
                    action="{{ route('verification.send.guest') }}"
                    class="mt-3 flex justify-center"
                    autocomplete="off"
                >
                    @csrf
                    <input type="hidden" name="email" value="{{ old('email') }}">
                    <button type="submit" class="underline text-sm text-yellow-900 hover:text-yellow-700">
                        {{ __('auth.registered.resend_verification_email') }}
                    </button>
                </form>
            @endif
        </div>
    @else
        <form method="POST" action="{{ route('login') }}">
            @csrf

            {{-- Autofill-Fänger (Browser füllt gern hier rein statt in echte Felder) --}}
            <input type="text" name="fake_username" autocomplete="username" class="hidden">
            <input type="password" name="fake_password" autocomplete="current-password" class="hidden">

            <!-- Benutzername / E-Mail -->
            <div>
                <x-input-label for="email" value="Benutzername / E-Mail" />
                <x-text-input
                    id="email"
                    class="block mt-1 w-full"
                    type="text"
                    name="email"
                    :value="old('email')"
                    required
                    autofocus
                    autocomplete="username"
                    autocapitalize="none"
                    spellcheck="false"
                />

                @if (!session('maintenance_login_blocked'))
                    <x-input-error :messages="$errors->get('email')" class="mt-2" />
                @endif
            </div>

            <!-- Password -->
            <div class="mt-4">
                <x-input-label for="password" :value="__('Password')" />

                <div class="mt-1 flex">
                    <x-text-input
                        id="password"
                        class="block w-full rounded-r-none"
                        type="password"
                        name="password"
                        required
                        autocomplete="current-password"
                        autocapitalize="none"
                        spellcheck="false"
                    />

                    <button
                        type="button"
                        class="inline-flex items-center px-3 border border-l-0 rounded-l-none text-gray-600"
                        data-ks-toggle-password="1"
                        data-ks-target="password"
                        aria-controls="password"
                        aria-label="Toggle password visibility"
                    >
                        🔒
                    </button>
                </div>

                <x-input-error :messages="$errors->get('password')" class="mt-2" />
            </div>

            <!-- Remember Me -->
            <div class="block mt-4">
                <label for="remember_me" class="inline-flex items-center">
                    <input
                        id="remember_me"
                        type="checkbox"
                        class="rounded border-gray-300 text-indigo-600 shadow-sm focus:ring-indigo-500"
                        name="remember"
                    >
                    <span class="ms-2 text-sm text-gray-600">{{ __('Remember me') }}</span>
                </label>
            </div>

            <div class="flex items-center justify-end mt-4">
                @if (Route::has('password.request'))
                    <a
                        class="underline text-sm text-gray-600 hover:text-gray-900 rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                        href="{{ route('password.request') }}"
                    >
                        {{ __('Forgot your password?') }}
                    </a>
                @endif

                <x-primary-button class="ms-3">
                    {{ __('Log in') }}
                </x-primary-button>
            </div>
        </form>
    @endif
</x-guest-layout>