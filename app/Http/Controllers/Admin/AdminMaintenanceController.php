<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Admin\AdminMaintenanceController.php
// Purpose: Admin – Wartungsmodus UI (aus routes/web.php ausgelagert, Logik unverändert)
// ============================================================================

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\SystemSetting;
use App\Support\SystemSettingHelper;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class AdminMaintenanceController extends Controller
{
    public function home(Request $request)
    {
        abort_unless(auth()->check() && (string) auth()->user()->role === 'admin', 403);

        $hasSettingsTable = Schema::hasTable('app_settings');
        $settings = null;

        if ($hasSettingsTable) {
            $settings = DB::table('app_settings')->select([
                'maintenance_enabled',
                'maintenance_show_eta',
                'maintenance_eta_at',
            ])->first();
        }

        $maintenanceEnabled  = $settings ? (bool) $settings->maintenance_enabled : false;
        $maintenanceShowEta  = $settings ? (bool) $settings->maintenance_show_eta : false;
        $maintenanceEtaAt    = (string) ($settings->maintenance_eta_at ?? '');

        $etaDateValue = '';
        $etaTimeValue = '';

        if ($maintenanceEtaAt !== '') {
            try {
                $dt = Carbon::parse($maintenanceEtaAt);
                $etaDateValue = $dt->format('Y-m-d');
                $etaTimeValue = $dt->format('H:i');
            } catch (\Throwable $e) {
                $etaDateValue = '';
                $etaTimeValue = '';
            }
        }

        $hasSystemSettingsTable = Schema::hasTable('system_settings');

        $debugUiEnabled = false;
        $debugRoutesEnabled = false;

        $breakGlassEnabled = false;
        $breakGlassTotpSecret = '';
        $breakGlassTtlMinutes = 15;

        $simulateProd = false;

        if ($hasSystemSettingsTable) {
            $debugUiEnabled = (bool) SystemSettingHelper::get('debug.ui_enabled', false);
            $debugRoutesEnabled = (bool) SystemSettingHelper::get('debug.routes_enabled', false);

            $breakGlassEnabled = (bool) SystemSettingHelper::get('debug.break_glass', false);
            $breakGlassTotpSecret = (string) SystemSettingHelper::get('debug.break_glass_totp_secret', '');
            $breakGlassTtlMinutes = (int) SystemSettingHelper::get('debug.break_glass_ttl_minutes', 15);

            $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);

            if ($breakGlassTtlMinutes < 1) {
                $breakGlassTtlMinutes = 1;
            }
            if ($breakGlassTtlMinutes > 120) {
                $breakGlassTtlMinutes = 120;
            }
        }

        $notice = session('admin_notice');

        $statusBg = $maintenanceEnabled ? '#fff5f5' : '#f0fff4';
        $statusBorder = $maintenanceEnabled ? '#fecaca' : '#bbf7d0';
        $statusBadgeBg = $maintenanceEnabled ? '#dc2626' : '#16a34a';
        $statusBadgeText = $maintenanceEnabled ? 'WARTUNG AKTIV' : 'LIVE';

        $isProd = app()->environment('production');

        $envBadgeText = $isProd ? 'PRODUCTION' : 'LOCAL';
        $envBadgeBg = $isProd ? '#7c3aed' : '#0ea5e9';

        if (!$isProd && $simulateProd) {
            $envBadgeText = 'PROD-SIM';
            $envBadgeBg = '#f59e0b';
        }

        $html = '<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">';
        $html .= '<title>Admin – Wartungsmodus</title>';

        // CSS: Toggles + Badge + Toast + Mini-Button
        $html .= '<style>
            .ks-row { display:flex; align-items:center; justify-content:space-between; gap:12px; }
            .ks-label { display:flex; flex-direction:column; gap:2px; min-width:0; }
            .ks-label strong { font-weight:700; }
            .ks-sub { color:#555; font-size:12px; line-height:1.2; }
            .ks-info { cursor:help; user-select:none; color:#111; opacity:.7; margin-left:6px; }
            .ks-toggle { position:relative; width:46px; height:26px; flex:0 0 auto; }
            .ks-toggle input { opacity:0; width:0; height:0; }
            .ks-slider { position:absolute; cursor:pointer; top:0; left:0; right:0; bottom:0; background:#dc2626; border-radius:999px; transition: .15s; }
            .ks-slider:before { position:absolute; content:""; height:20px; width:20px; left:3px; top:3px; background:white; border-radius:50%; transition: .15s; box-shadow:0 1px 2px rgba(0,0,0,.18); }
            .ks-toggle input:checked + .ks-slider { background:#16a34a; }
            .ks-toggle input:checked + .ks-slider:before { transform: translateX(20px); }
            .ks-toggle input:disabled + .ks-slider { opacity:.45; cursor:not-allowed; }
            .ks-badge { display:inline-flex; align-items:center; justify-content:center; padding:6px 10px; border-radius:999px; font-weight:800; font-size:12px; letter-spacing:.4px; color:#fff; }
            .ks-toast { display:none; margin:0 0 16px 0; padding:12px 16px; border-radius:8px; border:1px solid #b6e0b6; background:#eef7ee; }
            .ks-toast.is-error { border-color:#fecaca; background:#fff5f5; }

            /* Mini-Button in Toggle-Größe */
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

            /* Modal */
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
                max-width: 360px;
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
            .ks-code-actions { display:flex; gap:10px; flex-wrap:wrap; margin-top:8px; }
        </style>';

        $html .= '</head><body style="font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; padding:24px; max-width:900px; margin:0 auto;">';

        $html .= '<h1 style="margin:0 0 8px 0;">Admin – Wartung</h1>';
        $html .= '<p style="margin:0 0 16px 0; color:#444;">Minimal-Backend (nur Admin). Änderungen werden automatisch gespeichert.</p>';

        if ($notice) {
            $html .= '<div style="padding:12px 16px; background:#eef7ee; border:1px solid #b6e0b6; border-radius:8px; margin:0 0 16px 0;">' . e($notice) . '</div>';
        }

        $html .= '<div id="ks_toast" class="ks-toast"></div>';

        $html .= '<div style="padding:16px; border:1px solid ' . $statusBorder . '; background:' . $statusBg . '; border-radius:10px; margin:0 0 16px 0;">';
        $html .= '<div style="display:flex; align-items:center; justify-content:space-between; gap:12px; margin:0 0 12px 0;">';
        $html .= '<h2 style="margin:0; font-size:18px;">Wartung & Debug</h2>';
        $html .= '<div style="display:flex; align-items:center; gap:10px;">';
        $html .= '<span class="ks-badge" id="ks_badge" style="background:' . $statusBadgeBg . ';">' . $statusBadgeText . '</span>';
        $html .= '<span class="ks-badge" id="ks_env_badge" style="background:' . $envBadgeBg . ';">' . $envBadgeText . '</span>';
        $html .= '</div>';
        $html .= '</div>';

        if (!$hasSettingsTable) {
            $html .= '<p style="margin:0; color:#a00;">Hinweis: Tabelle <code>app_settings</code> existiert nicht. Wartung kann hier nicht geschaltet werden.</p>';
        }

        if (!$hasSystemSettingsTable) {
            $html .= '<p style="margin:10px 0 0 0; color:#a00;">Hinweis: Tabelle <code>system_settings</code> existiert nicht. Debug-Schalter können nicht gespeichert werden.</p>';
        }

        $html .= '<input type="hidden" id="ks_csrf" value="' . e(csrf_token()) . '">';

        $maintenanceDisabled = (!$hasSettingsTable) ? ' disabled' : '';
        $systemSettingsDisabled = (!$hasSystemSettingsTable) ? ' disabled' : '';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>Wartungsmodus aktiv</strong>';
        $html .= '<span class="ks-info" title="Schaltet den Wartungsmodus ein.">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Blockiert normale Nutzung, bis du Wartung wieder ausschaltest.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="maintenance_enabled" value="1"' . ($maintenanceEnabled ? ' checked' : '') . $maintenanceDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div><strong>Wartungsende anzeigen</strong></div>';
        $html .= '<div class="ks-sub">Zeigt das Wartungsende im Wartungshinweis an.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="maintenance_show_eta" value="1"' . ($maintenanceShowEta ? ' checked' : '') . $maintenanceDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<label style="display:block; margin:0 0 6px 0; font-weight:600;">Wartung endet am</label>';

        $html .= '<div style="display:flex; gap:10px; flex-wrap:wrap; margin:0 0 10px 0; align-items:center;">';
        $html .= '<input type="date" id="maintenance_eta_date" value="' . e($etaDateValue) . '" style="padding:10px 12px; border:1px solid #ccc; border-radius:10px; width:170px;"' . $maintenanceDisabled . '>';
        $html .= '<input type="time" id="maintenance_eta_time" value="' . e($etaTimeValue) . '" style="padding:10px 12px; border:1px solid #ccc; border-radius:10px; width:120px;"' . $maintenanceDisabled . '>';
        $html .= '<button type="button" id="maintenance_eta_clear" class="ks-mini-btn" title="Zurücksetzen"' . $maintenanceDisabled . '>';
        $html .= '<span class="ks-mini-icon">↺</span>';
        $html .= '</button>';
        $html .= '</div>';

        $html .= '<hr style="border:0; border-top:1px solid #e5e7eb; margin:14px 0;">';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>Debug freigeben</strong> <span style="color:#555;">(<code>debug.ui_enabled</code>)</span>';
        $html .= '<span class="ks-info" title="Haupt-Freigabe für Debug im Wartungsmodus.">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Erlaubt Debug-Funktionen nur während Wartung aktiv ist.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="debug_ui_enabled" value="1"' . ($debugUiEnabled ? ' checked' : '') . $systemSettingsDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>Debug-Routen aktivieren</strong> <span style="color:#555;">(<code>debug.routes_enabled</code>)</span>';
        $html .= '<span class="ks-info" title="Aktiviert interne Debug-Routen wie /__whoami und /__web_loaded.">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Schaltet zusätzliche Debug-URLs frei (nur bei Debug-Freigabe).</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="debug_routes_enabled" value="1"' . ($debugRoutesEnabled ? ' checked' : '') . $systemSettingsDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<hr style="border:0; border-top:1px solid #e5e7eb; margin:14px 0;">';

        // Live-Modus simulieren (direkt über Noteinstieg)
        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>Live-Modus simulieren</strong> <span style="color:#555;">(<code>debug.simulate_production</code>)</span>';
        $html .= '<span class="ks-info" title="Nur bei aktiver Wartung: schaltet lokal in einen Live-Simulationsmodus (für Noteinstieg Tests).">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Nur bei aktiver Wartung. In Production hat dieser Schalter keine Wirkung.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="debug_simulate_production" value="1"' . ($simulateProd ? ' checked' : '') . $systemSettingsDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        $html .= '<div class="ks-row" style="margin:0 0 12px 0;">';
        $html .= '<div class="ks-label">';
        $html .= '<div>';
        $html .= '<strong>Noteinstieg aktiv</strong> <span style="color:#555;">(<code>debug.break_glass</code>)</span>';
        $html .= '<span class="ks-info" title="Notfallzugang (Ebene 3).">ⓘ</span>';
        $html .= '</div>';
        $html .= '<div class="ks-sub">Schaltet Noteinstieg frei.</div>';
        $html .= '</div>';
        $html .= '<label class="ks-toggle" style="margin-left:auto;">';
        $html .= '<input type="checkbox" id="debug_break_glass" value="1"' . ($breakGlassEnabled ? ' checked' : '') . $systemSettingsDisabled . '>';
        $html .= '<span class="ks-slider"></span>';
        $html .= '</label>';
        $html .= '</div>';

        // Link: nur anzeigen, wenn Noteinstieg aktiv ist
        $html .= '<div id="break_glass_link_wrap" style="display:none; margin:-6px 0 12px 0;">';
        $html .= '<div class="ks-sub">Link zum Testen (öffnet Noteinstieg Eingabe):</div>';
        $html .= '<a id="break_glass_link" href="' . e(url('/noteinstieg?next=/noteinstieg-einstieg')) . '" target="_blank" rel="noopener noreferrer" style="word-break:break-all; color:#0ea5e9; text-decoration:underline;" title="Privates Fenster kann nicht erzwungen werden (Browser-Funktion).">' . e(url('/noteinstieg?next=/noteinstieg-einstieg')) . '</a>';
        $html .= '</div>';

        $html .= '<label style="display:block; margin:12px 0 6px 0; font-weight:600;">Noteinstieg TTL (Minuten)</label>';

        $html .= '<div style="display:flex; align-items:center; gap:10px; flex-wrap:wrap; margin-top:0;">';
        $html .= '<input type="number" id="debug_break_glass_ttl_minutes" min="1" max="120" value="' . e((string) $breakGlassTtlMinutes) . '" style="padding:10px 12px; border:1px solid #ccc; border-radius:10px; width:160px;"' . $systemSettingsDisabled . '>';
        $html .= '<button type="button" id="break_glass_qr_btn" class="ks-btn" style="display:none;"' . $systemSettingsDisabled . '>QR-Code anzeigen</button>';
        $html .= '<button type="button" id="noteinstieg_recovery_show_btn" class="ks-btn" style="display:none;"' . $systemSettingsDisabled . '>Notfallcodes anzeigen</button>';
        $html .= '</div>';

        $html .= '<div id="noteinstieg_codes" class="ks-codes">';
        $html .= '<h3>Notfallcodes (einmalig)</h3>';
        $html .= '<div id="noteinstieg_codes_list"></div>';
        $html .= '<div class="ks-code-actions" style="justify-content:center;">';
        $html .= '<button type="button" id="noteinstieg_recovery_generate_btn" class="ks-btn">5 Notfallcodes erzeugen</button>';
        $html .= '<button type="button" id="noteinstieg_print_btn" class="ks-btn">Drucken</button>';
        $html .= '</div>';
        $html .= '</div>';

        $html .= '<input type="hidden" id="debug_break_glass_totp_secret" value="' . e($breakGlassTotpSecret) . '"' . $systemSettingsDisabled . '>';

        $html .= '<div id="break_glass_qr_modal" class="ks-modal" aria-hidden="true">';
        $html .= '<div class="ks-modal-box" role="dialog" aria-modal="true" aria-label="Google Authenticator QR-Code">';
        $html .= '<div class="ks-modal-head">';
        $html .= '<div class="ks-modal-title">Google Authenticator</div>';
        $html .= '<button type="button" id="break_glass_qr_close" class="ks-modal-close" aria-label="Schließen">✕</button>';
        $html .= '</div>';
        $html .= '<img id="break_glass_qr_img" alt="Break-Glass QR" width="320" height="320" style="display:block; width:100%; height:auto; border-radius:10px; border:1px solid #e5e7eb;">';
        $html .= '</div>';
        $html .= '</div>';

        $html .= '<script>
            (() => {
                const hasSettingsTable = ' . ($hasSettingsTable ? 'true' : 'false') . ';
                const hasSystemSettingsTable = ' . ($hasSystemSettingsTable ? 'true' : 'false') . ';
                const isProd = ' . (app()->environment('production') ? 'true' : 'false') . ';

                const csrf = document.getElementById("ks_csrf")?.value || "";
                const toast = document.getElementById("ks_toast");
                const badge = document.getElementById("ks_badge");
                const envBadge = document.getElementById("ks_env_badge");

                const m = document.getElementById("maintenance_enabled");
                const etaShow = document.getElementById("maintenance_show_eta");
                const etaDate = document.getElementById("maintenance_eta_date");
                const etaTime = document.getElementById("maintenance_eta_time");
                const etaClear = document.getElementById("maintenance_eta_clear");

                const ui = document.getElementById("debug_ui_enabled");
                const r = document.getElementById("debug_routes_enabled");

                const sim = document.getElementById("debug_simulate_production");

                const bg = document.getElementById("debug_break_glass");
                const bgSecret = document.getElementById("debug_break_glass_totp_secret");
                const bgTtl = document.getElementById("debug_break_glass_ttl_minutes");

                const bgLinkWrap = document.getElementById("break_glass_link_wrap");
                const bgLink = document.getElementById("break_glass_link");

                const bgQrBtn = document.getElementById("break_glass_qr_btn");
                const bgQrModal = document.getElementById("break_glass_qr_modal");
                const bgQrClose = document.getElementById("break_glass_qr_close");
                const bgQrImg = document.getElementById("break_glass_qr_img");

                const showBtn = document.getElementById("noteinstieg_recovery_show_btn");
                const genBtn = document.getElementById("noteinstieg_recovery_generate_btn");

                const codesWrap = document.getElementById("noteinstieg_codes");
                const codesList = document.getElementById("noteinstieg_codes_list");
                const printBtn = document.getElementById("noteinstieg_print_btn");

                if (!sim || !m || !ui || !r || !bg || !bgSecret || !bgTtl || !etaShow || !etaDate || !etaTime || !etaClear || !bgLinkWrap || !bgLink || !bgQrBtn || !bgQrModal || !bgQrClose || !bgQrImg || !envBadge || !showBtn || !genBtn || !codesWrap || !codesList || !printBtn) return;

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
                        // ohne Clear, ohne Toast-Spam
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

                const setBadge = (maintenanceOn) => {
                    if (!badge) return;
                    if (maintenanceOn) {
                        badge.textContent = "WARTUNG AKTIV";
                        badge.style.background = "#dc2626";
                    } else {
                        badge.textContent = "LIVE";
                        badge.style.background = "#16a34a";
                    }
                };

                const setEnvBadge = (maintenanceOn) => {
                    if (!envBadge) return;

                    if (isProd) {
                        envBadge.textContent = "PRODUCTION";
                        envBadge.style.background = "#7c3aed";
                        return;
                    }

                    if (maintenanceOn && !!sim.checked) {
                        envBadge.textContent = "PROD-SIM";
                        envBadge.style.background = "#f59e0b";
                        return;
                    }

                    envBadge.textContent = "LOCAL";
                    envBadge.style.background = "#0ea5e9";
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
                    return (s || "").toString().trim().toUpperCase().replace(/\\s+/g, "");
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

                const clearCodes = () => {
                    stopCodesPolling();
                    codesList.innerHTML = "";
                    codesWrap.style.display = "none";
                    codesWrap.__codes = null;
                };

                const renderCodes = (codes) => {
                    clearCodes();
                    if (!Array.isArray(codes) || codes.length < 1) return;

                    codesWrap.__codes = codes.slice();

                    for (const c of codes) {
                        if (!c || typeof c.code !== "string") continue;

                        const div = document.createElement("div");
                        div.className = "ks-code-item" + (c.used ? " is-used" : "");
                        div.textContent = c.code;
                        codesList.appendChild(div);
                    }

                    codesWrap.style.display = "block";
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
                        await postJson("' . e(route('admin.settings.save.ajax')) . '", {
                            simulate_production: !!sim.checked,

                            maintenance_enabled: !!m.checked,
                            debug_ui_enabled: !!ui.checked,
                            debug_routes_enabled: !!r.checked,

                            break_glass_enabled: !!bg.checked,
                            break_glass_totp_secret: (bgSecret.value || ""),
                            break_glass_ttl_minutes: (bgTtl.value || "")
                        });

                        await postJson("' . e(route('admin.maintenance.eta.ajax')) . '", {
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

                const apply = () => {
                    if (!hasSettingsTable) {
                        m.disabled = true;
                    }
                    if (!hasSystemSettingsTable) {
                        ui.disabled = true;
                        r.disabled = true;
                        sim.disabled = true;
                        bg.disabled = true;
                        bgSecret.disabled = true;
                        bgTtl.disabled = true;
                        bgQrBtn.disabled = true;
                        bgQrBtn.style.display = "none";
                        bgLinkWrap.style.display = "none";
                        showBtn.disabled = true;
                        showBtn.style.display = "none";
                        genBtn.disabled = true;
                        clearCodes();
                    }

                    const maintenanceOn = !!m.checked;

                    setBadge(maintenanceOn);

                    etaShow.disabled = (!hasSettingsTable) || (!maintenanceOn);
                    etaDate.disabled = (!hasSettingsTable) || (!maintenanceOn);
                    etaTime.disabled = (!hasSettingsTable) || (!maintenanceOn);
                    etaClear.disabled = (!hasSettingsTable) || (!maintenanceOn);

                    if (hasSystemSettingsTable) {
                        const simShouldBeDisabled = isProd || !maintenanceOn;
                        sim.disabled = simShouldBeDisabled;
                        if (simShouldBeDisabled) {
                            sim.checked = false;
                        }
                    } else {
                        sim.checked = false;
                    }

                    setEnvBadge(maintenanceOn);

                    if (!maintenanceOn) {
                        etaShow.checked = false;
                        etaDate.value = "";
                        etaTime.value = "";

                        ui.checked = false;
                        r.checked = false;

                        bgTtl.value = "15";
                        bg.checked = false;

                        bgLinkWrap.style.display = "none";

                        bgQrBtn.disabled = true;
                        bgQrBtn.style.display = "none";
                        bgQrImg.removeAttribute("src");
                        closeQrModal();

                        showBtn.disabled = true;
                        showBtn.style.display = "none";
                        genBtn.disabled = true;
                        clearCodes();
                    }

                    if (hasSystemSettingsTable) {
                        ui.disabled = !maintenanceOn;

                        const debugOn = maintenanceOn && !!ui.checked;
                        r.disabled = !debugOn;

                        if (!debugOn) {
                            r.checked = false;
                        }
                    } else {
                        ui.checked = false;
                        r.checked = false;
                    }

                    const prodEffective = isProd || (maintenanceOn && !!sim.checked);

                    const breakGlassUiAllowed = maintenanceOn && prodEffective;

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

                        showBtn.disabled = true;
                        showBtn.style.display = "none";
                        genBtn.disabled = true;
                        clearCodes();
                        return;
                    }

                    bgLinkWrap.style.display = (!!bg.checked) ? "block" : "none";

                    if (!!bg.checked) {
                        showBtn.style.display = "inline-block";
                        showBtn.disabled = false;

                        genBtn.disabled = false;
                    } else {
                        showBtn.style.display = "none";
                        showBtn.disabled = true;

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

                const loadCodes = async ({ clear = true, toast = true } = {}) => {
                    try {
                        if (clear) {
                            clearCodes();
                        }

                        showBtn.disabled = true;

                        const out = await postJson("' . e(route('admin.noteinstieg.recovery.list.ajax')) . '", {});

                        if (!out || out.ok !== true || !Array.isArray(out.codes)) {
                            if (toast) showToast("Notfallcodes konnten nicht geladen werden.", true);
                            showBtn.disabled = false;
                            return;
                        }

                        renderCodes(out.codes);

                        if (toast) showToast("Notfallcodes geladen.");

                        // Polling nur wenn Liste sichtbar ist (nach renderCodes ist sie sichtbar)
                        startCodesPolling();

                        showBtn.disabled = false;
                    } catch (e) {
                        if (toast) showToast("Fehler beim Laden der Notfallcodes.", true);
                        showBtn.disabled = false;
                    }
                };

                showBtn.addEventListener("click", async () => {
                    await loadCodes();
                });

                genBtn.addEventListener("click", async () => {
                    try {
                        genBtn.disabled = true;

                        const out = await postJson("' . e(route('admin.noteinstieg.recovery.generate.ajax')) . '", {});

                        if (!out || out.ok !== true || !Array.isArray(out.codes) || out.codes.length !== 5) {
                            const msg = (out && typeof out.message === "string" && out.message !== "") ? out.message : "Notfallcodes konnten nicht erzeugt werden.";
                            showToast(msg, true);
                            genBtn.disabled = false;
                            return;
                        }

                        await loadCodes();
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

                    let html = "<!doctype html><html lang=\\"de\\"><head><meta charset=\\"utf-8\\">";
                    html += "<meta name=\\"viewport\\" content=\\"width=device-width, initial-scale=1\\">";
                    html += "<title>KiezSingles – Noteinstieg Notfallcodes</title>";
                    html += "<style>";
                    html += "@page { size: A4; margin: 18mm; }";
                    html += "body { font-family: system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; }";
                    html += "h1 { margin:0 0 6px 0; font-size:18px; }";
                    html += ".meta { color:#444; font-size:12px; margin:0 0 14px 0; }";
                    html += ".grid { display:grid; grid-template-columns: 1fr 1fr; gap:10px; }";
                    html += ".code { border:1px solid #ddd; border-radius:10px; padding:14px 10px; text-align:center; font-size:18px; font-weight:800; letter-spacing:1px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, \\"Liberation Mono\\", \\"Courier New\\", monospace; }";
                    html += ".code.used { text-decoration: line-through; opacity:.55; }";
                    html += ".hint { margin-top:14px; font-size:12px; color:#444; }";
                    html += "</style></head><body>";
                    html += "<h1>KiezSingles – Noteinstieg Notfallcodes</h1>";
                    html += "<p class=\\"meta\\">Stand " + esc(stamp) + " (durchgestrichen = bereits benutzt)</p>";
                    html += "<div class=\\"grid\\">";
                    for (const c of codes) {
                        if (!c || typeof c.code !== "string") continue;
                        html += "<div class=\\"code" + (c.used ? " used" : "") + "\\">" + esc(c.code) + "</div>";
                    }
                    html += "</div>";
                    html += "<div class=\\"hint\\">Hinweis: Notfallcodes funktionieren nur im Wartungsmodus bei aktivem Noteinstieg.</div>";
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

                sim.addEventListener("change", () => { apply(); scheduleSave(); });

                m.addEventListener("change", () => { apply(); scheduleSave(); });

                etaShow.addEventListener("change", () => { scheduleSave(); });
                etaDate.addEventListener("change", () => { scheduleSave(); });
                etaTime.addEventListener("change", () => { scheduleSave(); });

                etaClear.addEventListener("click", () => {
                    etaShow.checked = false;
                    etaDate.value = "";
                    etaTime.value = "";
                    scheduleSave();
                });

                ui.addEventListener("change", () => { apply(); scheduleSave(); });
                r.addEventListener("change", () => { apply(); scheduleSave(); });

                bg.addEventListener("change", () => { apply(); scheduleSave(); });
                bgTtl.addEventListener("input", () => { scheduleSave(); });

                apply();
            })();
        </script>';

        $html .= '</div>';

        $html .= '<p style="margin:0;"><a href="' . e(route('profile.edit')) . '">Zurück zum Profil</a></p>';

        $html .= '</body></html>';

        return response($html, 200);
    }
}
