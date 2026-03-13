<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\overview.blade.php
// Purpose: Admin Security - Overview dashboard (24h aggregates, top IPs/device hashes)
// Changed: 12-03-2026 16:31 (Europe/Berlin)
// Version: 0.7
// ============================================================================

?>
@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    <div class="ks-card mb-4">
        <div class="flex items-start justify-between gap-3">
            <h3>Security Overview</h3>
            <x-ui.help-popover id="security-overview-help" title="Hilfe: Übersicht">
                <ul>
                    <li>Die Kennzahlen laufen in einem rollenden 24h-Fenster und beziehen sich immer auf jetzt minus 24 Stunden.</li>
                    <li>Es gibt keinen manuellen Reset. Bei sinkender Aktivität gehen Werte von allein wieder runter.</li>
                    <li>Fehlgeschlagene Logins, auffällige IPs, Geräte-Hashes und E-Mails kommen aus den Sicherheitsereignissen.</li>
                    <li>Aktive IP-, Identitäts- und Geräte-Sperren kommen aus den aktiven Sperr-Einträgen (TTL offen oder noch nicht abgelaufen).</li>
                    <li>Gesperrte Konten zeigt die Anzahl von Nutzern mit aktivem Freeze-Flag.</li>
                    <li>Diese Seite ist das Lagebild fur schnelle Priorisierung. Sperren und Entsperren passiert in den jeweiligen Protection-Tabs.</li>
                    <li>Fur Detail-Korrelationen, Filter, Drilldown und Event-Tabellen direkt in den Tab „Event Analysis“ wechseln.</li>
                    <li>Korrelationen werden hier nur als kurze Teaser gezeigt, die vollstandige Analyse liegt ausschliesslich in „Event Analysis“.</li>
                </ul>
            </x-ui.help-popover>
        </div>

        <p class="text-sm mt-3">
            Verdichtetes Lagebild mit 24h-KPIs, auffälligen Mustern und direkten Sprungpunkten zur Event Analysis.
        </p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-4">
        <div class="ks-card">
            <h3>Fehlgeschlagene Logins (24h)</h3>
            <p class="text-2xl font-semibold">{{ $failedLogins24h }}</p>
        </div>
        <div class="ks-card">
            <h3>Aktive IP-Sperren</h3>
            <p class="text-2xl font-semibold">{{ $activeIpBans }}</p>
        </div>
        <div class="ks-card">
            <h3>Aktive Identitäts-Sperren</h3>
            <p class="text-2xl font-semibold">{{ $activeIdentityBans }}</p>
        </div>
        <div class="ks-card">
            <h3>Aktive Geräte-Sperren</h3>
            <p class="text-2xl font-semibold">{{ $activeDeviceBans }}</p>
        </div>
        <div class="ks-card">
            <h3>Gesperrte Konten</h3>
            <p class="text-2xl font-semibold">{{ $frozenAccounts }}</p>
        </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3 mb-4">
        <div class="ks-card">
            <div class="flex items-start justify-between gap-3 mb-3">
                <h3>Auffällige IPs (Top)</h3>

                <a class="ks-btn" href="{{ route('admin.security.events.index') }}">
                    Event Analysis
                </a>
            </div>

            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead>
                        <tr>
                            <th class="text-left px-2 py-1">IP</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Anzahl</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Aktion</th>
                        </tr>
                    </thead>
                    <tbody>
                    @forelse($topSuspiciousIps as $row)
                        <tr>
                            <td class="px-2 py-1 align-top break-all">{{ $row->ip }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">
                                <a class="underline" href="{{ route('admin.security.events.index', ['ip' => $row->ip]) }}">
                                    Filtern
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="3" class="px-2 py-2">Keine Daten.</td>
                        </tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>

        <div class="ks-card">
            <div class="flex items-start justify-between gap-3 mb-3">
                <h3>Geräte-Hashes (Top)</h3>

                <a class="ks-btn" href="{{ route('admin.security.events.index') }}">
                    Event Analysis
                </a>
            </div>

            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead>
                        <tr>
                            <th class="text-left px-2 py-1">Geräte-Hash</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Anzahl</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Aktion</th>
                        </tr>
                    </thead>
                    <tbody>
                    @forelse($topDeviceHashes as $row)
                        <tr>
                            <td class="px-2 py-1 align-top break-all">{{ $row->device_hash }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">
                                <a class="underline" href="{{ route('admin.security.events.index', ['device_hash' => $row->device_hash]) }}">
                                    Filtern
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="3" class="px-2 py-2">Keine Daten.</td>
                        </tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>

        <div class="ks-card">
            <div class="flex items-start justify-between gap-3 mb-3">
                <h3>Auffällige E-Mails (Top)</h3>

                <a class="ks-btn" href="{{ route('admin.security.events.index') }}">
                    Event Analysis
                </a>
            </div>

            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead>
                        <tr>
                            <th class="text-left px-2 py-1">E-Mail</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Anzahl</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Aktion</th>
                        </tr>
                    </thead>
                    <tbody>
                    @forelse($topSuspiciousEmails as $row)
                        <tr>
                            <td class="px-2 py-1 align-top break-all">{{ $row->email }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">
                                <a class="underline" href="{{ route('admin.security.events.index', ['email' => $row->email]) }}">
                                    Filtern
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="3" class="px-2 py-2">Keine Daten.</td>
                        </tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="grid grid-cols-1 xl:grid-cols-2 gap-3 mb-4">
        <div class="ks-card">
            <div class="flex items-start justify-between gap-3 mb-3">
                <h3>Wichtige Korrelationen: Geräte</h3>

                <a class="ks-btn" href="{{ route('admin.security.events.index') }}">
                    Event Analysis öffnen
                </a>
            </div>

            <p class="text-sm mb-3">
                Verdichteter Hinweis auf Gerate mit mehreren E-Mails oder IPs im 24h-Fenster.
            </p>

            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead>
                        <tr>
                            <th class="text-left px-2 py-1">Geräte-Hash</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">E-Mails</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">IPs</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Events</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Aktion</th>
                        </tr>
                    </thead>
                    <tbody>
                    @forelse($topCorrelatedDevices as $row)
                        <tr>
                            <td class="px-2 py-1 align-top break-all">{{ $row->device_hash }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->email_count }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->ip_count }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">
                                <a class="underline" href="{{ route('admin.security.events.index', ['device_hash' => $row->device_hash]) }}">
                                    Öffnen
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="px-2 py-2">Keine Daten.</td>
                        </tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>

        <div class="ks-card">
            <div class="flex items-start justify-between gap-3 mb-3">
                <h3>Wichtige Korrelationen: E-Mails</h3>

                <a class="ks-btn" href="{{ route('admin.security.events.index') }}">
                    Event Analysis öffnen
                </a>
            </div>

            <p class="text-sm mb-3">
                Verdichteter Hinweis auf E-Mails mit mehreren Geraten oder IPs im 24h-Fenster.
            </p>

            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead>
                        <tr>
                            <th class="text-left px-2 py-1">E-Mail</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Geräte</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">IPs</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Events</th>
                            <th class="text-left px-2 py-1 whitespace-nowrap">Aktion</th>
                        </tr>
                    </thead>
                    <tbody>
                    @forelse($topCorrelatedEmails as $row)
                        <tr>
                            <td class="px-2 py-1 align-top break-all">{{ $row->email }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->device_count }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->ip_count }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                            <td class="px-2 py-1 align-top whitespace-nowrap">
                                <a class="underline" href="{{ route('admin.security.events.index', ['email' => $row->email]) }}">
                                    Öffnen
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="px-2 py-2">Keine Daten.</td>
                        </tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="ks-card">
        <div class="flex items-start justify-between gap-3 mb-3">
            <h3>Weiter zur Detailanalyse</h3>

            <a class="ks-btn" href="{{ route('admin.security.events.index') }}">
                Event Analysis öffnen
            </a>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3 text-sm">
            <div class="border rounded p-3">
                <div class="font-semibold mb-2">Filter starten</div>
                <p>Von jeder Top-Liste direkt mit gesetztem IP-, E-Mail- oder Gerate-Hash-Filter in die Event Analysis springen.</p>
            </div>

            <div class="border rounded p-3">
                <div class="font-semibold mb-2">Korrelation vertiefen</div>
                <p>Gerate-, E-Mail- und IP-Korrelationen werden nur in „Event Analysis“ vollstandig aufgeschlusselt.</p>
            </div>

            <div class="border rounded p-3">
                <div class="font-semibold mb-2">Prufsicht nutzen</div>
                <p>Die aktive Prufsicht in „Event Analysis“ zeigt den aktuell analysierten Ausschnitt und die sichtbaren Gegenwerte.</p>
            </div>

            <div class="border rounded p-3">
                <div class="font-semibold mb-2">Events prufen</div>
                <p>Die eigentliche Event-Tabelle, Filterung und JSON-Ausgabe bleiben ausschliesslich auf der Event-Analysis-Seite.</p>
            </div>
        </div>
    </div>
@endsection
