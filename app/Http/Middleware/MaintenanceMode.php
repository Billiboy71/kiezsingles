<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\MaintenanceMode.php
// Purpose: App maintenance gate (DB-driven).
// Changed: 28-02-2026 02:33 (Europe/Berlin)
//          Superadmin is ALWAYS allowed (no toggle).
//          Admin allowed only if maintenance_settings.allow_admins = true.
//          Moderator allowed only if maintenance_settings.allow_moderators = true.
//          Non-allowed users are blocked during maintenance (no forced logout).
//          Registration and verification flows are blocked.
// Version: 2.7
// ============================================================================

namespace App\Http\Middleware;

use App\Support\KsMaintenance;
use App\Support\SystemSettingHelper;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\HttpFoundation\Response;

class MaintenanceMode
{
    public function handle(Request $request, Closure $next): Response
    {
        $maintenanceEnabled = KsMaintenance::enabled();

        if (!$maintenanceEnabled) {
            return $next($request);
        }

        // IMPORTANT: Avoid route-name redirects during maintenance to prevent redirect loops.
        // Redirect target is a hard URL that is explicitly allowlisted below.
        $maintenanceRedirectUrl = url('/');

        // Ensure session is started so auth/session state is reliable.
        if ($request->hasSession()) {
            $request->session()->start();

            // Breeze-style flash status (e.g. "verification-link-sent") should not appear in maintenance.
            $request->session()->forget('status');
        }

        $allowAdmins = KsMaintenance::allowAdmins();
        $allowModerators = KsMaintenance::allowModerators();

        $isAllowedDuringMaintenance = function (?string $role) use ($allowAdmins, $allowModerators): bool {
            $role = mb_strtolower(trim((string) ($role ?? '')));

            if ($role === 'superadmin') {
                return true;
            }

            if ($role === 'admin') {
                return $allowAdmins;
            }

            if ($role === 'moderator') {
                return $allowModerators;
            }

            return false;
        };

        // Role whitelist during maintenance (server-side, fail-closed).
        if (auth()->check() && $isAllowedDuringMaintenance((string) auth()->user()->role)) {
            return $next($request);
        }

        // Break-glass bypass (level 3): allow everything for valid bypass cookie while maintenance is active.
        // Gilt nur in Production ODER wenn simulate_production aktiv ist.
        try {
            if (Schema::hasTable('debug_settings') && (bool) SystemSettingHelper::get('debug.break_glass', false)) {
                $simulateProd = (bool) SystemSettingHelper::get('debug.simulate_production', false);
                $isProdEffective = app()->environment('production') || $simulateProd;

                if ($isProdEffective) {
                    $expiresAt = (int) $request->cookie('kiez_break_glass', 0);

                    if ($expiresAt > 0 && $expiresAt >= now()->timestamp) {
                        return $next($request);
                    }
                }
            }
        } catch (\Throwable $e) {
            // fail-closed (no break-glass)
        }

        // Block ALL verification-related endpoints during maintenance for non-whitelisted users.
        // Your screenshot shows POST to "verification-notification-guest".
        if (
            $request->is('verify-email') ||
            $request->is('email/*') ||
            $request->is('verification-notification-guest') ||
            $request->is('verification-notification*')
        ) {
            return redirect($maintenanceRedirectUrl);
        }

        // Always block registration (GET + POST), even if someone knows the URL.
        if ($request->is('register') || $request->is('register/*')) {
            return redirect($maintenanceRedirectUrl);
        }

        $isNoteinstieg = (
            $request->is('noteinstieg') ||
            $request->is('noteinstieg/*') ||
            $request->is('noteinstieg-einstieg') ||
            $request->is('noteinstieg-wartung')
        );

        $isLogout = $request->is('logout');

        // Root path handling: request()->path() is "/" in this project (tinker confirmed).
        $isMaintenanceLanding = false;
        try {
            $p = (string) $request->path();
            $isMaintenanceLanding = ($p === '' || $p === '/');
        } catch (\Throwable $ignore) {
            $isMaintenanceLanding = false;
        }

        // Public allowlist during maintenance (public essentials + login/logout + health + break-glass)
        if (
            $isMaintenanceLanding ||
            $request->is('contact') ||
            $request->is('impressum') ||
            $request->is('datenschutz') ||
            $request->is('nutzungsbedingungen') ||
            $request->is('login') ||
            $isLogout ||
            $request->is('up') ||
            $request->is('break-glass') ||
            $request->is('break-glass/*') ||
            $request->is('maintenance-notify') ||
            $isNoteinstieg
        ) {
            // If a non-whitelisted user is authenticated at ANY time during maintenance, block access but keep session.
            // Ausnahme: Noteinstieg muss auch dann erreichbar sein (Browser mit bestehender Session).
            // Ausnahme: Logout muss erreichbar sein.
            // Ausnahme: Maintenance Landing darf NICHT auf sich selbst redirecten (sonst 302-loop).
            if (auth()->check() && !$isAllowedDuringMaintenance((string) auth()->user()->role) && !$isNoteinstieg && !$isLogout && !$isMaintenanceLanding) {
                return redirect($maintenanceRedirectUrl);
            }

            // IMPORTANT: POST /login must reach the controller so it can show a clear maintenance message
            // (no role lookup by email/username here, to avoid redirect loops and enumeration).
            return $next($request);
        }

        // Everything else: redirect to maintenance landing.
        return redirect($maintenanceRedirectUrl);
    }
}