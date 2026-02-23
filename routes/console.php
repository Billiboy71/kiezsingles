<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\console.php
// Purpose: Console commands & scheduled tasks (Laravel 12)
// Changed: 22-02-2026 01:18 (Europe/Berlin)
// Version: 0.7
// ============================================================================

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// ---------------------------------------------------------------------------
// Governance: deterministic audit command
// IMPORTANT:
// - No closure-based ks:audit:superadmin here.
// - Command class KsAuditSuperadminCommand is auto-discovered via app/Console/Commands.
// - Ensures single source of truth and deterministic exit codes.
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Security: Retention / Cleanup
// ---------------------------------------------------------------------------

app()->booted(function () {
    /** @var \Illuminate\Console\Scheduling\Schedule $schedule */
    $schedule = app(Schedule::class);

    $schedule->command('security:cleanup-events')
        ->dailyAt('03:00');
});