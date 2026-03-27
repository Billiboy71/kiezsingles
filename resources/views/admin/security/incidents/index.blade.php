<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\incidents\index.blade.php
// Purpose: Admin Security incidents list view (read-only monitoring table)
// Created: 22-03-2026 21:30 (Europe/Berlin)
// Changed: 24-03-2026 23:44 (Europe/Berlin)
// Version: 1.8
// ============================================================================

?>
@php
    use App\Support\SecurityIncidentType;

    $typeMap = [
        'account_sharing' => 'Geteilter Account',
        'bot_pattern' => 'Bot-Muster',
        'device_cluster' => 'Geräte-Cluster',
        'credential_stuffing' => 'Login-Angriffe',
    ];

    $statusMap = [
        null => 'Offen',
        'reviewed' => 'Maßnahme ergriffen',
        'escalated' => 'In Prüfung',
        'ignored' => 'Ignoriert',
    ];

    $statusColor = [
        null => '#6c757d',
        'reviewed' => '#198754',
        'escalated' => '#fd7e14',
        'ignored' => '#198754',
    ];
@endphp
@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    <div class="ks-card p-3">
        <div class="flex items-center justify-between gap-3 mb-3">
            <h3>Security Incidents</h3>

            <form method="POST"
                  action="{{ route('admin.security.incidents.bulkDelete') }}"
                  onsubmit="return confirm('Alle offenen Incidents löschen?');">
                @csrf
                <input type="hidden" name="status" value="open">

                <button class="ks-btn" style="background:#dc3545; color:white;">
                    Alle offenen löschen
                </button>
            </form>
        </div>

        <form method="GET" action="{{ route('admin.security.incidents.index') }}" class="grid grid-cols-1 md:grid-cols-[220px_220px_auto] gap-3 mb-4">
            <div>
                <label for="type">Typ</label>
                @if(!empty($types))
                    <select id="type" name="type" class="w-full">
                        <option value="">Alle</option>
                        @foreach($types as $type)
                            <option value="{{ $type }}" {{ request('type') === $type ? 'selected' : '' }}>
                                {{ $typeMap[$type] ?? SecurityIncidentType::label($type) }}
                            </option>
                        @endforeach
                    </select>
                @else
                    <input id="type" type="text" name="type" value="{{ request('type') }}" placeholder="Type..." class="w-full">
                @endif
            </div>

            <div>
                <label for="status">Status</label>
                <select id="status" name="status" class="w-full">
                    <option value="open" {{ request('status', 'open') === 'open' ? 'selected' : '' }}>Offen</option>
                    <option value="reviewed" {{ request('status') === 'reviewed' ? 'selected' : '' }}>Maßnahme ergriffen</option>
                    <option value="escalated" {{ request('status') === 'escalated' ? 'selected' : '' }}>In Prüfung</option>
                    <option value="ignored" {{ request('status') === 'ignored' ? 'selected' : '' }}>Ignoriert</option>
                </select>
            </div>

            <div class="flex items-end gap-2">
                <button class="ks-btn" type="submit">Filter</button>

                @if(request()->filled('type') || request()->filled('status'))
                    <a class="ks-btn" href="{{ route('admin.security.incidents.index') }}">Reset</a>
                @endif
            </div>
        </form>

        <div class="flex items-center justify-end mb-2">
            <form method="GET" action="{{ route('admin.security.incidents.index') }}" class="flex items-center gap-2 text-xs">
                @if(request()->filled('type'))
                    <input type="hidden" name="type" value="{{ request('type') }}">
                @endif
                @if(request()->filled('status'))
                    <input type="hidden" name="status" value="{{ request('status') }}">
                @endif

                <select class="w-[75px] text-xs py-1" name="per_page" onchange="this.form.submit()">
                    <option value="20" {{ (int) $perPage === 20 ? 'selected' : '' }}>20</option>
                    <option value="50" {{ (int) $perPage === 50 ? 'selected' : '' }}>50</option>
                    <option value="100" {{ (int) $perPage === 100 ? 'selected' : '' }}>100</option>
                </select>
                <noscript>
                    <button class="ks-btn" type="submit">Anwenden</button>
                </noscript>
            </form>
        </div>

        <div class="overflow-x-auto">
            <table class="w-full min-w-[640px] text-sm">
                <thead>
                    <tr>
                        <th class="text-left px-3 py-2">ID</th>
                        <th class="text-left px-3 py-2">Typ</th>
                        <th class="text-left px-3 py-2 whitespace-nowrap">Erstellt</th>
                        <th class="text-left px-3 py-2 whitespace-nowrap">Events</th>
                        <th class="text-left px-3 py-2 whitespace-nowrap">Status</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($incidents as $incident)
                        <tr data-incident-id="{{ $incident->id }}" style="border-bottom:1px solid #eee; cursor:pointer;"
                            onclick="window.location='{{ route('admin.security.incidents.show', $incident->id) }}'"
                            onmouseover="this.style.background='#f9fafb'"
                            onmouseout="this.style.background='transparent'">
                            <td class="px-3 py-2 align-top">
                                <a href="{{ route('admin.security.incidents.show', $incident->id) }}">{{ $incident->id }}</a>
                            </td>
                            <td class="px-3 py-2 align-top">
                                @php
                                    $typeColor = match($incident->type) {
                                        'device_cluster' => '#f97316',
                                        'bot_pattern' => '#ef4444',
                                        'credential_stuffing' => '#eab308',
                                        'account_sharing' => '#3b82f6',
                                        default => '#999'
                                    };
                                @endphp
                                <span style="
                                    background: {{ $typeColor }};
                                    color:#fff;
                                    padding:4px 8px;
                                    border-radius:6px;
                                    font-size:12px;
                                    font-weight:600;
                                ">
                                    {{ $typeMap[$incident->type] ?? SecurityIncidentType::label($incident->type) }}
                                </span>
                            </td>
                            <td class="px-3 py-2 align-top whitespace-nowrap">{{ $incident->created_at ?? '-' }}</td>
                            <td class="px-3 py-2 align-top whitespace-nowrap" style="font-weight:600;">{{ $incident->events_count ?? '-' }}</td>
                            <td class="px-3 py-2 align-top whitespace-nowrap">
                                <span class="status-badge" style="
                                    padding:4px 8px;
                                    border-radius:6px;
                                    color:white;
                                    background: {{ $statusColor[$incident->action_status] ?? '#6c757d' }};
                                ">
                                    {{ $statusMap[$incident->action_status] ?? 'Offen' }}
                                </span>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="px-3 py-4 text-center">No incidents found.</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div class="mt-3">
            {{ $incidents->links('vendor.pagination.tailwind') }}
        </div>
    </div>

    <script>
    function syncIncidentStatuses() {
        document.querySelectorAll('[data-incident-id]').forEach(row => {
            const id = row.dataset.incidentId;
            const status = sessionStorage.getItem('incident_status_' + id);

            if (status) {
                const badge = row.querySelector('.status-badge');

                const map = {
                    reviewed: "Maßnahme ergriffen",
                    escalated: "In Prüfung",
                    ignored: "Ignoriert"
                };

                const color = {
                    reviewed: "#198754",
                    escalated: "#fd7e14",
                    ignored: "#198754"
                };

                if (badge) {
                    badge.innerText = map[status];
                    badge.style.background = color[status];
                }
            }
        });
    }

    syncIncidentStatuses();
    window.addEventListener('pageshow', syncIncidentStatuses);
    </script>
@endsection
