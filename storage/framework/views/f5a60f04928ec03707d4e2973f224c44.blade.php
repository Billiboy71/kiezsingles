@extends('admin.layouts.admin')

@section('content')
    <div class="space-y-4">
        <div class="rounded-xl border border-red-200 bg-red-50 p-4">
            <div class="text-base font-semibold text-red-900">
                Kein Zugriff auf dieses Modul.
            </div>
            @if(!empty($subtitle))
                <div class="mt-1 text-sm text-red-800">
                    {{ $subtitle }}
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