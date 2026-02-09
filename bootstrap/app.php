<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\bootstrap\app.php
// Purpose: Application bootstrap & middleware registration
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
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
