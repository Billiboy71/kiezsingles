<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\seeders\SystemSettingsSeeder.php
// Purpose: Ensure required debug_settings keys exist with safe defaults (fail-closed)
// Changed: 27-02-2026 19:15 (Europe/Berlin)
// Version: 0.3
// ============================================================================

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class SystemSettingsSeeder extends Seeder
{
    public function run(): void
    {
        if (!Schema::hasTable('debug_settings')) {
            return;
        }

        $hasCreatedAt = Schema::hasColumn('debug_settings', 'created_at');
        $hasUpdatedAt = Schema::hasColumn('debug_settings', 'updated_at');

        $now = now();

        $defaults = [];

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

            DB::table('debug_settings')->updateOrInsert(
                ['key' => (string) $key],
                array_merge($insert, $update)
            );
        }
    }
}
