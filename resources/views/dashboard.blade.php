{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\dashboard.blade.php
Purpose: User dashboard view (shows backend button in dashboard header for staff users)
Changed: 15-02-2026 17:52 (Europe/Berlin)
Version: 0.7
============================================================================ --}}

<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between gap-2 flex-wrap">
            <h2 class="font-semibold text-xl text-gray-800 leading-tight">
                {{ __('Dashboard') }}
            </h2>

            @if(auth()->check() && in_array((string) (auth()->user()->role ?? 'user'), ['admin', 'moderator'], true))
                <a
                    href="{{ url('/admin') }}"
                    class="inline-flex items-center px-4 py-2 bg-gray-800 border border-transparent rounded-md font-semibold text-xs text-white uppercase tracking-widest hover:bg-gray-700 focus:bg-gray-700 active:bg-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition ease-in-out duration-150"
                >
                    Backend
                </a>
            @endif
        </div>
    </x-slot>

    <div class="py-12">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8">
            <div class="bg-white overflow-hidden shadow-sm sm:rounded-lg">
                <div class="p-6 text-gray-900">
                    {{ __("You're logged in!") }}
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
