{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\profile\edit.blade.php
Purpose: User profile edit view + conditional admin access
Changed: 12-02-2026 22:40 (Europe/Berlin)
Version: 0.1
============================================================================ --}}

<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            {{ __('Profile') }}
        </h2>
    </x-slot>

    <div class="py-12">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8 space-y-6">

            @if(auth()->check() && (string) auth()->user()->role === 'admin')
                <div class="p-4 sm:p-8 bg-white shadow sm:rounded-lg border border-red-200">
                    <div class="max-w-xl">
                        <h3 class="font-semibold text-lg text-red-700 mb-2">
                            Admin
                        </h3>

                        <p class="text-sm text-gray-600 mb-4">
                            Zugriff auf das Administrations-Backend.
                        </p>

                        <a
                            href="{{ url('/admin') }}"
                            class="inline-flex items-center px-4 py-2 bg-red-600 border border-transparent rounded-md font-semibold text-xs text-white uppercase tracking-widest hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2"
                        >
                            Admin-Backend öffnen
                        </a>
                    </div>
                </div>
            @endif

            <div class="p-4 sm:p-8 bg-white shadow sm:rounded-lg">
                <div class="max-w-xl">
                    @include('profile.partials.update-profile-information-form')
                </div>
            </div>

            <div class="p-4 sm:p-8 bg-white shadow sm:rounded-lg">
                <div class="max-w-xl">
                    @include('profile.partials.update-password-form')
                </div>
            </div>

            <div class="p-4 sm:p-8 bg-white shadow sm:rounded-lg">
                <div class="max-w-xl">
                    @include('profile.partials.delete-user-form')
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
