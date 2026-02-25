{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\errors\403.blade.php
Purpose: Unified 403 view; render admin 403 inside admin layout for /admin* paths
Created: 25-02-2026 12:29 (Europe/Berlin)
Version: 0.1
============================================================================ --}}

@php
    $p = '';
    try {
        $p = (string) request()->path();
    } catch (\Throwable $e) {
        $p = '';
    }

    $isAdminPath = ($p === 'admin') || str_starts_with($p, 'admin/');

    $module = '';
    try {
        $module = (string) (request()->segment(2) ?? '');
    } catch (\Throwable $e) {
        $module = '';
    }

    $adminTitle = 'Kein Zugriff';
    $adminSubtitle = $module !== '' ? ('Modul: '.$module) : null;
@endphp

@if($isAdminPath)
    @extends('admin.layouts.admin')

    @section('content')
        <div class="space-y-4">
            <div class="rounded-xl border border-red-200 bg-red-50 p-4">
                <div class="text-base font-semibold text-red-900">
                    Kein Zugriff auf dieses Modul.
                </div>

                @if(!empty($adminSubtitle))
                    <div class="mt-1 text-sm text-red-800">
                        {{ $adminSubtitle }}
                    </div>
                @endif
            </div>

            <div>
                <a href="{{ url('/admin') }}" class="inline-flex items-center rounded-lg border px-3 py-2 text-sm font-medium">
                    Zurück zur Übersicht
                </a>
            </div>
        </div>
    @endsection
@else
    {{-- Fallback für Nicht-Admin: schlicht wie Standard --}}
    <!DOCTYPE html>
    <html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>{{ __('Forbidden') }}</title>
        @vite(['resources/css/app.css'])
    </head>
    <body class="font-sans antialiased bg-gray-100 min-h-screen">
        <div class="min-h-screen flex items-center justify-center px-6">
            <div class="max-w-lg w-full bg-white border rounded-xl p-6">
                <div class="text-lg font-semibold text-gray-900">{{ __('Forbidden') }}</div>
                <div class="mt-2 text-sm text-gray-700">
                    {{ __($exception->getMessage() ?: 'Forbidden') }}
                </div>
            </div>
        </div>
    </body>
    </html>
@endif