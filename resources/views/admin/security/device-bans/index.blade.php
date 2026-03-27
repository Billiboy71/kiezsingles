<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\device-bans\index.blade.php
// Purpose: Admin Security - Manage device bans (hash-based bans with optional TTL)
// Created: 02-03-2026 (Europe/Berlin)
// Changed: 24-03-2026 11:04 (Europe/Berlin)
// Version: 0.5
// ============================================================================

?>
@php
    if (!function_exists('extractIncidentId')) {
        function extractIncidentId($reason) {
            if (!$reason) {
                return null;
            }

            if (preg_match('/Incident\s+#?\s*(\d+)/i', $reason, $matches)) {
                return $matches[1];
            }

            return null;
        }
    }
@endphp
@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    @if(session('admin_notice'))
        <div class="ks-notice p-3 rounded-lg border mb-3">{{ session('admin_notice') }}</div>
    @endif

    <form method="POST" action="{{ route('admin.security.device_bans.store') }}" class="ks-card mb-4 grid grid-cols-1 md:grid-cols-3 gap-3">
        @csrf
        <div class="md:col-span-3 flex items-start justify-between gap-3">
            <h3>Geräte-Sperre anlegen</h3>
            <x-ui.help-popover id="security-device-bans-help" title="Hilfe: Geräte-Sperren">
                <ul>
                    <li>Eine Geräte-Sperre blockiert Login und Registrierung anhand des Geräte-Hash.</li>
                    <li>Den Hash findest du in Sicherheits-Ereignissen und in der Übersicht.</li>
                    <li>TTL ist optional: leer bedeutet unbefristet, sonst automatische Freigabe nach Ablauf.</li>
                    <li>Der Grund dient zur internen Nachvollziehbarkeit.</li>
                </ul>
            </x-ui.help-popover>
        </div>
        <div><label>Geräte-Hash (64 Zeichen)</label><input class="w-full" type="text" name="device_hash" maxlength="64" required></div>
        <div>
            <label>TTL Minuten (optional)</label>
            <input class="w-full" type="number" min="1" name="ttl_minutes" inputmode="numeric" data-ks-ttl-minutes>
            <input type="hidden" name="ttl_seconds" data-ks-ttl-seconds>
            <script>
                (function () {
                    try {
                        var minEl = document.querySelector('[data-ks-ttl-minutes]');
                        var secEl = document.querySelector('[data-ks-ttl-seconds]');
                        if (!minEl || !secEl) { return; }

                        function sync() {
                            var v = (minEl.value || '').toString().trim();
                            if (v === '') {
                                secEl.value = '';
                                return;
                            }
                            var n = parseInt(v, 10);
                            if (!isFinite(n) || n <= 0) {
                                secEl.value = '';
                                return;
                            }
                            secEl.value = String(n * 60);
                        }

                        minEl.addEventListener('input', sync);
                        minEl.addEventListener('change', sync);
                        sync();
                    } catch (e) {
                        // ignore
                    }
                })();
            </script>
        </div>
        <div><label>Grund</label><input class="w-full" type="text" name="reason"></div>
        <div><button class="ks-btn" type="submit">Geräte-Sperre speichern</button></div>
    </form>

    <div class="ks-card">
        <div class="flex items-center justify-end mb-2">
            <form method="GET" action="{{ route('admin.security.device_bans.index') }}" class="flex items-center gap-2 text-xs">
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
        <table class="w-full min-w-[860px] text-sm">
            <thead><tr><th class="text-left px-3 py-2">Geräte-Hash</th><th class="text-left px-3 py-2">Grund</th><th class="text-left px-3 py-2 whitespace-nowrap">Bis</th><th class="text-left px-3 py-2 whitespace-nowrap">Aktion</th></tr></thead>
            <tbody>
            @forelse($deviceBans as $ban)
                <tr>
                    <td class="px-3 py-2 align-top max-w-[360px] break-all">{{ $ban->device_hash }}</td>
                    <td class="px-3 py-2 align-top max-w-[420px] break-words">
                        @php $incidentId = extractIncidentId($ban->reason); @endphp

                        @if($incidentId)
                            <a href="{{ route('admin.security.incidents.show', $incidentId) }}">
                                {{ $ban->reason }}
                            </a>
                        @else
                            {{ $ban->reason }}
                        @endif

                        <div class="mt-1 text-xs text-gray-600">
                            {{ $ban->created_at ?? '-' }}
                            |
                            @if($ban->created_by_user_name)
                                {{ $ban->created_by_user_name }}
                            @elseif($ban->created_by_user_email)
                                {{ $ban->created_by_user_email }}
                            @elseif($ban->created_by)
                                User #{{ $ban->created_by }}
                            @else
                                System
                            @endif
                        </div>
                    </td>
                    <td class="px-3 py-2 align-top whitespace-nowrap">{{ $ban->banned_until }}</td>
                    <td class="px-3 py-2 align-top whitespace-nowrap">
                        <form method="POST" action="{{ route('admin.security.device_bans.destroy', $ban->id) }}">
                            @csrf
                            @method('DELETE')
                            <button class="ks-btn" type="submit">Entfernen</button>
                        </form>
                    </td>
                </tr>
            @empty
                <tr><td colspan="4" class="px-3 py-3">Keine Geräte-Sperren vorhanden.</td></tr>
            @endforelse
            </tbody>
        </table>
        </div>

        <div class="mt-3">{{ $deviceBans->appends(request()->query())->links('vendor.pagination.tailwind') }}</div>
    </div>
@endsection
