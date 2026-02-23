{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\layouts\footer.blade.php
Purpose: Global footer (always visible; renders optional footer slot; placeholder otherwise)
Changed: 16-02-2026 18:14 (Europe/Berlin)
Version: 0.1
============================================================================ --}}

<footer class="bg-white border-t border-gray-200">
    <div class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8 text-sm text-gray-600">
        @if(!empty($footer))
            {{ $footer }}
        @else
            <div>Footer (Platzhalter)</div>
        @endif
    </div>
</footer>
