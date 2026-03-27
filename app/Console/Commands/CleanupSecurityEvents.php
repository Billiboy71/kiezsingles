<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Console\Commands\CleanupSecurityEvents.php
// Purpose: Delete old SecurityEvent records based on security config retention
// Changed: 25-03-2026 00:07 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class CleanupSecurityEvents extends Command
{
    protected $signature = 'security:cleanup-events {--days= : Override retention days (integer)}';

    protected $description = 'Delete old security events with 30-day retention and cleanup orphan incident relations.';

    public function handle(): int
    {
        $days = $this->option('days');
        $days = is_numeric($days) ? (int) $days : 30;

        if ($days <= 0) {
            $this->error('Retention days invalid. Use --days with a value greater than zero.');
            return self::FAILURE;
        }

        if (!Schema::hasTable('security_events')) {
            $this->info('Skipping cleanup: security_events table does not exist.');
            return self::SUCCESS;
        }

        $cutoff = now()->subDays($days);

        $deleted = DB::table('security_events')
            ->where('created_at', '<', $cutoff)
            ->delete();

        $orphanedRelationsDeleted = 0;

        if (Schema::hasTable('security_incident_events')) {
            $orphanedRelationsDeleted = DB::table('security_incident_events')
                ->whereNotIn('security_event_id', function ($query) {
                    $query->select('id')->from('security_events');
                })
                ->delete();
        }

        $this->info("Deleted {$deleted} security events older than {$days} day(s) (before {$cutoff->toDateTimeString()}).");
        $this->info("Deleted {$orphanedRelationsDeleted} orphan security incident event relation(s).");

        return self::SUCCESS;
    }
}
