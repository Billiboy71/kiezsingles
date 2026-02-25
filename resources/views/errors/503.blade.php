{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\errors\503.blade.php
Purpose: Unified 503 view (maintenance / fail-closed)
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
    <div class="rounded-xl border border-gray-200 bg-white p-6">
        <div class="text-lg font-semibold text-gray-900">
            Service nicht verfügbar.
        </div>
        <div class="mt-2 text-sm text-gray-600">
            Wartungsmodus oder temporäres Backend-Problem.
        </div>
    </div>
</div>
@endsection
@else
<!DOCTYPE html>
<html lang="{{ app()->getLocale() }}">
<head>
    <meta charset="utf-8">
    <title>503</title>
    @vite(['resources/css/app.css'])
</head>
<body class="bg-gray-100 min-h-screen flex items-center justify-center">
    <div class="bg-white p-6 rounded-xl border max-w-md w-full">
        <div class="text-lg font-semibold">Service nicht verfügbar.</div>
    </div>
</body>
</html>
@endif