{{-- resources/views/auth/reset-password.blade.php --}}

<x-guest-layout>
    <form method="POST" action="{{ route('password.store') }}">
        @csrf

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
                :value="old('email', $request->email)"
                required
                autofocus
                autocomplete="username"
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
                    onclick="togglePassword('password', this)"
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
                    onclick="togglePassword('password_confirmation', this)"
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

        <script>
            function togglePassword(inputId, btn) {
                const input = document.getElementById(inputId);
                if (!input) return;

                const isHidden = input.type === 'password';
                input.type = isHidden ? 'text' : 'password';

                btn.textContent = isHidden ? '👁️' : '🔒';

                if (typeof window.__updateResetBtn === 'function') {
                    window.__updateResetBtn();
                }
            }

            (() => {
                const pw = document.getElementById('password');
                const pw2 = document.getElementById('password_confirmation');
                const rulesList = document.getElementById('password-rules');
                const matchEl = document.getElementById('pw-match');
                const btn = document.getElementById('resetBtn');

                if (!pw || !pw2 || !rulesList || !matchEl || !btn) return;

                const captchaEnabled = @json((bool) (config('captcha.enabled') && config('captcha.on_reset')));
                let captchaOk = captchaEnabled ? false : true;

                // Turnstile callbacks (nur wenn enabled)
                window.onTurnstileSuccess = function () { captchaOk = true;  update(); };
                window.onTurnstileExpired = function () { captchaOk = false; update(); };
                window.onTurnstileError   = function () { captchaOk = false; update(); };

                const rules = {
                    length:  v => v.length >= 10,
                    upper:   v => /[A-Z]/.test(v),
                    lower:   v => /[a-z]/.test(v),
                    number:  v => /[0-9]/.test(v),
                    special: v => /[^A-Za-z0-9]/.test(v),
                };

                const passwordRulesOk = (v) => {
                    return rules.length(v)
                        && rules.upper(v)
                        && rules.lower(v)
                        && rules.number(v)
                        && rules.special(v);
                };

                const setDisabled = (disabled) => {
                    btn.disabled = disabled;
                    btn.classList.toggle('opacity-50', disabled);
                    btn.classList.toggle('cursor-not-allowed', disabled);
                };

                const update = () => {
                    const v = pw.value ?? '';
                    const v2 = pw2.value ?? '';

                    // Regeln rot/grün
                    rulesList.querySelectorAll('li[data-rule]').forEach(li => {
                        const rule = li.getAttribute('data-rule');
                        const ok = rules[rule] ? rules[rule](v) : false;

                        li.classList.toggle('text-green-600', ok);
                        li.classList.toggle('text-red-600', !ok);

                        const text = li.textContent.replace(/^✅\s|^❌\s/, '');
                        li.textContent = (ok ? '✅ ' : '❌ ') + text;
                    });

                    // Match-Check
                    const match = v.length > 0 && v === v2;
                    matchEl.classList.toggle('text-green-600', match);
                    matchEl.classList.toggle('text-red-600', !match);
                    matchEl.textContent = match
                        ? '✅ Passwörter stimmen überein'
                        : '❌ Passwörter stimmen nicht überein';

                    const okAll = passwordRulesOk(v) && match && captchaOk;
                    setDisabled(!okAll);
                };

                window.__updateResetBtn = update;

                pw.addEventListener('input', update);
                pw2.addEventListener('input', update);

                setTimeout(update, 0);
            })();
        </script>
    </form>
</x-guest-layout>
