<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Console\Commands\CleanupSecurityEvents.php
// Purpose: Delete old SecurityEvent records based on security config retention
// ============================================================================

namespace App\Console\Commands;

use App\Models\SecurityEvent;
use Carbon\Carbon;
use Illuminate\Console\Command;

class CleanupSecurityEvents extends Command
{
    protected $signature = 'security:cleanup-events {--days= : Override retention days (integer)}';

    protected $description = 'Delete old security events based on security.ip_logging.retention_days (or --days).';

    public function handle(): int
    {
        // 1) Retention-Tage bestimmen
        $days = $this->option('days');

        if ($days === null || $days === '') {
            $days = config('security.ip_logging.retention_days');
        }

        $days = is_numeric($days) ? (int) $days : 0;

        if ($days <= 0) {
            $this->error('Retention days not set or invalid. Check security.ip_logging.retention_days or use --days=.');
            return self::FAILURE;
        }

        // 2) Cutoff berechnen
        $cutoff = Carbon::now()->subDays($days);

        // 3) Löschen
        $deleted = SecurityEvent::query()
            ->where('created_at', '<', $cutoff)
            ->delete();

        $this->info("Deleted {$deleted} security events older than {$days} day(s) (before {$cutoff->toDateTimeString()}).");

        return self::SUCCESS;
    }
}
