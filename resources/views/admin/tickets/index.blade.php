<!-- =========================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\tickets\index.blade.php
Purpose: Admin – Tickets Index (Blade)
Changed: 23-02-2026 23:22 (Europe/Berlin)
Version: 1.1
============================================================================= -->

@extends('admin.layouts.admin')

@php
    $type = (string) ($type ?? '');
    $status = (string) ($status ?? '');
    $ticketRows = $ticketRows ?? [];

    // Global Header (layouts/navigation.blade.php) – Admin Tabs + Badges
    $adminTab = $adminTab ?? 'tickets';
    $adminShowDebugTab = $adminShowDebugTab ?? (isset($maintenanceEnabled) ? (bool) $maintenanceEnabled : false);
@endphp

@section('content')
    <div class="ks-admin-tickets-index ks-wrap">
        <div class="ks-top">
            <h1 class="ks-h1">Admin – Tickets</h1>
        </div>

        <form method="GET" action="{{ route('admin.tickets.index') }}" class="ks-row ks-mb-14">
            <label class="ks-muted">Typ</label>
            <select class="ks-input" name="type">
                <option value="" @selected($type === '')>Alle</option>
                <option value="report" @selected($type === 'report')>Meldung</option>
                <option value="support" @selected($type === 'support')>Support</option>
            </select>

            <label class="ks-muted">Status</label>
            <select class="ks-input" name="status">
                <option value="" @selected($status === '')>Alle</option>
                <option value="open" @selected($status === 'open')>Offen</option>
                <option value="in_progress" @selected($status === 'in_progress')>In Bearbeitung</option>
                <option value="closed" @selected($status === 'closed')>Geschlossen</option>
                <option value="rejected" @selected($status === 'rejected')>Abgelehnt</option>
                <option value="escalated" @selected($status === 'escalated')>Eskaliert</option>
            </select>

            <button type="submit" class="ks-btn">Filtern</button>
        </form>

        <table>
            <thead>
            <tr>
                <th>ID</th>
                <th>Typ</th>
                <th>Kategorie</th>
                <th>Priorität</th>
                <th>Status</th>
                <th>Betreff</th>
                <th>Ersteller</th>
                <th>Gemeldet</th>
                <th>Erstellt</th>
            </tr>
            </thead>
            <tbody>
            @if(count($ticketRows) < 1)
                <tr><td colspan="9" class="ks-text-muted">(keine Tickets)</td></tr>
            @else
                @foreach($ticketRows as $r)
                    @php
                        $id = (int) ($r['id'] ?? 0);
                        $subjectText = (string) ($r['subject'] ?? '');
                        $rowHref = route('admin.tickets.show', $id);
                    @endphp
                    <tr data-href="{{ $rowHref }}">
                        <td><a href="{{ $rowHref }}">{{ $id }}</a></td>
                        <td>{{ (string) ($r['type_label'] ?? '') }}</td>
                        <td><span class="ks-badge {{ (string) ($r['category_class'] ?? '') }}">{{ ((string) ($r['category_raw'] ?? '')) !== '' ? (string) ($r['category_label'] ?? '') : '-' }}</span></td>
                        <td><span class="ks-badge {{ (string) ($r['priority_class'] ?? '') }}">{{ ((string) ($r['priority_label'] ?? '')) !== '' ? (string) ($r['priority_label'] ?? '') : '-' }}</span></td>
                        <td><span class="ks-badge {{ (string) ($r['status_class'] ?? '') }}">{{ (string) ($r['status_label'] ?? '') }}</span></td>
                        <td>
                            @if($subjectText !== '')
                                {{ $subjectText }}
                            @else
                                <span class="ks-text-muted">(ohne)</span>
                            @endif
                        </td>
                        <td>{{ (string) ($r['creator_display'] ?? '-') }}</td>
                        <td>{{ (string) ($r['reported_display'] ?? '-') }}</td>
                        <td>{{ (string) ($r['created_at'] ?? '') }}</td>
                    </tr>
                @endforeach
            @endif
            </tbody>
        </table>
    </div>
@endsection