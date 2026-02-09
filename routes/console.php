<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\console.php
// Purpose: Console commands & scheduled tasks (Laravel 12)
// ============================================================================

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// ---------------------------------------------------------------------------
// Security: Retention / Cleanup
// ---------------------------------------------------------------------------

Schedule::command('security:cleanup-events')
    ->dailyAt('03:00');
