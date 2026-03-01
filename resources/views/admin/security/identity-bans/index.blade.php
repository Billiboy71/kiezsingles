@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    @if(session('admin_notice'))
        <div class="ks-notice p-3 rounded-lg border mb-3">{{ session('admin_notice') }}</div>
    @endif

    <form method="POST" action="{{ route('admin.security.identity_bans.store') }}" class="ks-card mb-4 grid grid-cols-1 md:grid-cols-3 gap-3">
        @csrf
        <div><label>Email</label><input class="w-full" type="email" name="email" required></div>
        <div><label>TTL Sekunden (optional)</label><input class="w-full" type="number" min="1" name="ttl_seconds"></div>
        <div><label>Reason</label><input class="w-full" type="text" name="reason"></div>
        <div><button class="ks-btn" type="submit">Identity Ban speichern</button></div>
    </form>

    <div class="ks-card">
        <table class="w-full text-sm">
            <thead><tr><th class="text-left">Email</th><th class="text-left">Reason</th><th class="text-left">Until</th><th class="text-left">Action</th></tr></thead>
            <tbody>
            @forelse($identityBans as $ban)
                <tr>
                    <td>{{ $ban->email }}</td>
                    <td>{{ $ban->reason }}</td>
                    <td>{{ $ban->banned_until }}</td>
                    <td>
                        <form method="POST" action="{{ route('admin.security.identity_bans.destroy', $ban->id) }}">
                            @csrf
                            @method('DELETE')
                            <button class="ks-btn" type="submit">Entfernen</button>
                        </form>
                    </td>
                </tr>
            @empty
                <tr><td colspan="4">Keine Identity-Bans vorhanden.</td></tr>
            @endforelse
            </tbody>
        </table>

        <div class="mt-3">{{ $identityBans->links() }}</div>
    </div>
@endsection
