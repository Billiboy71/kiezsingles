<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureSuperadmin.php
// Purpose: Allow access only for superadmin users (server-side enforcement)
// Created: 19-02-2026 19:02 (Europe/Berlin)
// Changed: 20-02-2026 00:24 (Europe/Berlin)
// Version: 0.4
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
        $role = mb_strtolower(trim((string) ($user->role ?? 'user')));

        if ($role !== 'superadmin') {
            abort(403);
        }

        return $next($request);
    }
}