@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    @if(session('admin_notice'))
        <div class="ks-notice p-3 rounded-lg border mb-3">{{ session('admin_notice') }}</div>
    @endif

    <form method="POST" action="{{ route('admin.security.settings.update') }}" class="ks-card grid grid-cols-1 md:grid-cols-2 gap-3">
        @csrf
        @method('PUT')

        <div><label>Login Attempt Limit</label><input class="w-full" type="number" min="1" name="login_attempt_limit" value="{{ old('login_attempt_limit', $settings->login_attempt_limit) }}" required></div>
        <div><label>Lockout Seconds</label><input class="w-full" type="number" min="10" name="lockout_seconds" value="{{ old('lockout_seconds', $settings->lockout_seconds) }}" required></div>

        <div><label>IP Autoban Fail Threshold</label><input class="w-full" type="number" min="1" name="ip_autoban_fail_threshold" value="{{ old('ip_autoban_fail_threshold', $settings->ip_autoban_fail_threshold) }}" required></div>
        <div><label>IP Autoban Seconds</label><input class="w-full" type="number" min="60" name="ip_autoban_seconds" value="{{ old('ip_autoban_seconds', $settings->ip_autoban_seconds) }}" required></div>

        <label><input type="checkbox" name="ip_autoban_enabled" value="1" {{ old('ip_autoban_enabled', $settings->ip_autoban_enabled) ? 'checked' : '' }}> IP Autoban Enabled</label>
        <label><input type="checkbox" name="admin_stricter_limits_enabled" value="1" {{ old('admin_stricter_limits_enabled', $settings->admin_stricter_limits_enabled) ? 'checked' : '' }}> Admin Stricter Limits Enabled</label>
        <label><input type="checkbox" name="stepup_required_enabled" value="1" {{ old('stepup_required_enabled', $settings->stepup_required_enabled) ? 'checked' : '' }}> StepUp Required Enabled</label>

        <div><button class="ks-btn" type="submit">Settings speichern</button></div>
    </form>
@endsection
