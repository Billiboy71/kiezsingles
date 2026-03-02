<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\overview.blade.php
// Purpose: Admin Security - Overview dashboard (24h aggregates, top IPs/device hashes)
// Changed: 02-03-2026 00:52 (Europe/Berlin)
// Version: 0.2
// ============================================================================

?>
@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    <div class="ks-card mb-4">
        <div class="flex items-start justify-between gap-3">
            <h3>Sicherheits-Übersicht</h3>
            <x-ui.help-popover id="security-overview-help" title="Hilfe: Übersicht">
                <ul>
                    <li>Die Kennzahlen laufen in einem rollenden 24h-Fenster und beziehen sich immer auf jetzt minus 24 Stunden.</li>
                    <li>Es gibt keinen manuellen Reset. Bei sinkender Aktivität gehen Werte von allein wieder runter.</li>
                    <li>Fehlgeschlagene Logins, auffällige IPs und Geräte-Hashes kommen aus den Sicherheitsereignissen.</li>
                    <li>Aktive IP-Sperren und aktive Identitäts-Sperren kommen aus den aktiven Sperr-Einträgen (TTL offen oder noch nicht abgelaufen).</li>
                    <li>Gesperrte Konten zeigt die Anzahl von Nutzern mit aktivem Freeze-Flag.</li>
                    <li>Diese Seite ist nur zur Analyse. Sperren und Entsperren passiert in IP-Sperren oder Identitäts-Sperren.</li>
                </ul>
            </x-ui.help-popover>
        </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-4">
        <div class="ks-card"><h3>Fehlgeschlagene Logins (24h)</h3><p class="text-2xl font-semibold">{{ $failedLogins24h }}</p></div>
        <div class="ks-card"><h3>Aktive IP-Sperren</h3><p class="text-2xl font-semibold">{{ $activeIpBans }}</p></div>
        <div class="ks-card"><h3>Aktive Identitäts-Sperren</h3><p class="text-2xl font-semibold">{{ $activeIdentityBans }}</p></div>
        <div class="ks-card"><h3>Gesperrte Konten</h3><p class="text-2xl font-semibold">{{ $frozenAccounts }}</p></div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div class="ks-card">
            <h3>Auffällige IPs (Top)</h3>
            <table class="w-full text-sm">
                <thead><tr><th class="text-left">IP</th><th class="text-left">Anzahl</th></tr></thead>
                <tbody>
                @forelse($topSuspiciousIps as $row)
                    <tr><td>{{ $row->ip }}</td><td>{{ $row->aggregate_count }}</td></tr>
                @empty
                    <tr><td colspan="2">Keine Daten.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>

        <div class="ks-card">
            <h3>Geräte-Hashes (Top)</h3>
            <table class="w-full text-sm">
                <thead><tr><th class="text-left">Geräte-Hash</th><th class="text-left">Anzahl</th></tr></thead>
                <tbody>
                @forelse($topDeviceHashes as $row)
                    <tr><td class="break-all">{{ $row->device_hash }}</td><td>{{ $row->aggregate_count }}</td></tr>
                @empty
                    <tr><td colspan="2">Keine Daten.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>
    </div>
@endsection
