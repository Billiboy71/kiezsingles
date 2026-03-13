<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\bootstrap\app.php
// Purpose: Application bootstrap & middleware registration
// Changed: 12-03-2026 00:49 (Europe/Berlin)
// Version: 2.3
// ============================================================================

use App\Http\Middleware\MaintenanceMode;
use App\Http\Middleware\SetSessionLifetimeByRole;
use App\Http\Middleware\EnsureDeviceCookie;
use App\Http\Middleware\EncryptCookies;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Support\Facades\Blade;
use Symfony\Component\HttpFoundation\Request as SymfonyRequest;

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

        // Cookie encryption + device cookie must run first
        $middleware->web(prepend: [
            EncryptCookies::class,
            EnsureDeviceCookie::class,
        ]);

        // IMPORTANT: Maintenance must run inside the "web" group (session available).
        $middleware->web(append: [
            MaintenanceMode::class,
            SetSessionLifetimeByRole::class,
        ]);

        // Local-only: trust proxy headers so PowerShell tests can simulate client IP via X-Forwarded-For.
        // IMPORTANT: Do NOT enable this outside local dev (security risk).
        $isLocal = false;
        try {
            $appEnv = '';

            if (array_key_exists('APP_ENV', $_SERVER)) {
                $appEnv = trim((string) $_SERVER['APP_ENV']);
            }

            if ($appEnv === '' && array_key_exists('APP_ENV', $_ENV)) {
                $appEnv = trim((string) $_ENV['APP_ENV']);
            }

            if ($appEnv === '') {
                $envValue = getenv('APP_ENV');
                if ($envValue !== false) {
                    $appEnv = trim((string) $envValue);
                }
            }

            if ($appEnv === '') {
                $envPath = dirname(__DIR__).'/.env';
                if (is_file($envPath) && is_readable($envPath)) {
                    $envLines = @file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
                    if (is_array($envLines)) {
                        foreach ($envLines as $envLine) {
                            $envLine = trim((string) $envLine);
                            if (!str_starts_with($envLine, 'APP_ENV=')) {
                                continue;
                            }

                            $appEnv = trim((string) substr($envLine, 8), " \t\n\r\0\x0B\"'");
                            break;
                        }
                    }
                }
            }

            $isLocal = $appEnv === 'local';
        } catch (\Throwable $ignore) {
            $isLocal = false;
        }

        if ($isLocal) {
            $middleware->trustProxies(
                at: '*',
                headers: SymfonyRequest::HEADER_X_FORWARDED_FOR
                    | SymfonyRequest::HEADER_X_FORWARDED_HOST
                    | SymfonyRequest::HEADER_X_FORWARDED_PORT
                    | SymfonyRequest::HEADER_X_FORWARDED_PROTO
                    | SymfonyRequest::HEADER_X_FORWARDED_AWS_ELB
            );
        }

        $middleware->alias([
            'ensure.not.banned.ip' => \App\Http\Middleware\EnsureNotBannedIp::class,
            'ensure.admin.stepup' => \App\Http\Middleware\EnsureAdminStepUp::class,
            'superadmin' => \App\Http\Middleware\EnsureSuperadmin::class,
            'staff' => \App\Http\Middleware\EnsureStaff::class,
            'section' => \App\Http\Middleware\EnsureSectionAccess::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // (Rest unverändert)
    })->create();