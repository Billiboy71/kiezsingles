<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Providers\EventServiceProvider.php
// Purpose: Register event listeners (incl. optional IP logging)
// ============================================================================

namespace App\Providers;

use Illuminate\Auth\Events\Failed;
use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;

class EventServiceProvider extends ServiceProvider
{
    protected $listen = [
        Login::class => [
            \App\Listeners\LogLoginSuccess::class,
            \App\Listeners\LogLoginIp::class,
        ],

        Failed::class => [
            \App\Listeners\LogLoginFailed::class,
        ],

        PasswordReset::class => [
            \App\Listeners\LogPasswordResetCompleted::class,
        ],
    ];

    public function shouldDiscoverEvents(): bool
    {
        return false;
    }
}
