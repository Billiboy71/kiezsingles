<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Admin\AdminSecurityController.php
// Purpose: Admin Security controller (overview, events, bans, settings, event purge)
// Changed: 27-03-2026 00:51 (Europe/Berlin)
// Version: 2.5
// ============================================================================

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\SecurityAllowlistEntry;
use App\Models\SecurityDeviceBan;
use App\Models\SecurityEvent;
use App\Models\SecurityIdentityBan;
use App\Models\SecurityIpBan;
use App\Models\User;
use App\Services\Security\SecurityAllowlistService;
use App\Services\Security\SecuritySettingsService;
use App\Support\SystemSettingHelper;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\View\View;

class AdminSecurityController extends Controller
{
    public function __construct(
        private readonly SecuritySettingsService $securitySettingsService,
        private readonly SecurityAllowlistService $securityAllowlistService,
    ) {}

    public function overview(Request $request): View
    {
        $failedLogins24h = SecurityEvent::query()
            ->where('type', 'login_failed')
            ->where('created_at', '>=', now()->subHours(24))
            ->count();

        $activeIpBans = SecurityIpBan::query()
            ->active()
            ->where('created_at', '>=', now()->subHours(24))
            ->where('reason', 'like', 'Incident%')
            ->count();

        $activeIdentityBans = SecurityIdentityBan::query()
            ->active()
            ->where('created_at', '>=', now()->subHours(24))
            ->where('reason', 'like', 'Incident%')
            ->count();
        $activeDeviceBans = SecurityDeviceBan::query()
            ->active()
            ->where('created_at', '>=', now()->subHours(24))
            ->where('reason', 'like', 'Incident%')
            ->count();

        $frozenAccounts = User::query()->where('is_frozen', true)->count();

        $topSuspiciousIps = SecurityEvent::query()
            ->selectRaw('ip, COUNT(*) as aggregate_count')
            ->whereNotNull('ip')
            ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked', 'device_blocked'])
            ->where('created_at', '>=', now()->subDay())
            ->groupBy('ip')
            ->orderByDesc('aggregate_count')
            ->limit(10)
            ->get();

        $topDeviceHashes = SecurityEvent::query()
            ->selectRaw('device_hash, COUNT(*) as aggregate_count')
            ->whereNotNull('device_hash')
            ->where('device_hash', '!=', '')
            ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked', 'device_blocked'])
            ->where('created_at', '>=', now()->subDay())
            ->groupBy('device_hash')
            ->orderByDesc('aggregate_count')
            ->limit(10)
            ->get();

        $topSuspiciousEmails = SecurityEvent::query()
            ->selectRaw('email, COUNT(*) as aggregate_count')
            ->whereNotNull('email')
            ->where('email', '!=', '')
            ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked', 'device_blocked'])
            ->where('created_at', '>=', now()->subDay())
            ->groupBy('email')
            ->orderByDesc('aggregate_count')
            ->limit(10)
            ->get();

        $topCorrelatedDevices = SecurityEvent::query()
            ->selectRaw('device_hash, COUNT(*) as aggregate_count, COUNT(DISTINCT email) as email_count, COUNT(DISTINCT ip) as ip_count, MAX(created_at) as last_seen_at')
            ->whereNotNull('device_hash')
            ->where('device_hash', '!=', '')
            ->whereIn('type', ['login_failed', 'login_lockout'])
            ->where('created_at', '>=', now()->subHours(24))
            ->groupBy('device_hash')
            ->havingRaw('COUNT(*) >= 5 AND (COUNT(DISTINCT email) >= 2 OR COUNT(DISTINCT ip) >= 2)')
            ->orderByDesc('email_count')
            ->orderByDesc('ip_count')
            ->orderByDesc('aggregate_count')
            ->orderByDesc('last_seen_at')
            ->limit(5)
            ->get();

        $topCorrelatedEmails = SecurityEvent::query()
            ->selectRaw('email, COUNT(*) as aggregate_count, COUNT(DISTINCT device_hash) as device_count, COUNT(DISTINCT ip) as ip_count, MAX(created_at) as last_seen_at')
            ->whereNotNull('email')
            ->where('email', '!=', '')
            ->whereIn('type', ['login_failed', 'login_lockout'])
            ->where('created_at', '>=', now()->subHours(24))
            ->groupBy('email')
            ->havingRaw('COUNT(*) >= 5 AND (COUNT(DISTINCT device_hash) >= 2 OR COUNT(DISTINCT ip) >= 2)')
            ->orderByDesc('device_count')
            ->orderByDesc('ip_count')
            ->orderByDesc('aggregate_count')
            ->orderByDesc('last_seen_at')
            ->limit(5)
            ->get();

        $incidentStats = (object) [
            'total' => 0,
            'open' => 0,
            'in_progress' => 0,
            'resolved' => 0,
        ];

        $highIncidents = 0;
        $latestIncidents = collect();

        if (Schema::hasTable('security_incidents')) {
            $incidentStats = DB::table('security_incidents')
                ->selectRaw("
                    COUNT(*) as total,
                    SUM(CASE WHEN action_status IS NULL THEN 1 ELSE 0 END) as open,
                    SUM(CASE WHEN action_status = 'escalated' THEN 1 ELSE 0 END) as in_progress,
                    SUM(CASE WHEN action_status = 'reviewed' THEN 1 ELSE 0 END) as resolved
                ")
                ->first();

            $highIncidents = DB::table('security_incidents')
                ->whereNull('action_status')
                ->where('event_count', '>=', 100)
                ->count();

            $latestIncidents = DB::table('security_incidents')
                ->select('id', 'type', 'event_count')
                ->whereNull('action_status')
                ->orderByDesc('event_count')
                ->limit(5)
                ->get();
        }

        return view('admin.security.overview', [
            'adminTab' => 'security',
            'failedLogins24h' => $failedLogins24h,
            'activeIpBans' => $activeIpBans,
            'activeIdentityBans' => $activeIdentityBans,
            'activeDeviceBans' => $activeDeviceBans,
            'frozenAccounts' => $frozenAccounts,
            'topSuspiciousIps' => $topSuspiciousIps,
            'topDeviceHashes' => $topDeviceHashes,
            'topSuspiciousEmails' => $topSuspiciousEmails,
            'topCorrelatedDevices' => $topCorrelatedDevices,
            'topCorrelatedEmails' => $topCorrelatedEmails,
            'incidentStats' => $incidentStats,
            'highIncidents' => $highIncidents,
            'latestIncidents' => $latestIncidents,
        ]);
    }

    public function events(Request $request): View|JsonResponse
    {
        $filters = $this->normalizedSecurityEventFilters($request->query());

        $hasFocusedCorrelationFilter =
            $filters['ip'] !== ''
            || $filters['email'] !== ''
            || $filters['device_hash'] !== '';

        $perPage = (int) $request->query('per_page', $hasFocusedCorrelationFilter ? 100 : 20);
        if (!in_array($perPage, [20, 50, 100], true)) {
            $perPage = $hasFocusedCorrelationFilter ? 100 : 20;
        }

        $ip = $filters['ip'];
        $email = $filters['email'];
        $deviceHash = $filters['device_hash'];

        $detailLimit = $hasFocusedCorrelationFilter ? 100 : 20;

        $query = SecurityEvent::query()->latest('id');
        $this->applySecurityEventFilters($query, $request);

        $events = $query->paginate($perPage)->appends($request->query())->onEachSide(2);

        $deviceCorrelation = [
            'selected_device_hash' => $deviceHash,
            'selected_email' => $email,
            'selected_ip' => $ip,
            'emails_for_device' => collect(),
            'ips_for_device' => collect(),
            'devices_for_email' => collect(),
            'devices_for_ip' => collect(),
        ];

        if ($deviceHash !== '') {
            $deviceCorrelation['emails_for_device'] = $this->applySecurityEventFilters(
                SecurityEvent::query()
                    ->selectRaw('email, COUNT(*) as aggregate_count, MAX(created_at) as last_seen_at')
                    ->where('device_hash', $deviceHash)
                    ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked', 'device_blocked'])
                    ->whereNotNull('email')
                    ->where('email', '!=', ''),
                $request,
                ['email']
            )
                ->groupBy('email')
                ->orderByDesc('aggregate_count')
                ->orderByDesc('last_seen_at')
                ->limit($detailLimit)
                ->get();

            $deviceCorrelation['ips_for_device'] = $this->applySecurityEventFilters(
                SecurityEvent::query()
                    ->selectRaw('ip, COUNT(*) as aggregate_count, MAX(created_at) as last_seen_at')
                    ->where('device_hash', $deviceHash)
                    ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked', 'device_blocked'])
                    ->whereNotNull('ip')
                    ->where('ip', '!=', ''),
                $request,
                ['ip']
            )
                ->groupBy('ip')
                ->orderByDesc('aggregate_count')
                ->orderByDesc('last_seen_at')
                ->limit($detailLimit)
                ->get();
        }

        if ($email !== '') {
            $deviceCorrelation['devices_for_email'] = $this->applySecurityEventFilters(
                SecurityEvent::query()
                    ->selectRaw('device_hash, COUNT(*) as aggregate_count, MAX(created_at) as last_seen_at')
                    ->where('email', $email)
                    ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked', 'device_blocked'])
                    ->whereNotNull('device_hash')
                    ->where('device_hash', '!=', ''),
                $request,
                ['device_hash']
            )
                ->groupBy('device_hash')
                ->orderByDesc('aggregate_count')
                ->orderByDesc('last_seen_at')
                ->limit($detailLimit)
                ->get();
        }

        if ($ip !== '') {
            $deviceCorrelation['devices_for_ip'] = $this->applySecurityEventFilters(
                SecurityEvent::query()
                    ->selectRaw('device_hash, COUNT(*) as aggregate_count, MAX(created_at) as last_seen_at')
                    ->where('ip', $ip)
                    ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked', 'device_blocked'])
                    ->whereNotNull('device_hash')
                    ->where('device_hash', '!=', ''),
                $request,
                ['device_hash']
            )
                ->groupBy('device_hash')
                ->orderByDesc('aggregate_count')
                ->orderByDesc('last_seen_at')
                ->limit($detailLimit)
                ->get();
        }

        $correlationSummary = [
            'top_devices' => $this->applySecurityEventFilters(
                SecurityEvent::query()
                    ->selectRaw('device_hash, COUNT(*) as aggregate_count, COUNT(DISTINCT email) as email_count, COUNT(DISTINCT ip) as ip_count, MAX(created_at) as last_seen_at')
                    ->whereNotNull('device_hash')
                    ->where('device_hash', '!=', '')
                    ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked', 'device_blocked']),
                $request,
                ['device_hash']
            )
                ->groupBy('device_hash')
                ->havingRaw('COUNT(*) >= 5 AND (COUNT(DISTINCT email) >= 2 OR COUNT(DISTINCT ip) >= 2)')
                ->orderByDesc('email_count')
                ->orderByDesc('ip_count')
                ->orderByDesc('aggregate_count')
                ->orderByDesc('last_seen_at')
                ->limit(10)
                ->get(),

            'top_emails' => $this->applySecurityEventFilters(
                SecurityEvent::query()
                    ->selectRaw('email, COUNT(*) as aggregate_count, COUNT(DISTINCT device_hash) as device_count, COUNT(DISTINCT ip) as ip_count, MAX(created_at) as last_seen_at')
                    ->whereNotNull('email')
                    ->where('email', '!=', '')
                    ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked', 'device_blocked']),
                $request,
                ['email']
            )
                ->groupBy('email')
                ->havingRaw('COUNT(*) >= 5 AND (COUNT(DISTINCT device_hash) >= 2 OR COUNT(DISTINCT ip) >= 2)')
                ->orderByDesc('device_count')
                ->orderByDesc('ip_count')
                ->orderByDesc('aggregate_count')
                ->orderByDesc('last_seen_at')
                ->limit(10)
                ->get(),

            'top_ips' => $this->applySecurityEventFilters(
                SecurityEvent::query()
                    ->selectRaw('ip, COUNT(*) as aggregate_count, COUNT(DISTINCT device_hash) as device_count, COUNT(DISTINCT email) as email_count, MAX(created_at) as last_seen_at')
                    ->whereNotNull('ip')
                    ->where('ip', '!=', '')
                    ->whereIn('type', ['login_failed', 'login_lockout', 'ip_blocked', 'identity_blocked', 'device_blocked']),
                $request,
                ['ip']
            )
                ->groupBy('ip')
                ->havingRaw('COUNT(*) >= 5 AND (COUNT(DISTINCT email) >= 2 OR COUNT(DISTINCT device_hash) >= 2)')
                ->orderByDesc('device_count')
                ->orderByDesc('email_count')
                ->orderByDesc('aggregate_count')
                ->orderByDesc('last_seen_at')
                ->limit(10)
                ->get(),
        ];

        if ($this->wantsEventsJson($request)) {
            return response()->json([
                'filters' => $filters,
                'per_page' => $perPage,
                'focused_filter_mode' => $hasFocusedCorrelationFilter,
                'events' => $events->getCollection()->map(function (SecurityEvent $event): array {
                    return $this->mapSecurityEvent($event);
                })->values()->all(),
                'pagination' => [
                    'current_page' => $events->currentPage(),
                    'last_page' => $events->lastPage(),
                    'per_page' => $events->perPage(),
                    'total' => $events->total(),
                    'from' => $events->firstItem(),
                    'to' => $events->lastItem(),
                    'has_more_pages' => $events->hasMorePages(),
                ],
                'device_correlation' => [
                    'selected_device_hash' => $deviceCorrelation['selected_device_hash'],
                    'selected_email' => $deviceCorrelation['selected_email'],
                    'selected_ip' => $deviceCorrelation['selected_ip'],
                    'emails_for_device' => $this->mapRows(
                        $deviceCorrelation['emails_for_device'],
                        ['email', 'aggregate_count', 'last_seen_at']
                    ),
                    'ips_for_device' => $this->mapRows(
                        $deviceCorrelation['ips_for_device'],
                        ['ip', 'aggregate_count', 'last_seen_at']
                    ),
                    'devices_for_email' => $this->mapRows(
                        $deviceCorrelation['devices_for_email'],
                        ['device_hash', 'aggregate_count', 'last_seen_at']
                    ),
                    'devices_for_ip' => $this->mapRows(
                        $deviceCorrelation['devices_for_ip'],
                        ['device_hash', 'aggregate_count', 'last_seen_at']
                    ),
                ],
                'correlation_summary' => [
                    'top_devices' => $this->mapRows(
                        $correlationSummary['top_devices'],
                        ['device_hash', 'aggregate_count', 'email_count', 'ip_count', 'last_seen_at']
                    ),
                    'top_emails' => $this->mapRows(
                        $correlationSummary['top_emails'],
                        ['email', 'aggregate_count', 'device_count', 'ip_count', 'last_seen_at']
                    ),
                    'top_ips' => $this->mapRows(
                        $correlationSummary['top_ips'],
                        ['ip', 'aggregate_count', 'device_count', 'email_count', 'last_seen_at']
                    ),
                ],
            ]);
        }

        return view('admin.security.events.index', [
            'adminTab' => 'security',
            'events' => $events,
            'perPage' => $perPage,
            'filters' => $filters,
            'deviceCorrelation' => $deviceCorrelation,
            'correlationSummary' => $correlationSummary,
        ]);
    }

    public function ipBans(): View
    {
        $perPage = (int) request()->query('per_page', 20);
        if (!in_array($perPage, [20, 50, 100], true)) {
            $perPage = 20;
        }

        $ipBans = SecurityIpBan::query()
            ->leftJoin('users', 'users.id', '=', 'security_ip_bans.created_by')
            ->select(
                'security_ip_bans.*',
                'users.username as created_by_user_name',
                'users.email as created_by_user_email'
            )
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
            'ttl_minutes' => ['nullable', 'integer', 'min:1', 'max:525600'],
            'ttl_seconds' => ['nullable', 'integer', 'min:1', 'max:31536000'],
            'banned_until' => ['nullable', 'date_format:Y-m-d\TH:i'],
        ]);

        $ttlMinutes = isset($validated['ttl_minutes']) ? (int) $validated['ttl_minutes'] : null;
        $ttlSeconds = isset($validated['ttl_seconds']) ? (int) $validated['ttl_seconds'] : null;

        $bannedUntil = null;
        if (!empty($validated['banned_until'])) {
            $bannedUntil = Carbon::createFromFormat(
                'Y-m-d\TH:i',
                (string) $validated['banned_until'],
                config('app.timezone')
            );
        } elseif ($ttlMinutes !== null) {
            $bannedUntil = now()->addMinutes($ttlMinutes);
        } elseif ($ttlSeconds !== null) {
            $bannedUntil = now()->addSeconds($ttlSeconds);
        }

        SecurityIpBan::query()->create([
            'ip' => (string) $validated['ip'],
            'reason' => $validated['reason'] ?? null,
            'banned_until' => $bannedUntil,
            'created_by' => auth()->id(),
        ]);

        if ($request->filled('incident_id') && Schema::hasTable('security_incidents') && Schema::hasColumn('security_incidents', 'action_status')) {
            DB::table('security_incidents')
                ->where('id', $request->incident_id)
                ->update([
                    'action_status' => 'reviewed',
                ]);
        }

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
            ->leftJoin('users', 'users.id', '=', 'security_identity_bans.created_by')
            ->select(
                'security_identity_bans.*',
                'users.username as created_by_user_name',
                'users.email as created_by_user_email'
            )
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
            'ttl_minutes' => ['nullable', 'integer', 'min:1', 'max:525600'],
            'ttl_seconds' => ['nullable', 'integer', 'min:1', 'max:31536000'],
            'banned_until' => ['nullable', 'date_format:Y-m-d\TH:i'],
        ]);

        $ttlMinutes = isset($validated['ttl_minutes']) ? (int) $validated['ttl_minutes'] : null;
        $ttlSeconds = isset($validated['ttl_seconds']) ? (int) $validated['ttl_seconds'] : null;

        $bannedUntil = null;
        if (!empty($validated['banned_until'])) {
            $bannedUntil = Carbon::createFromFormat(
                'Y-m-d\TH:i',
                (string) $validated['banned_until'],
                config('app.timezone')
            );
        } elseif ($ttlMinutes !== null) {
            $bannedUntil = now()->addMinutes($ttlMinutes);
        } elseif ($ttlSeconds !== null) {
            $bannedUntil = now()->addSeconds($ttlSeconds);
        }

        SecurityIdentityBan::query()->create([
            'email' => mb_strtolower(trim((string) $validated['email'])),
            'reason' => $validated['reason'] ?? null,
            'banned_until' => $bannedUntil,
            'created_by' => auth()->id(),
        ]);

        if ($request->filled('incident_id') && Schema::hasTable('security_incidents') && Schema::hasColumn('security_incidents', 'action_status')) {
            DB::table('security_incidents')
                ->where('id', $request->incident_id)
                ->update([
                    'action_status' => 'reviewed',
                ]);
        }

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
            ->active()
            ->leftJoin('users', 'users.id', '=', 'security_device_bans.created_by')
            ->select(
                'security_device_bans.*',
                'users.username as created_by_user_name',
                'users.email as created_by_user_email'
            )
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
            'ttl_minutes' => ['nullable', 'integer', 'min:1', 'max:525600'],
            'ttl_seconds' => ['nullable', 'integer', 'min:1', 'max:31536000'],
            'banned_until' => ['nullable', 'date_format:Y-m-d\TH:i'],
        ]);

        $ttlMinutes = isset($validated['ttl_minutes']) ? (int) $validated['ttl_minutes'] : null;
        $ttlSeconds = isset($validated['ttl_seconds']) ? (int) $validated['ttl_seconds'] : null;

        $bannedUntil = null;
        if (!empty($validated['banned_until'])) {
            $bannedUntil = Carbon::createFromFormat(
                'Y-m-d\TH:i',
                (string) $validated['banned_until'],
                config('app.timezone')
            );
        } elseif ($ttlMinutes !== null) {
            $bannedUntil = now()->addMinutes($ttlMinutes);
        } elseif ($ttlSeconds !== null) {
            $bannedUntil = now()->addSeconds($ttlSeconds);
        }

        SecurityDeviceBan::query()->create([
            'device_hash' => trim((string) $validated['device_hash']),
            'reason' => $validated['reason'] ?? null,
            'banned_until' => $bannedUntil,
            'is_active' => true,
            'created_by' => auth()->id(),
        ]);

        if ($request->filled('incident_id') && Schema::hasTable('security_incidents') && Schema::hasColumn('security_incidents', 'action_status')) {
            DB::table('security_incidents')
                ->where('id', $request->incident_id)
                ->update([
                    'action_status' => 'reviewed',
                ]);
        }

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

    public function allowlistIp(): View
    {
        return view('admin.security.allowlist.ip.index', [
            'adminTab' => 'security',
            'allowlistEntries' => $this->allowlistEntriesByType('ip'),
            'perPage' => $this->allowlistPerPage(),
        ]);
    }

    public function storeAllowlistIp(Request $request): RedirectResponse
    {
        return $this->storeAllowlistEntry($request, 'ip', 'admin.security.allowlist.ip.index');
    }

    public function updateAllowlistIp(Request $request, int $id): RedirectResponse
    {
        return $this->updateAllowlistEntry($request, $id, 'ip', 'admin.security.allowlist.ip.index');
    }

    public function destroyAllowlistIp(int $id): RedirectResponse
    {
        return $this->destroyAllowlistEntry($id, 'ip', 'admin.security.allowlist.ip.index');
    }

    public function allowlistDevice(): View
    {
        return view('admin.security.allowlist.device.index', [
            'adminTab' => 'security',
            'allowlistEntries' => $this->allowlistEntriesByType('device'),
            'perPage' => $this->allowlistPerPage(),
        ]);
    }

    public function storeAllowlistDevice(Request $request): RedirectResponse
    {
        return $this->storeAllowlistEntry($request, 'device', 'admin.security.allowlist.device.index');
    }

    public function updateAllowlistDevice(Request $request, int $id): RedirectResponse
    {
        return $this->updateAllowlistEntry($request, $id, 'device', 'admin.security.allowlist.device.index');
    }

    public function destroyAllowlistDevice(int $id): RedirectResponse
    {
        return $this->destroyAllowlistEntry($id, 'device', 'admin.security.allowlist.device.index');
    }

    public function allowlistIdentity(): View
    {
        return view('admin.security.allowlist.identity.index', [
            'adminTab' => 'security',
            'allowlistEntries' => $this->allowlistEntriesByType('identity'),
            'perPage' => $this->allowlistPerPage(),
        ]);
    }

    public function storeAllowlistIdentity(Request $request): RedirectResponse
    {
        return $this->storeAllowlistEntry($request, 'identity', 'admin.security.allowlist.identity.index');
    }

    public function updateAllowlistIdentity(Request $request, int $id): RedirectResponse
    {
        return $this->updateAllowlistEntry($request, $id, 'identity', 'admin.security.allowlist.identity.index');
    }

    public function destroyAllowlistIdentity(int $id): RedirectResponse
    {
        return $this->destroyAllowlistEntry($id, 'identity', 'admin.security.allowlist.identity.index');
    }

    public function editSettings(): View
    {
        return view('admin.security.settings.edit', [
            'adminTab' => 'security',
            'settings' => $this->securitySettingsService->get(),
            'incidentDetectionSettings' => $this->securitySettingsService->getIncidentDetectionSettings(),
            'incidentAutoActionSettings' => $this->securitySettingsService->getIncidentAutoActionSettings(),
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
            'incidents_enabled' => ['sometimes', 'boolean'],
            'incident_credential_stuffing_enabled' => ['sometimes', 'boolean'],
            'incident_credential_stuffing_window_minutes' => ['required', 'integer', 'min:1', 'max:10080'],
            'incident_credential_stuffing_cooldown_minutes' => ['required', 'integer', 'min:1', 'max:10080'],
            'incident_credential_stuffing_min_distinct_emails' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_credential_stuffing_min_distinct_ips' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_credential_stuffing_linked_events_limit' => ['required', 'integer', 'min:1', 'max:1000'],
            'incident_credential_stuffing_meta_sample_limit' => ['required', 'integer', 'min:1', 'max:1000'],
            'incident_credential_stuffing_score_base' => ['required', 'integer', 'min:0', 'max:1000'],
            'incident_credential_stuffing_score_max' => ['required', 'integer', 'min:0', 'max:1000'],
            'incident_account_sharing_enabled' => ['sometimes', 'boolean'],
            'incident_account_sharing_window_minutes' => ['required', 'integer', 'min:1', 'max:10080'],
            'incident_account_sharing_cooldown_minutes' => ['required', 'integer', 'min:1', 'max:10080'],
            'incident_account_sharing_min_distinct_devices' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_account_sharing_min_distinct_ips' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_account_sharing_linked_events_limit' => ['required', 'integer', 'min:1', 'max:1000'],
            'incident_account_sharing_meta_sample_limit' => ['required', 'integer', 'min:1', 'max:1000'],
            'incident_account_sharing_score_base' => ['required', 'integer', 'min:0', 'max:1000'],
            'incident_account_sharing_score_max' => ['required', 'integer', 'min:0', 'max:1000'],
            'incident_bot_pattern_enabled' => ['sometimes', 'boolean'],
            'incident_bot_pattern_window_minutes' => ['required', 'integer', 'min:1', 'max:10080'],
            'incident_bot_pattern_cooldown_minutes' => ['required', 'integer', 'min:1', 'max:10080'],
            'incident_bot_pattern_min_events' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_bot_pattern_burst_min_events' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_bot_pattern_burst_min_distinct_emails' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_bot_pattern_burst_min_distinct_ips' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_bot_pattern_linked_events_limit' => ['required', 'integer', 'min:1', 'max:1000'],
            'incident_bot_pattern_meta_sample_limit' => ['required', 'integer', 'min:1', 'max:1000'],
            'incident_bot_pattern_score_base' => ['required', 'integer', 'min:0', 'max:1000'],
            'incident_bot_pattern_score_max' => ['required', 'integer', 'min:0', 'max:1000'],
            'incident_device_cluster_enabled' => ['sometimes', 'boolean'],
            'incident_device_cluster_window_minutes' => ['required', 'integer', 'min:1', 'max:10080'],
            'incident_device_cluster_cooldown_minutes' => ['required', 'integer', 'min:1', 'max:10080'],
            'incident_device_cluster_min_events' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_device_cluster_min_distinct_devices' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_device_cluster_min_distinct_emails' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_device_cluster_min_distinct_ips' => ['required', 'integer', 'min:1', 'max:100000'],
            'incident_device_cluster_linked_events_limit' => ['required', 'integer', 'min:1', 'max:1000'],
            'incident_device_cluster_meta_sample_limit' => ['required', 'integer', 'min:1', 'max:1000'],
            'incident_device_cluster_score_base' => ['required', 'integer', 'min:0', 'max:1000'],
            'incident_device_cluster_score_max' => ['required', 'integer', 'min:0', 'max:1000'],
            'incident_auto_actions_enabled' => ['sometimes', 'boolean'],
            'incident_auto_actions_update_incident_status' => ['sometimes', 'boolean'],
            'incident_auto_action_credential_stuffing_identity_ban_enabled' => ['sometimes', 'boolean'],
            'incident_auto_action_bot_pattern_ip_ban_enabled' => ['sometimes', 'boolean'],
            'incident_auto_action_device_cluster_device_ban_enabled' => ['sometimes', 'boolean'],
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

        SystemSettingHelper::set('incidents.enabled', $request->boolean('incidents_enabled'), 'bool');
        SystemSettingHelper::set('incidents.credential_stuffing.enabled', $request->boolean('incident_credential_stuffing_enabled'), 'bool');
        SystemSettingHelper::set('incidents.credential_stuffing.window_minutes', (int) $validated['incident_credential_stuffing_window_minutes'], 'int');
        SystemSettingHelper::set('incidents.credential_stuffing.cooldown_minutes', (int) $validated['incident_credential_stuffing_cooldown_minutes'], 'int');
        SystemSettingHelper::set('incidents.credential_stuffing.min_distinct_emails', (int) $validated['incident_credential_stuffing_min_distinct_emails'], 'int');
        SystemSettingHelper::set('incidents.credential_stuffing.min_distinct_ips', (int) $validated['incident_credential_stuffing_min_distinct_ips'], 'int');
        SystemSettingHelper::set('incidents.credential_stuffing.linked_events_limit', (int) $validated['incident_credential_stuffing_linked_events_limit'], 'int');
        SystemSettingHelper::set('incidents.credential_stuffing.meta_sample_limit', (int) $validated['incident_credential_stuffing_meta_sample_limit'], 'int');
        SystemSettingHelper::set('incidents.credential_stuffing.score_base', (int) $validated['incident_credential_stuffing_score_base'], 'int');
        SystemSettingHelper::set('incidents.credential_stuffing.score_max', (int) $validated['incident_credential_stuffing_score_max'], 'int');

        SystemSettingHelper::set('incidents.account_sharing.enabled', $request->boolean('incident_account_sharing_enabled'), 'bool');
        SystemSettingHelper::set('incidents.account_sharing.window_minutes', (int) $validated['incident_account_sharing_window_minutes'], 'int');
        SystemSettingHelper::set('incidents.account_sharing.cooldown_minutes', (int) $validated['incident_account_sharing_cooldown_minutes'], 'int');
        SystemSettingHelper::set('incidents.account_sharing.min_distinct_devices', (int) $validated['incident_account_sharing_min_distinct_devices'], 'int');
        SystemSettingHelper::set('incidents.account_sharing.min_distinct_ips', (int) $validated['incident_account_sharing_min_distinct_ips'], 'int');
        SystemSettingHelper::set('incidents.account_sharing.linked_events_limit', (int) $validated['incident_account_sharing_linked_events_limit'], 'int');
        SystemSettingHelper::set('incidents.account_sharing.meta_sample_limit', (int) $validated['incident_account_sharing_meta_sample_limit'], 'int');
        SystemSettingHelper::set('incidents.account_sharing.score_base', (int) $validated['incident_account_sharing_score_base'], 'int');
        SystemSettingHelper::set('incidents.account_sharing.score_max', (int) $validated['incident_account_sharing_score_max'], 'int');

        SystemSettingHelper::set('incidents.bot_pattern.enabled', $request->boolean('incident_bot_pattern_enabled'), 'bool');
        SystemSettingHelper::set('incidents.bot_pattern.window_minutes', (int) $validated['incident_bot_pattern_window_minutes'], 'int');
        SystemSettingHelper::set('incidents.bot_pattern.cooldown_minutes', (int) $validated['incident_bot_pattern_cooldown_minutes'], 'int');
        SystemSettingHelper::set('incidents.bot_pattern.min_events', (int) $validated['incident_bot_pattern_min_events'], 'int');
        SystemSettingHelper::set('incidents.bot_pattern.burst_min_events', (int) $validated['incident_bot_pattern_burst_min_events'], 'int');
        SystemSettingHelper::set('incidents.bot_pattern.burst_min_distinct_emails', (int) $validated['incident_bot_pattern_burst_min_distinct_emails'], 'int');
        SystemSettingHelper::set('incidents.bot_pattern.burst_min_distinct_ips', (int) $validated['incident_bot_pattern_burst_min_distinct_ips'], 'int');
        SystemSettingHelper::set('incidents.bot_pattern.linked_events_limit', (int) $validated['incident_bot_pattern_linked_events_limit'], 'int');
        SystemSettingHelper::set('incidents.bot_pattern.meta_sample_limit', (int) $validated['incident_bot_pattern_meta_sample_limit'], 'int');
        SystemSettingHelper::set('incidents.bot_pattern.score_base', (int) $validated['incident_bot_pattern_score_base'], 'int');
        SystemSettingHelper::set('incidents.bot_pattern.score_max', (int) $validated['incident_bot_pattern_score_max'], 'int');

        SystemSettingHelper::set('incidents.device_cluster.enabled', $request->boolean('incident_device_cluster_enabled'), 'bool');
        SystemSettingHelper::set('incidents.device_cluster.window_minutes', (int) $validated['incident_device_cluster_window_minutes'], 'int');
        SystemSettingHelper::set('incidents.device_cluster.cooldown_minutes', (int) $validated['incident_device_cluster_cooldown_minutes'], 'int');
        SystemSettingHelper::set('incidents.device_cluster.min_events', (int) $validated['incident_device_cluster_min_events'], 'int');
        SystemSettingHelper::set('incidents.device_cluster.min_distinct_devices', (int) $validated['incident_device_cluster_min_distinct_devices'], 'int');
        SystemSettingHelper::set('incidents.device_cluster.min_distinct_emails', (int) $validated['incident_device_cluster_min_distinct_emails'], 'int');
        SystemSettingHelper::set('incidents.device_cluster.min_distinct_ips', (int) $validated['incident_device_cluster_min_distinct_ips'], 'int');
        SystemSettingHelper::set('incidents.device_cluster.linked_events_limit', (int) $validated['incident_device_cluster_linked_events_limit'], 'int');
        SystemSettingHelper::set('incidents.device_cluster.meta_sample_limit', (int) $validated['incident_device_cluster_meta_sample_limit'], 'int');
        SystemSettingHelper::set('incidents.device_cluster.score_base', (int) $validated['incident_device_cluster_score_base'], 'int');
        SystemSettingHelper::set('incidents.device_cluster.score_max', (int) $validated['incident_device_cluster_score_max'], 'int');

        SystemSettingHelper::set('incidents.auto_actions.enabled', $request->boolean('incident_auto_actions_enabled'), 'bool');
        SystemSettingHelper::set('incidents.auto_actions.update_incident_status', $request->boolean('incident_auto_actions_update_incident_status'), 'bool');
        SystemSettingHelper::set('incidents.auto_actions.credential_stuffing.identity_ban_enabled', $request->boolean('incident_auto_action_credential_stuffing_identity_ban_enabled'), 'bool');
        SystemSettingHelper::set('incidents.auto_actions.bot_pattern.ip_ban_enabled', $request->boolean('incident_auto_action_bot_pattern_ip_ban_enabled'), 'bool');
        SystemSettingHelper::set('incidents.auto_actions.device_cluster.device_ban_enabled', $request->boolean('incident_auto_action_device_cluster_device_ban_enabled'), 'bool');

        return redirect()->route('admin.security.settings.edit')->with('admin_notice', 'Security-Settings gespeichert.');
    }

    private function allowlistPerPage(): int
    {
        $perPage = (int) request()->query('per_page', 20);
        if (!in_array($perPage, [20, 50, 100], true)) {
            $perPage = 20;
        }

        return $perPage;
    }

    private function allowlistEntriesByType(string $type)
    {
        return SecurityAllowlistEntry::query()
            ->where('type', $type)
            ->latest('id')
            ->paginate($this->allowlistPerPage())
            ->appends(request()->query())
            ->onEachSide(2);
    }

    private function storeAllowlistEntry(Request $request, string $type, string $redirectRoute): RedirectResponse
    {
        $validated = $request->validate([
            'value' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:1000'],
            'is_active' => ['sometimes', 'boolean'],
            'autoban_only' => ['sometimes', 'boolean'],
        ]);

        $normalizedValue = $this->securityAllowlistService->normalize($type, (string) $validated['value']);
        if ($normalizedValue === null) {
            return redirect()->route($redirectRoute)->with('admin_notice', 'Allowlist-Wert ist ungültig.');
        }

        $existing = SecurityAllowlistEntry::query()
            ->where('type', $type)
            ->where('value', $normalizedValue)
            ->first();

        if ($existing !== null) {
            $existing->fill([
                'description' => $validated['description'] ?? null,
                'is_active' => $request->boolean('is_active'),
                'autoban_only' => $request->boolean('autoban_only', true),
            ])->save();

            return redirect()->route($redirectRoute)->with('admin_notice', 'Allowlist-Eintrag aktualisiert.');
        }

        SecurityAllowlistEntry::query()->create([
            'type' => $type,
            'value' => $normalizedValue,
            'description' => $validated['description'] ?? null,
            'is_active' => $request->boolean('is_active'),
            'autoban_only' => $request->boolean('autoban_only', true),
            'created_by' => auth()->id(),
        ]);

        return redirect()->route($redirectRoute)->with('admin_notice', 'Allowlist-Eintrag gespeichert.');
    }

    private function updateAllowlistEntry(Request $request, int $id, string $type, string $redirectRoute): RedirectResponse
    {
        $entry = SecurityAllowlistEntry::query()
            ->whereKey($id)
            ->where('type', $type)
            ->first();

        if ($entry === null) {
            return redirect()->route($redirectRoute)->with('admin_notice', 'Allowlist-Eintrag nicht gefunden.');
        }

        $validated = $request->validate([
            'description' => ['nullable', 'string', 'max:1000'],
            'is_active' => ['sometimes', 'boolean'],
            'autoban_only' => ['sometimes', 'boolean'],
        ]);

        $entry->fill([
            'description' => $validated['description'] ?? null,
            'is_active' => $request->boolean('is_active'),
            'autoban_only' => $request->boolean('autoban_only', true),
        ])->save();

        return redirect()->route($redirectRoute)->with('admin_notice', 'Allowlist-Eintrag aktualisiert.');
    }

    private function destroyAllowlistEntry(int $id, string $type, string $redirectRoute): RedirectResponse
    {
        SecurityAllowlistEntry::query()
            ->whereKey($id)
            ->where('type', $type)
            ->delete();

        return redirect()->route($redirectRoute)->with('admin_notice', 'Allowlist-Eintrag entfernt.');
    }

    private function wantsEventsJson(Request $request): bool
    {
        $format = mb_strtolower(trim((string) $request->query('format', '')));
        $response = mb_strtolower(trim((string) $request->query('response', '')));

        return $request->boolean('as_json')
            || $format === 'json'
            || $response === 'json';
    }

    private function applySecurityEventFilters(Builder $query, Request $request, array $except = []): Builder
    {
        $filters = $this->normalizedSecurityEventFilters($request->all());

        if ($filters['type'] !== '' && !in_array('type', $except, true)) {
            $query->where('type', $filters['type']);
        }

        if ($filters['ip'] !== '' && !in_array('ip', $except, true)) {
            $query->where('ip', $filters['ip']);
        }

        if ($filters['email'] !== '' && !in_array('email', $except, true)) {
            $query->where('email', $filters['email']);
        }

        if ($filters['device_hash'] !== '' && !in_array('device_hash', $except, true)) {
            $query->where('device_hash', $filters['device_hash']);
        }

        if ($filters['support_ref'] !== '' && !in_array('support_ref', $except, true)) {
            $query->where('meta->support_ref', $filters['support_ref']);
        }

        if ($filters['date_from'] !== '' && !in_array('date_from', $except, true)) {
            $query->whereDate('created_at', '>=', $filters['date_from']);
        }

        if ($filters['date_to'] !== '' && !in_array('date_to', $except, true)) {
            $query->whereDate('created_at', '<=', $filters['date_to']);
        }

        return $query;
    }

    private function normalizedSecurityEventFilters(array $input): array
    {
        return [
            'type' => trim((string) ($input['type'] ?? '')),
            'ip' => trim((string) ($input['ip'] ?? '')),
            'email' => mb_strtolower(trim((string) ($input['email'] ?? ''))),
            'device_hash' => trim((string) ($input['device_hash'] ?? '')),
            'support_ref' => mb_strtoupper(trim((string) ($input['support_ref'] ?? ''))),
            'date_from' => trim((string) ($input['date_from'] ?? '')),
            'date_to' => trim((string) ($input['date_to'] ?? '')),
        ];
    }

    private function mapSecurityEvent(SecurityEvent $event): array
    {
        return [
            'id' => $event->id,
            'type' => $event->type,
            'ip' => $event->ip,
            'email' => $event->email,
            'device_hash' => $event->device_hash,
            'user_id' => $event->user_id,
            'meta' => is_array($event->meta) ? $event->meta : $event->meta,
            'created_at' => $event->created_at?->toDateTimeString(),
            'updated_at' => $event->updated_at?->toDateTimeString(),
        ];
    }

    private function mapRows(iterable $rows, array $fields): array
    {
        $result = [];

        foreach ($rows as $row) {
            $mapped = [];

            foreach ($fields as $field) {
                $value = data_get($row, $field);

                if ($value instanceof Carbon) {
                    $mapped[$field] = $value->toDateTimeString();
                    continue;
                }

                $mapped[$field] = $value;
            }

            $result[] = $mapped;
        }

        return $result;
    }
}
