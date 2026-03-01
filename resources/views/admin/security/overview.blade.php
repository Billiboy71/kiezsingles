@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-4">
        <div class="ks-card"><h3>Failed Logins 24h</h3><p class="text-2xl font-semibold">{{ $failedLogins24h }}</p></div>
        <div class="ks-card"><h3>Active IP Bans</h3><p class="text-2xl font-semibold">{{ $activeIpBans }}</p></div>
        <div class="ks-card"><h3>Active Identity Bans</h3><p class="text-2xl font-semibold">{{ $activeIdentityBans }}</p></div>
        <div class="ks-card"><h3>Frozen Accounts</h3><p class="text-2xl font-semibold">{{ $frozenAccounts }}</p></div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div class="ks-card">
            <h3>Top Suspicious IPs</h3>
            <table class="w-full text-sm">
                <thead><tr><th class="text-left">IP</th><th class="text-left">Count</th></tr></thead>
                <tbody>
                @forelse($topSuspiciousIps as $row)
                    <tr><td>{{ $row->ip }}</td><td>{{ $row->aggregate_count }}</td></tr>
                @empty
                    <tr><td colspan="2">Keine Daten.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>

        <div class="ks-card">
            <h3>Top Device Hash Counts</h3>
            <table class="w-full text-sm">
                <thead><tr><th class="text-left">Device Hash</th><th class="text-left">Count</th></tr></thead>
                <tbody>
                @forelse($topDeviceHashes as $row)
                    <tr><td class="break-all">{{ $row->device_hash }}</td><td>{{ $row->aggregate_count }}</td></tr>
                @empty
                    <tr><td colspan="2">Keine Daten.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>
    </div>
@endsection
