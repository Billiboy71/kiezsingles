{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\errors\500.blade.php
Purpose: Unified 500 view
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
    <div class="rounded-xl border border-red-200 bg-red-50 p-6">
        <div class="text-lg font-semibold text-red-900">
            Interner Serverfehler.
        </div>
        <div class="mt-2 text-sm text-red-800">
            Unerwarteter Fehler im Backend.
        </div>
    </div>
</div>
@endsection
@else
<!DOCTYPE html>
<html lang="{{ app()->getLocale() }}">
<head>
    <meta charset="utf-8">
    <title>500</title>
    @vite(['resources/css/app.css'])
</head>
<body class="bg-gray-100 min-h-screen flex items-center justify-center">
    <div class="bg-white p-6 rounded-xl border max-w-md w-full">
        <div class="text-lg font-semibold">Interner Serverfehler.</div>
    </div>
</body>
</html>
@endif