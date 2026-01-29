<section>
    <header>
        <h2 class="text-lg font-medium text-gray-900">
            {{ __('Update Password') }}
        </h2>

        <p class="mt-1 text-sm text-gray-600">
            {{ __('Ensure your account is using a long, random password to stay secure.') }}
        </p>
    </header>

    <form method="post" action="{{ route('password.update') }}" class="mt-6 space-y-6" autocomplete="off">
        @csrf
        @method('put')

        {{-- Autofill-Fänger (wie im Register) --}}
        <input type="text" name="username" autocomplete="username" style="display:none">
        <input type="password" name="password_fake" autocomplete="current-password" style="display:none">

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
                    onclick="togglePassword('update_password_current_password', this)"
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
                    onclick="togglePassword('update_password_password', this)"
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
                    onclick="togglePassword('update_password_password_confirmation', this)"
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

    <script>
        // 🔒 ↔ 🔓 (kein Auge)
        function togglePassword(inputId, button) {
            const input = document.getElementById(inputId);
            if (!input) return;

            const isHidden = input.type === 'password';
            input.type = isHidden ? 'text' : 'password';
            button.textContent = isHidden ? '🔓' : '🔒';
        }

        // Vorbefüllen hart entfernen (Safari/Password-Manager)
        document.addEventListener('DOMContentLoaded', () => {
            [
                'update_password_current_password',
                'update_password_password',
                'update_password_password_confirmation'
            ].forEach(id => {
                const el = document.getElementById(id);
                if (el) el.value = '';
            });
        });
    </script>
</section>
