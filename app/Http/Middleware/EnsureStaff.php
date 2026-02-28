<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureStaff.php
// Purpose: Allow access to admin backend for admin OR superadmin OR moderator (server-side)
// Created: 14-02-2026 17:15 (Europe/Berlin)
// Changed: 28-02-2026 14:49 (Europe/Berlin)
// Version: 0.5
// ============================================================================

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureStaff
{
    /**
     * NOTE (Architecture / SSOT):
     * This middleware is part of the Single Source of Truth for admin backend access:
     * auth + staff + section:*.
     * Do not duplicate role checks inside controllers.
     */

    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (!auth()->check()) {
            return redirect()->route('login');
        }

        $user = auth()->user();

        // Staff: admin, superadmin, moderator
        if (!$user || !$user->hasAnyRole(['admin', 'superadmin', 'moderator'])) {
            abort(403);
        }

        return $next($request);
    }
}