{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\users\index.blade.php
Purpose: Superadmin user list for role governance (Modul A)
Changed: 28-02-2026 15:11 (Europe/Berlin)
Version: 0.3
============================================================================ --}}

@extends('admin.layouts.admin')

@section('content')
    <div class="space-y-4">
        <div>
            <h1 class="text-xl font-bold text-gray-900">User-Verwaltung</h1>
            <p class="text-sm text-gray-600">Rollenverwaltung nur für Superadmin.</p>
        </div>

        @if(!empty($notice))
            <div class="rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-sm text-gray-800">
                {{ (string) $notice }}
            </div>
        @endif

        <form method="GET" action="{{ route('admin.users.index') }}" class="rounded-lg border border-gray-200 bg-white p-4">
            <div class="flex flex-wrap items-end gap-3">
                <div>
                    <label for="q" class="mb-1 block text-xs font-semibold text-gray-600">Suche</label>
                    <input id="q" name="q" type="text" value="{{ (string) ($q ?? '') }}" placeholder="Username oder E-Mail" class="w-64 rounded-md border border-gray-300 px-3 py-2 text-sm">
                </div>

                <div>
                    <label for="role" class="mb-1 block text-xs font-semibold text-gray-600">Rolle</label>
                    <select id="role" name="role" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
                        <option value="" @selected(($roleFilter ?? '') === '')>Alle</option>
                        <option value="superadmin" @selected(($roleFilter ?? '') === 'superadmin')>superadmin</option>
                        <option value="admin" @selected(($roleFilter ?? '') === 'admin')>admin</option>
                        <option value="moderator" @selected(($roleFilter ?? '') === 'moderator')>moderator</option>
                        <option value="user" @selected(($roleFilter ?? '') === 'user')>user</option>
                    </select>
                </div>

                <div>
                    <label for="per_page" class="mb-1 block text-xs font-semibold text-gray-600">Pro Seite</label>
                    <select id="per_page" name="per_page" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
                        <option value="50" @selected((int) ($perPage ?? 50) === 50)>50</option>
                        <option value="100" @selected((int) ($perPage ?? 50) === 100)>100</option>
                        <option value="150" @selected((int) ($perPage ?? 50) === 150)>150</option>
                        <option value="200" @selected((int) ($perPage ?? 50) === 200)>200</option>
                    </select>
                </div>

                <input type="hidden" name="sort" value="{{ (string) ($sort ?? 'id') }}">
                <input type="hidden" name="dir" value="{{ (string) ($dir ?? 'asc') }}">

                <button type="submit" class="rounded-md bg-gray-900 px-4 py-2 text-sm text-white">Filtern</button>
                <a href="{{ route('admin.users.index') }}" class="rounded-md border border-gray-300 px-4 py-2 text-sm">Reset</a>
            </div>
        </form>

        <div class="overflow-x-auto rounded-lg border border-gray-200 bg-white">
            <table class="min-w-full text-sm">
                <thead class="bg-gray-50 text-left">
                    <tr>
                        <th class="px-3 py-2">ID</th>
                        <th class="px-3 py-2">Username</th>
                        <th class="px-3 py-2">E-Mail</th>
                        @php
                            $nextRoleDir = (($sort ?? '') === 'role' && ($dir ?? 'asc') === 'asc') ? 'desc' : 'asc';
                            $nextProtectedDir = (($sort ?? '') === 'protected' && ($dir ?? 'asc') === 'asc') ? 'desc' : 'asc';
                        @endphp
                        <th class="px-3 py-2">
                            <a class="underline" href="{{ route('admin.users.index', array_filter(['q' => $q ?? '', 'role' => $roleFilter ?? '', 'sort' => 'role', 'dir' => $nextRoleDir, 'per_page' => $perPage ?? 50])) }}">
                                Rollen
                            </a>
                        </th>
                        <th class="px-3 py-2">
                            <a class="underline" href="{{ route('admin.users.index', array_filter(['q' => $q ?? '', 'role' => $roleFilter ?? '', 'sort' => 'protected', 'dir' => $nextProtectedDir, 'per_page' => $perPage ?? 50])) }}">
                                Protected
                            </a>
                        </th>
                        <th class="px-3 py-2">Aktion</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach($users as $user)
                        @php
                            $roleNames = $user->roles->pluck('name')->map(static fn ($r) => mb_strtolower((string) $r))->values()->all();
                            if (count($roleNames) < 1) {
                                $roleNames = ['user'];
                            }
                        @endphp
                        <tr class="border-t border-gray-100">
                            <td class="px-3 py-2">{{ (int) $user->id }}</td>
                            <td class="px-3 py-2">{{ (string) ($user->username ?? '-') }}</td>
                            <td class="px-3 py-2">{{ (string) ($user->email ?? '-') }}</td>
                            <td class="px-3 py-2">{{ implode(', ', $roleNames) }}</td>
                            <td class="px-3 py-2">{{ $user->is_protected_admin ? 'Ja' : 'Nein' }}</td>
                            <td class="px-3 py-2">
                                <a class="underline text-sky-700" href="{{ route('admin.users.show', $user) }}">Details</a>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>

        <div>
            {{ $users->links() }}
        </div>
    </div>
@endsection
