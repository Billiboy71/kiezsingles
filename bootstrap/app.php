<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\bootstrap\app.php
// Purpose: Application bootstrap & middleware registration
// Changed: 25-02-2026 12:25 (Europe/Berlin)
// Version: 1.4
// ============================================================================

use App\Http\Middleware\MaintenanceMode;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Support\Facades\Blade;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withCommands([
        __DIR__.'/../app/Console/Commands',
    ])
    ->withMiddleware(function (Middleware $middleware): void {
        // IMPORTANT: Maintenance must run inside the "web" group (session available).
        // Do NOT register it as global middleware.
        $middleware->web(append: [
            MaintenanceMode::class,
        ]);

        // Route middleware aliases (Laravel 11/12 bootstrap registration).
        $middleware->alias([
            // Superadmin-only
            'superadmin' => \App\Http\Middleware\EnsureSuperadmin::class,

            // Staff: admin + superadmin + moderator
            'staff' => \App\Http\Middleware\EnsureStaff::class,

            // Backend sections (admin full; moderator via DB whitelist)
            'section' => \App\Http\Middleware\EnsureSectionAccess::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Fail-closed bei DB-Verbindungsproblemen: alles sperren (503) statt "durchlassen".
        $exceptions->renderable(function (\Throwable $e, $request) {
            // Health-Endpoint nicht beeinflussen
            try {
                if (method_exists($request, 'path') && $request->path() === 'up') {
                    return null;
                }
            } catch (\Throwable $ignore) {
                // bewusst ignorieren
            }

            $isDbError =
                $e instanceof \PDOException
                || $e instanceof \Illuminate\Database\QueryException
                || $e instanceof \Illuminate\Database\ConnectionException;

            if (!$isDbError) {
                return null;
            }

            // Correlation-ID für Diagnose (Response: nur ID; Details ins Log)
            $errId = null;
            try {
                $errId = 'KS-DB-'.strtoupper(bin2hex(random_bytes(3)));
            } catch (\Throwable $ignore) {
                $errId = 'KS-DB-'.strtoupper(dechex((int) (microtime(true) * 1000000) & 0xFFFFFF));
            }

            $path = null;
            $routeName = null;
            try {
                if (method_exists($request, 'path')) {
                    $path = $request->path();
                }
            } catch (\Throwable $ignore) {
                // bewusst ignorieren
            }
            try {
                if (method_exists($request, 'route')) {
                    $route = $request->route();
                    if ($route && method_exists($route, 'getName')) {
                        $routeName = $route->getName();
                    }
                }
            } catch (\Throwable $ignore) {
                // bewusst ignorieren
            }

            try {
                if (function_exists('logger')) {
                    logger()->error('KS fail-closed DB exception', [
                        'ks_err_id' => $errId,
                        'exception' => get_class($e),
                        'message' => $e->getMessage(),
                        'path' => $path,
                        'route' => $routeName,
                    ]);
                } else {
                    @error_log('KS fail-closed DB exception: '.$errId.' '.get_class($e).' path='.($path ?? '').' route='.($routeName ?? '').' msg='.$e->getMessage());
                }
            } catch (\Throwable $ignore) {
                // bewusst ignorieren
            }

            $isLocal = false;
            try {
                if (function_exists('app')) {
                    $isLocal = app()->environment('local');
                }
            } catch (\Throwable $ignore) {
                $isLocal = false;
            }

            $extraHeaders = [];
            if ($isLocal) {
                $extraHeaders = [
                    'X-KS-Err-Type' => get_class($e),
                    'X-KS-Path' => (string) ($path ?? ''),
                ];
            }

            // JSON/Fetch clients
            try {
                if (method_exists($request, 'expectsJson') && $request->expectsJson()) {
                    $resp = response()->json(['ok' => false, 'message' => 'Service unavailable'], 503);
                    $resp->headers->set('X-KS-Err-Id', $errId);
                    foreach ($extraHeaders as $k => $v) {
                        $resp->headers->set($k, $v);
                    }
                    return $resp;
                }
            } catch (\Throwable $ignore) {
                // bewusst ignorieren
            }

            // HTML clients: bevorzugt eigene 503 View, sonst plain text
            try {
                if (function_exists('view') && view()->exists('errors.503')) {
                    $resp = response()->view('errors.503', ['ksErrId' => $errId], 503);
                    $resp->headers->set('X-KS-Err-Id', $errId);
                    foreach ($extraHeaders as $k => $v) {
                        $resp->headers->set($k, $v);
                    }
                    return $resp;
                }
            } catch (\Throwable $ignore) {
                // bewusst ignorieren
            }

            $resp = response('Service unavailable', 503);
            $resp->headers->set('X-KS-Err-Id', $errId);
            foreach ($extraHeaders as $k => $v) {
                $resp->headers->set($k, $v);
            }
            return $resp;
        });

        // Admin-Layout für "Forbidden" (403) statt Default-Errorseite.
        $exceptions->renderable(function (\Throwable $e, $request) {
            $status = null;

            try {
                if ($e instanceof \Symfony\Component\HttpKernel\Exception\HttpExceptionInterface) {
                    $status = (int) $e->getStatusCode();
                } elseif ($e instanceof \Illuminate\Auth\Access\AuthorizationException) {
                    $status = 403;
                }
            } catch (\Throwable $ignore) {
                $status = null;
            }

            if ($status !== 403) {
                return null;
            }

            // JSON/Fetch clients
            try {
                if (method_exists($request, 'expectsJson') && $request->expectsJson()) {
                    return response()->json(['ok' => false, 'message' => 'Forbidden'], 403);
                }
            } catch (\Throwable $ignore) {
                // bewusst ignorieren
            }

            // Nur Admin-URLs im Admin-Layout rendern
            $isAdminPath = false;
            try {
                if (method_exists($request, 'path')) {
                    $p = (string) $request->path();
                    $isAdminPath = ($p === 'admin') || str_starts_with($p, 'admin/');
                }
            } catch (\Throwable $ignore) {
                $isAdminPath = false;
            }

            if (!$isAdminPath) {
                return null;
            }

            // Wenn Admin-Layout nicht existiert, nichts überschreiben (Default-Handler)
            try {
                if (!function_exists('view') || !view()->exists('admin.layouts.admin')) {
                    return null;
                }
            } catch (\Throwable $ignore) {
                return null;
            }

            $module = null;
            try {
                if (method_exists($request, 'segment')) {
                    $module = (string) ($request->segment(2) ?? '');
                }
            } catch (\Throwable $ignore) {
                $module = null;
            }

            $title = 'Kein Zugriff';
            $subtitle = null;
            if (!empty($module)) {
                $subtitle = 'Modul: '.$module;
            }

            $tpl = <<<'BLADE'
@extends('admin.layouts.admin')

@section('content')
    <div class="space-y-4">
        <div class="rounded-xl border border-red-200 bg-red-50 p-4">
            <div class="text-base font-semibold text-red-900">
                Kein Zugriff auf dieses Modul.
            </div>
            @if(!empty($subtitle))
                <div class="mt-1 text-sm text-red-800">
                    {{ $subtitle }}
                </div>
            @endif
        </div>

        <div>
            <a href="{{ url('/admin') }}" class="inline-flex items-center rounded-lg border px-3 py-2 text-sm font-medium">
                Zurück zur Übersicht
            </a>
        </div>
    </div>
@endsection
BLADE;

            try {
                $html = Blade::render($tpl, [
                    'adminTitle' => $title,
                    'adminSubtitle' => null,
                    'subtitle' => $subtitle,
                ]);

                return response($html, 403);
            } catch (\Throwable $ignore) {
                return null;
            }
        });
    })->create();