<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\MaintenanceMode.php
// Purpose: App maintenance gate (DB-driven). Admins may login and access all.
//          Non-admin users are blocked during maintenance (no forced logout).
//          Registration and verification flows are blocked.
// Changed: 09-02-2026 02:02
// ============================================================================

namespace App\Http\Middleware;

use App\Models\User;
use App\Support\SystemSettingHelper;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\HttpFoundation\Response;

class MaintenanceMode
{
    public function handle(Request $request, Closure $next): Response
    {
        // If settings table doesn't exist yet (e.g. before migrate), do nothing.
        if (!Schema::hasTable('app_settings')) {
            return $next($request);
        }

        $settings = DB::table('app_settings')->select([
            'maintenance_enabled',
            'maintenance_show_eta',
            'maintenance_eta_at',
        ])->first();

        // If no settings row exists yet, do nothing.
        if (!$settings) {
            return $next($request);
        }

        $maintenanceEnabled = (bool) $settings->maintenance_enabled;

        if (!$maintenanceEnabled) {
            return $next($request);
        }

        // Ensure session is started so auth/session state is reliable.
        if ($request->hasSession()) {
            $request->session()->start();

            // Breeze-style flash status (e.g. "verification-link-sent") should not appear in maintenance.
            $request->session()->forget('status');
        }

        // Admin bypass: allow everything for logged-in admins.
        if (auth()->check() && (string) auth()->user()->role === 'admin') {
            return $next($request);
        }

        // Break-glass bypass (level 3): allow everything for valid bypass cookie while maintenance is active.
        if ((bool) SystemSettingHelper::get('debug.break_glass', false)) {
            $expiresAt = (int) $request->cookie('kiez_break_glass', 0);

            if ($expiresAt > 0 && $expiresAt >= now()->timestamp) {
                return $next($request);
            }
        }

        // Block ALL verification-related endpoints during maintenance for non-admins.
        // Your screenshot shows POST to "verification-notification-guest".
        if (
            $request->is('verify-email') ||
            $request->is('email/*') ||
            $request->is('verification-notification-guest') ||
            $request->is('verification-notification*')
        ) {
            return redirect()->route('home');
        }

        // Always block registration (GET + POST), even if someone knows the URL.
        if ($request->is('register') || $request->is('register/*')) {
            return redirect()->route('home');
        }

        // Public allowlist during maintenance (public essentials + login/logout + health + break-glass)
        if (
            $request->is('/') ||
            $request->is('contact') ||
            $request->is('impressum') ||
            $request->is('datenschutz') ||
            $request->is('nutzungsbedingungen') ||
            $request->is('login') ||
            $request->is('logout') ||
            $request->is('up') ||
            $request->is('break-glass') ||
            $request->is('break-glass/*')
        ) {
            // If a non-admin is authenticated at ANY time during maintenance, block access but keep session.
            if (auth()->check()) {
                return redirect()->route('home');
            }

            // Special case: POST /login is allowed, but only admins may attempt to log in.
            // Non-admins get redirected to the maintenance home BEFORE the auth flow can produce "auth.failed".
            if ($request->is('login') && $request->isMethod('post')) {
                $login = (string) $request->input('email', '');
                $login = trim($login);

                $loginLower = mb_strtolower($login);

                $user = $login !== ''
                    ? User::query()
                        ->select(['id', 'role'])
                        ->where(function ($q) use ($login, $loginLower) {
                            $q->where('email', $loginLower);

                            // Support username login in maintenance as well (login comes in "email" field).
                            if (!str_contains($login, '@')) {
                                $q->orWhere('username', $login)
                                  ->orWhere('username', $loginLower);
                            }
                        })
                        ->first()
                    : null;

                if (!$user || (string) $user->role !== 'admin') {
                    return redirect()->route('home');
                }

                return $next($request);
            }

            return $next($request);
        }

        // Everything else: redirect to landing page.
        return redirect()->route('home');
    }
}
