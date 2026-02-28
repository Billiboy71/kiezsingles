<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureSectionAccess.php
// Purpose: Enforce backend section access server-side via staff_permissions SSOT (fail-closed for staff)
// Changed: 28-02-2026 14:49 (Europe/Berlin)
// Version: 2.1
// ============================================================================

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\HttpKernel\Exception\HttpException;

class EnsureSectionAccess
{
    /**
     * NOTE (Architecture / SSOT):
     * Section access is the only server-side authorization layer for admin backend modules.
     * Routes must be guarded via middleware stacks:
     * - auth + staff/superadmin + section:*
     * Controllers must not implement additional role/security checks.
     */

    /**
     * Route middleware usage:
     * - ->middleware('section:overview')
     * - ->middleware('section:tickets')
     * - ->middleware('section:maintenance')
     * - ->middleware('section:debug')
     * - ->middleware('section:moderation')
     * - ->middleware('section:roles')
     */
    public function handle(Request $request, Closure $next, string $sectionKey = 'overview')
    {
        // SSOT: auth is enforced via route middleware stack. If missing, fail-closed here.
        abort_unless(auth()->check(), 403);

        $user = auth()->user();

        $isStaff = $user && $user->hasAnyRole(['admin', 'superadmin', 'moderator']);
        if (!$isStaff) {
            abort(403);
        }

        $role = mb_strtolower(trim((string) ($user?->role ?? 'user')));

        $originalSectionKey = $sectionKey;
        $sectionKey = mb_strtolower(trim((string) $sectionKey));
        if ($sectionKey === '') {
            $sectionKey = 'overview';
        }

        try {
            // Failsafe: superadmin must never be locked out by module rows.
            if ($role !== 'superadmin') {
                // Overview stays reachable for staff and is not module-managed.
                if ($sectionKey === 'overview') {
                    return $next($request);
                }

                // Fail-closed for staff if permission source is missing/unreadable.
                if (!Schema::hasTable('staff_permissions')) {
                    abort(403);
                }

                $isAllowed = DB::table('staff_permissions')
                    ->where('user_id', (int) $user->id)
                    ->where('module_key', $sectionKey)
                    ->where('allowed', true)
                    ->exists();

                // Fail-closed for staff: no row means no access.
                abort_unless($isAllowed, 403);
            }
        } catch (HttpException $e) {
            // LOCAL diagnostics: expose why we 403'd via headers (no behavior change in prod).
            // IMPORTANT: Do NOT return a plain "Forbidden" response here, otherwise the global 403 rendering
            // (admin layout) cannot take over.
            if ($e->getStatusCode() === 403 && app()->environment('local')) {
                $headers = [
                    'X-KS-Role' => (string) $role,
                    'X-KS-Section' => (string) $sectionKey,
                    'X-KS-Section-Original' => (string) $originalSectionKey,
                    'X-KS-Path' => (string) $request->path(),
                    'X-KS-Access-SSOT' => 'staff_permissions',
                ];

                throw new HttpException(403, $e->getMessage() ?: 'Forbidden', $e, $headers, $e->getCode());
            }

            throw $e;
        }

        return $next($request);
    }
}