<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Providers\EventServiceProvider.php
// Purpose: Register event listeners (incl. optional IP logging)
// Changed: 12-02-2026 23:56 (Europe/Berlin)
// Version: 0.3
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

        // =========================================================================
        // Ticket Domain Events (Core)
        // =========================================================================

        \App\Events\TicketCreated::class => [
            \App\Listeners\HandleTicketCreated::class,
        ],

        \App\Events\TicketReplied::class => [
            \App\Listeners\HandleTicketReplied::class,
        ],

        \App\Events\TicketClosed::class => [
            \App\Listeners\HandleTicketClosed::class,
        ],

        // =========================================================================
        // Ticket Domain Events (B3 – Admin Management)
        // =========================================================================

        \App\Events\TicketAssignedAdmin::class => [
            \App\Listeners\HandleTicketAssignedAdmin::class,
        ],

        \App\Events\TicketCategoryChanged::class => [
            \App\Listeners\HandleTicketCategoryChanged::class,
        ],

        \App\Events\TicketPriorityChanged::class => [
            \App\Listeners\HandleTicketPriorityChanged::class,
        ],

        \App\Events\TicketStatusChanged::class => [
            \App\Listeners\HandleTicketStatusChanged::class,
        ],

        // =========================================================================
        // Ticket Domain Events (B4 – Moderation)
        // =========================================================================

        \App\Events\TicketReportUserWarned::class => [
            \App\Listeners\HandleTicketReportUserWarned::class,
        ],

        \App\Events\TicketReportUserTemporarilyBanned::class => [
            \App\Listeners\HandleTicketReportUserTemporarilyBanned::class,
        ],

        \App\Events\TicketReportUserPermanentlyBanned::class => [
            \App\Listeners\HandleTicketReportUserPermanentlyBanned::class,
        ],

        \App\Events\TicketReportMarkedUnfounded::class => [
            \App\Listeners\HandleTicketReportMarkedUnfounded::class,
        ],
    ];

    public function shouldDiscoverEvents(): bool
    {
        return false;
    }
}
