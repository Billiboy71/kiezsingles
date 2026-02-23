{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\moderation.blade.php
Purpose: Admin moderation UI (configure per-user section whitelist for moderator/admin)
Changed: 19-02-2026 00:03 (Europe/Berlin)
Version: 0.1
============================================================================ --}}

@extends('admin.layouts.admin')

@section('content')

    <div style="padding:0; margin:0;">

        <h1 style="margin:0 0 8px 0;">Admin – Moderation</h1>

        <p style="margin:0 0 16px 0; color:#444;">
            Rechteverwaltung (Section-Whitelist, DB-basiert, pro User) für <b>{{ $roleLabel }}</b>.
        </p>

        @if(!empty($notice))
            <div style="padding:12px 14px; border-radius:10px; border:1px solid #bbf7d0; background:#f0fff4; margin:0 0 16px 0;">
                {{ (string) $notice }}
            </div>
        @endif

        @if(!$hasUsersTable)
            <div style="padding:12px 14px; border-radius:10px; border:1px solid #fecaca; background:#fff5f5; margin:0 0 16px 0;">
                <b>Hinweis:</b> Tabelle <code>users</code> existiert nicht. Auswahl ist nicht möglich.
            </div>
        @elseif(count($users) < 1)
            <div style="padding:12px 14px; border-radius:10px; border:1px solid #fecaca; background:#fff5f5; margin:0 0 16px 0;">
                <b>Hinweis:</b> Keine User gefunden (role = <code>{{ $targetRole }}</code>).
            </div>
        @endif

        @if(!$hasSystemSettingsTable)
            <div style="padding:12px 14px; border-radius:10px; border:1px solid #fecaca; background:#fff5f5; margin:0 0 16px 0;">
                <b>Hinweis:</b> Tabelle <code>system_settings</code> existiert nicht. Speichern ist nicht möglich.
            </div>
        @endif

        {{-- GET: Rolle/User wählen – Auto-Load (ohne "Laden"-Button) --}}
        <form id="js-select-form" method="GET" action="{{ route('admin.moderation') }}" style="margin:0 0 16px 0;">
            <div style="border:1px solid #e5e7eb; border-radius:12px; padding:14px 14px; background:#fff;">
                <h2 style="margin:0 0 8px 0; font-size:16px;">Rolle &amp; User auswählen</h2>

                <div style="display:flex; gap:10px; flex-wrap:wrap; align-items:center;">
                    <label style="display:flex; flex-direction:column; gap:6px; font-size:13px; color:#555;">
                        Rolle
                        <select id="js-role-select" name="role" style="padding:10px 12px; border-radius:10px; border:1px solid #cbd5e1; min-width:180px;">
                            <option value="moderator" @selected($targetRole === 'moderator')>Moderator</option>
                            <option value="admin" @selected($targetRole === 'admin')>Admin</option>
                        </select>
                    </label>

                    @if($hasUsersTable && count($users) > 0)
                        <label style="display:flex; flex-direction:column; gap:6px; font-size:13px; color:#555;">
                            User
                            <select id="js-user-select" name="user_id" style="padding:10px 12px; border-radius:10px; border:1px solid #cbd5e1; min-width:320px;">
                                @foreach($users as $u)
                                    @php
                                        $uid = (int) ($u->id ?? 0);

                                        $label = '';
                                        if (!empty($hasUserNameColumn)) {
                                            $label = trim((string) ($u->name ?? ''));
                                        }
                                        if ($label === '' && !empty($hasUserUsernameColumn)) {
                                            $label = trim((string) ($u->username ?? ''));
                                        }
                                        if ($label === '') {
                                            $label = (string) ($u->email ?? ('User #' . $uid));
                                        }
                                    @endphp

                                    <option value="{{ (string) $uid }}" @selected($selectedUserId !== null && (int) $selectedUserId === $uid)>
                                        {{ $label }} (ID {{ (string) $uid }})
                                    </option>
                                @endforeach
                            </select>
                        </label>
                    @else
                        <div style="color:#666; font-size:13px;">Keine Auswahl möglich.</div>
                    @endif

                    <div id="js-load-status" style="color:#666; font-size:13px; margin-left:auto;"></div>
                </div>
            </div>
        </form>

        {{-- POST: Sections – Auto-Save per Checkbox-Change (Submit nach Debounce; Button bleibt als Fallback) --}}
        <form id="js-sections-form" method="POST" action="{{ route('admin.moderation.save') }}" style="margin:0;">
            @csrf

            <input type="hidden" name="role" value="{{ $targetRole }}">

            @if($selectedUserId !== null)
                <input type="hidden" name="user_id" value="{{ (string) $selectedUserId }}">
            @endif

            <div style="border:1px solid #e5e7eb; border-radius:12px; padding:14px 14px; background:#fff; margin:0 0 16px 0;">
                <div style="display:flex; gap:10px; align-items:flex-end; flex-wrap:wrap; margin:0 0 10px 0;">
                    <div style="flex:1 1 auto;">
                        <h2 style="margin:0 0 6px 0; font-size:16px;">{{ $roleLabel }} darf sehen/darf nutzen</h2>
                        <div style="color:#555; font-size:13px;">Diese Sections werden serverseitig erzwungen (Middleware <code>section:*</code>).</div>
                    </div>
                    <div id="js-save-status" style="color:#666; font-size:13px; min-width:180px; text-align:right;"></div>
                </div>

                @foreach($options as $key => $label)
                    @php
                        $checked = in_array((string) $key, (array) $current, true);
                        $disabled = (!$hasSystemSettingsTable || $selectedUserId === null);
                    @endphp

                    <label style="display:flex; align-items:center; gap:10px; padding:10px 12px; border:1px solid #e5e7eb; border-radius:10px; margin:0 0 10px 0;">
                        <input class="js-section-box" type="checkbox" name="sections[]" value="{{ (string) $key }}" @checked($checked) @disabled($disabled)>
                        <div>
                            <b>{{ (string) $label }}</b>
                            <div style="color:#666; font-size:12px;">{{ (string) $key }}</div>
                        </div>
                    </label>
                @endforeach
            </div>

            <div style="display:flex; gap:10px; flex-wrap:wrap;">
                <a href="{{ url('/admin') }}" style="padding:10px 12px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; text-decoration:none; color:#111;">
                    Zur Übersicht
                </a>

                <button
                    type="submit"
                    style="padding:10px 12px; border-radius:10px; border:1px solid #111827; background:#111827; color:#fff; cursor:pointer;"
                    @disabled(!$hasSystemSettingsTable || $selectedUserId === null)
                >
                    Speichern
                </button>
            </div>
        </form>

        <script>
            (function () {
                var f = document.getElementById('js-select-form');
                var rs = document.getElementById('js-role-select');
                var us = document.getElementById('js-user-select');
                var ls = document.getElementById('js-load-status');

                function submitSelect() {
                    if (!f) return;
                    if (ls) ls.textContent = 'lädt…';
                    try { f.submit(); } catch (e) {}
                }

                if (rs) { rs.addEventListener('change', function () { submitSelect(); }); }
                if (us) { us.addEventListener('change', function () { submitSelect(); }); }

                var sf = document.getElementById('js-sections-form');
                var ss = document.getElementById('js-save-status');
                var t = null;

                function scheduleSave() {
                    if (!sf) return;
                    if (t) clearTimeout(t);
                    if (ss) ss.textContent = 'speichert…';
                    t = setTimeout(function () {
                        try { sf.submit(); } catch (e) {}
                    }, 600);
                }

                if (sf) {
                    var boxes = sf.querySelectorAll('.js-section-box');
                    for (var i = 0; i < boxes.length; i++) {
                        boxes[i].addEventListener('change', function () { scheduleSave(); });
                    }
                }
            })();
        </script>

    </div>

@endsection
