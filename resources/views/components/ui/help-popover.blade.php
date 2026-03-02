{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\components\ui\help-popover.blade.php
Purpose: Reusable admin help popover trigger/content component
Changed: 02-03-2026 01:43 (Europe/Berlin)
Version: 0.1
============================================================================ --}}

@props([
    'id',
    'title' => null,
])

<div class="ks-help-wrap">
    <button
        type="button"
        class="ks-help-btn"
        data-ks-help-open="{{ $id }}"
        aria-controls="{{ $id }}"
        aria-expanded="false"
        aria-haspopup="dialog"
        aria-label="Hilfe anzeigen"
    >i</button>

    <div
        id="{{ $id }}"
        class="ks-help-popover"
        data-ks-help="{{ $id }}"
        role="dialog"
        aria-modal="false"
        aria-hidden="true"
        hidden
    >
        @if(!empty($title))
            <div class="ks-help-popover__title">{{ $title }}</div>
        @endif
        <div class="ks-help-popover__body">
            {{ $slot }}
        </div>
    </div>
</div>
