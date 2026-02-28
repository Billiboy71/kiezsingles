<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_27_1845_create_maintenance_settings_table.php
// Purpose: Create maintenance_settings as maintenance SSOT with legacy backfill
// Created: 27-02-2026 18:44 (Europe/Berlin)
// Changed: 27-02-2026 19:15 (Europe/Berlin)
// Version: 0.2
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('maintenance_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('enabled')->default(false);
            $table->boolean('show_eta')->default(false);
            $table->dateTime('eta_at')->nullable();
            $table->boolean('notify_enabled')->default(false);
            $table->boolean('allow_admins')->default(false);
            $table->boolean('allow_moderators')->default(false);
            $table->timestamps();
        });

        $toBool = static function ($value): int {
            if (is_bool($value)) {
                return $value ? 1 : 0;
            }

            if (is_int($value)) {
                return $value === 1 ? 1 : 0;
            }

            $stringValue = trim((string) $value);
            if ($stringValue === '1') {
                return 1;
            }

            return mb_strtolower($stringValue) === 'true' ? 1 : 0;
        };

        $row = [
            'enabled' => 0,
            'show_eta' => 0,
            'eta_at' => null,
            'notify_enabled' => 0,
            'allow_admins' => 0,
            'allow_moderators' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ];

        try {
            if (Schema::hasTable('app_settings')) {
                $legacyAppRow = DB::table('app_settings')
                    ->orderBy('id', 'asc')
                    ->first();

                if ($legacyAppRow) {
                    $row['enabled'] = $toBool($legacyAppRow->maintenance_enabled ?? 0);
                    $row['show_eta'] = $toBool($legacyAppRow->maintenance_show_eta ?? 0);
                    $row['eta_at'] = $legacyAppRow->maintenance_eta_at ?? null;
                }
            }

            if (Schema::hasTable('debug_settings')) {
                $legacySystem = DB::table('debug_settings')
                    ->whereIn('key', [
                        'maintenance.notify_enabled',
                        'maintenance.allow_admins',
                        'maintenance.allow_moderators',
                    ])
                    ->pluck('value', 'key')
                    ->all();

                if (array_key_exists('maintenance.notify_enabled', $legacySystem)) {
                    $row['notify_enabled'] = $toBool($legacySystem['maintenance.notify_enabled']);
                }
                if (array_key_exists('maintenance.allow_admins', $legacySystem)) {
                    $row['allow_admins'] = $toBool($legacySystem['maintenance.allow_admins']);
                }
                if (array_key_exists('maintenance.allow_moderators', $legacySystem)) {
                    $row['allow_moderators'] = $toBool($legacySystem['maintenance.allow_moderators']);
                }
            }
        } catch (\Throwable $e) {
            // fail-closed defaults are already set in $row
        }

        DB::table('maintenance_settings')->insert($row);
    }

    public function down(): void
    {
        Schema::dropIfExists('maintenance_settings');
    }
};
