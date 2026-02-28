{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\develop.blade.php
Purpose: Admin develop page (layout outlines controls)
Changed: 27-02-2026 19:15 (Europe/Berlin)
Version: 0.5
============================================================================ --}}

@extends('admin.layouts.admin')

@php
    $adminTab = 'develop';
    $hasSystemSettingsTable = $hasSystemSettingsTable ?? true;

    $maintenanceEnabled = (bool) ($maintenanceEnabled ?? false);

    $layoutOutlinesFrontendEnabled = (bool) ($layoutOutlinesFrontendEnabled ?? false);
    $layoutOutlinesAdminEnabled = (bool) ($layoutOutlinesAdminEnabled ?? false);
    $layoutOutlinesAllowProduction = (bool) ($layoutOutlinesAllowProduction ?? false);
@endphp

@section('content')
    @if(!empty($notice))
        <div class="ks-notice p-3 rounded-lg border mb-3">
            {{ $notice }}
        </div>
    @endif

    <div class="ks-card">
        <h3>Develop</h3>
        <p class="mb-3">Layout Outlines (Debug-Rahmen).</p>

        @if(!$hasSystemSettingsTable)
            <p class="m-0 text-sm text-red-700 mb-3">
                Hinweis: Tabelle <code>debug_settings</code> fehlt. Speichern nicht möglich.
            </p>
        @endif

        <div class="space-y-3">
            <div class="ks-row">
                <div class="ks-label">
                    <div>
                        <strong>Frontend-Rahmen</strong> <span class="text-gray-600">(<code>debug.layout_outlines_frontend_enabled</code>)</span>
                    </div>
                    <div class="ks-sub">Nur visuell, ohne Funktionsänderung.</div>
                </div>

                <form method="POST" action="{{ route('admin.settings.layout_outlines') }}" class="m-0">
                    @csrf
                    <input type="hidden" name="layout_outlines_frontend_enabled" value="0">
                    <label class="ks-toggle ml-auto">
                        <input
                            type="checkbox"
                            name="layout_outlines_frontend_enabled"
                            value="1"
                            @checked($layoutOutlinesFrontendEnabled)
                            @disabled(!$hasSystemSettingsTable)
                            onchange="this.form.submit()"
                        >
                        <span class="ks-slider"></span>
                    </label>
                    <noscript>
                        <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900" @disabled(!$hasSystemSettingsTable)>Speichern</button>
                    </noscript>
                </form>
            </div>

            <div class="ks-row">
                <div class="ks-label">
                    <div>
                        <strong>Admin-Rahmen</strong> <span class="text-gray-600">(<code>debug.layout_outlines_admin_enabled</code>)</span>
                    </div>
                    <div class="ks-sub">Nur visuell, ohne Funktionsänderung.</div>
                </div>

                <form method="POST" action="{{ route('admin.settings.layout_outlines') }}" class="m-0">
                    @csrf
                    <input type="hidden" name="layout_outlines_admin_enabled" value="0">
                    <label class="ks-toggle ml-auto">
                        <input
                            type="checkbox"
                            name="layout_outlines_admin_enabled"
                            value="1"
                            @checked($layoutOutlinesAdminEnabled)
                            @disabled(!$hasSystemSettingsTable)
                            onchange="this.form.submit()"
                        >
                        <span class="ks-slider"></span>
                    </label>
                    <noscript>
                        <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900" @disabled(!$hasSystemSettingsTable)>Speichern</button>
                    </noscript>
                </form>
            </div>

            <div class="ks-row">
                <div class="ks-label">
                    <div>
                        <strong>Production erlauben</strong> <span class="text-gray-600">(<code>debug.layout_outlines_allow_production</code>)</span>
                    </div>
                    <div class="ks-sub">Standard: aus (fail-closed). Nur schaltbar im Wartungsmodus.</div>
                </div>

                <form method="POST" action="{{ route('admin.settings.layout_outlines') }}" class="m-0">
                    @csrf
                    <input type="hidden" name="layout_outlines_allow_production" value="0">
                    <label class="ks-toggle ml-auto">
                        <input
                            type="checkbox"
                            name="layout_outlines_allow_production"
                            value="1"
                            @checked($layoutOutlinesAllowProduction)
                            @disabled(!$hasSystemSettingsTable || !$maintenanceEnabled)
                            onchange="this.form.submit()"
                        >
                        <span class="ks-slider"></span>
                    </label>
                    <noscript>
                        <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900" @disabled(!$hasSystemSettingsTable || !$maintenanceEnabled)>Speichern</button>
                    </noscript>
                </form>
            </div>
        </div>
    </div>
@endsection
