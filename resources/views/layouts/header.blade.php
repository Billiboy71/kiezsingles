{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\layouts\header.blade.php
Purpose: Global header (navigation + optional leader + optional page header)
Changed: 25-02-2026 21:31 (Europe/Berlin)
Version: 0.4
============================================================================ --}}

@php
    $showFrontendOutlines = $showFrontendOutlines ?? false;
@endphp

<div class="{{ $showFrontendOutlines ? 'relative border-2 border-dashed border-cyan-400 max-w-7xl mx-auto' : '' }}">
    @if($showFrontendOutlines)
        <div class="absolute -top-3 left-2 bg-cyan-500 text-white text-[10px] leading-none px-2 py-1 rounded">FRONTEND-TOP-HEADER</div>
    @endif

    @include('layouts.navigation', [
        'showBackendButton' => (auth()->check() && in_array((string) (auth()->user()->role ?? 'user'), ['superadmin', 'admin', 'moderator'], true)),
        'showFrontendOutlines' => false,
    ])
</div>

<!-- Page Leader (optional) -->
<div class="{{ $showFrontendOutlines ? 'relative border-2 border-dashed border-amber-400 max-w-7xl mx-auto' : '' }}">
    @if($showFrontendOutlines)
        <div class="absolute -top-3 left-2 bg-amber-500 text-white text-[10px] leading-none px-2 py-1 rounded">FRONTEND-NAV</div>
    @endif

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
</div>
