<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\seeders\SystemSettingsSeeder.php
// Purpose: Ensure required system_settings keys exist with safe defaults (fail-closed)
// Changed: 16-02-2026 22:07 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class SystemSettingsSeeder extends Seeder
{
    public function run(): void
    {
        if (!Schema::hasTable('system_settings')) {
            return;
        }

        $hasCreatedAt = Schema::hasColumn('system_settings', 'created_at');
        $hasUpdatedAt = Schema::hasColumn('system_settings', 'updated_at');

        $now = now();

        $defaults = [
            // Wartungsmodus-Whitelist (fail-closed defaults)
            'maintenance.allow_admins' => '0',
            'maintenance.allow_moderators' => '0',
        ];

        foreach ($defaults as $key => $value) {
            $insert = [
                'key' => (string) $key,
                'value' => (string) $value,
            ];

            if ($hasCreatedAt) {
                $insert['created_at'] = $now;
            }
            if ($hasUpdatedAt) {
                $insert['updated_at'] = $now;
            }

            $update = [
                'value' => (string) $value,
            ];

            if ($hasUpdatedAt) {
                $update['updated_at'] = $now;
            }

            DB::table('system_settings')->updateOrInsert(
                ['key' => (string) $key],
                array_merge($insert, $update)
            );
        }
    }
}
