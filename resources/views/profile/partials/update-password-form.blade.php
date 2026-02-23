{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\profile\partials\update-password-form.blade.php
Purpose: Profile – Update password form (Breeze) + no inline scripts
Changed: 23-02-2026 23:45 (Europe/Berlin)
Version: 0.4
============================================================================ --}}

<section>
    <header>
        <h2 class="text-lg font-medium text-gray-900">
            {{ __('Update Password') }}
        </h2>

        <p class="mt-1 text-sm text-gray-600">
            {{ __('Ensure your account is using a long, random password to stay secure.') }}
        </p>
    </header>

    <form
        method="post"
        action="{{ route('password.update') }}"
        class="mt-6 space-y-6"
        autocomplete="off"
        data-ks-profile-update-password="1"
    >
        @csrf
        @method('put')

        {{-- Autofill-Fänger (wie im Register) --}}
        <input type="text" name="username" autocomplete="username" class="hidden">
        <input type="password" name="password_fake" autocomplete="current-password" class="hidden">

        <!-- Derzeitiges Passwort -->
        <div class="mt-4">
            <x-input-label for="update_password_current_password" value="Derzeitiges Passwort" />

            <div class="mt-1 flex">
                <x-text-input
                    id="update_password_current_password"
                    class="block w-full rounded-r-none"
                    type="password"
                    name="current_password"
                    required
                    autocomplete="new-password"
                />

                <button
                    type="button"
                    class="inline-flex items-center px-3 border border-l-0 rounded-l-none text-gray-600"
                    aria-label="Passwort anzeigen oder verbergen"
                    data-ks-toggle-password="1"
                    data-ks-target="update_password_current_password"
                    aria-controls="update_password_current_password"
                    data-ks-lock-unlock="1"
                >
                    🔒
                </button>
            </div>

            <x-input-error :messages="$errors->updatePassword->get('current_password')" class="mt-2" />
        </div>

        <!-- Neues Passwort -->
        <div class="mt-4">
            <x-input-label for="update_password_password" value="Neues Passwort" />

            <div class="mt-1 flex">
                <x-text-input
                    id="update_password_password"
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
                    data-ks-target="update_password_password"
                    aria-controls="update_password_password"
                    data-ks-lock-unlock="1"
                >
                    🔒
                </button>
            </div>

            <x-input-error :messages="$errors->updatePassword->get('password')" class="mt-2" />
        </div>

        <!-- Passwort bestätigen -->
        <div class="mt-4">
            <x-input-label for="update_password_password_confirmation" value="Passwort bestätigen" />

            <div class="mt-1 flex">
                <x-text-input
                    id="update_password_password_confirmation"
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
                    data-ks-target="update_password_password_confirmation"
                    aria-controls="update_password_password_confirmation"
                    data-ks-lock-unlock="1"
                >
                    🔒
                </button>
            </div>

            <x-input-error :messages="$errors->updatePassword->get('password_confirmation')" class="mt-2" />
        </div>

        <div class="flex items-center gap-4">
            <x-primary-button>{{ __('Save') }}</x-primary-button>

            @if (session('status') === 'password-updated')
                <p
                    x-data="{ show: true }"
                    x-show="show"
                    x-transition
                    x-init="setTimeout(() => show = false, 2000)"
                    class="text-sm text-gray-600"
                >
                    {{ __('Saved.') }}
                </p>
            @endif
        </div>
    </form>
</section>