<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\events\index.blade.php
// Purpose: Admin Security - Security events log with filters
// Changed: 02-03-2026 01:18 (Europe/Berlin)
// Version: 1.0
// ============================================================================

?>
@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    <div class="ks-card mb-4 p-3">
        <div class="flex items-start justify-between gap-3 mb-3">
            <h3>Ereignis-Filter</h3>

            <x-ui.help-popover id="security-events-help" title="Hilfe: Ereignisse">
                <ul>
                    <li>Ereignisse ist das Sicherheits-Log für Login-Fehler, Lockouts, Sperr-Blocks, erfolgreiche Logins und weitere Sicherheitssignale.</li>
                    <li>Typ, IP, E-Mail, Geräte-Hash und Zeitraum filtern nur die aktuelle Ansicht.</li>
                    <li>Die Seite hat keine direkte Steuerfunktion und ändert keine Sperren oder Konten.</li>
                    <li>Meta enthält technische Zusatzdaten zum jeweiligen Event (z.B. Quelle, Pfad, Kontext).</li>
                    <li>Typischer Ablauf: hier analysieren, dann in IP-Sperren oder Identitäts-Sperren Maßnahmen setzen.</li>
                </ul>
            </x-ui.help-popover>
        </div>

        <form id="events-filter-form" method="GET" action="{{ route('admin.security.events.index') }}" class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div><label>Typ</label><input class="w-full" type="text" name="type" value="{{ $filters['type'] }}"></div>
            <div><label>IP</label><input class="w-full" type="text" name="ip" value="{{ $filters['ip'] }}"></div>
            <div><label>E-Mail</label><input class="w-full" type="text" name="email" value="{{ $filters['email'] }}"></div>
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

    <div class="ks-card">
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
                        <td class="px-3 py-2 align-top">{{ $event->ip }}</td>
                        <td class="px-3 py-2 align-top">{{ $event->email }}</td>
                        <td class="px-3 py-2 align-top max-w-[260px] break-all">{{ $event->device_hash }}</td>
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