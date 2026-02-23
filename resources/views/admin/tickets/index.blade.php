<!-- =========================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\tickets\index.blade.php
Purpose: Admin – Tickets Index (Blade)
Changed: 18-02-2026 23:42 (Europe/Berlin)
Version: 0.8
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
    <style>
        *, *::before, *::after { box-sizing:border-box; }

        /*
         * Layout kommt aus admin.layouts.admin (Container + Padding + Card).
         * Tickets-Index darf hier keine eigene max-width/padding erzwingen.
         */
        .ks-wrap { padding:0; max-width:100%; margin:0; }
        .ks-top { display:flex; align-items:center; justify-content:space-between; gap:12px; flex-wrap:wrap; margin:0 0 14px 0; }
        .ks-h1 { margin:0; }
        .ks-badge { display:inline-flex; align-items:center; justify-content:center; padding:4px 9px; border-radius:999px; font-weight:900; font-size:12px; letter-spacing:.2px; color:#111; background:#e5e7eb; border:1px solid #e5e7eb; }
        .ks-btn { padding:8px 10px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; cursor:pointer; user-select:none; font-weight:700; font-size:13px; }
        .ks-btn:hover { background:#f8fafc; }
        .ks-btn:active { background:#f1f5f9; }
        .ks-input { padding:8px 10px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; font-size:13px; }

        table { width:100%; border-collapse:separate; border-spacing:0; background:#fff; border:1px solid #e5e7eb; border-radius:12px; overflow:hidden; }
        th, td { text-align:left; padding:10px 12px; border-bottom:1px solid #e5e7eb; vertical-align:top; }
        th { font-size:12px; color:#555; letter-spacing:.3px; text-transform:uppercase; background:#f8fafc; }
        tr:last-child td { border-bottom:none; }

        a { color:#0ea5e9; text-decoration:none; }
        a:hover { text-decoration:underline; }
        .ks-sub { color:#444; margin:0 0 12px 0; }
        .ks-row { display:flex; gap:10px; flex-wrap:wrap; align-items:center; }
        .ks-muted { color:#666; font-size:13px; }
        tr[data-href] { cursor:pointer; }
        tr[data-href]:hover { background:#f8fafc; }
        tr[data-href]:active { background:#f1f5f9; }

        .st-open { background:#fef9c3; border-color:#fde68a; }
        .st-inprogress { background:#e0f2fe; border-color:#bae6fd; }
        .st-closed { background:#dcfce7; border-color:#bbf7d0; }
        .st-rejected { background:#f1f5f9; border-color:#e2e8f0; }
        .st-escalated { background:#fee2e2; border-color:#fecaca; }
        .st-other { background:#e5e7eb; border-color:#e5e7eb; }

        .cat-none { background:#f1f5f9; border-color:#e2e8f0; }
        .cat-support { background:#e0f2fe; border-color:#bae6fd; }
        .cat-abuse { background:#fee2e2; border-color:#fecaca; }
        .cat-spam { background:#ffedd5; border-color:#fed7aa; }
        .cat-billing { background:#ede9fe; border-color:#ddd6fe; }
        .cat-bug { background:#ccfbf1; border-color:#99f6e4; }
        .cat-other { background:#e5e7eb; border-color:#e5e7eb; }

        .prio-none { background:#dcfce7; border-color:#bbf7d0; }
        .prio-low { background:#ecfccb; border-color:#d9f99d; }
        .prio-normal { background:#fef9c3; border-color:#fde68a; }
        .prio-high { background:#ffedd5; border-color:#fed7aa; }
        .prio-critical { background:#fee2e2; border-color:#fecaca; }
        .prio-other { background:#e5e7eb; border-color:#e5e7eb; }
    </style>

    <div class="ks-wrap">
        <div class="ks-top">
            <h1 class="ks-h1">Admin – Tickets</h1>
        </div>

        <form method="GET" action="{{ route('admin.tickets.index') }}" class="ks-row" style="margin:0 0 14px 0;">
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
                <tr><td colspan="9" style="color:#666;">(keine Tickets)</td></tr>
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
                                <span style="color:#666;">(ohne)</span>
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

    <script>
        (function () {
            document.addEventListener("click", function (e) {
                var tr = e.target && e.target.closest ? e.target.closest("tr[data-href]") : null;
                if (!tr) return;

                if (e.target && e.target.closest) {
                    if (e.target.closest("a, button, input, select, textarea, label")) return;
                }

                var href = tr.getAttribute("data-href");
                if (!href) return;
                window.location.href = href;
            });
        })();
    </script>
@endsection
