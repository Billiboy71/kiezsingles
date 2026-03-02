<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Admin\AdminSecurityController.php
// Purpose: Admin Security controller (overview, events, bans, settings, event purge)
// Changed: 02-03-2026 14:57 (Europe/Berlin)
// Version: 0.4
// ============================================================================

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\SecurityDeviceBan;
use App\Models\SecurityEvent;
use App\Models\SecurityIdentityBan;
use App\Models\SecurityIpBan;
use App\Models\User;
use App\Services\Security\SecuritySettingsService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminSecurityController extends Controller
{
    public function __construct(
        private readonly SecuritySettingsService $securitySettingsService,
    ) {}

    public function overview(Request $request): View
    {
        $failedLogins24h = SecurityEvent::query()
            ->where('type', 'login_failed')
            ->where('created_at', '>=', now()->subDay())
            ->count();

        $activeIpBans = SecurityIpBan::query()->active()->count();

        $activeIdentityBans = SecurityIdentityBan::query()->active()->count();
        $activeDeviceBans = SecurityDeviceBan::query()->active()->count();

        $frozenAccounts = User::query()->where('is_frozen', true)->count();

        $topSuspiciousIps = SecurityEvent::query()
            ->selectRaw('ip, COUNT(*) as aggregate_count')
            ->whereNotNull('ip')
            ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked'])
            ->where('created_at', '>=', now()->subDay())
            ->groupBy('ip')
            ->orderByDesc('aggregate_count')
            ->limit(10)
            ->get();

        $topDeviceHashes = SecurityEvent::query()
            ->selectRaw('device_hash, COUNT(*) as aggregate_count')
            ->whereNotNull('device_hash')
            ->where('created_at', '>=', now()->subDay())
            ->groupBy('device_hash')
            ->orderByDesc('aggregate_count')
            ->limit(10)
            ->get();

        return view('admin.security.overview', [
            'adminTab' => 'security',
            'failedLogins24h' => $failedLogins24h,
            'activeIpBans' => $activeIpBans,
            'activeIdentityBans' => $activeIdentityBans,
            'activeDeviceBans' => $activeDeviceBans,
            'frozenAccounts' => $frozenAccounts,
            'topSuspiciousIps' => $topSuspiciousIps,
            'topDeviceHashes' => $topDeviceHashes,
        ]);
    }

    public function events(Request $request): View
    {
        $perPage = (int) $request->query('per_page', 20);
        if (!in_array($perPage, [20, 50, 100], true)) {
            $perPage = 20;
        }

        $query = SecurityEvent::query()->latest('id');

        $type = trim((string) $request->query('type', ''));
        $ip = trim((string) $request->query('ip', ''));
        $email = mb_strtolower(trim((string) $request->query('email', '')));
        $deviceHash = trim((string) $request->query('device_hash', ''));
        $dateFrom = trim((string) $request->query('date_from', ''));
        $dateTo = trim((string) $request->query('date_to', ''));

        if ($type !== '') {
            $query->where('type', $type);
        }

        if ($ip !== '') {
            $query->where('ip', $ip);
        }

        if ($email !== '') {
            $query->where('email', $email);
        }

        if ($deviceHash !== '') {
            $query->where('device_hash', $deviceHash);
        }

        if ($dateFrom !== '') {
            $query->whereDate('created_at', '>=', $dateFrom);
        }

        if ($dateTo !== '') {
            $query->whereDate('created_at', '<=', $dateTo);
        }

        $events = $query->paginate($perPage)->appends($request->query())->onEachSide(2);

        return view('admin.security.events.index', [
            'adminTab' => 'security',
            'events' => $events,
            'perPage' => $perPage,
            'filters' => [
                'type' => $type,
                'ip' => $ip,
                'email' => $email,
                'device_hash' => $deviceHash,
                'date_from' => $dateFrom,
                'date_to' => $dateTo,
            ],
        ]);
    }

    public function purgeEvents(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'confirm' => ['required', 'string'],
            'type' => ['nullable', 'string', 'max:100'],
            'ip' => ['nullable', 'string', 'max:100'],
            'email' => ['nullable', 'string', 'max:255'],
            'device_hash' => ['nullable', 'string', 'max:128'],
            'date_from' => ['nullable', 'date'],
            'date_to' => ['nullable', 'date'],
        ]);

        if (trim((string) $validated['confirm']) !== 'DELETE') {
            return redirect()->route('admin.security.events.index')->with('admin_notice', 'Löschen abgebrochen (Confirm muss "DELETE" sein).');
        }

        $query = SecurityEvent::query();

        $type = trim((string) ($validated['type'] ?? ''));
        $ip = trim((string) ($validated['ip'] ?? ''));
        $email = mb_strtolower(trim((string) ($validated['email'] ?? '')));
        $deviceHash = trim((string) ($validated['device_hash'] ?? ''));
        $dateFrom = trim((string) ($validated['date_from'] ?? ''));
        $dateTo = trim((string) ($validated['date_to'] ?? ''));

        if ($type !== '') {
            $query->where('type', $type);
        }

        if ($ip !== '') {
            $query->where('ip', $ip);
        }

        if ($email !== '') {
            $query->where('email', $email);
        }

        if ($deviceHash !== '') {
            $query->where('device_hash', $deviceHash);
        }

        if ($dateFrom !== '') {
            $query->whereDate('created_at', '>=', $dateFrom);
        }

        if ($dateTo !== '') {
            $query->whereDate('created_at', '<=', $dateTo);
        }

        $deleted = (int) $query->delete();

        return redirect()->route('admin.security.events.index')->with('admin_notice', 'Security-Events gelöscht: '.$deleted);
    }

    public function ipBans(): View
    {
        $perPage = (int) request()->query('per_page', 20);
        if (!in_array($perPage, [20, 50, 100], true)) {
            $perPage = 20;
        }

        $ipBans = SecurityIpBan::query()
            ->latest('id')
            ->paginate($perPage)
            ->appends(request()->query())
            ->onEachSide(2);

        return view('admin.security.ip-bans.index', [
            'adminTab' => 'security',
            'ipBans' => $ipBans,
            'perPage' => $perPage,
        ]);
    }

    public function storeIpBan(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'ip' => ['required', 'ip'],
            'reason' => ['nullable', 'string', 'max:1000'],
            'ttl_seconds' => ['nullable', 'integer', 'min:1', 'max:31536000'],
        ]);

        $ttlSeconds = isset($validated['ttl_seconds']) ? (int) $validated['ttl_seconds'] : null;

        SecurityIpBan::query()->create([
            'ip' => (string) $validated['ip'],
            'reason' => $validated['reason'] ?? null,
            'banned_until' => $ttlSeconds !== null ? now()->addSeconds($ttlSeconds) : null,
            'created_by' => auth()->id(),
        ]);

        return redirect()->route('admin.security.ip_bans.index')->with('admin_notice', 'IP-Ban gespeichert.');
    }

    public function destroyIpBan(int $id): RedirectResponse
    {
        SecurityIpBan::query()->whereKey($id)->delete();

        return redirect()->route('admin.security.ip_bans.index')->with('admin_notice', 'IP-Ban entfernt.');
    }

    public function identityBans(): View
    {
        $perPage = (int) request()->query('per_page', 20);
        if (!in_array($perPage, [20, 50, 100], true)) {
            $perPage = 20;
        }

        $identityBans = SecurityIdentityBan::query()
            ->latest('id')
            ->paginate($perPage)
            ->appends(request()->query())
            ->onEachSide(2);

        return view('admin.security.identity-bans.index', [
            'adminTab' => 'security',
            'identityBans' => $identityBans,
            'perPage' => $perPage,
        ]);
    }

    public function storeIdentityBan(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email', 'max:255'],
            'reason' => ['nullable', 'string', 'max:1000'],
            'ttl_seconds' => ['nullable', 'integer', 'min:1', 'max:31536000'],
        ]);

        $ttlSeconds = isset($validated['ttl_seconds']) ? (int) $validated['ttl_seconds'] : null;

        SecurityIdentityBan::query()->create([
            'email' => mb_strtolower(trim((string) $validated['email'])),
            'reason' => $validated['reason'] ?? null,
            'banned_until' => $ttlSeconds !== null ? now()->addSeconds($ttlSeconds) : null,
            'created_by' => auth()->id(),
        ]);

        return redirect()->route('admin.security.identity_bans.index')->with('admin_notice', 'Identity-Ban gespeichert.');
    }

    public function destroyIdentityBan(int $id): RedirectResponse
    {
        SecurityIdentityBan::query()->whereKey($id)->delete();

        return redirect()->route('admin.security.identity_bans.index')->with('admin_notice', 'Identity-Ban entfernt.');
    }

    public function deviceBans(): View
    {
        $perPage = (int) request()->query('per_page', 20);
        if (!in_array($perPage, [20, 50, 100], true)) {
            $perPage = 20;
        }

        $deviceBans = SecurityDeviceBan::query()
            ->latest('id')
            ->paginate($perPage)
            ->appends(request()->query())
            ->onEachSide(2);

        return view('admin.security.device-bans.index', [
            'adminTab' => 'security',
            'deviceBans' => $deviceBans,
            'perPage' => $perPage,
        ]);
    }

    public function storeDeviceBan(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'device_hash' => ['required', 'string', 'size:64'],
            'reason' => ['nullable', 'string', 'max:1000'],
            'ttl_seconds' => ['nullable', 'integer', 'min:1', 'max:31536000'],
        ]);

        $ttlSeconds = isset($validated['ttl_seconds']) ? (int) $validated['ttl_seconds'] : null;

        SecurityDeviceBan::query()->create([
            'device_hash' => trim((string) $validated['device_hash']),
            'reason' => $validated['reason'] ?? null,
            'banned_until' => $ttlSeconds !== null ? now()->addSeconds($ttlSeconds) : null,
            'is_active' => true,
            'created_by' => auth()->id(),
        ]);

        return redirect()->route('admin.security.device_bans.index')->with('admin_notice', 'Geräte-Sperre gespeichert.');
    }

    public function destroyDeviceBan(int $id): RedirectResponse
    {
        $ban = SecurityDeviceBan::query()->whereKey($id)->first();

        if ($ban) {
            $ban->fill([
                'is_active' => false,
                'revoked_at' => now(),
            ])->save();
        }

        return redirect()->route('admin.security.device_bans.index')->with('admin_notice', 'Geräte-Sperre entfernt.');
    }

    public function editSettings(): View
    {
        return view('admin.security.settings.edit', [
            'adminTab' => 'security',
            'settings' => $this->securitySettingsService->get(),
        ]);
    }

    public function updateSettings(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'login_attempt_limit' => ['required', 'integer', 'min:1', 'max:100'],
            'lockout_seconds' => ['required', 'integer', 'min:10', 'max:86400'],
            'ip_autoban_enabled' => ['sometimes', 'boolean'],
            'ip_autoban_fail_threshold' => ['required', 'integer', 'min:1', 'max:100000'],
            'ip_autoban_seconds' => ['required', 'integer', 'min:60', 'max:31536000'],
            'device_autoban_enabled' => ['sometimes', 'boolean'],
            'device_autoban_fail_threshold' => ['required', 'integer', 'min:1', 'max:100000'],
            'device_autoban_seconds' => ['required', 'integer', 'min:60', 'max:31536000'],
            'admin_stricter_limits_enabled' => ['sometimes', 'boolean'],
            'stepup_required_enabled' => ['sometimes', 'boolean'],
        ]);

        $settings = $this->securitySettingsService->get();

        $settings->fill([
            'login_attempt_limit' => (int) $validated['login_attempt_limit'],
            'lockout_seconds' => (int) $validated['lockout_seconds'],
            'ip_autoban_enabled' => $request->boolean('ip_autoban_enabled'),
            'ip_autoban_fail_threshold' => (int) $validated['ip_autoban_fail_threshold'],
            'ip_autoban_seconds' => (int) $validated['ip_autoban_seconds'],
            'device_autoban_enabled' => $request->boolean('device_autoban_enabled'),
            'device_autoban_fail_threshold' => (int) $validated['device_autoban_fail_threshold'],
            'device_autoban_seconds' => (int) $validated['device_autoban_seconds'],
            'admin_stricter_limits_enabled' => $request->boolean('admin_stricter_limits_enabled'),
            'stepup_required_enabled' => $request->boolean('stepup_required_enabled'),
        ]);

        $settings->save();

        return redirect()->route('admin.security.settings.edit')->with('admin_notice', 'Security-Settings gespeichert.');
    }
}
