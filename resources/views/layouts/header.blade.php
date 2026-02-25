{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\layouts\header.blade.php
Purpose: Global header (navigation + optional leader + optional page header)
Changed: 17-02-2026 16:28 (Europe/Berlin)
Version: 0.2
============================================================================ --}}

@include('layouts.navigation', ['showBackendButton' => (auth()->check() && in_array((string) (auth()->user()->role ?? 'user'), ['superadmin', 'admin', 'moderator'], true))])

<!-- Page Leader (optional) -->
@if(!empty($leader))
    <div class="bg-gray-100">
        <div class="max-w-7xl mx-auto py-4 px-4 sm:px-6 lg:px-8">
            {{ $leader }}
        </div>
    </div>
@endif

<!-- Page Heading -->
@if(!empty($header))
    <div class="bg-white border-b border-gray-200">
        <div class="max-w-7xl mx-auto py-3 px-4 sm:px-6 lg:px-8">
            {{ $header }}
        </div>
    </div>
@endif
