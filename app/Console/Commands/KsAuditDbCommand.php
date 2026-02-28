<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Console\Commands\KsAuditDbCommand.php
// Purpose: Non-interactive DB sanity check for audit scripts (no tinker/psysh)
// Created: 19-02-2026 18:45 (Europe/Berlin)
// Changed: 28-02-2026 00:30 (Europe/Berlin)
// Version: 0.3
// ============================================================================

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class KsAuditDbCommand extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'ks:audit:db {--json : Output as JSON}';

    /**
     * The console command description.
     */
    protected $description = 'KiezSingles: DB sanity checks (users count, debug_settings count, maintenance_settings first row, staff_permissions count) without tinker.';

    public function handle(): int
    {
        $asJson = (bool) $this->option('json');

        $result = [
            'ok' => true,
            'checks' => [],
        ];

        // 1) Basic connectivity (cheap)
        $this->runCheck($result, 'db_connect', function () {
            DB::connection()->getPdo();
            return ['ok' => true];
        });

        // 2) users count
        $this->runCheck($result, 'users_count', function () {
            $count = DB::table('users')->count();
            return ['ok' => true, 'count' => $count];
        });

        // 3) debug_settings count (table may not exist yet)
        $this->runCheck($result, 'debug_settings_count', function () {
            if (!Schema::hasTable('debug_settings')) {
                return ['ok' => true, 'skipped' => true, 'reason' => 'table_missing'];
            }
            $count = DB::table('debug_settings')->count();
            return ['ok' => true, 'count' => $count];
        });

        // 4) maintenance_settings first row (SSOT; table may not exist yet)
        $this->runCheck($result, 'maintenance_settings_first', function () {
            if (!Schema::hasTable('maintenance_settings')) {
                return ['ok' => true, 'skipped' => true, 'reason' => 'table_missing'];
            }
            $row = DB::table('maintenance_settings')->first();
            return ['ok' => true, 'row' => $row];
        });

        // 5) staff_permissions count (table may not exist yet)
        $this->runCheck($result, 'staff_permissions_count', function () {
            if (!Schema::hasTable('staff_permissions')) {
                return ['ok' => true, 'skipped' => true, 'reason' => 'table_missing'];
            }
            $count = DB::table('staff_permissions')->count();
            return ['ok' => true, 'count' => $count];
        });

        if ($asJson) {
            $this->line(json_encode($result, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
        } else {
            $this->line('KS DB Audit: ' . ($result['ok'] ? 'OK' : 'FAIL'));
            foreach ($result['checks'] as $check) {
                $name = (string) ($check['name'] ?? '');
                $ok = (bool) ($check['ok'] ?? false);

                if (!$ok) {
                    $this->line("- {$name}: FAIL (" . ((string) ($check['error'] ?? 'unknown')) . ")");
                    continue;
                }

                if (!empty($check['skipped'])) {
                    $this->line("- {$name}: OK (skipped: " . ((string) ($check['reason'] ?? '')) . ")");
                    continue;
                }

                if (array_key_exists('count', $check)) {
                    $this->line("- {$name}: OK (count=" . ((string) $check['count']) . ")");
                    continue;
                }

                if (array_key_exists('row', $check)) {
                    $row = $check['row'];
                    if ($row === null) {
                        $this->line("- {$name}: OK (row=null)");
                    } else {
                        // Keep it compact and deterministic
                        $arr = json_decode(json_encode($row), true);
                        $this->line("- {$name}: OK (row=" . json_encode($arr, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . ")");
                    }
                    continue;
                }

                $this->line("- {$name}: OK");
            }
        }

        return $result['ok'] ? Command::SUCCESS : Command::FAILURE;
    }

    private function runCheck(array &$result, string $name, callable $fn): void
    {
        try {
            $payload = $fn();
            if (!is_array($payload)) {
                $payload = ['ok' => true];
            }

            $payload['name'] = $name;
            if (!array_key_exists('ok', $payload)) {
                $payload['ok'] = true;
            }

            $result['checks'][] = $payload;

            if (!(bool) $payload['ok']) {
                $result['ok'] = false;
            }
        } catch (\Throwable $e) {
            $result['ok'] = false;
            $result['checks'][] = [
                'name' => $name,
                'ok' => false,
                'error' => get_class($e),
                'message' => $e->getMessage(),
            ];
        }
    }
}