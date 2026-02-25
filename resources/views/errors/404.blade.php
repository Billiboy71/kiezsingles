{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\errors\404.blade.php
Purpose: Unified 404 view (admin-aware)
Created: 25-02-2026 12:32 (Europe/Berlin)
Changed: 25-02-2026 12:33 (Europe/Berlin)
Version: 0.2
============================================================================ --}}

@php
    $path = request()->path();
    $isAdmin = $path === 'admin' || str_starts_with($path, 'admin/');
@endphp

@if($isAdmin)
@extends('admin.layouts.admin')

@section('content')
<div class="space-y-4">
    <div class="rounded-xl border border-gray-200 bg-white p-6">
        <div class="text-lg font-semibold text-gray-900">
            Seite nicht gefunden.
        </div>
        <div class="mt-2 text-sm text-gray-600">
            Das angeforderte Modul oder die Route existiert nicht.
        </div>
    </div>

    <div>
        <a href="{{ url('/admin') }}" class="inline-flex items-center rounded-lg border px-3 py-2 text-sm font-medium">
            Zurück zur Übersicht
        </a>
    </div>
</div>
@endsection
@else
<x-app-layout>
    <div class="space-y-4">
        <div class="text-lg font-semibold text-gray-900">
            Seite nicht gefunden.
        </div>

        <div class="text-sm text-gray-600">
            Die angeforderte Seite existiert nicht.
        </div>
    </div>
</x-app-layout>
@endif