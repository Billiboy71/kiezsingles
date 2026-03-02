<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\SetSessionLifetimeByRole.php
// Purpose: Set session lifetime by authenticated user role (user/moderator/admin/superadmin)
// Changed: 02-03-2026 12:41 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class SetSessionLifetimeByRole
{
    /**
     * Role policy (minutes):
     * - user: 60
     * - moderator: 120
     * - admin/superadmin: 240
     */
    public function handle(Request $request, Closure $next)
    {
        $minutes = 60;

        try {
            if (function_exists('auth') && auth()->check()) {
                $role = null;

                try {
                    $role = (string) (auth()->user()->role ?? '');
                } catch (\Throwable $ignore) {
                    $role = null;
                }

                if ($role === 'moderator') {
                    $minutes = 120;
                } elseif ($role === 'admin' || $role === 'superadmin') {
                    $minutes = 240;
                } else {
                    $minutes = 60;
                }
            }
        } catch (\Throwable $ignore) {
            $minutes = 60;
        }

        try {
            config(['session.lifetime' => $minutes]);
        } catch (\Throwable $ignore) {
            // bewusst ignorieren
        }

        return $next($request);
    }
}