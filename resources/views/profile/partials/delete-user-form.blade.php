<section class="space-y-6">
    <header>
        <h2 class="text-lg font-medium text-gray-900">
            {{ __('Delete Account') }}
        </h2>

        <p class="mt-1 text-sm text-gray-600">
            {{ __('Once your account is deleted, all of its resources and data will be permanently deleted. Before deleting your account, please download any data or information that you wish to retain.') }}
        </p>
    </header>

    <x-danger-button
        x-data=""
        x-on:click.prevent="$dispatch('open-modal', 'confirm-user-deletion')"
    >{{ __('Delete Account') }}</x-danger-button>

    <x-modal name="confirm-user-deletion" :show="$errors->userDeletion->isNotEmpty()" focusable>
        <form method="post" action="{{ route('profile.destroy') }}" class="p-6" autocomplete="off">
            @csrf
            @method('delete')

            {{-- Autofill-Fänger (verhindert Safari/Password-Manager im Modal) --}}
            <input type="text" name="username" autocomplete="username" style="display:none">
            <input type="password" name="password_fake" autocomplete="current-password" style="display:none">

            <h2 class="text-lg font-medium text-gray-900">
                {{ __('Are you sure you want to delete your account?') }}
            </h2>

            <p class="mt-1 text-sm text-gray-600">
                {{ __('Once your account is deleted, all of its resources and data will be permanently deleted. Please enter your password to confirm you would like to permanently delete your account.') }}
            </p>

            <div class="mt-6">
                <x-input-label for="delete_user_password" :value="__('Password')" class="sr-only" />

                {{-- Passwort + Schloss-Toggle (🔒/🔓) --}}
                <div class="mt-1 flex">
                    <x-text-input
                        id="delete_user_password"
                        name="password"
                        type="password"
                        class="block w-full rounded-r-none"
                        placeholder="{{ __('Password') }}"
                        autocomplete="new-password"
                    />

                    <button
                        type="button"
                        class="inline-flex items-center px-3 border border-l-0 rounded-l-none text-gray-600"
                        aria-label="Passwort anzeigen oder verbergen"
                        onclick="togglePassword('delete_user_password', this)"
                    >
                        🔒
                    </button>
                </div>

                <x-input-error :messages="$errors->userDeletion->get('password')" class="mt-2" />
            </div>

            <div class="mt-6 flex justify-end">
                <x-secondary-button x-on:click="$dispatch('close')">
                    {{ __('Cancel') }}
                </x-secondary-button>

                <x-danger-button class="ms-3">
                    {{ __('Delete Account') }}
                </x-danger-button>
            </div>
        </form>
    </x-modal>

    <script>
        // togglePassword (falls noch nicht global vorhanden): 🔒 ↔ 🔓
        if (typeof window.togglePassword !== 'function') {
            window.togglePassword = function (inputId, button) {
                const input = document.getElementById(inputId);
                if (!input) return;

                const isHidden = input.type === 'password';
                input.type = isHidden ? 'text' : 'password';
                if (button) button.textContent = isHidden ? '🔓' : '🔒';
            };
        }

        // Modal-Reset: Safari füllt manchmal NACH dem Öffnen -> deshalb hier hart leeren
        document.addEventListener('open-modal', (e) => {
            if (e.detail !== 'confirm-user-deletion') return;

            const input = document.getElementById('delete_user_password');
            if (!input) return;

            // zurück auf "versteckt" + leer
            input.type = 'password';
            input.value = '';

            // Button wieder auf Schloss zu setzen
            const btn = input.parentElement?.querySelector('button[onclick*="delete_user_password"]');
            if (btn) btn.textContent = '🔒';
        });
    </script>
</section>
