{{-- ==========================================================================
File: C:\laragon\www\kiezsingles\resources\views\profile\show.blade.php
Purpose: Public user profile (read-only) for /u/{public_id}
========================================================================== --}}

<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Öffentliches Profil
        </h2>
    </x-slot>

    <div class="py-12">
        <div class="max-w-3xl mx-auto sm:px-6 lg:px-8">
            <div class="p-6 bg-white shadow sm:rounded-lg space-y-3">
                <div class="text-sm text-gray-500">
                    Public ID: <span class="font-mono">{{ $user->public_id }}</span>
                </div>

                <div class="text-2xl font-semibold text-gray-900">
                    {{ $user->username }}
                </div>

                <div class="text-gray-700">
                    {{ $user->district }}
                    @if($user->postcode)
                        · {{ $user->postcode }}
                    @endif
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
