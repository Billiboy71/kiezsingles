<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\allowlist\ip\index.blade.php
// Purpose: Admin Security - Manage IP allowlist entries for autoban exclusions
// Created: 09-03-2026 (Europe/Berlin)
// Changed: 09-03-2026 04:14 (Europe/Berlin)
// Version: 0.1
// ============================================================================

?>
@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')
    @include('admin.security.allowlist._tabs')

    @if(session('admin_notice'))
        <div class="ks-notice p-3 rounded-lg border mb-3">{{ session('admin_notice') }}</div>
    @endif

    <form method="POST" action="{{ route('admin.security.allowlist.ip.store') }}" class="ks-card mb-4 grid grid-cols-1 md:grid-cols-4 gap-3">
        @csrf
        <div class="md:col-span-4 flex items-start justify-between gap-3">
            <h3>IP-Allowlist-Eintrag anlegen</h3>
        </div>
        <div><label>IP / Pattern</label><input class="w-full" type="text" name="value" required></div>
        <div><label>Beschreibung</label><input class="w-full" type="text" name="description"></div>
        <div class="flex items-end"><label class="inline-flex items-center gap-2"><input type="checkbox" name="is_active" value="1" checked> Aktiv</label></div>
        <div class="flex items-end"><label class="inline-flex items-center gap-2"><input type="checkbox" name="autoban_only" value="1" checked> Nur Autoban umgehen</label></div>
        <div><button class="ks-btn" type="submit">Allowlist speichern</button></div>
    </form>

    <div class="ks-card">
        <div class="flex items-center justify-end mb-2">
            <form method="GET" action="{{ route('admin.security.allowlist.ip.index') }}" class="flex items-center gap-2 text-xs">
                <select class="w-[75px] py-1 text-xs" name="per_page" onchange="this.form.submit()">
                    <option value="20" {{ (int) $perPage === 20 ? 'selected' : '' }}>20</option>
                    <option value="50" {{ (int) $perPage === 50 ? 'selected' : '' }}>50</option>
                    <option value="100" {{ (int) $perPage === 100 ? 'selected' : '' }}>100</option>
                </select>
                <noscript><button class="ks-btn" type="submit">OK</button></noscript>
            </form>
        </div>

        <div class="overflow-x-auto">
            <table class="w-full min-w-[980px] text-sm">
                <thead>
                <tr>
                    <th class="text-left px-3 py-2">Wert</th>
                    <th class="text-left px-3 py-2">Beschreibung</th>
                    <th class="text-left px-3 py-2 whitespace-nowrap">Aktiv</th>
                    <th class="text-left px-3 py-2 whitespace-nowrap">Nur Autoban</th>
                    <th class="text-left px-3 py-2 whitespace-nowrap">Created</th>
                    <th class="text-left px-3 py-2 whitespace-nowrap">Updated</th>
                    <th class="text-left px-3 py-2 whitespace-nowrap">Aktion</th>
                </tr>
                </thead>
                <tbody>
                @forelse($allowlistEntries as $entry)
                    <tr>
                        <td class="px-3 py-2 align-top">{{ $entry->value }}</td>
                        <td class="px-3 py-2 align-top max-w-[360px] break-words">
                            <form method="POST" action="{{ route('admin.security.allowlist.ip.update', $entry->id) }}" class="flex flex-col gap-2">
                                @csrf
                                @method('PATCH')
                                <input class="w-full" type="text" name="description" value="{{ $entry->description }}">
                                <label class="inline-flex items-center gap-2"><input type="checkbox" name="is_active" value="1" {{ $entry->is_active ? 'checked' : '' }}> Aktiv</label>
                                <label class="inline-flex items-center gap-2"><input type="checkbox" name="autoban_only" value="1" {{ $entry->autoban_only ? 'checked' : '' }}> Nur Autoban umgehen</label>
                                <button class="ks-btn w-fit" type="submit">Aktualisieren</button>
                            </form>
                        </td>
                        <td class="px-3 py-2 align-top whitespace-nowrap">{{ $entry->is_active ? 'Ja' : 'Nein' }}</td>
                        <td class="px-3 py-2 align-top whitespace-nowrap">{{ $entry->autoban_only ? 'Ja' : 'Nein' }}</td>
                        <td class="px-3 py-2 align-top whitespace-nowrap">{{ $entry->created_at }}</td>
                        <td class="px-3 py-2 align-top whitespace-nowrap">{{ $entry->updated_at }}</td>
                        <td class="px-3 py-2 align-top whitespace-nowrap">
                            <form method="POST" action="{{ route('admin.security.allowlist.ip.destroy', $entry->id) }}">
                                @csrf
                                @method('DELETE')
                                <button class="ks-btn" type="submit">Entfernen</button>
                            </form>
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="7" class="px-3 py-3">Keine IP-Allowlist-Einträge vorhanden.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>

        <div class="mt-3">{{ $allowlistEntries->appends(request()->query())->links('vendor.pagination.tailwind') }}</div>
    </div>
@endsection
