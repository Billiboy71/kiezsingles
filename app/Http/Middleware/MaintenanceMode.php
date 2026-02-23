<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\MaintenanceMode.php
// Purpose: App maintenance gate (DB-driven).
//          Superadmin is ALWAYS allowed (no toggle).
//          Admin allowed only if maintenance.allow_admins = true.
//          Moderator allowed only if maintenance.allow_moderators = true.
//          Non-allowed users are blocked during maintenance (no forced logout).
//          Registration and verification flows are blocked.
// Changed: 20-02-2026 16:33 (Europe/Berlin)
// Version: 2.1
// ============================================================================

namespace App\Http\Middleware;

use App\Models\User;
use App\Support\SystemSettingHelper;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\HttpFoundation\Response;

class MaintenanceMode
{
    public function handle(Request $request, Closure $next): Response
    {
        try {
            // If settings table doesn't exist yet (e.g. before migrate), do nothing.
            if (!Schema::hasTable('app_settings')) {
                return $next($request);
            }

            $settings = DB::table('app_settings')->select([
                'maintenance_enabled',
                'maintenance_show_eta',
                'maintenance_eta_at',
            ])->first();
        } catch (\Throwable $e) {
            Log::error('MaintenanceMode: DB access failed (forcing 503 maintenance fallback).', [
                'exception' => get_class($e),
                'message' => $e->getMessage(),
                'url' => $request->fullUrl(),
                'method' => $request->method(),
                'path' => $request->path(),
            ]);

            $now = now()->format('Y-m-d H:i:s');

            // Prefer editable static HTML in /public (DB-independent). Fallback to inline minimal HTML.
            $staticPath = public_path('maintenance-db-down.html');
            $html = null;

            if (is_string($staticPath) && $staticPath !== '' && is_file($staticPath) && is_readable($staticPath)) {
                $content = @file_get_contents($staticPath);

                if (is_string($content) && $content !== '') {
                    // Optional placeholder support: replace {{timestamp}} with current server time.
                    $html = str_replace('{{timestamp}}', $now, $content);
                }
            }

            if (!is_string($html) || $html === '') {
                $html = '<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
                    . '<title>Wartung</title></head><body style="font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; padding: 24px; line-height: 1.4;">'
                    . '<h1 style="margin: 0 0 12px 0;">Service nicht verf&uuml;gbar</h1>'
                    . '<p style="margin: 0 0 12px 0;">Die Anwendung ist momentan nicht erreichbar (Datenbankverbindung fehlgeschlagen).</p>'
                    . '<p style="margin: 0; color: #666;">Zeitpunkt: ' . e($now) . '</p>'
                    . '</body></html>';
            }

            return response($html, 503)
                ->header('Content-Type', 'text/html; charset=UTF-8')
                ->header('Retry-After', '60');
        }

        // If no settings row exists yet, do nothing.
        if (!$settings) {
            return $next($request);
        }

        $maintenanceEnabled = (bool) $settings->maintenance_enabled;

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

        $allowAdmins = false;
        $allowModerators = false;

        try {
            if (Schema::hasTable('system_settings')) {
                $allowAdmins = (bool) SystemSettingHelper::get('maintenance.allow_admins', false);
                $allowModerators = (bool) SystemSettingHelper::get('maintenance.allow_moderators', false);
            }
        } catch (\Throwable $e) {
            // fail-closed
            $allowAdmins = false;
            $allowModerators = false;
        }

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
            if (Schema::hasTable('system_settings') && (bool) SystemSettingHelper::get('debug.break_glass', false)) {
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

        // Public allowlist during maintenance (public essentials + login/logout + health + break-glass)
        if (
            $request->is('/') ||
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
            if (auth()->check() && !$isAllowedDuringMaintenance((string) auth()->user()->role) && !$isNoteinstieg && !$isLogout) {
                return redirect($maintenanceRedirectUrl);
            }

            // Special case: POST /login is allowed, but only whitelisted roles may attempt to log in.
            // Others get redirected to the maintenance home BEFORE the auth flow can produce "auth.failed".
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

                if (!$user || !$isAllowedDuringMaintenance((string) $user->role)) {
                    return redirect($maintenanceRedirectUrl);
                }

                return $next($request);
            }

            return $next($request);
        }

        // Everything else: redirect to maintenance landing.
        return redirect($maintenanceRedirectUrl);
    }
}