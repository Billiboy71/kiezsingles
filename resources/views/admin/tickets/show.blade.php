<!-- =========================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\tickets\show.blade.php
Purpose: Admin – Ticket Detail (Blade)
Changed: 27-02-2026 14:15 (Europe/Berlin)
Version: 2.6
============================================================================= -->

@extends('admin.layouts.admin')

@php
    $ticketId = (int) ($ticketId ?? 0);

    $type = (string) ($type ?? '');
    $typeLabel = (string) ($typeLabel ?? '');

    $status = (string) ($status ?? '');
    $statusLabel = (string) ($statusLabel ?? '');
    $statusClass = (string) ($statusClass ?? '');

    $category = (string) ($category ?? '');
    $categoryLabel = (string) ($categoryLabel ?? '');
    $categoryClass = (string) ($categoryClass ?? '');

    $priorityRaw = (string) ($priorityRaw ?? '');
    $priorityLabel = (string) ($priorityLabel ?? '');
    $priorityClass = (string) ($priorityClass ?? '');

    $subjectText = (string) ($subjectText ?? '');
    $messageText = (string) ($messageText ?? '');

    $creatorDisplay = (string) ($creatorDisplay ?? '-');
    $reportedDisplay = (string) ($reportedDisplay ?? '-');
    $assignedAdminDisplay = (string) ($assignedAdminDisplay ?? '-');
    $assignedAdminRole = mb_strtolower(trim((string) ($assignedAdminRole ?? '')));
    $assignedAdminProfileUrl = (string) ($assignedAdminProfileUrl ?? '');
    $creatorRole = mb_strtolower(trim((string) ($creatorRole ?? '')));
    $reportedRole = mb_strtolower(trim((string) ($reportedRole ?? '')));
    $creatorProfileUrl = (string) ($creatorProfileUrl ?? '');
    $reportedProfileUrl = (string) ($reportedProfileUrl ?? '');

    $createdAt = (string) ($createdAt ?? '');
    $closedAt = (string) ($closedAt ?? '');

    $notice = $notice ?? null;

    $adminOptions = $adminOptions ?? [];
    $categoryOptions = $categoryOptions ?? [];
    $priorityOptions = $priorityOptions ?? [];
    $statusOptions = $statusOptions ?? [];

    $messageRows = $messageRows ?? [];
    $auditRows = $auditRows ?? [];

    $isReport = (bool) ($isReport ?? false);

    // Optional: server-side draft support (controller can pass these)
    $draftSaveUrl = (string) ($draftSaveUrl ?? '');
    $draftReplyText = (string) ($draftReplyText ?? '');
    $draftInternalText = (string) ($draftInternalText ?? '');

    // Global Header (layouts/navigation.blade.php) – Admin Tabs
    $adminTab = $adminTab ?? 'tickets';
    $adminShowDebugTab = $adminShowDebugTab ?? (isset($maintenanceEnabled) ? (bool) $maintenanceEnabled : false);

    // Badge color mapping (replaces former inline CSS st-*/cat-*/prio-* classes)
    $statusBadgeTw = match ($status) {
        'open' => 'bg-yellow-100 border-yellow-200',
        'in_progress' => 'bg-sky-100 border-sky-200',
        'closed' => 'bg-emerald-100 border-emerald-200',
        'rejected' => 'bg-slate-100 border-slate-200',
        'escalated' => 'bg-red-100 border-red-200',
        default => 'bg-slate-200 border-slate-200',
    };

    $categoryBadgeTw = match ($category) {
        '' => 'bg-slate-100 border-slate-200',
        'none' => 'bg-slate-100 border-slate-200',
        'support' => 'bg-sky-100 border-sky-200',
        'abuse' => 'bg-red-100 border-red-200',
        'spam' => 'bg-orange-100 border-orange-200',
        'billing' => 'bg-violet-100 border-violet-200',
        'bug' => 'bg-teal-100 border-teal-200',
        default => 'bg-slate-200 border-slate-200',
    };

    $priorityBadgeTw = match ($priorityRaw) {
        '' => 'bg-emerald-100 border-emerald-200',
        'none' => 'bg-emerald-100 border-emerald-200',
        'low' => 'bg-lime-100 border-lime-200',
        'normal' => 'bg-yellow-100 border-yellow-200',
        'high' => 'bg-orange-100 border-orange-200',
        'critical' => 'bg-red-100 border-red-200',
        default => 'bg-slate-200 border-slate-200',
    };

    $ksBadgeBaseTw = 'inline-flex items-center justify-center px-2 py-1 rounded-full font-black text-xs tracking-wide text-slate-900 border';

    $roleUi = static function (string $role): array {
        return match ($role) {
            'superadmin' => [
                'box' => 'bg-red-100 border-red-200',
                'pill' => 'bg-red-600 border-red-700 text-white',
                'label' => 'Superadmin',
            ],
            'admin' => [
                'box' => 'bg-yellow-100 border-yellow-200',
                'pill' => 'bg-yellow-500 border-yellow-600 text-black',
                'label' => 'Admin',
            ],
            'moderator' => [
                'box' => 'bg-green-100 border-green-200',
                'pill' => 'bg-green-600 border-green-700 text-white',
                'label' => 'Moderator',
            ],
            default => [
                'box' => 'bg-slate-100 border-slate-200',
                'pill' => 'bg-slate-500 border-slate-600 text-white',
                'label' => ($role !== '' ? ucfirst($role) : 'User'),
            ],
        };
    };

    $creatorRoleUi = $roleUi($creatorRole);
    $reportedRoleUi = $roleUi($reportedRole);
    $assignedRoleUi = $roleUi($assignedAdminRole);
@endphp

@section('content')
    <div id="ks_ticket_page"
         data-ticket-id="{{ $ticketId }}"
         data-draft-save-url="{{ $draftSaveUrl }}"
         class="ks-admin-ticket-show"
    >

        <div class="flex items-center justify-between gap-3 flex-wrap mb-3">
            <div class="flex items-center gap-3 flex-wrap">
                <h1 class="m-0">Ticket {{ $ticketId }}</h1>
            </div>

            <div class="flex-1 flex justify-center">
                <span id="js-status-badge" class="{{ $ksBadgeBaseTw }} {{ $statusBadgeTw }}">{{ $statusLabel }}</span>
            </div>

            <div class="flex items-center gap-3 flex-wrap">
                <a class="ks-btn no-underline text-slate-900" href="{{ route('admin.tickets.index') }}">Zurück zur Liste</a>
            </div>
        </div>

        @if($notice)
            <div class="ks-notice border p-3 rounded-xl mb-3">{{ (string) $notice }}</div>
        @endif

        <div class="ks-card mb-3">

            <div class="flex gap-2.5 items-stretch flex-wrap mb-2.5">
                <div class="bg-slate-50 border border-slate-200 rounded-xl px-2 py-1.5 min-w-[96px] flex-1 basis-[96px] text-center">
                    <b class="block text-[11px] text-slate-600 tracking-wide uppercase mb-0.5 text-left">Typ</b>
                    <span class="text-slate-900 font-extrabold">{{ $typeLabel }}</span>
                </div>

                <div id="js-box-category" class="bg-slate-50 border border-slate-200 rounded-xl px-2 py-1.5 min-w-[96px] flex-1 basis-[96px] text-center">
                    <b class="block text-[11px] text-slate-600 tracking-wide uppercase mb-0.5 text-left">Kategorie</b>
                    <span id="js-head-category-badge" class="block text-slate-900 font-extrabold">{{ $category !== '' ? $categoryLabel : '-' }}</span>
                </div>

                <div id="js-box-priority" class="bg-slate-50 border border-slate-200 rounded-xl px-2 py-1.5 min-w-[96px] flex-1 basis-[96px] text-center">
                    <b class="block text-[11px] text-slate-600 tracking-wide uppercase mb-0.5 text-left">Priorität</b>
                    <span id="js-head-priority-badge" class="block text-slate-900 font-extrabold">{{ $priorityLabel !== '' ? $priorityLabel : '-' }}</span>
                </div>

                <div class="{{ $creatorRoleUi['box'] }} border rounded-xl px-2 py-1.5 min-w-[96px] flex-1 basis-[96px] text-center">
                    <b class="block text-[11px] text-slate-600 tracking-wide uppercase mb-0.5 text-left">Ersteller</b>
                    @if($creatorProfileUrl !== '')
                        <a href="{{ $creatorProfileUrl }}" target="_self" class="block text-slate-900 font-extrabold underline leading-tight">{{ $creatorDisplay }}</a>
                    @else
                        <span class="block text-slate-900 font-extrabold leading-tight">{{ $creatorDisplay }}</span>
                    @endif
                    <div class="mt-0.5 text-xs text-slate-700 leading-tight">{{ $creatorRoleUi['label'] }}</div>
                </div>

                <div class="{{ $reportedRoleUi['box'] }} border rounded-xl px-2 py-1.5 min-w-[96px] flex-1 basis-[96px] text-center">
                    <b class="block text-[11px] text-slate-600 tracking-wide uppercase mb-0.5 text-left">Gemeldet</b>
                    @if($reportedProfileUrl !== '' && $reportedDisplay !== '-')
                        <a href="{{ $reportedProfileUrl }}" target="_self" class="text-slate-900 font-extrabold underline">{{ $reportedDisplay }}</a>
                    @else
                        <span class="text-slate-900 font-extrabold">{{ $reportedDisplay }}</span>
                    @endif
                    @if($reportedDisplay !== '-')
                        <div class="mt-1 text-xs text-slate-700">{{ $reportedRoleUi['label'] }}</div>
                    @endif
                </div>

                <div id="js-box-assigned" class="bg-emerald-100 border border-emerald-200 rounded-xl px-2 py-1.5 min-w-[96px] flex-1 basis-[96px] text-center">
                    <b class="block text-[11px] text-slate-600 tracking-wide uppercase mb-0.5 text-left">Bearbeiter</b>
                    @if($assignedAdminRole !== 'superadmin' && $assignedAdminProfileUrl !== '' && $assignedAdminDisplay !== '-')
                        <a id="js-head-assigned-link" href="{{ $assignedAdminProfileUrl }}" target="_self" class="text-slate-900 font-extrabold underline">{{ $assignedAdminDisplay }}</a>
                        <span id="js-head-assigned-text" class="hidden text-slate-900 font-extrabold">{{ $assignedAdminDisplay }}</span>
                    @else
                        <a id="js-head-assigned-link" href="#" target="_self" class="hidden text-slate-900 font-extrabold underline">{{ $assignedAdminDisplay }}</a>
                        <span id="js-head-assigned-text" class="text-slate-900 font-extrabold">{{ $assignedAdminDisplay }}</span>
                    @endif
                    <div id="js-head-assigned-role" class="mt-1 text-xs text-slate-700">{{ $assignedRoleUi['label'] }}</div>
                </div>
            </div>

            <div class="flex gap-2.5 flex-wrap items-center">
                <div class="bg-slate-100 border border-slate-200 rounded-xl px-2 py-1.5 basis-[180px] grow-0 shrink-0">
                    <b class="block text-[11px] text-slate-600 tracking-wide uppercase mb-0.5 text-left">Erstellt</b>
                    <span class="text-slate-900 font-extrabold">{{ $createdAt }}</span>
                </div>
                <div class="bg-emerald-50 border border-emerald-200 rounded-xl px-2 py-1.5 basis-[180px] grow-0 shrink-0">
                    <b class="block text-[11px] text-slate-600 tracking-wide uppercase mb-0.5 text-left">Geschlossen</b>
                    <span class="text-slate-900 font-extrabold">{!! $closedAt !== '' ? e($closedAt) : '<span class="text-slate-500">-</span>' !!}</span>
                </div>
            </div>

        </div>

        <h2 class="mt-5 mb-2.5 text-[18px]">Admin – Verwaltung</h2>
        <div class="ks-card">
            <form id="js-meta-form" method="POST" action="{{ route('admin.tickets.updateMeta', $ticketId) }}">
                @csrf

                <div class="flex items-end justify-between gap-3 flex-wrap mb-2.5">
                    <div class="ks-muted">Autospeichern aktiv (bei Änderung).</div>
                    <div class="flex items-center gap-2">
                        <div class="ks-muted" id="js-meta-status"></div>
                        <button id="js-meta-save-fallback" type="submit" class="ks-btn hidden">Speichern (Fallback)</button>
                    </div>
                </div>

                <div class="flex gap-3 flex-wrap items-end">
                    <div class="min-w-[210px]">
                        <div class="ks-muted mb-1.5">Bearbeiter</div>
                        <select id="js-assigned-admin-select" class="ks-input ks-select js-meta-field" name="assigned_admin_user_id">
                            @foreach($adminOptions as $o)
                                @php
                                    $id = $o['id'] ?? null;
                                    $label = (string) ($o['label'] ?? '');
                                    $display = (string) ($o['display'] ?? $label);
                                    $role = mb_strtolower(trim((string) ($o['role'] ?? '')));
                                    $roleLabel = (string) ($o['role_label'] ?? 'User');
                                    $profileUrl = (string) ($o['profile_url'] ?? '');
                                    $selected = (bool) ($o['selected'] ?? false);
                                    $value = ($id === null) ? '' : (string) (int) $id;
                                @endphp
                                <option value="{{ $value }}" data-display="{{ $display }}" data-role="{{ $role }}" data-role-label="{{ $roleLabel }}" data-profile-url="{{ $profileUrl }}" @selected($selected)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div class="min-w-[210px]">
                        <div class="ks-muted mb-1.5">Kategorie</div>
                        <select id="js-category-select" class="ks-input ks-select js-colored-select js-meta-field" name="category" data-kind="category">
                            @foreach($categoryOptions as $o)
                                @php
                                    $value = (string) ($o['value'] ?? '');
                                    $label = (string) ($o['label'] ?? '');
                                    $selected = (bool) ($o['selected'] ?? false);
                                @endphp
                                <option value="{{ $value }}" @selected($selected)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div class="min-w-[210px]">
                        <div class="ks-muted mb-1.5">Priorität</div>
                        <select id="js-priority-select" class="ks-input ks-select js-colored-select js-meta-field" name="priority" data-kind="priority">
                            @foreach($priorityOptions as $o)
                                @php
                                    $value = (string) ($o['value'] ?? '');
                                    $label = (string) ($o['label'] ?? '');
                                    $selected = (bool) ($o['selected'] ?? false);
                                @endphp
                                <option value="{{ $value }}" @selected($selected)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div class="min-w-[210px]">
                        <div class="ks-muted mb-1.5">Status</div>
                        <select id="js-status-select" class="ks-input ks-select js-colored-select js-meta-field" name="status" data-kind="status">
                            @foreach($statusOptions as $o)
                                @php
                                    $value = (string) ($o['value'] ?? '');
                                    $label = (string) ($o['label'] ?? '');
                                    $selected = (bool) ($o['selected'] ?? false);
                                @endphp
                                <option value="{{ $value }}" @selected($selected)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                </div>

            </form>
        </div>

        <div class="ks-card mt-3">
            <div class="ks-muted mb-1.5 underline">Betreff</div>

            <div class="font-black mb-2.5">
                @if($subjectText !== '')
                    {{ $subjectText }}
                @else
                    <span class="text-slate-500">(ohne)</span>
                @endif
            </div>

            <div class="border-t border-slate-200 my-2.5"></div>

            <div class="ks-muted mb-1.5 underline">Erstnachricht</div>
            <pre class="whitespace-pre-wrap m-0 font-inherit text-[14px]">{!! $messageText !== '' ? e($messageText) : '<span class="text-slate-500">(ohne)</span>' !!}</pre>
        </div>

        @if($isReport)
            <h2 class="mt-5 mb-2.5 text-[18px]">Moderation – Schnellaktionen</h2>
            <div class="ks-card">
                <div class="flex gap-3 flex-wrap items-center mb-3">

                    <form method="POST" action="{{ route('admin.tickets.moderate.warn', $ticketId) }}" class="m-0 flex gap-2.5 flex-wrap items-center">
                        @csrf
                        <input class="ks-input min-w-[240px]" type="text" name="note" placeholder="Notiz (optional)">
                        <button type="submit" class="ks-btn">Verwarnen</button>
                    </form>

                    <form method="POST" action="{{ route('admin.tickets.moderate.tempBan', $ticketId) }}" class="m-0 flex gap-2.5 flex-wrap items-center">
                        @csrf
                        <input class="ks-input w-24" type="number" name="days" min="1" max="365" value="7" required>
                        <input class="ks-input min-w-[240px]" type="text" name="note" placeholder="Notiz (optional)">
                        <button type="submit" class="ks-btn">Temp. Sperre</button>
                    </form>

                    <form method="POST" action="{{ route('admin.tickets.moderate.permBan', $ticketId) }}" class="m-0 flex gap-2.5 flex-wrap items-center">
                        @csrf
                        <input class="ks-input min-w-[240px]" type="text" name="note" placeholder="Notiz (optional)">
                        <button type="submit" class="ks-btn">Dauerhaft</button>
                    </form>

                    <form method="POST" action="{{ route('admin.tickets.moderate.unfounded', $ticketId) }}" class="m-0 flex gap-2.5 flex-wrap items-center">
                        @csrf
                        <input class="ks-input min-w-[240px]" type="text" name="note" placeholder="Notiz (optional)">
                        <button type="submit" class="ks-btn">Unbegründet</button>
                    </form>

                </div>
            </div>
        @endif

        <h2 class="mt-5 mb-2.5 text-[18px]">Antwort</h2>

        <div class="ks-card">
            @if($errors && $errors->any())
                <div class="border border-red-200 bg-red-50 rounded-xl p-3 mb-3">
                    <div class="font-black mb-1.5">Fehler beim Absenden</div>
                    <ul class="m-0 pl-5">
                        @foreach($errors->all() as $err)
                            <li>{{ $err }}</li>
                        @endforeach
                    </ul>
                </div>
            @endif

            <form id="js-reply-form" method="POST" action="{{ route('admin.tickets.reply', $ticketId) }}">
                @csrf

                <div class="flex items-end justify-between gap-3 flex-wrap mb-1.5">
                    <div class="ks-label">Antwort an Nutzer (sichtbar)</div>

                    <div class="flex items-center justify-end gap-2">
                        <span class="ks-muted" id="js-draft-status"></span>
                        <span class="ks-info" title="Entwürfe werden automatisch als Draft gespeichert. Erst 'Absenden' erzeugt einen sichtbaren Eintrag und triggert Events.">i</span>
                    </div>
                </div>

                <textarea id="js-reply-message" class="w-full max-w-full block min-h-[160px] px-3 py-2.5 rounded-xl border border-slate-300 bg-white font-inherit text-[14px]" name="reply_message" placeholder="Antwort an den Nutzer...">{{ $draftReplyText }}</textarea>

                <div class="ks-label mt-3 mb-1.5">Interne Admin-Notiz (nicht sichtbar für den Nutzer)</div>
                <textarea id="js-internal-note" class="w-full max-w-full block min-h-[160px] px-3 py-2.5 rounded-xl border border-slate-300 bg-white font-inherit text-[14px]" name="internal_note" placeholder="Interne Notiz...">{{ $draftInternalText }}</textarea>

                <div class="flex justify-end mt-2.5">
                    <div class="flex gap-2.5">
                        <button id="js-draft-save-fallback" type="submit" class="ks-btn" formaction="{{ route('admin.tickets.draftSave', $ticketId) }}" formmethod="POST">Entwurf speichern (Fallback)</button>
                        <button id="js-reply-submit" type="submit" class="ks-btn" formaction="{{ route('admin.tickets.reply', $ticketId) }}" formmethod="POST">Absenden</button>
                        <button type="submit" class="ks-btn" formaction="{{ route('admin.tickets.close', $ticketId) }}" formmethod="POST">Ticket schließen</button>
                    </div>
                </div>
            </form>
        </div>

        <h2 class="mt-5 mb-2.5 text-[18px]">Verlauf</h2>

        @if(count($messageRows) < 1)
            <div class="ks-muted">(noch keine Nachrichten)</div>
        @else
            @foreach($messageRows as $m)
                @php
                    $who = (string) ($m['who'] ?? '-');
                    $actorRoleLabel = (string) ($m['actor_role_label'] ?? '');
                    $actorRoleClass = (string) ($m['actor_role_class'] ?? 'bg-slate-500 border-slate-600 text-white');
                    $isInternal = (bool) ($m['is_internal'] ?? false);
                    $msgText = (string) ($m['message'] ?? '');
                    $ts = (string) ($m['created_at'] ?? '');
                @endphp

                <div class="border border-slate-200 rounded-xl p-3 bg-white mb-2.5">
                    <div class="flex justify-between gap-2.5 flex-wrap mb-1.5">
                        <div class="flex items-center gap-2 flex-wrap">
                            <span class="inline-flex flex-col items-center justify-center px-3 py-1 rounded-full text-xs font-black border text-center leading-tight {{ $actorRoleClass }}">
                                <span class="block">{{ $who }}</span>
                                @if($actorRoleLabel !== '')
                                    <span class="block text-[11px] font-black opacity-95">({{ $actorRoleLabel }})</span>
                                @endif
                            </span>

                            @if($isInternal)
                                <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-black border border-slate-900 bg-slate-900 text-slate-200">INTERN</span>
                            @endif
                        </div>
                        <div class="ks-muted">{{ $ts }}</div>
                    </div>
                    <pre class="whitespace-pre-wrap m-0 font-inherit text-[14px]">{{ $msgText }}</pre>
                </div>
            @endforeach
        @endif

        <h2 class="mt-5 mb-2.5 text-[18px]">Audit</h2>
        <div class="ks-card">
            <div class="border border-slate-200 rounded-xl bg-white overflow-hidden">
                <table class="w-full border-separate border-spacing-0">
                    <thead>
                    <tr>
                        <th class="text-left px-3 py-2.5 border-b border-slate-200 align-top text-xs text-slate-600 tracking-wide uppercase bg-slate-50">Zeit</th>
                        <th class="text-left px-3 py-2.5 border-b border-slate-200 align-top text-xs text-slate-600 tracking-wide uppercase bg-slate-50">Event</th>
                        <th class="text-left px-3 py-2.5 border-b border-slate-200 align-top text-xs text-slate-600 tracking-wide uppercase bg-slate-50">Akteur</th>
                        <th class="text-left px-3 py-2.5 border-b border-slate-200 align-top text-xs text-slate-600 tracking-wide uppercase bg-slate-50">Meta</th>
                    </tr>
                    </thead>
                    <tbody>
                    @if(count($auditRows) < 1)
                        <tr><td colspan="4" class="text-slate-500">(keine Audit-Logs)</td></tr>
                    @else
                        @foreach($auditRows as $a)
                            @php
                                $ts = (string) ($a['created_at'] ?? '');
                                $evLabel = (string) ($a['event_label'] ?? '');
                                $who = (string) ($a['who'] ?? '-');
                                $actorRoleLabel = (string) ($a['actor_role_label'] ?? '');
                                $actorRoleClass = (string) ($a['actor_role_class'] ?? 'bg-slate-500 border-slate-600 text-white');
                                $meta = (string) ($a['meta'] ?? '');
                            @endphp
                            <tr>
                                <td class="text-left px-3 py-2.5 border-b border-slate-200 align-top">{{ $ts }}</td>
                                <td class="text-left px-3 py-2.5 border-b border-slate-200 align-top">{{ $evLabel }}</td>
                                <td class="px-3 py-2.5 border-b border-slate-200 align-top">
                                    <div class="flex justify-center">
                                        <span class="inline-flex flex-col items-center justify-center px-3 py-1 rounded-full text-xs font-black border text-center leading-tight {{ $actorRoleClass }}">
                                            <span class="block">{{ $who }}</span>
                                            @if($actorRoleLabel !== '')
                                                <span class="block text-[11px] font-black opacity-95">({{ $actorRoleLabel }})</span>
                                            @endif
                                        </span>
                                    </div>
                                </td>
                                <td class="text-left px-3 py-2.5 border-b border-slate-200 align-top"><pre class="whitespace-pre-wrap m-0 font-inherit text-[14px]">{{ $meta }}</pre></td>
                            </tr>
                        @endforeach
                    @endif
                    </tbody>
                </table>
            </div>
        </div>

    </div>
@endsection