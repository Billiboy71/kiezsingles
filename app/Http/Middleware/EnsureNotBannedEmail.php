<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureNotBannedEmail.php
// Purpose: Block requests for active email bans and log blocking events
// Changed: 02-03-2026 03:34 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Http\Middleware;

use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class EnsureNotBannedEmail
{
    public function __construct(
        private readonly SecurityEventLogger $securityEventLogger,
        private readonly DeviceHashService $deviceHashService,
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
        $supportRef = $this->generateSupportReference();

        $meta = [
            'support_ref' => $supportRef,
            'path' => $request->path(),
        ];

        if (isset($banRow['reason']) && $banRow['reason'] !== null) {
            $meta['reason'] = (string) $banRow['reason'];
        }

        if (array_key_exists('banned_until', $banRow)) {
            $meta['banned_until'] = $banRow['banned_until'] !== null ? (string) $banRow['banned_until'] : null;
        }

        $this->securityEventLogger->log(
            type: 'email_blocked',
            ip: $ip !== '' ? $ip : null,
            email: $email,
            deviceHash: $this->deviceHashService->forRequest($request),
            meta: $meta,
        );

        if ($request->expectsJson()) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        return redirect()
            ->route('login')
            ->with('security_ban_support_ref', $supportRef)
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

    private function generateSupportReference(): string
    {
        return 'SEC-'.Str::upper(Str::random(random_int(6, 8)));
    }
}