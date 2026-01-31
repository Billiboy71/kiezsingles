<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Providers\EventServiceProvider.php
// Purpose: Register event listeners (incl. optional IP logging)
// ============================================================================

namespace App\Providers;

use Illuminate\Auth\Events\Failed;
use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Auth\Events\Registered;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;

class EventServiceProvider extends ServiceProvider
{
    public function boot(): void
{
    logger()->warning('ESP BOOT HIT', [
        'pid' => getmypid(),
        'ts'  => now()->toDateTimeString(),
        'bt'  => collect(debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 8))
            ->pluck('file')
            ->filter()
            ->values()
            ->all(),
    ]);

    parent::boot();
}
    protected $listen = [
        Registered::class => [
            \App\Listeners\DebugRegisteredEvent::class,
            \App\Listeners\LogRegistrationIp::class,
        ],

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

    /**
     * IMPORTANT:
     * We register listeners explicitly via $listen.
     * Disable event discovery to prevent duplicate listener registration
     * (e.g. DebugRegisteredEvent + DebugRegisteredEvent@handle).
     */
    public function shouldDiscoverEvents(): bool
    {
        return false;
    }
}
