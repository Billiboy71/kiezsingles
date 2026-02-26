// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\js\admin.js
// Purpose: Admin-only JS (centralized handlers for admin views; no inline scripts)
// Created: 23-02-2026 17:52 (Europe/Berlin)
// Changed: 25-02-2026 23:51 (Europe/Berlin)
// Version: 1.5
// ============================================================================

(function () {
    'use strict';

    function toBool01(checked) {
        return checked ? '1' : '0';
    }

    // ------------------------------------------------------------------------
    // 1) Auto-submit toggle forms (opt-in via data attributes)
    //
    // Expected markup:
    // <form data-ks-toggle-form="1">
    //   <input type="hidden" name="value" value="0|1">
    //   <input type="checkbox" data-ks-toggle="1">
    // </form>
    // ------------------------------------------------------------------------
    document.addEventListener('change', function (e) {
        var target = e.target;
        if (!target) return;

        if (!(target instanceof HTMLInputElement)) return;
        if (target.type !== 'checkbox') return;
        if (target.getAttribute('data-ks-toggle') !== '1') return;

        var form = target.closest('form');
        if (!form) return;
        if (form.getAttribute('data-ks-toggle-form') !== '1') return;

        var valueInput = form.querySelector('input[type="hidden"][name="value"]');
        if (!valueInput) return;

        valueInput.value = toBool01(target.checked);
        try { form.submit(); } catch (err) {}
    });

    // ------------------------------------------------------------------------
    // 2) Moderation UI (admin/moderation)
    // Re-implements the previous inline <script> behavior using existing IDs.
    // ------------------------------------------------------------------------
    (function initModerationUi() {
        var f = document.getElementById('js-select-form');
        var rs = document.getElementById('js-role-select');
        var us = document.getElementById('js-user-select');
        var ls = document.getElementById('js-load-status');

        function submitSelect() {
            if (!f) return;
            if (ls) ls.textContent = 'lädt…';
            try { f.submit(); } catch (err) {}
        }

        if (rs) { rs.addEventListener('change', function () { submitSelect(); }); }
        if (us) { us.addEventListener('change', function () { submitSelect(); }); }

        var sf = document.getElementById('js-sections-form');
        var ss = document.getElementById('js-save-status');
        var t = null;

        function scheduleSave() {
            if (!sf) return;
            if (t) clearTimeout(t);
            if (ss) ss.textContent = 'speichert…';
            t = setTimeout(function () {
                try { sf.submit(); } catch (err) {}
            }, 600);
        }

        if (sf) {
            var boxes = sf.querySelectorAll('.js-section-box');
            for (var i = 0; i < boxes.length; i++) {
                boxes[i].addEventListener('change', function () { scheduleSave(); });
            }
        }
    })();

    // ------------------------------------------------------------------------
    // 3) Admin navigation: force same-tab navigation for admin nav links
    // (extracted from resources/views/admin/layouts/navigation.blade.php)
    // ------------------------------------------------------------------------
    (function initAdminNavigationSameTabGuard() {
        function isModifiedClick(e) {
            return !!(e && (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button === 1));
        }

        document.addEventListener('click', function (e) {
            if (!e || isModifiedClick(e)) return;

            var target = e.target;
            if (!target || !target.closest) return;

            var a = target.closest('[data-ks-admin-nav] a[href]');
            if (!a) return;

            var href = (a.getAttribute('href') || '');
            if (!href || href === '#') return;

            var lower = href.trim().toLowerCase();
            if (lower.indexOf('javascript:') === 0 || lower.indexOf('mailto:') === 0 || lower.indexOf('tel:') === 0) return;

            try {
                var url = new URL(a.href, window.location.href);
                if (url.origin !== window.location.origin) return;
            } catch (err) {
                return;
            }

            e.preventDefault();
            window.location.assign(a.href);
        }, true);
    })();

    // ------------------------------------------------------------------------
    // 4) Maintenance UI (admin/maintenance)
    // Re-implements inline JS behavior using existing IDs & backend routes in data attributes.
    //
    // Required markup:
    // - <input type="hidden" id="ks_csrf" value="...">
    // - <div id="ks_toast">...</div>
    // - <div id="ks_status_wrap" data-ks-has-settings-table="1|0" data-ks-has-system-settings-table="1|0" data-ks-is-prod="1|0"
    //        data-ks-url-settings-save-ajax="..."
    //        data-ks-url-maintenance-eta-ajax="..."
    //        data-ks-url-recovery-list-ajax="..."
    //        data-ks-url-recovery-generate-ajax="...">...</div>
    // - IDs used below must exist (same as in the blade)
    // ------------------------------------------------------------------------
    (function initMaintenanceUi() {
        var statusWrap = document.getElementById('ks_status_wrap');
        if (!statusWrap) return;

        var csrfEl = document.getElementById('ks_csrf');
        var csrf = csrfEl ? (csrfEl.value || '') : '';
        var toast = document.getElementById('ks_toast');

        var hasSettingsTable = (statusWrap.getAttribute('data-ks-has-settings-table') === '1');
        var hasSystemSettingsTable = (statusWrap.getAttribute('data-ks-has-system-settings-table') === '1');
        var isProd = (statusWrap.getAttribute('data-ks-is-prod') === '1');

        var urlSettingsSave = statusWrap.getAttribute('data-ks-url-settings-save-ajax') || '';
        var urlEtaSave = statusWrap.getAttribute('data-ks-url-maintenance-eta-ajax') || '';
        var urlRecoveryList = statusWrap.getAttribute('data-ks-url-recovery-list-ajax') || '';
        var urlRecoveryGenerate = statusWrap.getAttribute('data-ks-url-recovery-generate-ajax') || '';

        var m = document.getElementById('maintenance_enabled');
        var allowAdmins = document.getElementById('maintenance_allow_admins');
        var allowMods = document.getElementById('maintenance_allow_moderators');

        var etaShow = document.getElementById('maintenance_show_eta');
        var etaDate = document.getElementById('maintenance_eta_date');
        var etaTime = document.getElementById('maintenance_eta_time');
        var etaClear = document.getElementById('maintenance_eta_clear');

        var notify = document.getElementById('maintenance_notify_enabled');
        var outlinesFrontend = document.getElementById('layout_outlines_frontend_enabled');
        var outlinesAdmin = document.getElementById('layout_outlines_admin_enabled');
        var outlinesAllowProduction = document.getElementById('layout_outlines_allow_production');

        var sim = document.getElementById('debug_simulate_production'); // can be absent

        var bg = document.getElementById('debug_break_glass');
        var bgSecret = document.getElementById('debug_break_glass_totp_secret');
        var bgTtl = document.getElementById('debug_break_glass_ttl_minutes');

        var bgLinkWrap = document.getElementById('break_glass_link_wrap');
        var bgLink = document.getElementById('break_glass_link');

        var bgQrBtn = document.getElementById('break_glass_qr_btn');
        var bgQrModal = document.getElementById('break_glass_qr_modal');
        var bgQrClose = document.getElementById('break_glass_qr_close');
        var bgQrImg = document.getElementById('break_glass_qr_img');

        var recBtn = document.getElementById('noteinstieg_recovery_btn');
        var genBtn = document.getElementById('noteinstieg_recovery_generate_btn');
        var codesWrap = document.getElementById('noteinstieg_codes');
        var codesList = document.getElementById('noteinstieg_codes_list');
        var printBtn = document.getElementById('noteinstieg_print_btn');
        var localDebugBanner = document.getElementById('ks_local_debug_banner');

        if (!toast || !m || !allowAdmins || !allowMods || !bg || !bgSecret || !bgTtl || !etaShow || !etaDate || !etaTime || !etaClear || !bgLinkWrap || !bgLink || !bgQrBtn || !bgQrModal || !bgQrClose || !bgQrImg || !recBtn || !genBtn || !codesWrap || !codesList || !printBtn || !notify) return;

        if (!urlSettingsSave || !urlEtaSave || !urlRecoveryList || !urlRecoveryGenerate) return;

        var saveTimer = null;
        var saving = false;
        var pendingSaveSettings = false;
        var pendingSaveEta = false;
        var reloadAfterSave = false;

        var codesPollTimer = null;
        var CODES_POLL_MS = 5000;

        function stopCodesPolling() {
            if (codesPollTimer) {
                window.clearInterval(codesPollTimer);
                codesPollTimer = null;
            }
        }

        function startCodesPolling() {
            if (codesPollTimer) return;
            codesPollTimer = window.setInterval(function () {
                loadCodes({ clear: false, toast: false });
            }, CODES_POLL_MS);
        }

        function showToast(msg, isError) {
            if (!toast) return;

            toast.textContent = (msg || '').toString();

            toast.classList.remove('border-green-200', 'bg-green-50', 'border-red-200', 'bg-red-50');
            toast.classList.add(isError ? 'border-red-200' : 'border-green-200');
            toast.classList.add(isError ? 'bg-red-50' : 'bg-green-50');

            toast.classList.remove('hidden');
            window.clearTimeout(toast.__t);
            toast.__t = window.setTimeout(function () {
                toast.classList.add('hidden');
            }, 2000);
        }

        function setStatusBox(maintenanceOn) {
            var on = !!maintenanceOn;
            statusWrap.classList.remove('border-green-200', 'bg-green-50', 'border-red-200', 'bg-red-50');
            statusWrap.classList.add(on ? 'border-red-200' : 'border-green-200');
            statusWrap.classList.add(on ? 'bg-red-50' : 'bg-green-50');
        }

        function closeQrModal() {
            bgQrModal.classList.add('hidden');
            bgQrModal.classList.remove('flex');
            bgQrModal.setAttribute('aria-hidden', 'true');
        }

        function openQrModal() {
            bgQrModal.classList.remove('hidden');
            bgQrModal.classList.add('flex');
            bgQrModal.setAttribute('aria-hidden', 'false');
        }

        bgQrImg.addEventListener('error', function () {
            showToast('QR-Code konnte nicht geladen werden.', true);
        });

        function genBase32(len) {
            var alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
            var out = '';
            var bytes = new Uint8Array(len);
            try { crypto.getRandomValues(bytes); } catch (e) { bytes = null; }

            if (!bytes) {
                // fallback (not cryptographically strong) - but only used if crypto unavailable
                for (var j = 0; j < len; j++) {
                    out += alphabet.charAt(Math.floor(Math.random() * alphabet.length));
                }
                return out;
            }

            for (var i = 0; i < len; i++) {
                out += alphabet[bytes[i] % alphabet.length];
            }
            return out;
        }

        function normalizeBase32(s) {
            return (s || '').toString().trim().toUpperCase().replace(/\s+/g, '');
        }

        function isValidBase32(s) {
            return /^[A-Z2-7]+$/.test(s) && s.length >= 16;
        }

        function ensureSecret() {
            var breakGlassOn = !!bg.checked;
            if (!breakGlassOn) return false;

            var current = normalizeBase32(bgSecret.value);

            if (current !== '' && isValidBase32(current)) {
                if (bgSecret.value !== current) {
                    bgSecret.value = current;
                    return true;
                }
                return false;
            }

            var generated = genBase32(32);
            bgSecret.value = generated;
            return true;
        }

        function buildOtpAuthUri() {
            var secret = normalizeBase32(bgSecret.value);
            var issuer = 'KiezSingles';
            var label = 'noteinstieg';
            return 'otpauth://totp/' + issuer + ':' + label
                + '?secret=' + secret
                + '&issuer=' + issuer
                + '&digits=6&period=30';
        }

        function prepareQr() {
            var breakGlassOn = !!bg.checked;
            var secret = normalizeBase32(bgSecret.value);

            if (!breakGlassOn || secret === '' || !isValidBase32(secret)) {
                bgQrBtn.classList.add('hidden');
                bgQrBtn.disabled = true;
                bgQrImg.removeAttribute('src');
                closeQrModal();
                return;
            }

            var uri = buildOtpAuthUri();
            var qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=320x320&ecc=H&data=' + encodeURIComponent(uri);

            bgQrImg.setAttribute('src', qrUrl);
            bgQrBtn.classList.remove('hidden');
            bgQrBtn.disabled = false;
        }

        function copyText(text) {
            var t = (text || '').toString();
            if (t === '') return Promise.resolve(false);

            try {
                if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
                    return navigator.clipboard.writeText(t).then(function () { return true; }).catch(function () { return false; });
                }
            } catch (e) {}

            try {
                var ta = document.createElement('textarea');
                ta.value = t;
                ta.setAttribute('readonly', 'readonly');
                ta.style.position = 'fixed';
                ta.style.left = '-9999px';
                ta.style.top = '0';
                document.body.appendChild(ta);
                ta.select();
                var ok = false;
                try { ok = document.execCommand('copy'); } catch (e2) { ok = false; }
                document.body.removeChild(ta);
                return Promise.resolve(!!ok);
            } catch (e3) {}

            return Promise.resolve(false);
        }

        function clearCodes() {
            stopCodesPolling();
            codesList.innerHTML = '';
            codesWrap.classList.add('hidden');
            codesWrap.__codes = null;
        }

        function renderCodes(codes) {
            clearCodes();
            if (!Array.isArray(codes) || codes.length < 1) return;

            var normalizedCodes = [];
            for (var i = 0; i < codes.length; i++) {
                var c = codes[i];
                if (typeof c === 'string') {
                    normalizedCodes.push({ code: c, used: false });
                    continue;
                }
                if (c && typeof c === 'object' && typeof c.code === 'string') {
                    normalizedCodes.push({ code: c.code, used: !!c.used });
                }
            }
            if (normalizedCodes.length < 1) return;

            codesWrap.__codes = normalizedCodes.slice();

            for (var j = 0; j < normalizedCodes.length; j++) {
                var item = normalizedCodes[j];

                var row = document.createElement('div');
                row.className = 'flex items-center justify-center gap-[10px] my-2';

                var div = document.createElement('div');
                div.className = 'font-mono font-extrabold tracking-[.8px] px-[10px] py-2 border border-gray-200 rounded-[10px] bg-gray-50 text-center text-[16px]';
                if (item.used) {
                    div.classList.add('line-through', 'opacity-55');
                }
                div.textContent = item.code;

                var btn = document.createElement('button');
                btn.type = 'button';
                btn.className = 'w-[34px] h-[34px] rounded-[10px] border border-slate-300 bg-white inline-flex items-center justify-center p-0 leading-none select-none flex-[0_0_auto] hover:bg-slate-50 active:bg-slate-100 disabled:opacity-45 disabled:cursor-not-allowed';
                btn.setAttribute('aria-label', 'Code kopieren');
                btn.title = 'Kopieren';
                btn.innerHTML = '<span class="text-[14px] -translate-y-[.5px]">⧉</span>';
                btn.addEventListener('click', (function (code) {
                    return function () {
                        copyText(code).then(function (ok) {
                            showToast(ok ? 'Kopiert.' : 'Kopieren nicht möglich.', !ok);
                        });
                    };
                })(item.code));

                row.appendChild(div);
                row.appendChild(btn);
                codesList.appendChild(row);
            }

            codesWrap.classList.remove('hidden');
            startCodesPolling();
        }

        function postJson(url, payload) {
            return fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': csrf,
                    'Accept': 'application/json'
                },
                body: JSON.stringify(payload || {})
            }).then(function (res) {
                if (!res.ok) {
                    return res.text().then(function (t) {
                        throw new Error('HTTP ' + res.status + (t ? (': ' + t) : ''));
                    }).catch(function () {
                        throw new Error('HTTP ' + res.status);
                    });
                }
                return res.json();
            });
        }

        function scheduleSave(kind) {
            var k = (kind || '').toString();

            if (k === 'eta') {
                pendingSaveEta = true;
            } else if (k === 'both') {
                pendingSaveSettings = true;
                pendingSaveEta = true;
            } else {
                pendingSaveSettings = true;
            }

            window.clearTimeout(saveTimer);
            saveTimer = window.setTimeout(saveAll, 200);
        }

        function saveAll() {
            if (saving) return;
            if (!pendingSaveSettings && !pendingSaveEta) return;
            saving = true;

            var payloadSettings = {
                simulate_production: sim ? !!sim.checked : false,

                maintenance_enabled: !!m.checked,
                maintenance_notify_enabled: !!notify.checked,

                maintenance_allow_admins: !!allowAdmins.checked,
                maintenance_allow_moderators: !!allowMods.checked,

                // IMPORTANT:
                // Some backends treat missing keys as default(0). Keep maintenance_show_eta stable across
                // settings saves by always sending the current value as well.
                maintenance_show_eta: !!etaShow.checked,

                break_glass_enabled: !!bg.checked,
                break_glass_totp_secret: (bgSecret.value || ''),
                break_glass_ttl_minutes: (bgTtl.value || '')
            };

            if (outlinesFrontend) {
                payloadSettings.layout_outlines_frontend_enabled = !!outlinesFrontend.checked;
            }
            if (outlinesAdmin) {
                payloadSettings.layout_outlines_admin_enabled = !!outlinesAdmin.checked;
            }
            if (outlinesAllowProduction) {
                payloadSettings.layout_outlines_allow_production = !!outlinesAllowProduction.checked;
            }

            var payloadEta = {
                maintenance_show_eta: !!etaShow.checked,
                maintenance_eta_date: (etaDate.value || ''),
                maintenance_eta_time: (etaTime.value || '')
            };

            var doSettings = pendingSaveSettings;
            var doEta = pendingSaveEta;

            pendingSaveSettings = false;
            pendingSaveEta = false;

            Promise.resolve()
                .then(function () {
                    if (!doSettings) return null;
                    return postJson(urlSettingsSave, payloadSettings);
                })
                .then(function () {
                    if (!doEta) return null;
                    return postJson(urlEtaSave, payloadEta);
                })
                .then(function () {
                    showToast('Gespeichert.', false);
                    if (reloadAfterSave) {
                        reloadAfterSave = false;
                        window.setTimeout(function () {
                            window.location.reload();
                        }, 150);
                    }
                })
                .catch(function () {
                    reloadAfterSave = false;
                    showToast('Fehler beim Speichern.', true);
                })
                .finally(function () {
                    saving = false;
                    if (pendingSaveSettings || pendingSaveEta) {
                        scheduleSave('both');
                    }
                });
        }

        function loadCodes(opts) {
            opts = opts || {};
            var clear = (typeof opts.clear === 'boolean') ? opts.clear : true;
            var doToast = (typeof opts.toast === 'boolean') ? opts.toast : true;

            if (clear) clearCodes();

            recBtn.disabled = true;

            return postJson(urlRecoveryList, {})
                .then(function (out) {
                    if (!out || out.ok !== true || !Array.isArray(out.codes)) {
                        if (doToast) showToast('Notfallcodes konnten nicht geladen werden.', true);
                        recBtn.disabled = false;
                        return;
                    }

                    renderCodes(out.codes);

                    if (doToast) showToast('Notfallcodes geladen.', false);
                    recBtn.disabled = false;
                })
                .catch(function () {
                    if (doToast) showToast('Fehler beim Laden der Notfallcodes.', true);
                    recBtn.disabled = false;
                });
        }

        function apply() {
            if (!hasSettingsTable) {
                m.disabled = true;
            }

            var maintenanceOn = !!m.checked;
            if (localDebugBanner) {
                var localBannerEnabled = (localDebugBanner.getAttribute('data-ks-local-banner-enabled') === '1');
                localDebugBanner.classList.toggle('hidden', !(maintenanceOn && localBannerEnabled));
            }

            // Statusfarben: rot wenn Wartungsmodus aktiv, sonst grün.
            setStatusBox(maintenanceOn);

            // Wenn system_settings fehlt: alles außer Wartung/ETA blockieren.
            if (!hasSystemSettingsTable) {
                allowAdmins.disabled = true;
                allowMods.disabled = true;

                notify.disabled = true;
                if (sim) sim.disabled = true;

                bg.disabled = true;
                bgSecret.disabled = true;
                bgTtl.disabled = true;

                bgQrBtn.disabled = true;
                bgQrBtn.classList.add('hidden');

                bgLinkWrap.classList.add('hidden');

                recBtn.disabled = true;
                recBtn.classList.add('hidden');

                genBtn.disabled = true;
                clearCodes();
            }

            // Wenn Wartung AUS: alles deaktivieren + zurücksetzen (UI-State).
            if (!maintenanceOn) {
                etaShow.checked = false;
                etaDate.value = '';
                etaTime.value = '';

                notify.checked = false;

                allowAdmins.checked = false;
                allowMods.checked = false;

                if (sim) sim.checked = false;

                bg.checked = false;
                bgTtl.value = '15';

                bgLinkWrap.classList.add('hidden');

                bgQrBtn.disabled = true;
                bgQrBtn.classList.add('hidden');
                bgQrImg.removeAttribute('src');
                closeQrModal();

                recBtn.disabled = true;
                recBtn.classList.add('hidden');
                genBtn.disabled = true;
                clearCodes();

                etaShow.disabled = true;
                etaDate.disabled = true;
                etaTime.disabled = true;
                etaClear.disabled = true;

                if (hasSystemSettingsTable) {
                    allowAdmins.disabled = true;
                    allowMods.disabled = true;

                    notify.disabled = true;
                    if (sim) sim.disabled = true;

                    bg.disabled = true;
                    bgTtl.disabled = true;
                    bgSecret.disabled = true;
                }

                return;
            }

            // Wartung AN: ETA aktivierbar.
            etaShow.disabled = (!hasSettingsTable);
            etaDate.disabled = (!hasSettingsTable) || (!etaShow.checked);
            etaTime.disabled = (!hasSettingsTable) || (!etaShow.checked);
            etaClear.disabled = (!hasSettingsTable);

            // Wartung AN: Allowlist bedienbar (nur wenn system_settings existiert).
            if (hasSystemSettingsTable) {
                allowAdmins.disabled = false;
                allowMods.disabled = false;
            } else {
                allowAdmins.disabled = true;
                allowMods.disabled = true;
            }

            // Wartung AN: Notify erst jetzt bedienbar.
            if (hasSystemSettingsTable) {
                notify.disabled = false;
                if (sim) sim.disabled = false;
            } else {
                notify.disabled = true;
            }

            // Break-Glass UI: nur im Wartungsmodus und nur in PROD (oder lokal mit Live-Simulation).
            var prodEffective = isProd || (!!(sim ? sim.checked : false));
            var breakGlassUiAllowed = hasSystemSettingsTable && maintenanceOn && prodEffective;

            bg.disabled = !breakGlassUiAllowed;
            bgTtl.disabled = !breakGlassUiAllowed;
            bgSecret.disabled = !breakGlassUiAllowed;

            if (!breakGlassUiAllowed) {
                bg.checked = false;
                bgLinkWrap.classList.add('hidden');

                bgQrBtn.disabled = true;
                bgQrBtn.classList.add('hidden');
                bgQrImg.removeAttribute('src');
                closeQrModal();

                recBtn.disabled = true;
                recBtn.classList.add('hidden');

                genBtn.disabled = true;
                clearCodes();
                return;
            }

            var linkAllowed = !!bg.checked;

            if (linkAllowed) {
                bgLinkWrap.classList.remove('hidden');

                recBtn.classList.remove('hidden');
                recBtn.disabled = false;

                genBtn.disabled = false;
            } else {
                bgLinkWrap.classList.add('hidden');

                recBtn.classList.add('hidden');
                recBtn.disabled = true;

                genBtn.disabled = true;
                clearCodes();
            }

            var secretWasGeneratedOrNormalized = ensureSecret();
            prepareQr();

            if (secretWasGeneratedOrNormalized) {
                scheduleSave('settings');
            }
        }

        bgQrBtn.addEventListener('click', function () {
            prepareQr();
            var src = (bgQrImg.getAttribute('src') || '');
            if (src === '') {
                showToast('Kein QR-Code verfügbar.', true);
                return;
            }
            openQrModal();
        });

        bgQrClose.addEventListener('click', function () {
            closeQrModal();
        });

        bgQrModal.addEventListener('click', function (ev) {
            if (ev && ev.target === bgQrModal) {
                closeQrModal();
            }
        });

        recBtn.addEventListener('click', function () {
            loadCodes({ clear: true, toast: true });
        });

        genBtn.addEventListener('click', function () {
            genBtn.disabled = true;

            postJson(urlRecoveryGenerate, {})
                .then(function (out) {
                    if (!out || out.ok !== true) {
                        var msg = (out && typeof out.message === 'string' && out.message !== '') ? out.message : 'Notfallcodes konnten nicht erzeugt werden.';
                        showToast(msg, true);
                        genBtn.disabled = false;
                        return;
                    }

                    return loadCodes({ clear: true, toast: false }).then(function () {
                        showToast('Notfallcodes erzeugt.', false);
                        genBtn.disabled = false;
                    });
                })
                .catch(function () {
                    showToast('Fehler beim Erzeugen der Notfallcodes.', true);
                    genBtn.disabled = false;
                });
        });

        printBtn.addEventListener('click', function () {
            var codes = codesWrap.__codes;
            if (!Array.isArray(codes) || codes.length < 1) {
                showToast('Keine Notfallcodes zum Drucken.', true);
                return;
            }

            function esc(s) {
                return (s || '').toString()
                    .replace(/&/g, '&amp;')
                    .replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;')
                    .replace(/"/g, '&quot;');
            }

            var today = new Date();
            function pad2(n) { return String(n).padStart(2, '0'); }
            var stamp = pad2(today.getDate()) + '.' + pad2(today.getMonth() + 1) + '.' + today.getFullYear();

            var html = '<!doctype html><html lang="de"><head><meta charset="utf-8">';
            html += '<meta name="viewport" content="width=device-width, initial-scale=1">';
            html += '<title>KiezSingles – Noteinstieg Notfallcodes</title>';
            html += '<style>';
            html += '@page { size: A4; margin: 18mm; }';
            html += 'body { font-family: system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; }';
            html += 'h1 { margin:0 0 6px 0; font-size:18px; }';
            html += '.meta { color:#444; font-size:12px; margin:0 0 14px 0; }';
            html += '.grid { display:grid; grid-template-columns: 1fr 1fr; gap:10px; }';
            html += '.code { border:1px solid #ddd; border-radius:10px; padding:14px 10px; text-align:center; font-size:18px; font-weight:800; letter-spacing:1px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace; }';
            html += '.code.used { text-decoration: line-through; opacity:.55; }';
            html += '.hint { margin-top:14px; font-size:12px; color:#444; }';
            html += '</style></head><body>';
            html += '<h1>KiezSingles – Noteinstieg Notfallcodes</h1>';
            html += '<p class="meta">Stand ' + esc(stamp) + ' (durchgestrichen = bereits benutzt)</p>';
            html += '<div class="grid">';

            for (var i = 0; i < codes.length; i++) {
                var c = codes[i];
                if (!c || typeof c.code !== 'string') continue;
                html += '<div class="code' + (c.used ? ' used' : '') + '">' + esc(c.code) + '</div>';
            }

            html += '</div>';
            html += '<div class="hint">Hinweis: Notfallcodes funktionieren nur im Wartungsmodus bei aktivem Noteinstieg.</div>';
            html += '<script>window.onload=()=>{ window.print(); };</' + 'script>';
            html += '</body></html>';

            var w = window.open('about:blank', '_blank');
            if (!w) {
                showToast('Popup blockiert (Drucken nicht möglich).', true);
                return;
            }

            try {
                w.document.open();
                w.document.write(html);
                w.document.close();
                w.focus();
            } catch (e) {
                showToast('Druckansicht konnte nicht geöffnet werden.', true);
            }
        });

        if (sim) {
            sim.addEventListener('change', function () {
                reloadAfterSave = true;
                apply();
                scheduleSave('settings');
            });
        }

        m.addEventListener('change', function () {
            reloadAfterSave = true;
            apply();
            scheduleSave('both');
        });

        allowAdmins.addEventListener('change', function () { apply(); scheduleSave('settings'); });
        allowMods.addEventListener('change', function () { apply(); scheduleSave('settings'); });

        // When ETA display is toggled OFF: clear date/time immediately and persist via eta-ajax.
        etaShow.addEventListener('change', function () {
            if (!etaShow.checked) {
                etaDate.value = '';
                etaTime.value = '';
            }
            apply();
            scheduleSave('eta');
        });

        etaDate.addEventListener('change', function () { scheduleSave('eta'); });
        etaTime.addEventListener('change', function () { scheduleSave('eta'); });

        etaClear.addEventListener('click', function () {
            etaShow.checked = false;
            etaDate.value = '';
            etaTime.value = '';
            apply();
            scheduleSave('eta');
        });

        notify.addEventListener('change', function () { apply(); scheduleSave('settings'); });
        if (outlinesFrontend) {
            outlinesFrontend.addEventListener('change', function () {
                reloadAfterSave = true;
                scheduleSave('settings');
            });
        }
        if (outlinesAdmin) {
            outlinesAdmin.addEventListener('change', function () {
                reloadAfterSave = true;
                scheduleSave('settings');
            });
        }
        if (outlinesAllowProduction) {
            outlinesAllowProduction.addEventListener('change', function () {
                reloadAfterSave = true;
                scheduleSave('settings');
            });
        }

        bg.addEventListener('change', function () { apply(); scheduleSave('settings'); });
        bgTtl.addEventListener('input', function () { scheduleSave('settings'); });

        apply();
    })();

    // ------------------------------------------------------------------------
    // 6) Admin tickets: clickable table rows (tr[data-href]) without inline scripts
    // Re-implements behavior from resources/views/admin/tickets/index.blade.php
    // ------------------------------------------------------------------------
    (function initAdminTicketsRowNavigation() {
        function isModifiedClick(e) {
            return !!(e && (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button === 1));
        }

        // Only attach if at least one ticket row exists
        if (!document.querySelector('tr[data-href]')) return;

        document.addEventListener('click', function (e) {
            if (!e || isModifiedClick(e)) return;

            var target = e.target;
            if (!target || !target.closest) return;

            var tr = target.closest('tr[data-href]');
            if (!tr) return;

            if (target.closest('a, button, input, select, textarea, label')) return;

            var href = tr.getAttribute('data-href') || '';
            if (!href) return;

            e.preventDefault();
            window.location.assign(href);
        });
    })();
})();