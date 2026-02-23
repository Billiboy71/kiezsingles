{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\debug.blade.php
Purpose: Admin Debug UI (toggles + log tail) – rendered via view() from routes/web/admin/debug.php
Changed: 19-02-2026 00:17 (Europe/Berlin)
Version: 0.2
============================================================================ --}}

@extends('admin.layouts.admin')

@section('content')

    <div class="ks-card mb-4">
        <div class="text-sm font-extrabold text-gray-900 mb-4">Schalter</div>

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>LOCAL Debug Banner anzeigen</strong>
                    <span class="ks-info" title="Blendet das gelbe LOCAL DEBUG Banner im Admin-Layout ein/aus (nur LOCAL).">i</span>
                </div>
                <div class="ks-sub"><code>debug.local_banner_enabled</code></div>
            </div>

            <form method="POST" action="{{ url('/admin/debug/toggle') }}" class="m-0 flex-shrink-0">
                @csrf
                <input type="hidden" name="key" value="debug.local_banner_enabled">
                <input type="hidden" name="value" value="{{ $debugLocalBannerEnabled ? '1' : '0' }}">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        @checked($debugLocalBannerEnabled)
                        onchange="this.form.value.value = this.checked ? '1' : '0'; this.form.submit();"
                    >
                    <span class="ks-slider"></span>
                </label>
            </form>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>Debug UI (Master)</strong>
                    <span class="ks-info" title="Master-Schalter für Debug-Funktionen.">i</span>
                </div>
                <div class="ks-sub"><code>debug.ui_enabled</code></div>
            </div>

            <form method="POST" action="{{ url('/admin/debug/toggle') }}" class="m-0 flex-shrink-0">
                @csrf
                <input type="hidden" name="key" value="debug.ui_enabled">
                <input type="hidden" name="value" value="{{ $debugUiEnabled ? '1' : '0' }}">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        @checked($debugUiEnabled)
                        onchange="this.form.value.value = this.checked ? '1' : '0'; this.form.submit();"
                    >
                    <span class="ks-slider"></span>
                </label>
            </form>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>Debug Routes</strong>
                    <span class="ks-info" title="Aktiviert zusätzliche Debug-Routen.">i</span>
                </div>
                <div class="ks-sub"><code>debug.routes_enabled</code></div>
            </div>

            <form method="POST" action="{{ url('/admin/debug/toggle') }}" class="m-0 flex-shrink-0">
                @csrf
                <input type="hidden" name="key" value="debug.routes_enabled">
                <input type="hidden" name="value" value="{{ $getBool('debug.routes_enabled', false) ? '1' : '0' }}">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        @checked((bool) $getBool('debug.routes_enabled', false))
                        onchange="this.form.value.value = this.checked ? '1' : '0'; this.form.submit();"
                    >
                    <span class="ks-slider"></span>
                </label>
            </form>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>Turnstile Debug</strong>
                    <span class="ks-info" title="Aktiviert Debug-Modus für Turnstile (Diagnose/Tests je nach Implementierung).">i</span>
                </div>
                <div class="ks-sub"><code>debug.turnstile_enabled</code></div>
            </div>

            <form method="POST" action="{{ url('/admin/debug/toggle') }}" class="m-0 flex-shrink-0">
                @csrf
                <input type="hidden" name="key" value="debug.turnstile_enabled">
                <input type="hidden" name="value" value="{{ $debugTurnstile ? '1' : '0' }}">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        @checked($debugTurnstile)
                        onchange="this.form.value.value = this.checked ? '1' : '0'; this.form.submit();"
                    >
                    <span class="ks-slider"></span>
                </label>
            </form>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>Register: Validation Errors loggen</strong>
                    <span class="ks-info" title="Wenn aktiv: Registrierungs-Validierungsfehler werden protokolliert.">i</span>
                </div>
                <div class="ks-sub"><code>debug.register_errors</code></div>
            </div>

            <form method="POST" action="{{ url('/admin/debug/toggle') }}" class="m-0 flex-shrink-0">
                @csrf
                <input type="hidden" name="key" value="debug.register_errors">
                <input type="hidden" name="value" value="{{ $debugRegisterErrors ? '1' : '0' }}">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        @checked($debugRegisterErrors)
                        onchange="this.form.value.value = this.checked ? '1' : '0'; this.form.submit();"
                    >
                    <span class="ks-slider"></span>
                </label>
            </form>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>Register: Payload in Session flashen</strong>
                    <span class="ks-info" title="Wenn aktiv: Registrierungs-Payload wird in die Session geflasht (nur Debugging).">i</span>
                </div>
                <div class="ks-sub"><code>debug.register_payload</code></div>
            </div>

            <form method="POST" action="{{ url('/admin/debug/toggle') }}" class="m-0 flex-shrink-0">
                @csrf
                <input type="hidden" name="key" value="debug.register_payload">
                <input type="hidden" name="value" value="{{ $debugRegisterPayload ? '1' : '0' }}">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        @checked($debugRegisterPayload)
                        onchange="this.form.value.value = this.checked ? '1' : '0'; this.form.submit();"
                    >
                    <span class="ks-slider"></span>
                </label>
            </form>
        </div>
    </div>

    <div class="ks-card">
        <div class="text-sm font-extrabold text-gray-900 mb-3">Logs</div>

        <form method="POST" action="{{ url('/admin/debug/log-tail') }}" class="m-0 mb-3">
            @csrf
            <button type="submit" class="inline-flex items-center px-4 py-2 rounded-xl border border-gray-300 bg-white text-xs font-extrabold text-gray-900 uppercase tracking-widest hover:bg-gray-50">
                Letzte Logzeilen laden
            </button>
        </form>

        @if(!empty($logLines))
            <pre class="whitespace-pre-wrap bg-gray-900 text-gray-100 px-4 py-3 rounded-xl border border-gray-800 overflow-auto max-h-[420px] m-0">{{ implode("\n", array_map(fn($l) => (string) $l, $logLines)) }}</pre>
        @else
            <div class="text-sm text-gray-600">(noch keine Logausgabe geladen)</div>
        @endif
    </div>

@endsection
