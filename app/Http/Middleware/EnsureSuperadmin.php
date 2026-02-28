<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureSuperadmin.php
// Purpose: Allow access only for superadmin users (server-side enforcement)
// Created: 19-02-2026 19:02 (Europe/Berlin)
// Changed: 28-02-2026 14:49 (Europe/Berlin)
// Version: 0.5
// ============================================================================

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureSuperadmin
{
    /**
     * NOTE (Architecture / SSOT):
     * This middleware is part of the Single Source of Truth for
     * privileged admin backend sections:
     * auth + superadmin + section:*.
     * No additional role checks should exist inside controllers.
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

        if (!$user || !$user->hasRole('superadmin')) {
            abort(403);
        }

        return $next($request);
    }
}