{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\maintenance.blade.php
Purpose: Admin maintenance page (restored full maintenance + debug UI, based on historical routes/web.php UI)
Changed: 25-02-2026 15:55 (Europe/Berlin)
Version: 1.9
============================================================================ --}}

@extends('admin.layouts.admin')

@php
    $adminTab = 'maintenance';

    $hasSettingsTable = $hasSettingsTable ?? true;
    $hasSystemSettingsTable = $hasSystemSettingsTable ?? true;

    $maintenanceEnabled = (bool) ($maintenanceEnabled ?? false);
    $maintenanceShowEta = (bool) ($maintenanceShowEta ?? false);

    $etaDateValue = (string) ($etaDateValue ?? '');
    $etaTimeValue = (string) ($etaTimeValue ?? '');

    // Defensive UI policy: if 00:00 is present, treat as "no time".
    if ($etaTimeValue === '00:00') {
        $etaTimeValue = '';
    }

    // UI policy: if ETA display is off, do not prefill date/time inputs (matches "disabled => cleared" behavior on reload).
    $etaDateInputValue = $maintenanceShowEta ? $etaDateValue : '';
    $etaTimeInputValue = $maintenanceShowEta ? $etaTimeValue : '';

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

    // Preview text for maintenance ETA (admin page)
    $etaPreviewText = '';
    if ($maintenanceShowEta && $etaDateValue !== '') {
        $etaPreviewText = 'Voraussichtlich bis zum ' . $etaDateValue;
        if ($etaTimeValue !== '') {
            $etaPreviewText .= ' ' . $etaTimeValue . ' Uhr';
        }
    }
@endphp

@section('content')

    @if(!empty($notice))
        <div class="ks-notice p-3 rounded-lg border mb-3">
            {{ $notice }}
        </div>
    @endif

    <div
        id="ks_toast"
        class="hidden mb-4 px-4 py-3 rounded-lg border border-green-200 bg-green-50 text-sm text-gray-900"
    ></div>

    <div
        id="ks_status_wrap"
        class="p-4 rounded-lg border mb-4 {{ $maintenanceEnabled ? 'border-red-200 bg-red-50' : 'border-green-200 bg-green-50' }}"
        data-ks-has-settings-table="{{ $hasSettingsTable ? '1' : '0' }}"
        data-ks-has-system-settings-table="{{ $hasSystemSettingsTable ? '1' : '0' }}"
        data-ks-is-prod="{{ $isProd ? '1' : '0' }}"
        data-ks-url-settings-save-ajax="{{ route('admin.settings.save.ajax') }}"
        data-ks-url-maintenance-eta-ajax="{{ route('admin.maintenance.eta.ajax') }}"
        data-ks-url-recovery-list-ajax="{{ route('admin.noteinstieg.recovery.list.ajax') }}"
        data-ks-url-recovery-generate-ajax="{{ route('admin.noteinstieg.recovery.generate.ajax') }}"
    >

        @if(!$hasSettingsTable)
            <p class="m-0 text-sm text-red-700">
                Hinweis: Tabelle <code>app_settings</code> existiert nicht. Wartung kann hier nicht geschaltet werden.
            </p>
        @endif

        @if(!$hasSystemSettingsTable)
            <p class="m-0 text-sm mt-2 text-red-700">
                Hinweis: Tabelle <code>system_settings</code> existiert nicht. Debug-Schalter können nicht gespeichert werden.
            </p>
        @endif

        <input type="hidden" id="ks_csrf" value="{{ csrf_token() }}">

        @php
            $maintenanceDisabled = (!$hasSettingsTable) ? ' disabled' : '';
            $systemSettingsDisabled = (!$hasSystemSettingsTable) ? ' disabled' : '';
        @endphp

        {{-- Wartung --}}
        <div class="ks-row mb-3">
            <div class="ks-label">
                <div>
                    <strong>Wartungsmodus aktiv</strong>
                    <span class="ks-info" title="Schaltet den Wartungsmodus ein. Blockiert normale Nutzung, bis du Wartung wieder ausschaltest.">i</span>
                </div>
                <div class="ks-sub">Blockiert normale Nutzung, bis du Wartung wieder ausschaltest.</div>
            </div>

            <label class="ks-toggle ml-auto">
                <input type="checkbox" id="maintenance_enabled" name="maintenance_enabled" value="1" @checked($maintenanceEnabled) {!! $maintenanceDisabled !!}>
                <span class="ks-slider"></span>
            </label>
        </div>

        <div class="ks-row mb-3">
            <div class="ks-label">
                <div>
                    <strong>Wartungsende anzeigen</strong>
                    <span class="ks-info" title="Zeigt das Wartungsende im Wartungshinweis an. Nur aktivierbar, wenn Wartung eingeschaltet ist.">i</span>
                </div>
                <div class="ks-sub">Zeigt das Wartungsende im Wartungshinweis an.</div>
            </div>

            <label class="ks-toggle ml-auto">
                <input type="checkbox" id="maintenance_show_eta" name="maintenance_show_eta" value="1" @checked($maintenanceShowEta) {!! $maintenanceDisabled !!}>
                <span class="ks-slider"></span>
            </label>
        </div>

        <label class="block mb-[6px] font-semibold">Wartung endet am</label>

        <div class="flex gap-[10px] flex-wrap items-center mb-[10px]">
            <input
                type="date"
                id="maintenance_eta_date"
                name="maintenance_eta_date"
                value="{{ $etaDateInputValue }}"
                class="px-[12px] py-[10px] border border-gray-300 rounded-[10px] w-[170px] bg-white"
                {!! $maintenanceDisabled !!}
            >
            <input
                type="time"
                id="maintenance_eta_time"
                name="maintenance_eta_time"
                value="{{ $etaTimeInputValue }}"
                class="px-[12px] py-[10px] border border-gray-300 rounded-[10px] w-[120px] bg-white"
                {!! $maintenanceDisabled !!}
            >
            <button
                type="button"
                id="maintenance_eta_clear"
                title="Zurücksetzen"
                class="w-[46px] h-[26px] rounded-full border border-slate-300 bg-white inline-flex items-center justify-center p-0 leading-none select-none hover:bg-slate-50 active:bg-slate-100 disabled:opacity-45 disabled:cursor-not-allowed"
                {!! $maintenanceDisabled !!}
            >
                <span class="text-[14px] -translate-y-[.5px]">×</span>
            </button>
        </div>

        @if($etaPreviewText !== '')
            <div class="text-sm text-gray-700 mb-3">
                {{ $etaPreviewText }}
            </div>
        @else
            <div class="text-sm text-gray-500 mb-3">
                @if($maintenanceShowEta)
                    Hinweis: Datum reicht aus (Uhrzeit optional).
                @else
                    Hinweis: Wartungsende ist deaktiviert.
                @endif
            </div>
        @endif

        {{-- Notify --}}
        <div class="ks-row mb-3">
            <div class="ks-label">
                <div>
                    <strong>E-Mail-Notify im Wartungsmodus</strong> <span class="text-gray-600">(<code>maintenance.notify_enabled</code>)</span>
                    <span class="ks-info" title="Zeigt im Wartungsmodus ein E-Mail-Feld auf der öffentlichen Wartungsseite. Wenn Wartung beendet wird, können gespeicherte Adressen benachrichtigt werden (serverseitig).">i</span>
                </div>
                <div class="ks-sub">Nur relevant, solange Wartung aktiv ist.</div>
            </div>

            <label class="ks-toggle ml-auto">
                <input type="checkbox" id="maintenance_notify_enabled" name="maintenance_notify_enabled" value="1" @checked($maintenanceNotifyEnabled) {!! $systemSettingsDisabled !!}>
                <span class="ks-slider"></span>
            </label>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        {{-- Login-Allowlist im Wartungsmodus --}}
        <div class="ks-row mb-3">
            <div class="ks-label">
                <div>
                    <strong>Admins dürfen sich einloggen</strong> <span class="text-gray-600">(<code>maintenance.allow_admins</code>)</span>
                    <span class="ks-info" title="Wenn aktiv: Rolle admin darf sich im Wartungsmodus einloggen. Superadmin ist immer erlaubt.">i</span>
                </div>
                <div class="ks-sub">Gilt nur, solange Wartung aktiv ist. Superadmin immer erlaubt.</div>
            </div>

            <label class="ks-toggle ml-auto">
                <input type="checkbox" id="maintenance_allow_admins" name="maintenance_allow_admins" value="1" @checked($maintenanceAllowAdmins) {!! $systemSettingsDisabled !!}>
                <span class="ks-slider"></span>
            </label>
        </div>

        <div class="ks-row mb-3">
            <div class="ks-label">
                <div>
                    <strong>Moderatoren dürfen sich einloggen</strong> <span class="text-gray-600">(<code>maintenance.allow_moderators</code>)</span>
                    <span class="ks-info" title="Wenn aktiv: Rolle moderator darf sich im Wartungsmodus einloggen (sonst ausgesperrt). Superadmin ist immer erlaubt.">i</span>
                </div>
                <div class="ks-sub">Gilt nur, solange Wartung aktiv ist.</div>
            </div>

            <label class="ks-toggle ml-auto">
                <input type="checkbox" id="maintenance_allow_moderators" name="maintenance_allow_moderators" value="1" @checked($maintenanceAllowModerators) {!! $systemSettingsDisabled !!}>
                <span class="ks-slider"></span>
            </label>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        {{-- Simulate Production + Noteinstieg --}}
        @if(!$isProd)
            <div class="ks-row mb-3">
                <div class="ks-label">
                    <div>
                        <strong>Live-Modus simulieren</strong> <span class="text-gray-600">(<code>debug.simulate_production</code>)</span>
                        <span class="ks-info" title="Schaltet lokal in einen Live-Simulationsmodus (für Noteinstieg Tests). In Production wird dieser Schalter nicht angezeigt.">i</span>
                    </div>
                    <div class="ks-sub">In Production hat dieser Schalter keine Wirkung.</div>
                </div>

                <label class="ks-toggle ml-auto">
                    <input type="checkbox" id="debug_simulate_production" name="debug_simulate_production" value="1" @checked($simulateProd) {!! $systemSettingsDisabled !!}>
                    <span class="ks-slider"></span>
                </label>
            </div>
        @endif

        <div class="ks-row mb-3">
            <div class="ks-label">
                <div>
                    <strong>Noteinstieg aktiv</strong> <span class="text-gray-600">(<code>debug.break_glass</code>)</span>
                    <span class="ks-info" title="Notfallzugang (Ebene 3). Nur sinnvoll im Wartungsmodus.">i</span>
                </div>
                <div class="ks-sub">Schaltet Noteinstieg frei.</div>
            </div>

            <label class="ks-toggle ml-auto">
                <input type="checkbox" id="debug_break_glass" name="debug_break_glass" value="1" @checked($breakGlassEnabled) {!! $systemSettingsDisabled !!}>
                <span class="ks-slider"></span>
            </label>
        </div>

        <div id="break_glass_link_wrap" class="hidden mt-[-6px] mb-3">
            <div class="ks-sub">Link zum Testen (öffnet Noteinstieg Eingabe):</div>
            <a
                id="break_glass_link"
                href="{{ url('/noteinstieg?next=/noteinstieg-einstieg') }}"
                target="_blank"
                rel="noopener noreferrer"
                class="break-words text-sky-500 underline"
                title="Privates Fenster kann nicht erzwungen werden (Browser-Funktion)."
            >
                {{ url('/noteinstieg?next=/noteinstieg-einstieg') }}
            </a>
        </div>

        <label class="block mt-3 mb-[6px] font-semibold">Noteinstieg TTL (Minuten)</label>

        <div class="flex items-center gap-[10px] flex-wrap">
            <input
                type="number"
                id="debug_break_glass_ttl_minutes"
                name="debug_break_glass_ttl_minutes"
                min="1"
                max="120"
                value="{{ (string) $breakGlassTtlMinutes }}"
                class="px-[12px] py-[10px] border border-gray-300 rounded-[10px] w-[160px] bg-white"
                {!! $systemSettingsDisabled !!}
            >
            <button type="button" id="break_glass_qr_btn" class="ks-btn hidden" {!! $systemSettingsDisabled !!}>QR-Code anzeigen</button>
            <button type="button" id="noteinstieg_recovery_btn" class="ks-btn hidden" {!! $systemSettingsDisabled !!}>Notfallcodes anzeigen</button>
        </div>

        <div
            id="noteinstieg_codes"
            class="hidden mt-[10px] p-3 rounded-[10px] border border-gray-200 bg-white"
        >
            <h3 class="m-0 mb-2 text-[14px] font-bold text-gray-900">Notfallcodes (einmalig)</h3>
            <div id="noteinstieg_codes_list"></div>
            <div class="flex gap-[10px] flex-wrap mt-2 justify-center">
                <button type="button" id="noteinstieg_recovery_generate_btn" class="ks-btn">5 neue Notfallcodes erzeugen</button>
                <button type="button" id="noteinstieg_print_btn" class="ks-btn">Drucken</button>
            </div>
        </div>

        <input type="hidden" id="debug_break_glass_totp_secret" name="debug_break_glass_totp_secret" value="{{ $breakGlassTotpSecret }}" {!! $systemSettingsDisabled !!}>

        <div
            id="break_glass_qr_modal"
            class="hidden fixed inset-0 bg-black/55 z-[9999] items-center justify-center p-6"
            aria-hidden="true"
        >
            <div
                class="w-full max-w-[420px] bg-white rounded-[12px] border border-gray-200 shadow-[0_10px_25px_rgba(0,0,0,.25)] p-[14px]"
                role="dialog"
                aria-modal="true"
                aria-label="Google Authenticator QR-Code"
            >
                <div class="flex items-center justify-between gap-3 mb-[10px]">
                    <div class="font-bold text-gray-900">Google Authenticator</div>
                    <button
                        type="button"
                        id="break_glass_qr_close"
                        aria-label="Schließen"
                        class="w-[34px] h-[34px] rounded-[10px] border border-slate-300 bg-white inline-flex items-center justify-center p-0 leading-none select-none hover:bg-slate-50 active:bg-slate-100"
                    >
                        ×
                    </button>
                </div>

                <img
                    id="break_glass_qr_img"
                    alt="Break-Glass QR"
                    width="320"
                    height="320"
                    class="block w-full h-auto rounded-[10px] border border-gray-200"
                >
            </div>
        </div>

    </div>

@endsection