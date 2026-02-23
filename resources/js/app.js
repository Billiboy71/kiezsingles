// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\js\app.js
// Purpose: Frontend JS entry (public/site) – keep admin-only logic out
// Changed: 23-02-2026 22:08 (Europe/Berlin)
// Version: 0.9
// ============================================================================

import './bootstrap';

import Alpine from 'alpinejs';

window.Alpine = Alpine;

Alpine.start();

/**
 * Frontend page initializers (guarded by DOM presence).
 * No side-effects on other pages.
 */

function initRegisterPostcodes() {
    const districtEl = document.getElementById('district');
    const postcodeEl = document.getElementById('postcode');
    if (!districtEl || !postcodeEl) return;

    const ds = postcodeEl.dataset || {};
    const postcodeRequired = ds.postcodeRequired === '1' || ds.postcodeRequired === 'true';

    const oldDistrict = ds.oldDistrict || '';
    const oldPostcode = ds.oldPostcode || '';
    const urlTemplate = ds.postcodesUrlTemplate || '';

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

        postcodes.forEach((pc) => {
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

        if (!urlTemplate) {
            reset('Fehler beim Laden…');
            return;
        }

        const url = urlTemplate.replace('___D___', encodeURIComponent(district));

        let res;
        try {
            res = await fetch(url, { headers: { 'Accept': 'application/json' } });
        } catch (e) {
            reset('Fehler beim Laden…');
            return;
        }

        if (!res.ok) {
            reset('Fehler beim Laden…');
            return;
        }

        let data;
        try {
            data = await res.json();
        } catch (e) {
            reset('Fehler beim Laden…');
            return;
        }

        setOptions(data.postcodes ?? [], selected);
    };

    districtEl.addEventListener('change', () => {
        loadPostcodes(districtEl.value, null);
    });

    const initialDistrict = oldDistrict || districtEl.value || '';
    const initialPostcode = oldPostcode || postcodeEl.value || '';

    if (initialDistrict) {
        districtEl.value = initialDistrict;
        loadPostcodes(initialDistrict, initialPostcode || null);
    } else {
        reset('Bitte zuerst Stadtbezirk wählen…');
    }
}

function initRegisterPasswordRules() {
    const pw = document.getElementById('password');
    const rulesList = document.getElementById('password-rules');
    if (!pw || !rulesList) return;

    const rules = {
        length: (v) => v.length >= 10,
        upper: (v) => /[A-Z]/.test(v),
        lower: (v) => /[a-z]/.test(v),
        number: (v) => /[0-9]/.test(v),
        special: (v) => /[^A-Za-z0-9]/.test(v),
    };

    const update = () => {
        const v = pw.value ?? '';

        rulesList.querySelectorAll('li[data-rule]').forEach((li) => {
            const rule = li.getAttribute('data-rule');
            const ok = rules[rule] ? rules[rule](v) : false;

            li.classList.toggle('text-green-600', ok);
            li.classList.toggle('text-red-600', !ok);

            const text = li.textContent.replace(/^✅\s|^⛔\s/, '');
            li.textContent = (ok ? '✅ ' : '⛔ ') + text;
        });
    };

    pw.addEventListener('input', update);
    update();
}

function initRegisterEmailHint() {
    const email = document.querySelector('input[name="email"]');
    const hint = document.getElementById('emailHint');
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
    check();
}

function initRegisterAgeHint() {
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
}

function initResetPasswordForm() {
    const form = document.querySelector('form[data-ks-reset="1"]');
    if (!form) return;

    const pw = document.getElementById('password');
    const pw2 = document.getElementById('password_confirmation');
    const rulesList = document.getElementById('password-rules');
    const matchEl = document.getElementById('pw-match');
    const btn = document.getElementById('resetBtn');

    if (!pw || !pw2 || !rulesList || !matchEl || !btn) return;

    const captchaEnabled = (form.dataset.captchaEnabled || '') === '1';
    let captchaOk = captchaEnabled ? false : true;

    window.__ksOnTurnstile = function __ksOnTurnstile(ok) {
        captchaOk = !!ok;
        update();
    };

    const rules = {
        length: (v) => v.length >= 10,
        upper: (v) => /[A-Z]/.test(v),
        lower: (v) => /[a-z]/.test(v),
        number: (v) => /[0-9]/.test(v),
        special: (v) => /[^A-Za-z0-9]/.test(v),
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

        rulesList.querySelectorAll('li[data-rule]').forEach((li) => {
            const rule = li.getAttribute('data-rule');
            const ok = rules[rule] ? rules[rule](v) : false;

            li.classList.toggle('text-green-600', ok);
            li.classList.toggle('text-red-600', !ok);

            const text = li.textContent.replace(/^✅\s|^❌\s/, '');
            li.textContent = (ok ? '✅ ' : '❌ ') + text;
        });

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
}

function initVerifyEmailResend() {
    const form = document.querySelector('form[data-ks-verify="1"]');
    if (!form) return;

    const btn = document.getElementById('verifyResendBtn');
    if (!btn) return;

    const captchaEnabled = (form.dataset.captchaEnabled || '') === '1';
    let captchaOk = captchaEnabled ? false : true;

    window.__ksOnTurnstile = function __ksOnTurnstile(ok) {
        captchaOk = !!ok;
        update();
    };

    const update = () => {
        if (!captchaEnabled) {
            btn.disabled = false;
            btn.classList.remove('opacity-50', 'cursor-not-allowed');
            return;
        }

        const disabled = !captchaOk;
        btn.disabled = disabled;
        btn.classList.toggle('opacity-50', disabled);
        btn.classList.toggle('cursor-not-allowed', disabled);
    };

    update();
}

function initContactForm() {
    const form = document.querySelector('form[data-ks-contact="1"]');
    if (!form) return;

    const btn = document.getElementById('contactBtn');
    if (!btn) return;

    const captchaEnabled = (form.dataset.captchaEnabled || '') === '1';
    let captchaOk = captchaEnabled ? false : true;

    window.__ksOnTurnstile = function __ksOnTurnstile(ok) {
        captchaOk = !!ok;
        update();
    };

    const update = () => {
        if (!captchaEnabled) {
            btn.disabled = false;
            btn.classList.remove('opacity-50', 'cursor-not-allowed');
            return;
        }

        const disabled = !captchaOk;
        btn.disabled = disabled;
        btn.classList.toggle('opacity-50', disabled);
        btn.classList.toggle('cursor-not-allowed', disabled);
    };

    update();
}

function initProfileUpdatePasswordForm() {
    const form = document.querySelector('form[data-ks-profile-update-password="1"]');
    if (!form) return;

    // Vorbefüllen hart entfernen (Safari/Password-Manager)
    [
        'update_password_current_password',
        'update_password_password',
        'update_password_password_confirmation',
    ].forEach((id) => {
        const el = document.getElementById(id);
        if (el) el.value = '';
    });
}

function initProfileDeleteUserModal() {
    const form = document.querySelector('form[data-ks-profile-delete-user="1"][data-ks-modal-name]');
    if (!form) return;

    const modalName = form.dataset.ksModalName || '';
    if (!modalName) return;

    document.addEventListener('open-modal', (e) => {
        if (e.detail !== modalName) return;

        const input = document.getElementById('delete_user_password');
        if (!input) return;

        input.type = 'password';
        input.value = '';

        const btn = input.parentElement
            ? input.parentElement.querySelector('button[data-ks-lock-unlock="1"]')
            : null;
        if (btn) btn.textContent = '🔒';
    });
}

function initNoteinstiegEntryCountdown() {
    const el = document.getElementById('bg_countdown');
    if (!el) return;

    // Avoid double-init (e.g. if an old inline script still exists)
    if (el.dataset && el.dataset.ksCountdownInit === '1') return;
    if (el.dataset) el.dataset.ksCountdownInit = '1';

    let remaining = 0;

    if (el.dataset && typeof el.dataset.remainingSeconds === 'string' && el.dataset.remainingSeconds !== '') {
        const n = parseInt(el.dataset.remainingSeconds, 10);
        remaining = Number.isFinite(n) ? n : 0;
    } else if (typeof window.__ksNoteinstiegRemainingSeconds === 'number') {
        remaining = window.__ksNoteinstiegRemainingSeconds;
    } else {
        // No source for remaining seconds -> do nothing (keeps separation; view can later provide dataset)
        return;
    }

    const aLogin = document.getElementById('bg_login');
    const aRegister = document.getElementById('bg_register');
    const aReopen = document.getElementById('bg_reopen');

    const pad2 = (n) => String(n).padStart(2, '0');

    const render = () => {
        const sec = Math.max(0, remaining);
        const m = Math.floor(sec / 60);
        const s = sec % 60;

        el.textContent = pad2(m) + ':' + pad2(s);

        if (sec <= 0) {
            if (aLogin) aLogin.setAttribute('aria-disabled', 'true');
            if (aRegister) aRegister.setAttribute('aria-disabled', 'true');
            if (aReopen) aReopen.setAttribute('aria-disabled', 'true');
        }
    };

    render();

    const t = window.setInterval(() => {
        remaining -= 1;
        render();

        if (remaining <= 0) {
            window.clearInterval(t);
        }
    }, 1000);
}

function initNoteinstiegShowOtp() {
    const form = document.querySelector('form[data-ks-noteinstieg-form="1"]');
    if (!form) return;

    // Avoid double-init
    if (form.dataset && form.dataset.ksInit === '1') return;
    if (form.dataset) form.dataset.ksInit = '1';

    const wrap = document.getElementById('bg_otp');
    const hidden = document.getElementById('totp');
    const btn = document.getElementById('bg_submit');
    if (!wrap || !hidden || !btn) return;

    const inputs = Array.from(wrap.querySelectorAll('input[data-idx]'));
    if (inputs.length !== 6) return;

    const recovery = form.querySelector('input[name="recovery_code"]');

    const onlyDigit = (v) => (v || '').toString().replace(/\D+/g, '');

    const updateHiddenAndMaybeSubmit = () => {
        const code = inputs.map((i) => onlyDigit(i.value).slice(0, 1)).join('');
        hidden.value = code;

        const recoveryFilled = recovery ? (String(recovery.value || '').trim() !== '') : false;

        if (!recoveryFilled && code.length === 6) {
            // Auto-Submit sobald vollständig (nur wenn kein Notfallcode gesetzt ist)
            form.requestSubmit();
        }
    };

    const setFromString = (s) => {
        const digits = onlyDigit(s).slice(0, 6).split('');
        for (let i = 0; i < 6; i++) {
            inputs[i].value = digits[i] || '';
        }
        updateHiddenAndMaybeSubmit();
    };

    inputs.forEach((inp, idx) => {
        inp.addEventListener('input', () => {
            const d = onlyDigit(inp.value);
            if (d.length > 1) {
                // z.B. Paste in ein Feld
                setFromString(d);
                return;
            }

            inp.value = d.slice(0, 1);

            if (inp.value !== '' && idx < 5) {
                inputs[idx + 1].focus();
                inputs[idx + 1].select();
            }

            updateHiddenAndMaybeSubmit();
        });

        inp.addEventListener('keydown', (e) => {
            if (e.key === 'Backspace') {
                if (inp.value === '' && idx > 0) {
                    inputs[idx - 1].focus();
                    inputs[idx - 1].select();
                }
                return;
            }

            if (e.key === 'ArrowLeft' && idx > 0) {
                e.preventDefault();
                inputs[idx - 1].focus();
                inputs[idx - 1].select();
                return;
            }

            if (e.key === 'ArrowRight' && idx < 5) {
                e.preventDefault();
                inputs[idx + 1].focus();
                inputs[idx + 1].select();
                return;
            }
        });

        inp.addEventListener('paste', (e) => {
            e.preventDefault();
            const t = (e.clipboardData || window.clipboardData).getData('text');
            setFromString(t);
        });

        inp.addEventListener('focus', () => {
            inp.select();
        });
    });

    // Wenn Recovery-Code getippt wird, soll TOTP nicht mehr auto-submitted werden,
    // aber hidden darf (harmlos) weiter gepflegt werden.
    if (recovery) {
        recovery.addEventListener('input', () => {
            // sobald Recovery gefüllt wird: OTP nicht löschen (keine Nebenwirkungen),
            // aber hidden sauber halten
            updateHiddenAndMaybeSubmit();
        });
    }

    // Initial state
    updateHiddenAndMaybeSubmit();

    // Initial focus
    inputs[0].focus();
    inputs[0].select();
}

/**
 * Kept global to preserve existing markup usage (onclick="togglePassword(...)").
 */
window.togglePassword = function togglePassword(inputId, btn) {
    const input = document.getElementById(inputId);
    if (!input) return;

    const isHidden = input.type === 'password';
    input.type = isHidden ? 'text' : 'password';

    if (btn) {
        const lockUnlock = (btn.dataset && btn.dataset.ksLockUnlock === '1') || false;
        btn.textContent = lockUnlock
            ? (isHidden ? '🔓' : '🔒')
            : (isHidden ? '👁️' : '🔒');
    }

    if (typeof window.__updateResetBtn === 'function') {
        window.__updateResetBtn();
    }
};

/**
 * Turnstile callbacks referenced by data-callback attributes.
 * Keep contract:
 * - store token in #cf-turnstile-response (if present)
 * - notify per-page hooks
 */
window.onTurnstileSuccess = function onTurnstileSuccess(token) {
    const el = document.getElementById('cf-turnstile-response');
    if (el) el.value = token || '';

    if (typeof window.__ksOnTurnstile === 'function') window.__ksOnTurnstile(true);

    if (typeof window.__updateRegisterBtn === 'function') window.__updateRegisterBtn();
    if (typeof window.__updateResetBtn === 'function') window.__updateResetBtn();
};

window.onTurnstileExpired = function onTurnstileExpired() {
    const el = document.getElementById('cf-turnstile-response');
    if (el) el.value = '';

    if (typeof window.__ksOnTurnstile === 'function') window.__ksOnTurnstile(false);

    if (typeof window.__updateRegisterBtn === 'function') window.__updateRegisterBtn();
    if (typeof window.__updateResetBtn === 'function') window.__updateResetBtn();
};

window.onTurnstileError = function onTurnstileError() {
    const el = document.getElementById('cf-turnstile-response');
    if (el) el.value = '';

    if (typeof window.__ksOnTurnstile === 'function') window.__ksOnTurnstile(false);

    if (typeof window.__updateRegisterBtn === 'function') window.__updateRegisterBtn();
    if (typeof window.__updateResetBtn === 'function') window.__updateResetBtn();
};

document.addEventListener('DOMContentLoaded', () => {
    initRegisterPostcodes();
    initRegisterPasswordRules();
    initRegisterEmailHint();
    initRegisterAgeHint();
    initResetPasswordForm();
    initVerifyEmailResend();
    initContactForm();
    initProfileUpdatePasswordForm();
    initProfileDeleteUserModal();
    initNoteinstiegEntryCountdown();
    initNoteinstiegShowOtp();
});