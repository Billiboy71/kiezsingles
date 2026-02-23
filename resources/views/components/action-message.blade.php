{{-- ========================================================================= --}}
{{-- File: C:\laragon\www\kiezsingles\resources\views\components\action-message.blade.php --}}
{{-- Changed: 23-02-2026 23:29 (Europe/Berlin)                                 --}}
{{-- Version: 0.1                                                              --}}
{{-- Purpose: Action message component (Alpine show/hide)                      --}}
{{-- ========================================================================= --}}

@props(['on'])

<div x-data="{ shown: false, timeout: null }"
     x-init="@this.on('{{ $on }}', () => { clearTimeout(timeout); shown = true; timeout = setTimeout(() => { shown = false }, 2000); })"
     x-show="shown"
     x-cloak
     x-transition:leave.opacity.duration.1500ms
    {{ $attributes->merge(['class' => 'text-sm text-gray-600']) }}>
    {{ $slot->isEmpty() ? __('Saved.') : $slot }}
</div>