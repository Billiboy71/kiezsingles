<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EnsureDeviceCookie.php
// Purpose: Ensure persistent ks_device_id cookie exists so device_hash stays stable
// Changed: 12-03-2026 22:43 (Europe/Berlin)
// Version: 0.6
// ============================================================================

namespace App\Http\Middleware;

use App\Services\Security\DeviceHashService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Cookie;
use Symfony\Component\HttpFoundation\Response;

class EnsureDeviceCookie
{
    public function __construct(
        private readonly DeviceHashService $deviceHashService,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $cookieName = $this->deviceHashService->cookieName();
        $incomingDeviceCookieId = (string) $request->cookie($cookieName, '');
        $hasValidDeviceCookie = $this->deviceHashService->forRequest($request) !== null;
        $deviceCookieId = $this->deviceHashService->ensureDeviceCookieId($incomingDeviceCookieId);

        // Device-Kontext schon im aktuellen Request verfügbar machen
        $request->cookies->set($cookieName, $deviceCookieId);

        // Request weiterlaufen lassen
        $response = $next($request);

        // Bereits gültiger Cookie vorhanden → nichts überschreiben
        if ($hasValidDeviceCookie) {
            return $response;
        }

        $cookie = Cookie::create(
            $cookieName,
            $deviceCookieId,
            now()->addMinutes(60 * 24 * 365 * 5),
            '/',
            null,
            false,
            true,
            false,
            'lax'
        );

        $response->headers->setCookie($cookie);

        return $response;
    }
}