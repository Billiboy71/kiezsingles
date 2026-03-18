<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureNotBannedEmail.php
// Purpose: Block requests for active email bans and log blocking events
// Changed: 17-03-2026 12:26 (Europe/Berlin)
// Version: 1.0
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

class EnsureNotBannedEmail
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
        private readonly SecuritySupportAccessTokenService $securitySupportAccessTokenService,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $email = $this->normalizedEmail((string) $request->input('email', ''));

        if ($email === null) {
            return $next($request);
        }

        $banRow = $this->findActiveEmailBan($email);

        if ($banRow === null) {
            return $next($request);
        }

        $ip = (string) ($request->ip() ?? '');
        $deviceHash = $this->deviceHashService->forRequest($request);
        $banId = isset($banRow['id']) && $banRow['id'] !== null ? (int) $banRow['id'] : 0;
        $caseKey = 'email_ban:'.$banId.':email:'.$email;

        $meta = [
            'reason' => 'email_ban',
            'path' => $request->path(),
        ];

        if (isset($banRow['reason']) && $banRow['reason'] !== null) {
            $meta['ban_reason'] = (string) $banRow['reason'];
        }

        if (array_key_exists('banned_until', $banRow)) {
            $meta['banned_until'] = $banRow['banned_until'] !== null ? (string) $banRow['banned_until'] : null;
        }

        $this->securityEventLogger->log(
            type: 'email_blocked',
            ip: $ip !== '' ? $ip : null,
            email: $email,
            deviceHash: $deviceHash,
            meta: $meta,
        );

        $supportRef = $this->resolveLatestSecurityReference($ip !== '' ? $ip : null, $email, $deviceHash);
        $supportAccess = $this->securitySupportAccessTokenService->issueForCase(
            caseKey: $caseKey,
            securityEventType: 'email_blocked',
            sourceContext: 'security_login_block',
            contactEmail: $email,
            preferredSupportReference: $supportRef,
        );
        $supportAccessToken = (string) $supportAccess['plain_token'];

        if ($request->expectsJson()) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        return redirect()
            ->route('login')
            ->with('security_ban_support_ref', $supportRef)
            ->with('security_ban_support_reference', $supportRef)
            ->with('security_support_reference', $supportRef)
            ->with('security_ban_support_access_token', $supportAccessToken)
            ->with('security_ban_contact_email', $email)
            ->with('security_contact_email', $email)
            ->withInput([
                'email' => (string) $request->input('email', ''),
            ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    private function findActiveEmailBan(string $email): ?array
    {
        // Best-effort: support differing table/column layouts without assuming a model exists.
        $table = 'security_email_bans';

        if (!Schema::hasTable($table)) {
            return null;
        }

        $query = DB::table($table);

        if (Schema::hasColumn($table, 'email')) {
            $query->where('email', $email);
        } else {
            return null;
        }

        // If there is a "revoked_at" column, only non-revoked bans apply.
        if (Schema::hasColumn($table, 'revoked_at')) {
            $query->whereNull('revoked_at');
        }

        // If there is an "is_active" column, require it.
        if (Schema::hasColumn($table, 'is_active')) {
            $query->where('is_active', 1);
        }

        // If there is a "banned_until" column, treat NULL as permanent, future as active.
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

        return $value !== '' ? $value : null;
    }

    private function resolveLatestSecurityReference(?string $ip, ?string $email, ?string $deviceHash): string
    {
        $query = \App\Models\SecurityEvent::query()
            ->where('created_at', '>=', now()->subMinutes(10))
            ->latest('id');

        $ip = $ip !== null ? trim($ip) : null;
        $email = $email !== null ? trim($email) : null;
        $deviceHash = $deviceHash !== null ? trim($deviceHash) : null;

        if ($ip === null || $ip === '') {
            $query->whereNull('ip');
        } else {
            $query->where('ip', $ip);
        }

        if ($email === null || $email === '') {
            $query->whereNull('email');
        } else {
            $query->where('email', $email);
        }

        if ($deviceHash === null || $deviceHash === '') {
            $query->whereNull('device_hash');
        } else {
            $query->where('device_hash', $deviceHash);
        }

        $event = $query->first(['reference']);

        if ($event === null || !is_string($event->reference) || trim($event->reference) === '') {
            abort(403);
        }

        return trim($event->reference);
    }

}
