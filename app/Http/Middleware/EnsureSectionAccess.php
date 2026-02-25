<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureSectionAccess.php
// Purpose: Enforce backend section access server-side (admin full; moderator via DB whitelist; fail-closed)
// Changed: 25-02-2026 12:27 (Europe/Berlin)
// Version: 1.7
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

        // Fail-closed: if autoload/namespace is broken, do not allow access.
        if (!class_exists(\App\Support\Admin\AdminSectionAccess::class)) {
            abort(503);
        }

        $role = (string) (auth()->user()->role ?? 'user');
        $role = \App\Support\Admin\AdminSectionAccess::normalizeRole($role);

        $originalSectionKey = $sectionKey;

        $sectionKey = \App\Support\Admin\AdminSectionAccess::normalizeSectionKey($sectionKey);

        $maintenanceEnabled = false;

        try {
            if (Schema::hasTable('app_settings')) {
                $row = DB::table('app_settings')->select(['maintenance_enabled'])->first();
                $maintenanceEnabled = $row ? (bool) ($row->maintenance_enabled ?? false) : false;
            }
        } catch (\Throwable $e) {
            // fail-closed
            $maintenanceEnabled = false;
        }

        try {
            \App\Support\Admin\AdminSectionAccess::requireSection($role, $sectionKey, $maintenanceEnabled, auth()->user());
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
                ];

                throw new HttpException(403, $e->getMessage() ?: 'Forbidden', $e, $headers, $e->getCode());
            }

            throw $e;
        }

        return $next($request);
    }
}