<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureSessionIntegrity.php
// Purpose: Invalidate authenticated sessions when the client IP changes
// Created: 16-03-2026 (Europe/Berlin)
// Changed: 16-03-2026 23:09 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class EnsureSessionIntegrity
{
    public function handle(Request $request, Closure $next): Response
    {
        if (!Auth::guard('web')->check()) {
            return $next($request);
        }

        if (!$request->hasSession()) {
            return $next($request);
        }

        $currentIp = trim((string) ($request->ip() ?? ''));
        $sessionIp = trim((string) $request->session()->get('session_login_ip', ''));

        if ($sessionIp === '') {
            $request->session()->put('session_login_ip', $currentIp);

            return $next($request);
        }

        if ($currentIp === '' || hash_equals($sessionIp, $currentIp)) {
            return $next($request);
        }

        Auth::guard('web')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
