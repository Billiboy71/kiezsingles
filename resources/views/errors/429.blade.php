{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\errors\429.blade.php
Purpose: Unified 429 view (rate limit)
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
    <div class="rounded-xl border border-orange-200 bg-orange-50 p-6">
        <div class="text-lg font-semibold text-orange-900">
            Zu viele Anfragen.
        </div>
        <div class="mt-2 text-sm text-orange-800">
            Bitte kurz warten und erneut versuchen.
        </div>
    </div>
</div>
@endsection
@else
<!DOCTYPE html>
<html lang="{{ app()->getLocale() }}">
<head>
    <meta charset="utf-8">
    <title>429</title>
    @vite(['resources/css/app.css'])
</head>
<body class="bg-gray-100 min-h-screen flex items-center justify-center">
    <div class="bg-white p-6 rounded-xl border max-w-md w-full">
        <div class="text-lg font-semibold">Zu viele Anfragen.</div>
    </div>
</body>
</html>
@endif