{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\errors\419.blade.php
Purpose: Unified 419 view (session expired)
Created: 25-02-2026 12:32 (Europe/Berlin)
Version: 0.1
============================================================================ --}}

@php
    $path = request()->path();
    $isAdmin = $path === 'admin' || str_starts_with($path, 'admin/');
@endphp

@if($isAdmin)
@extends('admin.layouts.admin')

@section('content')
<div class="space-y-4">
    <div class="rounded-xl border border-yellow-200 bg-yellow-50 p-6">
        <div class="text-lg font-semibold text-yellow-900">
            Sitzung abgelaufen.
        </div>
        <div class="mt-2 text-sm text-yellow-800">
            Bitte Seite neu laden oder erneut anmelden.
        </div>
    </div>

    <div>
        <a href="{{ url()->current() }}" class="inline-flex items-center rounded-lg border px-3 py-2 text-sm font-medium">
            Neu laden
        </a>
    </div>
</div>
@endsection
@else
<!DOCTYPE html>
<html lang="{{ app()->getLocale() }}">
<head>
    <meta charset="utf-8">
    <title>419</title>
    @vite(['resources/css/app.css'])
</head>
<body class="bg-gray-100 min-h-screen flex items-center justify-center">
    <div class="bg-white p-6 rounded-xl border max-w-md w-full">
        <div class="text-lg font-semibold">Sitzung abgelaufen.</div>
    </div>
</body>
</html>
@endif