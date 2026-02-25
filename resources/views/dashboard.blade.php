{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\dashboard.blade.php
Purpose: User dashboard view (shows backend button in dashboard header for staff users)
Changed: 25-02-2026 19:10 (Europe/Berlin)
Version: 0.8
============================================================================ --}}

<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between gap-2 flex-wrap">
            <h2 class="font-semibold text-xl text-gray-800 leading-tight">
                {{ __('Dashboard') }}
            </h2>
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