{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\layouts\footer.blade.php
Purpose: Admin footer (default footer + optional per-view adminFooter section)
Changed: 16-02-2026 17:50 (Europe/Berlin)
Version: 0.1
============================================================================ --}}

<footer class="bg-white border-t border-gray-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 text-xs text-gray-500">
        @hasSection('adminFooter')
            @yield('adminFooter')
        @else
            <div>Admin-Bereich</div>
        @endif
    </div>
</footer>
