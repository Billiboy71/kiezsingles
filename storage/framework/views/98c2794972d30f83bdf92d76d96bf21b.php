



<?php
    $adminTab = 'maintenance';

    $hasSettingsTable = $hasSettingsTable ?? true;
    $hasSystemSettingsTable = $hasSystemSettingsTable ?? true;

    $maintenanceEnabled = (bool) ($maintenanceEnabled ?? false);
    $maintenanceShowEta = (bool) ($maintenanceShowEta ?? false);

    $etaDateValue = (string) ($etaDateValue ?? '');
    $etaTimeValue = (string) ($etaTimeValue ?? '');

    $simulateProd = (bool) ($simulateProd ?? false);
    $isProd = (bool) ($isProd ?? app()->environment('production'));

    $breakGlassEnabled = (bool) ($breakGlassEnabled ?? false);
    $breakGlassTotpSecret = (string) ($breakGlassTotpSecret ?? '');
    $breakGlassTtlMinutes = (int) ($breakGlassTtlMinutes ?? 15);

    $maintenanceNotifyEnabled = (bool) ($maintenanceNotifyEnabled ?? false);

    // Wer darf sich im Wartungsmodus einloggen?
    // Erwartet system_settings keys:
    // - maintenance.allow_admins
    // - maintenance.allow_moderators
    $maintenanceAllowAdmins = (bool) ($maintenanceAllowAdmins ?? false);
    $maintenanceAllowModerators = (bool) ($maintenanceAllowModerators ?? false);

    // Statusfarben: grün default (LIVE), rot wenn Wartungsmodus aktiv ist.
    $statusBg = (string) ($statusBg ?? ($maintenanceEnabled ? '#fff5f5' : '#f0fff4'));
    $statusBorder = (string) ($statusBorder ?? ($maintenanceEnabled ? '#fecaca' : '#bbf7d0'));
?>

<?php $__env->startSection('content'); ?>

    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($notice)): ?>
        <div class="p-3 rounded-lg border mb-3" style="background:#eef7ee; border-color:#b6e0b6;">
            <?php echo e($notice); ?>

        </div>
    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

    <div id="ks_toast" class="ks-toast"></div>

    <div
        id="ks_status_wrap"
        class="p-4 rounded-lg border mb-4"
        style="border-color: <?php echo e($statusBorder); ?>;
               background: <?php echo e($statusBg); ?>;"
    >

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!$hasSettingsTable): ?>
            <p class="m-0 text-sm" style="color:#a00;">
                Hinweis: Tabelle <code>app_settings</code> existiert nicht. Wartung kann hier nicht geschaltet werden.
            </p>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!$hasSystemSettingsTable): ?>
            <p class="m-0 text-sm mt-2" style="color:#a00;">
                Hinweis: Tabelle <code>system_settings</code> existiert nicht. Debug-Schalter können nicht gespeichert werden.
            </p>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <input type="hidden" id="ks_csrf" value="<?php echo e(csrf_token()); ?>">

        
        <style>
            .ks-toast { display:none; margin:0 0 16px 0; padding:12px 16px; border-radius:8px; border:1px solid #b6e0b6; background:#eef7ee; }
            .ks-toast.is-error { border-color:#fecaca; background:#fff5f5; }

            .ks-mini-btn {
                width:46px;
                height:26px;
                border-radius:999px;
                border:1px solid #cbd5e1;
                background:#fff;
                cursor:pointer;
                display:inline-flex;
                align-items:center;
                justify-content:center;
                padding:0;
                line-height:1;
                user-select:none;
            }
            .ks-mini-btn:hover { background:#f8fafc; }
            .ks-mini-btn:active { background:#f1f5f9; }
            .ks-mini-btn:disabled { opacity:.45; cursor:not-allowed; }
            .ks-mini-icon { font-size:14px; transform: translateY(-.5px); }

            .ks-btn {
                padding:10px 12px;
                border-radius:10px;
                border:1px solid #cbd5e1;
                background:#fff;
                cursor:pointer;
                user-select:none;
            }
            .ks-btn:hover { background:#f8fafc; }
            .ks-btn:active { background:#f1f5f9; }
            .ks-btn:disabled { opacity:.45; cursor:not-allowed; }

            .ks-modal {
                display:none;
                position:fixed;
                inset:0;
                background: rgba(0,0,0,.55);
                z-index: 9999;
                align-items:center;
                justify-content:center;
                padding: 24px;
            }
            .ks-modal-box {
                width: 100%;
                max-width: 420px;
                background:#fff;
                border-radius:12px;
                border:1px solid #e5e7eb;
                box-shadow: 0 10px 25px rgba(0,0,0,.25);
                padding: 14px 14px 16px 14px;
            }
            .ks-modal-head {
                display:flex;
                align-items:center;
                justify-content:space-between;
                gap: 12px;
                margin: 0 0 10px 0;
            }
            .ks-modal-title { font-weight:700; }
            .ks-modal-close {
                width:34px;
                height:34px;
                border-radius:10px;
                border:1px solid #cbd5e1;
                background:#fff;
                cursor:pointer;
                display:inline-flex;
                align-items:center;
                justify-content:center;
                padding:0;
                line-height:1;
                user-select:none;
            }
            .ks-modal-close:hover { background:#f8fafc; }
            .ks-modal-close:active { background:#f1f5f9; }

            .ks-codes {
                display:none;
                margin-top:10px;
                padding:12px 12px;
                border-radius:10px;
                border:1px solid #e5e7eb;
                background:#fff;
            }
            .ks-codes h3 { margin:0 0 8px 0; font-size:14px; }
            .ks-code-item {
                font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
                font-weight:800;
                letter-spacing:.8px;
                padding:8px 10px;
                border:1px solid #e5e7eb;
                border-radius:10px;
                background:#fafafa;
                margin:8px 0;
                text-align:center;
                font-size:16px;
            }
            .ks-code-item.is-used {
                text-decoration: line-through;
                opacity: .55;
            }
            .ks-code-row {
                display:flex;
                align-items:center;
                justify-content:center;
                gap:10px;
                margin:8px 0;
            }
            .ks-code-copy {
                width:34px;
                height:34px;
                border-radius:10px;
                border:1px solid #cbd5e1;
                background:#fff;
                cursor:pointer;
                display:inline-flex;
                align-items:center;
                justify-content:center;
                padding:0;
                line-height:1;
                user-select:none;
                flex:0 0 auto;
            }
            .ks-code-copy:hover { background:#f8fafc; }
            .ks-code-copy:active { background:#f1f5f9; }
            .ks-code-copy:disabled { opacity:.45; cursor:not-allowed; }
            .ks-code-copy-icon { font-size:14px; transform: translateY(-.5px); }

            .ks-code-actions { display:flex; gap:10px; flex-wrap:wrap; margin-top:8px; justify-content:center; }
        </style>

        <?php
            $maintenanceDisabled = (!$hasSettingsTable) ? ' disabled' : '';
            $systemSettingsDisabled = (!$hasSystemSettingsTable) ? ' disabled' : '';
        ?>

        
        <div class="ks-row" style="margin:0 0 12px 0;">
            <div class="ks-label">
                <div>
                    <strong>Wartungsmodus aktiv</strong>
                    <span class="ks-info" title="Schaltet den Wartungsmodus ein. Blockiert normale Nutzung, bis du Wartung wieder ausschaltest.">i</span>
                </div>
                <div class="ks-sub">Blockiert normale Nutzung, bis du Wartung wieder ausschaltest.</div>
            </div>

            <label class="ks-toggle" style="margin-left:auto;">
                <input type="checkbox" id="maintenance_enabled" value="1" <?php if($maintenanceEnabled): echo 'checked'; endif; ?> <?php echo $maintenanceDisabled; ?>>
                <span class="ks-slider"></span>
            </label>
        </div>

        <div class="ks-row" style="margin:0 0 12px 0;">
            <div class="ks-label">
                <div>
                    <strong>Wartungsende anzeigen</strong>
                    <span class="ks-info" title="Zeigt das Wartungsende im Wartungshinweis an. Nur aktivierbar, wenn Wartung eingeschaltet ist.">i</span>
                </div>
                <div class="ks-sub">Zeigt das Wartungsende im Wartungshinweis an.</div>
            </div>

            <label class="ks-toggle" style="margin-left:auto;">
                <input type="checkbox" id="maintenance_show_eta" value="1" <?php if($maintenanceShowEta): echo 'checked'; endif; ?> <?php echo $maintenanceDisabled; ?>>
                <span class="ks-slider"></span>
            </label>
        </div>

        <label style="display:block; margin:0 0 6px 0; font-weight:600;">Wartung endet am</label>

        <div style="display:flex; gap:10px; flex-wrap:wrap; margin:0 0 10px 0; align-items:center;">
            <input type="date" id="maintenance_eta_date" value="<?php echo e($etaDateValue); ?>"
                   style="padding:10px 12px; border:1px solid #ccc; border-radius:10px; width:170px;" <?php echo $maintenanceDisabled; ?>>
            <input type="time" id="maintenance_eta_time" value="<?php echo e($etaTimeValue); ?>"
                   style="padding:10px 12px; border:1px solid #ccc; border-radius:10px; width:120px;" <?php echo $maintenanceDisabled; ?>>
            <button type="button" id="maintenance_eta_clear" class="ks-mini-btn" title="Zurücksetzen" <?php echo $maintenanceDisabled; ?>>
                <span class="ks-mini-icon">×</span>
            </button>
        </div>

        
        <div class="ks-row" style="margin:0 0 12px 0;">
            <div class="ks-label">
                <div>
                    <strong>E-Mail-Notify im Wartungsmodus</strong> <span style="color:#555;">(<code>maintenance.notify_enabled</code>)</span>
                    <span class="ks-info" title="Zeigt im Wartungsmodus ein E-Mail-Feld auf der öffentlichen Wartungsseite. Wenn Wartung beendet wird, können gespeicherte Adressen benachrichtigt werden (serverseitig).">i</span>
                </div>
                <div class="ks-sub">Nur relevant, solange Wartung aktiv ist.</div>
            </div>

            <label class="ks-toggle" style="margin-left:auto;">
                <input type="checkbox" id="maintenance_notify_enabled" value="1" <?php if($maintenanceNotifyEnabled): echo 'checked'; endif; ?> <?php echo $systemSettingsDisabled; ?>>
                <span class="ks-slider"></span>
            </label>
        </div>

        <hr style="border:0; border-top:1px solid #e5e7eb; margin:14px 0;">

        
        <div class="ks-row" style="margin:0 0 12px 0;">
            <div class="ks-label">
                <div>
                    <strong>Admins dürfen sich einloggen</strong> <span style="color:#555;">(<code>maintenance.allow_admins</code>)</span>
                    <span class="ks-info" title="Wenn aktiv: Rolle admin darf sich im Wartungsmodus einloggen. Superadmin ist immer erlaubt.">i</span>
                </div>
                <div class="ks-sub">Gilt nur, solange Wartung aktiv ist. Superadmin immer erlaubt.</div>
            </div>

            <label class="ks-toggle" style="margin-left:auto;">
                <input type="checkbox" id="maintenance_allow_admins" value="1" <?php if($maintenanceAllowAdmins): echo 'checked'; endif; ?> <?php echo $systemSettingsDisabled; ?>>
                <span class="ks-slider"></span>
            </label>
        </div>

        <div class="ks-row" style="margin:0 0 12px 0;">
            <div class="ks-label">
                <div>
                    <strong>Moderatoren dürfen sich einloggen</strong> <span style="color:#555;">(<code>maintenance.allow_moderators</code>)</span>
                    <span class="ks-info" title="Wenn aktiv: Rolle moderator darf sich im Wartungsmodus einloggen (sonst ausgesperrt). Superadmin ist immer erlaubt.">i</span>
                </div>
                <div class="ks-sub">Gilt nur, solange Wartung aktiv ist.</div>
            </div>

            <label class="ks-toggle" style="margin-left:auto;">
                <input type="checkbox" id="maintenance_allow_moderators" value="1" <?php if($maintenanceAllowModerators): echo 'checked'; endif; ?> <?php echo $systemSettingsDisabled; ?>>
                <span class="ks-slider"></span>
            </label>
        </div>

        <hr style="border:0; border-top:1px solid #e5e7eb; margin:14px 0;">

        
        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!$isProd): ?>
            <div class="ks-row" style="margin:0 0 12px 0;">
                <div class="ks-label">
                    <div>
                        <strong>Live-Modus simulieren</strong> <span style="color:#555;">(<code>debug.simulate_production</code>)</span>
                        <span class="ks-info" title="Schaltet lokal in einen Live-Simulationsmodus (für Noteinstieg Tests). In Production wird dieser Schalter nicht angezeigt.">i</span>
                    </div>
                    <div class="ks-sub">In Production hat dieser Schalter keine Wirkung.</div>
                </div>

                <label class="ks-toggle" style="margin-left:auto;">
                    <input type="checkbox" id="debug_simulate_production" value="1" <?php if($simulateProd): echo 'checked'; endif; ?> <?php echo $systemSettingsDisabled; ?>>
                    <span class="ks-slider"></span>
                </label>
            </div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <div class="ks-row" style="margin:0 0 12px 0;">
            <div class="ks-label">
                <div>
                    <strong>Noteinstieg aktiv</strong> <span style="color:#555;">(<code>debug.break_glass</code>)</span>
                    <span class="ks-info" title="Notfallzugang (Ebene 3). Nur sinnvoll im Wartungsmodus.">i</span>
                </div>
                <div class="ks-sub">Schaltet Noteinstieg frei.</div>
            </div>

            <label class="ks-toggle" style="margin-left:auto;">
                <input type="checkbox" id="debug_break_glass" value="1" <?php if($breakGlassEnabled): echo 'checked'; endif; ?> <?php echo $systemSettingsDisabled; ?>>
                <span class="ks-slider"></span>
            </label>
        </div>

        <div id="break_glass_link_wrap" style="display:none; margin:-6px 0 12px 0;">
            <div class="ks-sub">Link zum Testen (öffnet Noteinstieg Eingabe):</div>
            <a
                id="break_glass_link"
                href="<?php echo e(url('/noteinstieg?next=/noteinstieg-einstieg')); ?>"
                target="_blank"
                rel="noopener noreferrer"
                style="word-break:break-all; color:#0ea5e9; text-decoration:underline;"
                title="Privates Fenster kann nicht erzwungen werden (Browser-Funktion)."
            >
                <?php echo e(url('/noteinstieg?next=/noteinstieg-einstieg')); ?>

            </a>
        </div>

        <label style="display:block; margin:12px 0 6px 0; font-weight:600;">Noteinstieg TTL (Minuten)</label>

        <div style="display:flex; align-items:center; gap:10px; flex-wrap:wrap; margin-top:0;">
            <input type="number" id="debug_break_glass_ttl_minutes" min="1" max="120" value="<?php echo e((string) $breakGlassTtlMinutes); ?>"
                   style="padding:10px 12px; border:1px solid #ccc; border-radius:10px; width:160px;" <?php echo $systemSettingsDisabled; ?>>
            <button type="button" id="break_glass_qr_btn" class="ks-btn" style="display:none;" <?php echo $systemSettingsDisabled; ?>>QR-Code anzeigen</button>
            <button type="button" id="noteinstieg_recovery_btn" class="ks-btn" style="display:none;" <?php echo $systemSettingsDisabled; ?>>Notfallcodes anzeigen</button>
        </div>

        <div id="noteinstieg_codes" class="ks-codes">
            <h3>Notfallcodes (einmalig)</h3>
            <div id="noteinstieg_codes_list"></div>
            <div class="ks-code-actions">
                <button type="button" id="noteinstieg_recovery_generate_btn" class="ks-btn">5 neue Notfallcodes erzeugen</button>
                <button type="button" id="noteinstieg_print_btn" class="ks-btn">Drucken</button>
            </div>
        </div>

        <input type="hidden" id="debug_break_glass_totp_secret" value="<?php echo e($breakGlassTotpSecret); ?>" <?php echo $systemSettingsDisabled; ?>>

        <div id="break_glass_qr_modal" class="ks-modal" aria-hidden="true">
            <div class="ks-modal-box" role="dialog" aria-modal="true" aria-label="Google Authenticator QR-Code">
                <div class="ks-modal-head">
                    <div class="ks-modal-title">Google Authenticator</div>
                    <button type="button" id="break_glass_qr_close" class="ks-modal-close" aria-label="Schließen">×</button>
                </div>
                <img id="break_glass_qr_img" alt="Break-Glass QR" width="320" height="320"
                     style="display:block; width:100%; height:auto; border-radius:10px; border:1px solid #e5e7eb;">
            </div>
        </div>

        <script>
            (() => {
                const hasSettingsTable = <?php echo e($hasSettingsTable ? 'true' : 'false'); ?>;
                const hasSystemSettingsTable = <?php echo e($hasSystemSettingsTable ? 'true' : 'false'); ?>;
                const isProd = <?php echo e($isProd ? 'true' : 'false'); ?>;

                const csrf = document.getElementById("ks_csrf")?.value || "";
                const toast = document.getElementById("ks_toast");

                const statusWrap = document.getElementById("ks_status_wrap");

                const m = document.getElementById("maintenance_enabled");
                const allowAdmins = document.getElementById("maintenance_allow_admins");
                const allowMods = document.getElementById("maintenance_allow_moderators");

                const etaShow = document.getElementById("maintenance_show_eta");
                const etaDate = document.getElementById("maintenance_eta_date");
                const etaTime = document.getElementById("maintenance_eta_time");
                const etaClear = document.getElementById("maintenance_eta_clear");

                const notify = document.getElementById("maintenance_notify_enabled");

                const sim = document.getElementById("debug_simulate_production"); // kann in PROD fehlen (ausgeblendet)

                const bg = document.getElementById("debug_break_glass");
                const bgSecret = document.getElementById("debug_break_glass_totp_secret");
                const bgTtl = document.getElementById("debug_break_glass_ttl_minutes");

                const bgLinkWrap = document.getElementById("break_glass_link_wrap");
                const bgLink = document.getElementById("break_glass_link");

                const bgQrBtn = document.getElementById("break_glass_qr_btn");
                const bgQrModal = document.getElementById("break_glass_qr_modal");
                const bgQrClose = document.getElementById("break_glass_qr_close");
                const bgQrImg = document.getElementById("break_glass_qr_img");

                const recBtn = document.getElementById("noteinstieg_recovery_btn");
                const genBtn = document.getElementById("noteinstieg_recovery_generate_btn");
                const codesWrap = document.getElementById("noteinstieg_codes");
                const codesList = document.getElementById("noteinstieg_codes_list");
                const printBtn = document.getElementById("noteinstieg_print_btn");

                if (!statusWrap || !m || !allowAdmins || !allowMods || !bg || !bgSecret || !bgTtl || !etaShow || !etaDate || !etaTime || !etaClear || !bgLinkWrap || !bgLink || !bgQrBtn || !bgQrModal || !bgQrClose || !bgQrImg || !recBtn || !genBtn || !codesWrap || !codesList || !printBtn || !notify) return;

                let saveTimer = null;
                let saving = false;

                let codesPollTimer = null;
                const CODES_POLL_MS = 5000;

                const stopCodesPolling = () => {
                    if (codesPollTimer) {
                        window.clearInterval(codesPollTimer);
                        codesPollTimer = null;
                    }
                };

                const startCodesPolling = () => {
                    if (codesPollTimer) return;
                    codesPollTimer = window.setInterval(() => {
                        loadCodes({ clear: false, toast: false });
                    }, CODES_POLL_MS);
                };

                const showToast = (msg, isError=false) => {
                    if (!toast) return;
                    toast.textContent = msg;
                    toast.classList.toggle("is-error", !!isError);
                    toast.style.display = "block";
                    window.clearTimeout(toast.__t);
                    toast.__t = window.setTimeout(() => {
                        toast.style.display = "none";
                    }, 2000);
                };

                const setStatusBox = (maintenanceOn) => {
                    const on = !!maintenanceOn;
                    const bgc = on ? "#fff5f5" : "#f0fff4";
                    const border = on ? "#fecaca" : "#bbf7d0";
                    statusWrap.style.background = bgc;
                    statusWrap.style.borderColor = border;
                };

                const closeQrModal = () => {
                    bgQrModal.style.display = "none";
                    bgQrModal.setAttribute("aria-hidden", "true");
                };

                const openQrModal = () => {
                    bgQrModal.style.display = "flex";
                    bgQrModal.setAttribute("aria-hidden", "false");
                };

                bgQrImg.addEventListener("error", () => {
                    showToast("QR-Code konnte nicht geladen werden.", true);
                });

                const genBase32 = (len) => {
                    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
                    let out = "";
                    const bytes = new Uint8Array(len);
                    crypto.getRandomValues(bytes);
                    for (let i = 0; i < len; i++) {
                        out += alphabet[bytes[i] % alphabet.length];
                    }
                    return out;
                };

                const normalizeBase32 = (s) => {
                    return (s || "").toString().trim().toUpperCase().replace(/\s+/g, "");
                };

                const isValidBase32 = (s) => {
                    return /^[A-Z2-7]+$/.test(s) && s.length >= 16;
                };

                const ensureSecret = () => {
                    const breakGlassOn = !!bg.checked;
                    if (!breakGlassOn) return false;

                    const current = normalizeBase32(bgSecret.value);

                    if (current !== "" && isValidBase32(current)) {
                        if (bgSecret.value !== current) {
                            bgSecret.value = current;
                            return true;
                        }
                        return false;
                    }

                    const generated = genBase32(32);
                    bgSecret.value = generated;
                    return true;
                };

                const buildOtpAuthUri = () => {
                    const secret = normalizeBase32(bgSecret.value);
                    const issuer = "KiezSingles";
                    const label = "noteinstieg";
                    return "otpauth://totp/" + issuer + ":" + label
                        + "?secret=" + secret
                        + "&issuer=" + issuer
                        + "&digits=6&period=30";
                };

                const prepareQr = () => {
                    const breakGlassOn = !!bg.checked;
                    const secret = normalizeBase32(bgSecret.value);

                    if (!breakGlassOn || secret === "" || !isValidBase32(secret)) {
                        bgQrBtn.style.display = "none";
                        bgQrBtn.disabled = true;
                        bgQrImg.removeAttribute("src");
                        closeQrModal();
                        return;
                    }

                    const uri = buildOtpAuthUri();
                    const qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=320x320&ecc=H&data=" + encodeURIComponent(uri);

                    bgQrImg.setAttribute("src", qrUrl);
                    bgQrBtn.style.display = "inline-block";
                    bgQrBtn.disabled = false;
                };

                const copyText = async (text) => {
                    const t = (text || "").toString();
                    if (t === "") return false;

                    try {
                        if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
                            await navigator.clipboard.writeText(t);
                            return true;
                        }
                    } catch (e) {}

                    try {
                        const ta = document.createElement("textarea");
                        ta.value = t;
                        ta.setAttribute("readonly", "readonly");
                        ta.style.position = "fixed";
                        ta.style.left = "-9999px";
                        ta.style.top = "0";
                        document.body.appendChild(ta);
                        ta.select();
                        const ok = document.execCommand("copy");
                        document.body.removeChild(ta);
                        return !!ok;
                    } catch (e) {}

                    return false;
                };

                const clearCodes = () => {
                    stopCodesPolling();
                    codesList.innerHTML = "";
                    codesWrap.style.display = "none";
                    codesWrap.__codes = null;
                };

                const renderCodes = (codes) => {
                    clearCodes();
                    if (!Array.isArray(codes) || codes.length < 1) return;

                    const normalizedCodes = [];
                    for (const c of codes) {
                        if (typeof c === "string") {
                            normalizedCodes.push({ code: c, used: false });
                            continue;
                        }
                        if (c && typeof c === "object" && typeof c.code === "string") {
                            normalizedCodes.push({ code: c.code, used: !!c.used });
                            continue;
                        }
                    }
                    if (normalizedCodes.length < 1) return;

                    codesWrap.__codes = normalizedCodes.slice();

                    for (const item of normalizedCodes) {
                        const row = document.createElement("div");
                        row.className = "ks-code-row";

                        const div = document.createElement("div");
                        div.className = "ks-code-item" + (item.used ? " is-used" : "");
                        div.textContent = item.code;

                        const btn = document.createElement("button");
                        btn.type = "button";
                        btn.className = "ks-code-copy";
                        btn.setAttribute("aria-label", "Code kopieren");
                        btn.title = "Kopieren";
                        btn.innerHTML = "<span class=\"ks-code-copy-icon\">⧉</span>";
                        btn.addEventListener("click", async () => {
                            const ok = await copyText(item.code);
                            showToast(ok ? "Kopiert." : "Kopieren nicht möglich.", !ok);
                        });

                        row.appendChild(div);
                        row.appendChild(btn);
                        codesList.appendChild(row);
                    }

                    codesWrap.style.display = "block";
                    startCodesPolling();
                };

                const postJson = async (url, payload) => {
                    const res = await fetch(url, {
                        method: "POST",
                        headers: {
                            "Content-Type": "application/json",
                            "X-CSRF-TOKEN": csrf,
                            "Accept": "application/json"
                        },
                        body: JSON.stringify(payload)
                    });

                    if (!res.ok) {
                        let t = "";
                        try { t = await res.text(); } catch (e) {}
                        throw new Error("HTTP " + res.status + (t ? (": " + t) : ""));
                    }

                    return await res.json();
                };

                const scheduleSave = () => {
                    window.clearTimeout(saveTimer);
                    saveTimer = window.setTimeout(saveAll, 200);
                };

                const saveAll = async () => {
                    if (saving) return;
                    saving = true;

                    try {
                        await postJson(<?php echo json_encode(route('admin.settings.save.ajax'), 15, 512) ?>, {
                            simulate_production: sim ? !!sim.checked : false,

                            maintenance_enabled: !!m.checked,
                            maintenance_notify_enabled: !!notify.checked,

                            maintenance_allow_admins: !!allowAdmins.checked,
                            maintenance_allow_moderators: !!allowMods.checked,

                            break_glass_enabled: !!bg.checked,
                            break_glass_totp_secret: (bgSecret.value || ""),
                            break_glass_ttl_minutes: (bgTtl.value || "")
                        });

                        await postJson(<?php echo json_encode(route('admin.maintenance.eta.ajax'), 15, 512) ?>, {
                            maintenance_show_eta: !!etaShow.checked,
                            maintenance_eta_date: (etaDate.value || ""),
                            maintenance_eta_time: (etaTime.value || "")
                        });

                        showToast("Gespeichert.");
                    } catch (e) {
                        showToast("Fehler beim Speichern.", true);
                    } finally {
                        saving = false;
                    }
                };

                const loadCodes = async ({ clear = true, toast = true } = {}) => {
                    try {
                        if (clear) clearCodes();

                        recBtn.disabled = true;

                        const out = await postJson(<?php echo json_encode(route('admin.noteinstieg.recovery.list.ajax'), 15, 512) ?>, {});
                        if (!out || out.ok !== true || !Array.isArray(out.codes)) {
                            if (toast) showToast("Notfallcodes konnten nicht geladen werden.", true);
                            recBtn.disabled = false;
                            return;
                        }

                        renderCodes(out.codes);

                        if (toast) showToast("Notfallcodes geladen.");
                        recBtn.disabled = false;
                    } catch (e) {
                        if (toast) showToast("Fehler beim Laden der Notfallcodes.", true);
                        recBtn.disabled = false;
                    }
                };

                const apply = () => {
                    if (!hasSettingsTable) {
                        m.disabled = true;
                    }

                    const maintenanceOn = !!m.checked;

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
                        bgQrBtn.style.display = "none";
                        bgLinkWrap.style.display = "none";
                        recBtn.disabled = true;
                        recBtn.style.display = "none";
                        genBtn.disabled = true;
                        clearCodes();
                    }

                    // Wenn Wartung AUS: alles deaktivieren + zurücksetzen (UI-State).
                    if (!maintenanceOn) {
                        etaShow.checked = false;
                        etaDate.value = "";
                        etaTime.value = "";

                        notify.checked = false;

                        if (sim) sim.checked = false;

                        bg.checked = false;
                        bgTtl.value = "15";

                        bgLinkWrap.style.display = "none";

                        bgQrBtn.disabled = true;
                        bgQrBtn.style.display = "none";
                        bgQrImg.removeAttribute("src");
                        closeQrModal();

                        recBtn.disabled = true;
                        recBtn.style.display = "none";
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
                    etaDate.disabled = (!hasSettingsTable);
                    etaTime.disabled = (!hasSettingsTable);
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
                    const prodEffective = isProd || (!!(sim ? sim.checked : false));
                    const breakGlassUiAllowed = hasSystemSettingsTable && maintenanceOn && prodEffective;

                    bg.disabled = !breakGlassUiAllowed;
                    bgTtl.disabled = !breakGlassUiAllowed;
                    bgSecret.disabled = !breakGlassUiAllowed;

                    if (!breakGlassUiAllowed) {
                        bg.checked = false;
                        bgLinkWrap.style.display = "none";
                        bgQrBtn.disabled = true;
                        bgQrBtn.style.display = "none";
                        bgQrImg.removeAttribute("src");
                        closeQrModal();

                        recBtn.disabled = true;
                        recBtn.style.display = "none";
                        genBtn.disabled = true;
                        clearCodes();
                        return;
                    }

                    const linkAllowed = !!bg.checked;

                    bgLinkWrap.style.display = linkAllowed ? "block" : "none";

                    if (linkAllowed) {
                        recBtn.style.display = "inline-block";
                        recBtn.disabled = false;

                        genBtn.disabled = false;
                    } else {
                        recBtn.style.display = "none";
                        recBtn.disabled = true;

                        genBtn.disabled = true;
                        clearCodes();
                    }

                    const secretWasGeneratedOrNormalized = ensureSecret();
                    prepareQr();

                    if (secretWasGeneratedOrNormalized) {
                        scheduleSave();
                    }
                };

                bgQrBtn.addEventListener("click", () => {
                    prepareQr();
                    const src = bgQrImg.getAttribute("src") || "";
                    if (src === "") {
                        showToast("Kein QR-Code verfügbar.", true);
                        return;
                    }
                    openQrModal();
                });

                bgQrClose.addEventListener("click", () => {
                    closeQrModal();
                });

                bgQrModal.addEventListener("click", (ev) => {
                    if (ev.target === bgQrModal) {
                        closeQrModal();
                    }
                });

                recBtn.addEventListener("click", async () => {
                    await loadCodes();
                });

                genBtn.addEventListener("click", async () => {
                    try {
                        genBtn.disabled = true;

                        const out = await postJson(<?php echo json_encode(route('admin.noteinstieg.recovery.generate.ajax'), 15, 512) ?>, {});
                        if (!out || out.ok !== true) {
                            const msg = (out && typeof out.message === "string" && out.message !== "") ? out.message : "Notfallcodes konnten nicht erzeugt werden.";
                            showToast(msg, true);
                            genBtn.disabled = false;
                            return;
                        }

                        await loadCodes({ clear: true, toast: false });
                        showToast("Notfallcodes erzeugt.");

                        genBtn.disabled = false;
                    } catch (e) {
                        showToast("Fehler beim Erzeugen der Notfallcodes.", true);
                        genBtn.disabled = false;
                    }
                });

                printBtn.addEventListener("click", () => {
                    const codes = codesWrap.__codes;
                    if (!Array.isArray(codes) || codes.length < 1) {
                        showToast("Keine Notfallcodes zum Drucken.", true);
                        return;
                    }

                    const esc = (s) => (s || "").toString()
                        .replace(/&/g, "&amp;")
                        .replace(/</g, "&lt;")
                        .replace(/>/g, "&gt;")
                        .replace(/"/g, "&quot;");

                    const today = new Date();
                    const pad2 = (n) => String(n).padStart(2, "0");
                    const stamp = pad2(today.getDate()) + "." + pad2(today.getMonth() + 1) + "." + today.getFullYear();

                    let html = "<!doctype html><html lang=\"de\"><head><meta charset=\"utf-8\">";
                    html += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">";
                    html += "<title>KiezSingles – Noteinstieg Notfallcodes</title>";
                    html += "<style>";
                    html += "@page { size: A4; margin: 18mm; }";
                    html += "body { font-family: system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; }";
                    html += "h1 { margin:0 0 6px 0; font-size:18px; }";
                    html += ".meta { color:#444; font-size:12px; margin:0 0 14px 0; }";
                    html += ".grid { display:grid; grid-template-columns: 1fr 1fr; gap:10px; }";
                    html += ".code { border:1px solid #ddd; border-radius:10px; padding:14px 10px; text-align:center; font-size:18px; font-weight:800; letter-spacing:1px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, \"Liberation Mono\", \"Courier New\", monospace; }";
                    html += ".code.used { text-decoration: line-through; opacity:.55; }";
                    html += ".hint { margin-top:14px; font-size:12px; color:#444; }";
                    html += "</style></head><body>";
                    html += "<h1>KiezSingles – Noteinstieg Notfallcodes</h1>";
                    html += "<p class=\"meta\">Stand " + esc(stamp) + " (durchgestrichen = bereits benutzt)</p>";
                    html += "<div class=\"grid\">";
                    for (const c of codes) {
                        if (!c || typeof c.code !== "string") continue;
                        html += "<div class=\"code" + (c.used ? " used" : "") + "\">" + esc(c.code) + "</div>";
                    }
                    html += "</div>";
                    html += "<div class=\"hint\">Hinweis: Notfallcodes funktionieren nur im Wartungsmodus bei aktivem Noteinstieg.</div>";
                    html += "<script>window.onload=()=>{ window.print(); };</" + "script>";
                    html += "</body></html>";

                    const w = window.open("about:blank", "_blank");
                    if (!w) {
                        showToast("Popup blockiert (Drucken nicht möglich).", true);
                        return;
                    }

                    try {
                        w.document.open();
                        w.document.write(html);
                        w.document.close();
                        w.focus();
                    } catch (e) {
                        showToast("Druckansicht konnte nicht geöffnet werden.", true);
                    }
                });

                if (sim) {
                    sim.addEventListener("change", () => { apply(); scheduleSave(); });
                }

                m.addEventListener("change", () => { apply(); scheduleSave(); });

                allowAdmins.addEventListener("change", () => { apply(); scheduleSave(); });
                allowMods.addEventListener("change", () => { apply(); scheduleSave(); });

                etaShow.addEventListener("change", () => { scheduleSave(); });
                etaDate.addEventListener("change", () => { scheduleSave(); });
                etaTime.addEventListener("change", () => { scheduleSave(); });

                etaClear.addEventListener("click", () => {
                    etaShow.checked = false;
                    etaDate.value = "";
                    etaTime.value = "";
                    scheduleSave();
                });

                notify.addEventListener("change", () => { apply(); scheduleSave(); });

                bg.addEventListener("change", () => { apply(); scheduleSave(); });
                bgTtl.addEventListener("input", () => { scheduleSave(); });

                apply();
            })();
        </script>

    </div>

<?php $__env->stopSection(); ?>

<?php echo $__env->make('admin.layouts.admin', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/maintenance.blade.php ENDPATH**/ ?>