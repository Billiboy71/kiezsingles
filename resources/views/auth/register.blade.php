{{-- ========================================================================= --}}
{{-- File: C:\laragon\www\kiezsingles\resources\views\auth\register.blade.php       --}}
{{-- Purpose: Login view (status banner + email-not-verified warning with resend) --}}
{{-- ========================================================================= --}}
<x-guest-layout>
    {{-- DEBUG: Server Validation Errors --}}
    @if (config('app.debug_register_errors') && $errors->any())
        <div style="background:#fee;border:1px solid #c00;padding:10px;margin:10px 0">
            <strong>DEBUG – Server Validation Errors:</strong>
            <ul style="margin:8px 0 0 16px">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </div>
    @endif

    {{-- DEBUG: Register Payload (sichtbar) --}}
    @if (config('app.debug_register_payload') && session()->has('debug_register_payload'))
        <pre class="mt-4 text-xs bg-gray-100 p-2 rounded overflow-auto">
{{ json_encode(session('debug_register_payload'), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}
        </pre>
    @endif

    @php
        $captchaEnabled = (bool) (config('captcha.enabled') && config('captcha.on_register'));
        $turnstileSiteKey = (string) config('captcha.site_key');
    @endphp

    {{-- Turnstile Script --}}
    @if ($captchaEnabled && $turnstileSiteKey !== '')
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>

        @if (config('captcha.debug'))
            <div class="mt-2 text-xs text-gray-500">
                DEBUG Turnstile: enabled |
                site_key_len={{ strlen($turnstileSiteKey) }} |
                host={{ request()->getHost() }}
            </div>
        @endif
    @endif

    <form method="POST" action="{{ route('register') }}" autocomplete="off">
        @csrf

        {{-- Autofill-Fänger --}}
        <input type="text" name="username" autocomplete="username" style="display:none">
        <input type="password" name="password_fake" autocomplete="current-password" style="display:none">

        <!-- Ich bin / Ich suche -->
        <div class="mt-4">
            <x-input-label for="match_type" value="Ich bin / ich suche" />

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
            <x-input-label for="nickname" value="Pseudonym (4–14 Zeichen)" />
            <x-text-input
                id="nickname"
                class="block mt-1 w-full"
                type="text"
                name="nickname"
                value="{{ old('nickname') }}"
                required
                minlength="4"
                maxlength="14"
            />
            <x-input-error :messages="$errors->get('nickname')" class="mt-2" />
        </div>

  

<div class="mt-4" style="display:flex; gap:12px; align-items:flex-end;">
    <!-- Geburtsdatum -->
    <div style="flex:1 1 0;">
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
    <div style="flex:1 1 0; white-space:nowrap;">
    <!-- Spacer statt "Alter"-Überschrift (damit die Zeile auf Input-Höhe sitzt) -->
    <div style="height:20px;"></div>

    <!-- Zeile mittig auf der Höhe des Date-Inputs -->
    <div style="height:42px; display:flex; align-items:center; font-size:18px; color:#4b5563; padding-left:10px;">
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
                class="ms-4 opacity-50 cursor-not-allowed"
                disabled
            >
                {{ __('Register') }}
            </x-primary-button>
        </div>

        {{-- JS: Postcodes nach District nachladen --}}
        @if (config('features.postcode.enabled'))
            <script>
                (() => {
                    const districtEl = document.getElementById('district');
                    const postcodeEl = document.getElementById('postcode');
                    if (!districtEl || !postcodeEl) return;

                    const postcodeRequired = @json((bool) config('features.postcode.required'));
                    const oldDistrict = @json(old('district'));
                    const oldPostcode = @json(old('postcode'));

                    const pingBtnUpdate = () => {
                        if (typeof window.__updateRegisterBtn === 'function') {
                            window.__updateRegisterBtn();
                        }
                    };

                    const reset = (text) => {
                        postcodeEl.innerHTML = '';
                        const opt = document.createElement('option');
                        opt.value = '';
                        opt.textContent = text;
                        postcodeEl.appendChild(opt);
                        postcodeEl.disabled = true;
                        pingBtnUpdate();
                    };

                    const setOptions = (postcodes, selected = null) => {
                        postcodeEl.innerHTML = '';

                        const first = document.createElement('option');
                        first.value = '';
                        first.textContent = 'Bitte wählen…';
                        postcodeEl.appendChild(first);

                        postcodes.forEach(pc => {
                            const opt = document.createElement('option');
                            opt.value = pc;
                            opt.textContent = pc;
                            if (selected && selected === pc) opt.selected = true;
                            postcodeEl.appendChild(opt);
                        });

                        postcodeEl.disabled = postcodes.length === 0;
                        if (postcodeRequired && !postcodeEl.disabled) postcodeEl.required = true;

                        pingBtnUpdate();
                    };

                    const loadPostcodes = async (district, selected = null) => {
                        if (!district) {
                            reset('Bitte zuerst Stadtbezirk wählen…');
                            return;
                        }

                        reset('Lade…');

                        const url = `{{ route('district.postcodes', ['district' => '___D___']) }}`
                            .replace('___D___', encodeURIComponent(district));

                        const res = await fetch(url, { headers: { 'Accept': 'application/json' } });

                        if (!res.ok) {
                            reset('Fehler beim Laden…');
                            return;
                        }

                        const data = await res.json();
                        setOptions(data.postcodes ?? [], selected);
                    };

                    districtEl.addEventListener('change', () => {
                        loadPostcodes(districtEl.value, null);
                    });

                    const initialDistrict = oldDistrict || districtEl.value || null;
                    const initialPostcode = oldPostcode || postcodeEl.value || null;

                    if (initialDistrict) {
                        districtEl.value = initialDistrict;
                        loadPostcodes(initialDistrict, initialPostcode);
                    } else {
                        reset('Bitte zuerst Stadtbezirk wählen…');
                    }
                })();
            </script>
        @endif

        {{-- JS: Passwort anzeigen/verbergen --}}
        <script>
            function togglePassword(inputId, btn) {
                const input = document.getElementById(inputId);
                if (!input) return;

                const isHidden = input.type === 'password';
                input.type = isHidden ? 'text' : 'password';
                btn.textContent = isHidden ? '👁️' : '🔒';

                if (typeof window.__updateRegisterBtn === 'function') {
                    window.__updateRegisterBtn();
                }
            }
        </script>

        {{-- JS: Passwort-Regeln rot/grün --}}
        <script>
            (() => {
                const pw = document.getElementById('password');
                const rulesList = document.getElementById('password-rules');
                if (!pw || !rulesList) return;

                const rules = {
                    length:  v => v.length >= 10,
                    upper:   v => /[A-Z]/.test(v),
                    lower:   v => /[a-z]/.test(v),
                    number:  v => /[0-9]/.test(v),
                    special: v => /[^A-Za-z0-9]/.test(v),
                };

                const update = () => {
                    const v = pw.value ?? '';

                    rulesList.querySelectorAll('li[data-rule]').forEach(li => {
                        const rule = li.getAttribute('data-rule');
                        const ok = rules[rule] ? rules[rule](v) : false;

                        li.classList.toggle('text-green-600', ok);
                        li.classList.toggle('text-red-600', !ok);

                        const text = li.textContent.replace(/^✅\s|^❌\s/, '');
                        li.textContent = (ok ? '✅ ' : '❌ ') + text;
                    });

                    if (typeof window.__updateRegisterBtn === 'function') {
                        window.__updateRegisterBtn();
                    }
                };

                pw.addEventListener('input', update);
                update();
            })();
        </script>

        {{-- JS: Register-Button erst aktiv wenn alles valid aussieht --}}
        <script>
            (() => {
                const form = document.querySelector('form[action="{{ route('register') }}"]');
                const btn  = document.getElementById('registerBtn');
                if (!form || !btn) return;

                const el = (id) => document.getElementById(id);

                const requiredIds = [
                    'match_type',
                    'nickname',
                    'birthdate',
                    'district',
                    'email',
                    'password',
                ];

                const postcodeEnabled  = @json((bool) config('features.postcode.enabled'));
                const postcodeRequired = @json((bool) config('features.postcode.required'));

                const captchaEnabled = @json((bool) (config('captcha.enabled') && config('captcha.on_register')));
                let captchaOk = captchaEnabled ? false : true;

                const setCaptchaToken = (token) => {
                    const hidden = document.getElementById('cf-turnstile-response');
                    if (hidden) hidden.value = token || '';
                };

                window.onTurnstileSuccess = function (token) {
                    captchaOk = true;
                    setCaptchaToken(token);
                    updateButton();
                };
                window.onTurnstileExpired = function () {
                    captchaOk = false;
                    setCaptchaToken('');
                    updateButton();
                };
                window.onTurnstileError = function () {
                    captchaOk = false;
                    setCaptchaToken('');
                    updateButton();
                };

                const passwordRulesOk = (v) => {
                    return v.length >= 10
                        && /[A-Z]/.test(v)
                        && /[a-z]/.test(v)
                        && /[0-9]/.test(v)
                        && /[^A-Za-z0-9]/.test(v);
                };

                const isFilled = (node) => {
                    if (!node) return false;
                    if (node.tagName === 'SELECT') return !!node.value;
                    return (node.value ?? '').trim().length > 0;
                };

                const setDisabled = (disabled) => {
                    btn.disabled = disabled;
                    btn.classList.toggle('opacity-50', disabled);
                    btn.classList.toggle('cursor-not-allowed', disabled);
                };

                const updateButton = () => {
                    for (const id of requiredIds) {
                        if (!isFilled(el(id))) return setDisabled(true);
                    }

                    const privacy = form.querySelector('input[name="privacy"]');
                    if (!privacy || !privacy.checked) return setDisabled(true);

                    const pw = el('password')?.value ?? '';
                    if (!passwordRulesOk(pw)) return setDisabled(true);

                    if (postcodeEnabled && postcodeRequired) {
                        const pc = el('postcode');
                        if (!pc || pc.disabled || !pc.value) return setDisabled(true);
                    }

                    if (!captchaOk) return setDisabled(true);

                    setDisabled(false);
                };

                window.__updateRegisterBtn = updateButton;

                form.addEventListener('input', updateButton);
                form.addEventListener('change', updateButton);

                setTimeout(updateButton, 0);
            })();
        </script>

        {{-- JS: Email-Hinweis --}}
        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const email = document.querySelector('input[name="email"]');
                const hint  = document.getElementById('emailHint');

                if (!email || !hint) return;

                const isObviouslyWrong = (v) => {
                    if (!v) return false;
                    if (!v.includes('@')) return true;

                    const parts = v.split('@');
                    if (parts.length !== 2) return true;

                    const domain = parts[1] || '';
                    if (!domain) return true;

                    if (domain.includes(',')) return true;
                    if (!domain.includes('.')) return true;

                    return false;
                };

                const check = () => {
                    hint.classList.toggle('hidden', !isObviouslyWrong(email.value.trim()));
                };

                email.addEventListener('input', check);
                email.addEventListener('blur', check);
            });
        </script>
        {{-- JS: Alter-Hinweis --}}
        <script>
(() => {
    const birthInput = document.getElementById('birthdate');
    const ageLine = document.getElementById('ageLine');
if (!birthInput || !ageLine) return;

    const calcAge = (v) => {
        if (!v) return null;
        const d = new Date(v + 'T00:00:00');
        if (isNaN(d)) return null;

        const t = new Date();
        let a = t.getFullYear() - d.getFullYear();
        const m = t.getMonth() - d.getMonth();
        if (m < 0 || (m === 0 && t.getDate() < d.getDate())) a--;
        return a >= 0 ? a : null;
    };

    const update = () => {
        const age = calcAge(birthInput.value);
        ageLine.textContent = (age === null) ? '' : `Alter: ${age} (stimmt das?)`;
    };

    birthInput.addEventListener('input', update);
    birthInput.addEventListener('change', update);
    update();
})();
</script>

    </form>
</x-guest-layout>
