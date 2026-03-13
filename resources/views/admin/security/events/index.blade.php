<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\events\index.blade.php
// Purpose: Admin Security - Security events log with filters
// Changed: 12-03-2026 16:31 (Europe/Berlin)
// Version: 1.7
// ============================================================================

?>
@extends('admin.layouts.admin')

@section('content')
    @php
        $selectedDeviceHash = (string) ($deviceCorrelation['selected_device_hash'] ?? '');
        $selectedEmail = (string) ($deviceCorrelation['selected_email'] ?? '');
        $selectedIp = (string) ($deviceCorrelation['selected_ip'] ?? '');

        $visibleEventEmails = $events->getCollection()
            ->pluck('email')
            ->filter(fn ($value) => filled($value))
            ->map(fn ($value) => mb_strtolower(trim((string) $value)))
            ->unique()
            ->values();

        $visibleEventIps = $events->getCollection()
            ->pluck('ip')
            ->filter(fn ($value) => filled($value))
            ->map(fn ($value) => trim((string) $value))
            ->unique()
            ->values();

        $visibleEventDeviceHashes = $events->getCollection()
            ->pluck('device_hash')
            ->filter(fn ($value) => filled($value))
            ->map(fn ($value) => trim((string) $value))
            ->unique()
            ->values();

        $deviceEmails = collect($deviceCorrelation['emails_for_device'] ?? [])
            ->pluck('email')
            ->filter(fn ($value) => filled($value))
            ->map(fn ($value) => mb_strtolower(trim((string) $value)))
            ->unique()
            ->values();

        $deviceIps = collect($deviceCorrelation['ips_for_device'] ?? [])
            ->pluck('ip')
            ->filter(fn ($value) => filled($value))
            ->map(fn ($value) => trim((string) $value))
            ->unique()
            ->values();

        $emailDevices = collect($deviceCorrelation['devices_for_email'] ?? [])
            ->pluck('device_hash')
            ->filter(fn ($value) => filled($value))
            ->map(fn ($value) => trim((string) $value))
            ->unique()
            ->values();

        $ipDevices = collect($deviceCorrelation['devices_for_ip'] ?? [])
            ->pluck('device_hash')
            ->filter(fn ($value) => filled($value))
            ->map(fn ($value) => trim((string) $value))
            ->unique()
            ->values();

        $hasActiveFilterSummary =
            $selectedDeviceHash !== '' ||
            $selectedEmail !== '' ||
            $selectedIp !== '' ||
            $visibleEventEmails->isNotEmpty() ||
            $visibleEventIps->isNotEmpty() ||
            $visibleEventDeviceHashes->isNotEmpty();
    @endphp

    @include('admin.security._tabs')

    <div class="ks-card mb-4 p-3">
        <div class="flex items-start justify-between gap-3 mb-3">
            <h3>Event Analysis</h3>

            <x-ui.help-popover id="security-events-help" title="Hilfe: Ereignisse">
                <ul>
                    <li>Ereignisse ist das Sicherheits-Log für Login-Fehler, Lockouts, Sperr-Blocks, erfolgreiche Logins und weitere Sicherheitssignale.</li>
                    <li>Typ, IP, E-Mail, SEC-Code, Geräte-Hash und Zeitraum filtern nur die aktuelle Ansicht.</li>
                    <li>Diese Seite ist die einzige vollstandige Analyse- und Drilldown-Seite der Security-Sektion.</li>
                    <li>Die Seite hat keine direkte Steuerfunktion und ändert keine Sperren oder Konten.</li>
                    <li>Meta enthält technische Zusatzdaten zum jeweiligen Event (z.B. Quelle, Pfad, Kontext).</li>
                    <li>Typischer Ablauf: hier analysieren, dann in den Protection-Tabs Maßnahmen setzen.</li>
                    <li>Korrelations-Panels zeigen verdichtete Muster zu Geräten, E-Mails und IPs innerhalb des aktuell gefilterten Ausschnitts.</li>
                </ul>
            </x-ui.help-popover>
        </div>

        <p class="text-sm mb-3">
            Einzige vollständige Analyse-Seite mit Event-Filtern, Event-Tabelle, Korrelationsübersicht, Detail-Korrelationen, Prüf-Sicht und JSON-Ausgabe.
        </p>

        <h4 class="mb-3">Event-Filter</h4>

        <form id="events-filter-form" method="GET" action="{{ route('admin.security.events.index') }}" class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div><label>Typ</label><input class="w-full" type="text" name="type" value="{{ $filters['type'] }}"></div>
            <div><label>IP</label><input class="w-full" type="text" name="ip" value="{{ $filters['ip'] }}"></div>
            <div><label>E-Mail</label><input class="w-full" type="text" name="email" value="{{ $filters['email'] }}"></div>
            <div><label>SEC-Code</label><input class="w-full" type="text" name="support_ref" value="{{ $filters['support_ref'] }}"></div>
            <div><label>Geräte-Hash</label><input class="w-full" type="text" name="device_hash" value="{{ $filters['device_hash'] }}"></div>
            <div><label>Von</label><input class="w-full" type="date" name="date_from" value="{{ $filters['date_from'] }}"></div>
            <div><label>Bis</label><input class="w-full" type="date" name="date_to" value="{{ $filters['date_to'] }}"></div>
        </form>

        <div class="flex justify-between items-end mt-4">
            <button form="events-filter-form" class="ks-btn" type="submit">
                Filtern
            </button>

            <form method="POST" action="{{ route('admin.security.events.purge') }}" class="flex items-end gap-2">
                @csrf

                <input type="hidden" name="type" value="{{ $filters['type'] }}">
                <input type="hidden" name="ip" value="{{ $filters['ip'] }}">
                <input type="hidden" name="email" value="{{ $filters['email'] }}">
                <input type="hidden" name="support_ref" value="{{ $filters['support_ref'] }}">
                <input type="hidden" name="device_hash" value="{{ $filters['device_hash'] }}">
                <input type="hidden" name="date_from" value="{{ $filters['date_from'] }}">
                <input type="hidden" name="date_to" value="{{ $filters['date_to'] }}">
                <input type="hidden" name="per_page" value="{{ (int) $perPage }}">

                <div>
                    <label class="block text-sm">Bestätigung</label>
                    <input class="w-28" type="text" name="confirm" placeholder="DELETE" required>
                </div>

                <button class="ks-btn" type="submit">
                    Ereignisse löschen
                </button>
            </form>
        </div>
    </div>

    @if($hasActiveFilterSummary)
        <div class="ks-card mb-4 p-3">
            <div class="flex items-start justify-between gap-3 mb-3">
                <h3>Aktive Prüf-Sicht</h3>
            </div>

            <div class="grid grid-cols-1 xl:grid-cols-2 gap-4">
                <div class="border rounded p-3">
                    <div class="font-semibold mb-2">Aktive Filter</div>

                    <div class="space-y-1 text-sm break-all">
                        @if($selectedDeviceHash !== '')
                            <div><strong>Geräte-Hash:</strong> {{ $selectedDeviceHash }}</div>
                        @endif

                        @if($selectedEmail !== '')
                            <div><strong>E-Mail:</strong> {{ $selectedEmail }}</div>
                        @endif

                        @if($selectedIp !== '')
                            <div><strong>IP:</strong> {{ $selectedIp }}</div>
                        @endif

                        @if(($filters['type'] ?? '') !== '')
                            <div><strong>Typ:</strong> {{ $filters['type'] }}</div>
                        @endif

                        @if(($filters['support_ref'] ?? '') !== '')
                            <div><strong>SEC-Code:</strong> {{ $filters['support_ref'] }}</div>
                        @endif

                        @if(($filters['date_from'] ?? '') !== '' || ($filters['date_to'] ?? '') !== '')
                            <div>
                                <strong>Zeitraum:</strong>
                                {{ $filters['date_from'] ?: 'offen' }} – {{ $filters['date_to'] ?: 'offen' }}
                            </div>
                        @endif
                    </div>
                </div>

                <div class="border rounded p-3">
                    <div class="font-semibold mb-2">Sichtbare Werte für Gegenprüfung</div>

                    <div class="space-y-3 text-sm break-all">
                        @if($deviceEmails->isNotEmpty())
                            <div>
                                <div><strong>Gerät → E-Mails</strong></div>
                                <div>{{ $deviceEmails->implode(' | ') }}</div>
                            </div>
                        @endif

                        @if($deviceIps->isNotEmpty())
                            <div>
                                <div><strong>Gerät → IPs</strong></div>
                                <div>{{ $deviceIps->implode(' | ') }}</div>
                            </div>
                        @endif

                        @if($emailDevices->isNotEmpty())
                            <div>
                                <div><strong>E-Mail → Geräte</strong></div>
                                <div>{{ $emailDevices->implode(' | ') }}</div>
                            </div>
                        @endif

                        @if($ipDevices->isNotEmpty())
                            <div>
                                <div><strong>IP → Geräte</strong></div>
                                <div>{{ $ipDevices->implode(' | ') }}</div>
                            </div>
                        @endif

                        @if($visibleEventEmails->isNotEmpty())
                            <div>
                                <div><strong>Sichtbare Event-E-Mails</strong></div>
                                <div>{{ $visibleEventEmails->implode(' | ') }}</div>
                            </div>
                        @endif

                        @if($visibleEventIps->isNotEmpty())
                            <div>
                                <div><strong>Sichtbare Event-IPs</strong></div>
                                <div>{{ $visibleEventIps->implode(' | ') }}</div>
                            </div>
                        @endif

                        @if($visibleEventDeviceHashes->isNotEmpty())
                            <div>
                                <div><strong>Sichtbare Event-Geräte-Hashes</strong></div>
                                <div>{{ $visibleEventDeviceHashes->implode(' | ') }}</div>
                            </div>
                        @endif
                    </div>
                </div>
            </div>
        </div>
    @endif

    @if(
        $correlationSummary['top_devices']->isNotEmpty() ||
        $correlationSummary['top_emails']->isNotEmpty() ||
        $correlationSummary['top_ips']->isNotEmpty()
    )
        <div class="ks-card mb-4 p-3">
            <div class="flex items-start justify-between gap-3 mb-3">
                <h3>Korrelations-Übersicht</h3>
            </div>

            <div class="grid grid-cols-1 xl:grid-cols-3 gap-4">
                <div class="border rounded p-3">
                    <div class="font-semibold mb-2">Auffällige Geräte</div>

                    <div class="overflow-x-auto">
                        <table class="w-full text-sm">
                            <thead>
                                <tr>
                                    <th class="text-left px-2 py-1">Geräte-Hash</th>
                                    <th class="text-left px-2 py-1 whitespace-nowrap">E-Mails</th>
                                    <th class="text-left px-2 py-1 whitespace-nowrap">IPs</th>
                                    <th class="text-left px-2 py-1 whitespace-nowrap">Events</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($correlationSummary['top_devices'] as $row)
                                    <tr>
                                        <td class="px-2 py-1 align-top break-all">
                                            <a class="underline" href="{{ route('admin.security.events.index', array_merge(request()->query(), ['device_hash' => $row->device_hash])) }}">
                                                {{ $row->device_hash }}
                                            </a>
                                        </td>
                                        <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->email_count }}</td>
                                        <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->ip_count }}</td>
                                        <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="4" class="px-2 py-2">Keine Geräte-Korrelationen gefunden.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="border rounded p-3">
                    <div class="font-semibold mb-2">Auffällige E-Mails</div>

                    <div class="overflow-x-auto">
                        <table class="w-full text-sm">
                            <thead>
                                <tr>
                                    <th class="text-left px-2 py-1">E-Mail</th>
                                    <th class="text-left px-2 py-1 whitespace-nowrap">Geräte</th>
                                    <th class="text-left px-2 py-1 whitespace-nowrap">IPs</th>
                                    <th class="text-left px-2 py-1 whitespace-nowrap">Events</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($correlationSummary['top_emails'] as $row)
                                    <tr>
                                        <td class="px-2 py-1 align-top break-all">
                                            <a class="underline" href="{{ route('admin.security.events.index', array_merge(request()->query(), ['email' => $row->email])) }}">
                                                {{ $row->email }}
                                            </a>
                                        </td>
                                        <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->device_count }}</td>
                                        <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->ip_count }}</td>
                                        <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="4" class="px-2 py-2">Keine E-Mail-Korrelationen gefunden.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="border rounded p-3">
                    <div class="font-semibold mb-2">Auffällige IPs</div>

                    <div class="overflow-x-auto">
                        <table class="w-full text-sm">
                            <thead>
                                <tr>
                                    <th class="text-left px-2 py-1">IP</th>
                                    <th class="text-left px-2 py-1 whitespace-nowrap">Geräte</th>
                                    <th class="text-left px-2 py-1 whitespace-nowrap">E-Mails</th>
                                    <th class="text-left px-2 py-1 whitespace-nowrap">Events</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($correlationSummary['top_ips'] as $row)
                                    <tr>
                                        <td class="px-2 py-1 align-top break-all">
                                            <a class="underline" href="{{ route('admin.security.events.index', array_merge(request()->query(), ['ip' => $row->ip])) }}">
                                                {{ $row->ip }}
                                            </a>
                                        </td>
                                        <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->device_count }}</td>
                                        <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->email_count }}</td>
                                        <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="4" class="px-2 py-2">Keine IP-Korrelationen gefunden.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    @endif

    @if(
        !empty($deviceCorrelation['selected_device_hash']) ||
        !empty($deviceCorrelation['selected_email']) ||
        !empty($deviceCorrelation['selected_ip'])
    )
        <div class="ks-card mb-4 p-3">
            <div class="flex items-start justify-between gap-3 mb-3">
                <h3>Device-Korrelation</h3>
            </div>

            <div class="grid grid-cols-1 xl:grid-cols-2 gap-4">
                @if(!empty($deviceCorrelation['selected_device_hash']))
                    <div class="border rounded p-3">
                        <div class="font-semibold mb-2">Gerät → E-Mails</div>

                        <div class="text-xs break-all mb-3">
                            <strong>Geräte-Hash:</strong> {{ $deviceCorrelation['selected_device_hash'] }}
                        </div>

                        <div class="overflow-x-auto">
                            <table class="w-full text-sm">
                                <thead>
                                    <tr>
                                        <th class="text-left px-2 py-1">E-Mail</th>
                                        <th class="text-left px-2 py-1 whitespace-nowrap">Events</th>
                                        <th class="text-left px-2 py-1 whitespace-nowrap">Last seen</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($deviceCorrelation['emails_for_device'] as $row)
                                        <tr>
                                            <td class="px-2 py-1 align-top break-all">
                                                <a class="underline" href="{{ route('admin.security.events.index', array_merge(request()->query(), ['email' => $row->email])) }}">
                                                    {{ $row->email }}
                                                </a>
                                            </td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->last_seen_at }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="px-2 py-2">Keine E-Mails zu diesem Gerät gefunden.</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <div class="border rounded p-3">
                        <div class="font-semibold mb-2">Gerät → IPs</div>

                        <div class="text-xs break-all mb-3">
                            <strong>Geräte-Hash:</strong> {{ $deviceCorrelation['selected_device_hash'] }}
                        </div>

                        <div class="overflow-x-auto">
                            <table class="w-full text-sm">
                                <thead>
                                    <tr>
                                        <th class="text-left px-2 py-1">IP</th>
                                        <th class="text-left px-2 py-1 whitespace-nowrap">Events</th>
                                        <th class="text-left px-2 py-1 whitespace-nowrap">Last seen</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($deviceCorrelation['ips_for_device'] as $row)
                                        <tr>
                                            <td class="px-2 py-1 align-top break-all">
                                                <a class="underline" href="{{ route('admin.security.events.index', array_merge(request()->query(), ['ip' => $row->ip])) }}">
                                                    {{ $row->ip }}
                                                </a>
                                            </td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->last_seen_at }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="px-2 py-2">Keine IPs zu diesem Gerät gefunden.</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                @endif

                @if(!empty($deviceCorrelation['selected_email']))
                    <div class="border rounded p-3">
                        <div class="font-semibold mb-2">E-Mail → Geräte</div>

                        <div class="text-xs break-all mb-3">
                            <strong>E-Mail:</strong> {{ $deviceCorrelation['selected_email'] }}
                        </div>

                        <div class="overflow-x-auto">
                            <table class="w-full text-sm">
                                <thead>
                                    <tr>
                                        <th class="text-left px-2 py-1">Geräte-Hash</th>
                                        <th class="text-left px-2 py-1 whitespace-nowrap">Events</th>
                                        <th class="text-left px-2 py-1 whitespace-nowrap">Last seen</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($deviceCorrelation['devices_for_email'] as $row)
                                        <tr>
                                            <td class="px-2 py-1 align-top break-all">
                                                <a class="underline" href="{{ route('admin.security.events.index', array_merge(request()->query(), ['device_hash' => $row->device_hash])) }}">
                                                    {{ $row->device_hash }}
                                                </a>
                                            </td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->last_seen_at }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="px-2 py-2">Keine Geräte zu dieser E-Mail gefunden.</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                @endif

                @if(!empty($deviceCorrelation['selected_ip']))
                    <div class="border rounded p-3">
                        <div class="font-semibold mb-2">IP → Geräte</div>

                        <div class="text-xs break-all mb-3">
                            <strong>IP:</strong> {{ $deviceCorrelation['selected_ip'] }}
                        </div>

                        <div class="overflow-x-auto">
                            <table class="w-full text-sm">
                                <thead>
                                    <tr>
                                        <th class="text-left px-2 py-1">Geräte-Hash</th>
                                        <th class="text-left px-2 py-1 whitespace-nowrap">Events</th>
                                        <th class="text-left px-2 py-1 whitespace-nowrap">Last seen</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($deviceCorrelation['devices_for_ip'] as $row)
                                        <tr>
                                            <td class="px-2 py-1 align-top break-all">
                                                <a class="underline" href="{{ route('admin.security.events.index', array_merge(request()->query(), ['device_hash' => $row->device_hash])) }}">
                                                    {{ $row->device_hash }}
                                                </a>
                                            </td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->aggregate_count }}</td>
                                            <td class="px-2 py-1 align-top whitespace-nowrap">{{ $row->last_seen_at }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="px-2 py-2">Keine Geräte zu dieser IP gefunden.</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                @endif
            </div>
        </div>
    @endif

    <div class="ks-card">
        <div class="flex items-start justify-between gap-3 mb-3">
            <h3>Event-Tabelle</h3>
        </div>

        <div class="flex items-center justify-end mb-2">
            <form method="GET" action="{{ route('admin.security.events.index') }}" class="flex items-center gap-2 text-xs">
                @foreach($filters as $key => $value)
                    @if($value !== null && $value !== '')
                        <input type="hidden" name="{{ $key }}" value="{{ $value }}">
                    @endif
                @endforeach

                <select class="w-[75px] py-1 text-xs" name="per_page" onchange="this.form.submit()">
                    <option value="20" {{ (int) $perPage === 20 ? 'selected' : '' }}>20</option>
                    <option value="50" {{ (int) $perPage === 50 ? 'selected' : '' }}>50</option>
                    <option value="100" {{ (int) $perPage === 100 ? 'selected' : '' }}>100</option>
                </select>

                <noscript>
                    <button class="ks-btn" type="submit">OK</button>
                </noscript>
            </form>
        </div>

        <div class="overflow-x-auto">
        <table class="w-full min-w-[980px] text-sm">
            <thead>
                <tr>
                    <th class="text-left px-3 py-2 whitespace-nowrap">Zeit</th>
                    <th class="text-left px-3 py-2 whitespace-nowrap">Typ</th>
                    <th class="text-left px-3 py-2">IP</th>
                    <th class="text-left px-3 py-2">E-Mail</th>
                    <th class="text-left px-3 py-2">Geräte-Hash</th>
                    <th class="text-left px-3 py-2">Meta</th>
                </tr>
            </thead>
            <tbody>
                @forelse($events as $event)
                    <tr>
                        <td class="px-3 py-2 whitespace-nowrap align-top">{{ $event->created_at }}</td>
                        <td class="px-3 py-2 whitespace-nowrap align-top">{{ $event->type }}</td>
                        <td class="px-3 py-2 align-top">
                            @if(!empty($event->ip))
                                <a class="underline break-all" href="{{ route('admin.security.events.index', array_merge(request()->query(), ['ip' => $event->ip])) }}">
                                    {{ $event->ip }}
                                </a>
                            @endif
                        </td>
                        <td class="px-3 py-2 align-top">
                            @if(!empty($event->email))
                                <a class="underline break-all" href="{{ route('admin.security.events.index', array_merge(request()->query(), ['email' => $event->email])) }}">
                                    {{ $event->email }}
                                </a>
                            @endif
                        </td>
                        <td class="px-3 py-2 align-top max-w-[260px] break-all">
                            @if(!empty($event->device_hash))
                                <a class="underline break-all" href="{{ route('admin.security.events.index', array_merge(request()->query(), ['device_hash' => $event->device_hash])) }}">
                                    {{ $event->device_hash }}
                                </a>
                            @endif
                        </td>
                        <td class="px-3 py-2 align-top max-w-[460px] break-words">
                            @if(is_array($event->meta))
                                {{ json_encode($event->meta, JSON_UNESCAPED_UNICODE) }}
                            @else
                                {{ $event->meta }}
                            @endif
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="6" class="px-3 py-3">Keine Ereignisse gefunden.</td></tr>
                @endforelse
            </tbody>
        </table>
        </div>

        <div class="mt-3">
            {{ $events->appends(request()->query())->links('vendor.pagination.tailwind') }}
        </div>
    </div>
@endsection
