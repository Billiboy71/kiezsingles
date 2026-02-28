{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\users\show.blade.php
Purpose: Superadmin user detail for role governance actions (Modul A)
Changed: 28-02-2026 15:07 (Europe/Berlin)
Version: 0.2
============================================================================ --}}

@extends('admin.layouts.admin')

@section('content')
    @php
        $roleNames = $targetUser->roles->pluck('name')->map(static fn ($r) => mb_strtolower((string) $r))->values()->all();
        if (count($roleNames) < 1) {
            $roleNames = ['user'];
        }
        $isProtected = (bool) ($targetUser->is_protected_admin ?? false);
        $primaryRole = in_array('superadmin', $roleNames, true)
            ? 'superadmin'
            : (in_array('admin', $roleNames, true)
                ? 'admin'
                : (in_array('moderator', $roleNames, true) ? 'moderator' : 'user'));
    @endphp

    <div class="space-y-4">
        <div class="flex items-center justify-between gap-3">
            <div>
                <h1 class="text-xl font-bold text-gray-900">User-Detail</h1>
                <p class="text-sm text-gray-600">{{ (string) ($targetUser->email ?? '-') }} (ID {{ (int) $targetUser->id }})</p>
            </div>
            <a href="{{ route('admin.users.index') }}" class="rounded-md border border-gray-300 px-3 py-2 text-sm">Zur Liste</a>
        </div>

        @if(!empty($notice))
            <div class="rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-sm text-gray-800">
                {{ (string) $notice }}
            </div>
        @endif

        @if($errors->any())
            <div class="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
                {{ $errors->first() }}
            </div>
        @endif

        <div class="rounded-lg border border-gray-200 bg-white p-4 text-sm">
            <div><b>Public ID:</b> {{ (string) ($targetUser->public_id ?? '-') }}</div>
            <div><b>Username:</b> {{ (string) ($targetUser->username ?? '-') }}</div>
            <div><b>Aktuelle Rollen:</b> {{ implode(', ', $roleNames) }}</div>
            <div><b>Protected-Admin:</b> {{ $targetUser->is_protected_admin ? 'Ja (DB-only)' : 'Nein' }}</div>
        </div>

        @if($isProtected)
            <div class="rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900">
                Dieser User ist als <b>Protected Admin</b> markiert. Rollenänderung und Löschung sind gesperrt.
            </div>
        @endif

        @if(!$isProtected)
            <div class="rounded-lg border border-gray-200 bg-white p-4">
                <h2 class="mb-3 text-base font-semibold text-gray-900">Rolle ändern</h2>

                <form method="POST" action="{{ route('admin.users.roles.update', $targetUser) }}" class="space-y-3">
                    @csrf
                    @method('PATCH')

                    <label class="block text-sm text-gray-700" for="role">Primäre Rolle</label>
                    <select id="role" name="role" class="w-full max-w-sm rounded-md border border-gray-300 px-3 py-2">
                        <option value="moderator" @selected($primaryRole === 'moderator')>moderator</option>
                        <option value="admin" @selected($primaryRole === 'admin')>admin</option>
                        <option value="superadmin" @selected($primaryRole === 'superadmin')>superadmin</option>
                        <option value="user" @selected($primaryRole === 'user')>user</option>
                    </select>

                    <button type="submit" class="rounded-md bg-gray-900 px-4 py-2 text-sm text-white">Rollen speichern</button>
                </form>
            </div>

            <div class="rounded-lg border border-red-200 bg-white p-4">
                <h2 class="mb-3 text-base font-semibold text-red-700">User löschen</h2>

                <form method="POST" action="{{ route('admin.users.destroy', $targetUser) }}">
                    @csrf
                    @method('DELETE')
                    <button type="submit" class="rounded-md border border-red-300 bg-red-50 px-4 py-2 text-sm text-red-700">User löschen</button>
                </form>
            </div>
        @endif
    </div>
@endsection
