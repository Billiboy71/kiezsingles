<?php

// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Console\Commands\KsAuditSuperadminCommand.php
// Purpose: Deterministic audit command: superadmin/admin/moderator counts (JSON) for admin-audit tool
// Created: 21-02-2026 00:35 (Europe/Berlin)
// Changed: 28-02-2026 14:49 (Europe/Berlin)
// Version: 0.4
// ============================================================================

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;

class KsAuditSuperadminCommand extends Command
{
    /**
     * Deterministic governance counts (no tinker).
     *
     * Output (JSON):
     *  { "ok": <bool>, "superadmins": <int>, "admins": <int>, "moderators": <int> }
     *
     * Exit codes:
     *  0 => OK (>=1 superadmin)
     *  3 => CRITICAL (0 superadmins)
     *  2 => FAIL (unexpected error)
     */
    protected $signature = 'ks:audit:superadmin {--json : Output JSON only}';

    protected $description = 'Deterministic audit: count superadmins/admins/moderators (JSON for admin audit tool)';

    public function handle(): int
    {
        try {
            $superadmins = (int) User::query()
                ->role('superadmin')
                ->count();

            $admins = (int) User::query()
                ->role('admin')
                ->count();

            $moderators = (int) User::query()
                ->role('moderator')
                ->count();

            $payload = [
                'ok'         => true,
                'superadmins' => $superadmins,
                'admins'      => $admins,
                'moderators'  => $moderators,
            ];

            if ($this->option('json')) {
                // IMPORTANT: Only JSON on stdout (deterministic parsing).
                $this->line((string) json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
            } else {
                $this->info('superadmins=' . $superadmins);
                $this->info('admins=' . $admins);
                $this->info('moderators=' . $moderators);
            }

            if ($superadmins <= 0) {
                return 3; // CRITICAL
            }

            return 0;
        } catch (\Throwable $e) {
            if ($this->option('json')) {
                $payload = [
                    'ok'         => false,
                    'superadmins' => null,
                    'admins'      => null,
                    'moderators'  => null,
                    'error'       => $e->getMessage(),
                    'error_class' => get_class($e),
                ];
                $this->line((string) json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
            } else {
                $this->error('Error: ' . $e->getMessage());
            }

            return 2;
        }
    }
}
