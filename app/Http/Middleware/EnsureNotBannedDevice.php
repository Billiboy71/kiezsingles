<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureNotBannedDevice.php
// Purpose: Block requests for active device bans and log blocking events
// Changed: 12-03-2026 03:11 (Europe/Berlin)
// Version: 1.2
// ============================================================================

namespace App\Http\Middleware;

use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use App\Services\Security\SecuritySupportAccessTokenService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\HttpFoundation\Response;

class EnsureNotBannedDevice
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
        private readonly SecuritySupportAccessTokenService $securitySupportAccessTokenService,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $deviceHash = $this->normalizedDeviceHash((string) ($this->deviceHashService->forRequest($request) ?? ''));

        if ($deviceHash === null) {
            return $next($request);
        }

        $banRow = $this->findActiveDeviceBan($deviceHash);

        if ($banRow === null) {
            return $next($request);
        }

        $ip = (string) ($request->ip() ?? '');
        $contactEmail = $this->normalizedEmail((string) $request->input('email', ''));

        $banId = isset($banRow['id']) && $banRow['id'] !== null ? (int) $banRow['id'] : 0;
        $caseKey = 'device_ban:'.$banId.':device:'.$deviceHash;
        $supportAccess = $this->securitySupportAccessTokenService->issueForCase(
            caseKey: $caseKey,
            securityEventType: 'device_blocked',
            sourceContext: 'security_login_block',
            contactEmail: $contactEmail,
        );
        $supportRef = (string) $supportAccess['support_reference'];
        $supportAccessToken = (string) $supportAccess['plain_token'];

        $meta = [
            'support_ref' => $supportRef,
            'path' => $request->path(),
            'device_hash' => $deviceHash,
            'device_correlation_key' => 'device:'.$deviceHash,
            'device_hash_source' => 'device_cookie',
        ];

        if (isset($banRow['reason']) && $banRow['reason'] !== null) {
            $meta['reason'] = (string) $banRow['reason'];
        }

        if (array_key_exists('banned_until', $banRow)) {
            $meta['banned_until'] = $banRow['banned_until'] !== null ? (string) $banRow['banned_until'] : null;
        }

        $this->securityEventLogger->log(
            type: 'device_blocked',
            ip: $ip !== '' ? $ip : null,
            email: $contactEmail,
            deviceHash: $deviceHash,
            meta: $meta,
        );

        if ($request->expectsJson()) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        $redirect = redirect()
            ->route('login')
            ->with('security_ban_support_ref', $supportRef)
            ->with('security_ban_support_reference', $supportRef)
            ->with('security_support_reference', $supportRef)
            ->with('security_ban_support_access_token', $supportAccessToken)
            ->withInput([
                'email' => (string) $request->input('email', ''),
            ]);

        if ($contactEmail !== null) {
            $redirect = $redirect
                ->with('security_ban_contact_email', $contactEmail)
                ->with('security_support_contact_email', $contactEmail);
        }

        return $redirect;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function findActiveDeviceBan(string $deviceHash): ?array
    {
        $table = 'security_device_bans';

        if (!Schema::hasTable($table)) {
            return null;
        }

        $query = DB::table($table);

        if (Schema::hasColumn($table, 'device_hash')) {
            $query->where('device_hash', $deviceHash);
        } elseif (Schema::hasColumn($table, 'deviceHash')) {
            $query->where('deviceHash', $deviceHash);
        } else {
            return null;
        }

        if (Schema::hasColumn($table, 'revoked_at')) {
            $query->whereNull('revoked_at');
        }

        if (Schema::hasColumn($table, 'is_active')) {
            $query->where('is_active', 1);
        }

        if (Schema::hasColumn($table, 'banned_until')) {
            $now = Carbon::now();
            $query->where(function ($q) use ($now) {
                $q->whereNull('banned_until')->orWhere('banned_until', '>', $now);
            });
        }

        if (Schema::hasColumn($table, 'id')) {
            $query->orderByDesc('id');
        }

        $row = $query->first();

        if ($row === null) {
            return null;
        }

        /** @var array<string, mixed> $arr */
        $arr = (array) $row;

        return $arr;
    }

    private function normalizedEmail(string $email): ?string
    {
        $value = mb_strtolower(trim($email));

        if ($value === '') {
            return null;
        }

        return filter_var($value, FILTER_VALIDATE_EMAIL) !== false ? $value : null;
    }

    private function normalizedDeviceHash(string $hash): ?string
    {
        $value = trim($hash);

        return $value !== '' ? $value : null;
    }
}
