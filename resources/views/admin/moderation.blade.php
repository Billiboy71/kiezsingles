{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\moderation.blade.php
Purpose: Admin moderation UI (configure per-user section whitelist for moderator/admin)
Changed: 23-02-2026 18:00 (Europe/Berlin)
Version: 0.3
============================================================================ --}}

@extends('admin.layouts.admin')

@section('content')

    <div>

        <h1 class="m-0 mb-2 text-xl font-bold text-gray-900">Admin – Moderation</h1>

        <p class="m-0 mb-4 text-[13px] text-gray-700">
            Rechteverwaltung (Section-Whitelist, DB-basiert, pro User) für <b>{{ $roleLabel }}</b>.
        </p>

        @if(!empty($notice))
            <div class="px-[14px] py-[12px] rounded-[10px] border border-green-200 bg-green-50 mb-4">
                {{ (string) $notice }}
            </div>
        @endif

        @if(!$hasUsersTable)
            <div class="px-[14px] py-[12px] rounded-[10px] border border-red-200 bg-red-50 mb-4">
                <b>Hinweis:</b> Tabelle <code>users</code> existiert nicht. Auswahl ist nicht möglich.
            </div>
        @elseif(count($users) < 1)
            <div class="px-[14px] py-[12px] rounded-[10px] border border-red-200 bg-red-50 mb-4">
                <b>Hinweis:</b> Keine User gefunden (role = <code>{{ $targetRole }}</code>).
            </div>
        @endif

        @if(!$hasSystemSettingsTable)
            <div class="px-[14px] py-[12px] rounded-[10px] border border-red-200 bg-red-50 mb-4">
                <b>Hinweis:</b> Tabelle <code>system_settings</code> existiert nicht. Speichern ist nicht möglich.
            </div>
        @endif

        {{-- GET: Rolle/User wählen – Auto-Load (ohne "Laden"-Button) --}}
        <form id="js-select-form" method="GET" action="{{ route('admin.moderation') }}" class="m-0 mb-4">
            <div class="ks-card">
                <h2 class="m-0 mb-2 text-[16px] font-bold text-gray-900">Rolle &amp; User auswählen</h2>

                <div class="flex gap-[10px] flex-wrap items-center">
                    <label class="flex flex-col gap-[6px] text-[13px] text-gray-600">
                        Rolle
                        <select id="js-role-select" name="role" class="px-[12px] py-[10px] rounded-[10px] border border-slate-300 min-w-[180px] bg-white">
                            <option value="moderator" @selected($targetRole === 'moderator')>Moderator</option>
                            <option value="admin" @selected($targetRole === 'admin')>Admin</option>
                        </select>
                    </label>

                    @if($hasUsersTable && count($users) > 0)
                        <label class="flex flex-col gap-[6px] text-[13px] text-gray-600">
                            User
                            <select id="js-user-select" name="user_id" class="px-[12px] py-[10px] rounded-[10px] border border-slate-300 min-w-[320px] bg-white">
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
                        <div class="text-[13px] text-gray-600">Keine Auswahl möglich.</div>
                    @endif

                    <div id="js-load-status" class="text-[13px] text-gray-600 ml-auto"></div>
                </div>
            </div>
        </form>

        {{-- POST: Sections – Auto-Save per Checkbox-Change (Submit nach Debounce; Button bleibt als Fallback) --}}
        <form id="js-sections-form" method="POST" action="{{ route('admin.moderation.save') }}" class="m-0">
            @csrf

            <input type="hidden" name="role" value="{{ $targetRole }}">

            @if($selectedUserId !== null)
                <input type="hidden" name="user_id" value="{{ (string) $selectedUserId }}">
            @endif

            <div class="ks-card mb-4">
                <div class="flex gap-[10px] items-end flex-wrap mb-[10px]">
                    <div class="flex-1 min-w-0">
                        <h2 class="m-0 mb-[6px] text-[16px] font-bold text-gray-900">{{ $roleLabel }} darf sehen/darf nutzen</h2>
                        <div class="text-[13px] text-gray-600">Diese Sections werden serverseitig erzwungen (Middleware <code>section:*</code>).</div>
                    </div>
                    <div id="js-save-status" class="text-[13px] text-gray-600 min-w-[180px] text-right"></div>
                </div>

                @foreach($options as $key => $label)
                    @php
                        $checked = in_array((string) $key, (array) $current, true);
                        $disabled = (!$hasSystemSettingsTable || $selectedUserId === null);
                    @endphp

                    <label class="flex items-center gap-[10px] px-[12px] py-[10px] border border-gray-200 rounded-[10px] mb-[10px]">
                        <input class="js-section-box" type="checkbox" name="sections[]" value="{{ (string) $key }}" @checked($checked) @disabled($disabled)>
                        <div>
                            <b>{{ (string) $label }}</b>
                            <div class="text-[12px] text-gray-500">{{ (string) $key }}</div>
                        </div>
                    </label>
                @endforeach
            </div>

            <div class="flex gap-[10px] flex-wrap">
                <a href="{{ url('/admin') }}" class="ks-btn no-underline text-gray-900">
                    Zur Übersicht
                </a>

                <button
                    type="submit"
                    class="px-[12px] py-[10px] rounded-[10px] border border-gray-900 bg-gray-900 text-white cursor-pointer disabled:opacity-45 disabled:cursor-not-allowed"
                    @disabled(!$hasSystemSettingsTable || $selectedUserId === null)
                >
                    Speichern
                </button>
            </div>
        </form>

    </div>

@endsection