<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\overview.blade.php
// Purpose: Admin Security - Overview dashboard (reduced, decision-focused)
// Changed: 27-03-2026 00:51 (Europe/Berlin)
// Version: 1.1
// ============================================================================

?>
@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    @php
        $failedLoginsColor = '#e6f7ff';
        if ($failedLogins24h > 100) {
            $failedLoginsColor = '#ffe5e5';
        } elseif ($failedLogins24h > 20) {
            $failedLoginsColor = '#fff3cd';
        }

        $ipBansColor = '#e6f7ff';
        if ($activeIpBans > 100) {
            $ipBansColor = '#ffe5e5';
        } elseif ($activeIpBans > 20) {
            $ipBansColor = '#fff3cd';
        }

        $identityBansColor = '#e6f7ff';
        if ($activeIdentityBans > 100) {
            $identityBansColor = '#ffe5e5';
        } elseif ($activeIdentityBans > 20) {
            $identityBansColor = '#fff3cd';
        }

        $deviceBansColor = '#e6f7ff';
        if ($activeDeviceBans > 100) {
            $deviceBansColor = '#ffe5e5';
        } elseif ($activeDeviceBans > 20) {
            $deviceBansColor = '#fff3cd';
        }
    @endphp

    {{-- =======================
        HAUPT: Sicherheitslage
    ======================== --}}
    <div style="
        margin-bottom:20px;
        padding:15px;
        border-radius:10px;
        background:
        @if($highIncidents > 0) #ffe5e5
        @elseif(($incidentStats->open ?? 0) > 0) #fff3cd
        @else #e6f7ff
        @endif;
    ">
        <strong>Aktive Sicherheitslage (letzte 24h)</strong>

        <div style="margin-top:8px; display:flex; gap:20px;">
            <div>🔴 Kritisch: {{ $highIncidents }}</div>
            <div>🟠 Offen: {{ $incidentStats->open ?? 0 }}</div>
            <div>🟢 Erledigt: {{ $incidentStats->resolved ?? 0 }}</div>
        </div>
    </div>

    {{-- =======================
        KPI (kompakt)
    ======================== --}}
    <div class="grid grid-cols-1 md:grid-cols-4 gap-3 mb-4">

        <div class="ks-card">
            <h3>Fehlgeschlagene Logins</h3>
            <div style="background: {{ $failedLoginsColor }}; padding:10px; border-radius:6px;">
                <p class="text-xl font-semibold">{{ $failedLogins24h }}</p>
            </div>
        </div>

        <div class="ks-card">
            <h3>IP-Sperren</h3>
            <div style="background: {{ $ipBansColor }}; padding:10px; border-radius:6px;">
                <p class="text-xl font-semibold">{{ $activeIpBans }}</p>
            </div>
        </div>

        <div class="ks-card">
            <h3>Identitäts-Sperren</h3>
            <div style="background: {{ $identityBansColor }}; padding:10px; border-radius:6px;">
                <p class="text-xl font-semibold">{{ $activeIdentityBans }}</p>
            </div>
        </div>

        <div class="ks-card">
            <h3>Geräte-Sperren</h3>
            <div style="background: {{ $deviceBansColor }}; padding:10px; border-radius:6px;">
                <p class="text-xl font-semibold">{{ $activeDeviceBans }}</p>
            </div>
        </div>

    </div>

    {{-- =======================
        KORRELATIONEN (nur wenn vorhanden)
    ======================== --}}
    @if($topCorrelatedDevices->count() > 0 || $topCorrelatedEmails->count() > 0)
        <div class="grid grid-cols-1 xl:grid-cols-2 gap-3 mb-4">

            @if($topCorrelatedDevices->count() > 0)
                <div class="ks-card" style="background:#ffe5e5;">
                    <div class="flex items-start justify-between gap-3 mb-3">
                        <h3>Geräte-Korrelationen</h3>

                        <a class="ks-btn" href="{{ route('admin.security.events.index') }}">
                            Öffnen
                        </a>
                    </div>

                    <div class="overflow-x-auto">
                        <table class="w-full text-sm">
                            <thead>
                                <tr>
                                    <th class="text-left px-2 py-1">Gerät</th>
                                    <th class="px-2 py-1">E-Mails</th>
                                    <th class="px-2 py-1">IPs</th>
                                    <th class="px-2 py-1">Events</th>
                                </tr>
                            </thead>
                            <tbody>
                            @foreach($topCorrelatedDevices as $row)
                                <tr>
                                    <td class="px-2 py-1 break-all">{{ $row->device_hash }}</td>
                                    <td class="px-2 py-1">{{ $row->email_count }}</td>
                                    <td class="px-2 py-1">{{ $row->ip_count }}</td>
                                    <td class="px-2 py-1">{{ $row->aggregate_count }}</td>
                                </tr>
                            @endforeach
                            </tbody>
                        </table>
                    </div>
                </div>
            @endif

            @if($topCorrelatedEmails->count() > 0)
                <div class="ks-card" style="background:#ffe5e5;">
                    <div class="flex items-start justify-between gap-3 mb-3">
                        <h3>E-Mail-Korrelationen</h3>

                        <a class="ks-btn" href="{{ route('admin.security.events.index') }}">
                            Öffnen
                        </a>
                    </div>

                    <div class="overflow-x-auto">
                        <table class="w-full text-sm">
                            <thead>
                                <tr>
                                    <th class="text-left px-2 py-1">E-Mail</th>
                                    <th class="px-2 py-1">Geräte</th>
                                    <th class="px-2 py-1">IPs</th>
                                    <th class="px-2 py-1">Events</th>
                                </tr>
                            </thead>
                            <tbody>
                            @foreach($topCorrelatedEmails as $row)
                                <tr>
                                    <td class="px-2 py-1 break-all">{{ $row->email }}</td>
                                    <td class="px-2 py-1">{{ $row->device_count }}</td>
                                    <td class="px-2 py-1">{{ $row->ip_count }}</td>
                                    <td class="px-2 py-1">{{ $row->aggregate_count }}</td>
                                </tr>
                            @endforeach
                            </tbody>
                        </table>
                    </div>
                </div>
            @endif

        </div>
    @endif

@endsection
