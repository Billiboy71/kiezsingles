@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    <form method="GET" action="{{ route('admin.security.events.index') }}" class="ks-card mb-4 grid grid-cols-1 md:grid-cols-3 gap-3">
        <div><label>Type</label><input class="w-full" type="text" name="type" value="{{ $filters['type'] }}"></div>
        <div><label>IP</label><input class="w-full" type="text" name="ip" value="{{ $filters['ip'] }}"></div>
        <div><label>Email</label><input class="w-full" type="text" name="email" value="{{ $filters['email'] }}"></div>
        <div><label>Device Hash</label><input class="w-full" type="text" name="device_hash" value="{{ $filters['device_hash'] }}"></div>
        <div><label>From</label><input class="w-full" type="date" name="date_from" value="{{ $filters['date_from'] }}"></div>
        <div><label>To</label><input class="w-full" type="date" name="date_to" value="{{ $filters['date_to'] }}"></div>
        <div><button class="ks-btn" type="submit">Filtern</button></div>
    </form>

    <div class="ks-card">
        <table class="w-full text-sm">
            <thead>
                <tr>
                    <th class="text-left">Zeit</th>
                    <th class="text-left">Type</th>
                    <th class="text-left">IP</th>
                    <th class="text-left">Email</th>
                    <th class="text-left">Device</th>
                    <th class="text-left">Meta</th>
                </tr>
            </thead>
            <tbody>
                @forelse($events as $event)
                    <tr>
                        <td>{{ $event->created_at }}</td>
                        <td>{{ $event->type }}</td>
                        <td>{{ $event->ip }}</td>
                        <td>{{ $event->email }}</td>
                        <td class="break-all">{{ $event->device_hash }}</td>
                        <td class="break-all">{{ is_array($event->meta) ? json_encode($event->meta, JSON_UNESCAPED_UNICODE) : '' }}</td>
                    </tr>
                @empty
                    <tr><td colspan="6">Keine Events gefunden.</td></tr>
                @endforelse
            </tbody>
        </table>

        <div class="mt-3">{{ $events->links() }}</div>
    </div>
@endsection
