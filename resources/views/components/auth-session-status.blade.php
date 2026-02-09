{{-- ========================================================================= --}}
{{-- File: C:\laragon\www\kiezsingles\resources\views\components\auth-session-status.blade.php --}}
{{-- Purpose: Render session status message (translated via __()) --}}
{{-- Changed: 07-02-2026 02:27 --}}
{{-- ========================================================================= --}}

@props(['status'])

@if ($status)
    <div {{ $attributes->merge(['class' => 'font-medium text-sm text-green-600']) }}>
        {{ __($status) }} {{-- Abgeleitet: 07-02-2026 02:27 --}}
    </div>
@endif
