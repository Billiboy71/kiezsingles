<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\bootstrap\app.php
// Purpose: Application bootstrap & middleware registration
// Changed: 22-02-2026 15:34 (Europe/Berlin)
// Version: 1.3
// ============================================================================

use App\Http\Middleware\MaintenanceMode;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

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
    })->create();