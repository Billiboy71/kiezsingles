<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_02_145700_add_device_autoban_to_security_settings_table.php
// Purpose: Add device autoban settings fields to security_settings SSOT
// Created: 02-03-2026 (Europe/Berlin)
// Changed: 02-03-2026 14:57 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('security_settings', function (Blueprint $table): void {
            if (!Schema::hasColumn('security_settings', 'device_autoban_enabled')) {
                $table->boolean('device_autoban_enabled')->default(false)->after('ip_autoban_seconds');
            }

            if (!Schema::hasColumn('security_settings', 'device_autoban_fail_threshold')) {
                $table->unsignedInteger('device_autoban_fail_threshold')->default(100)->after('device_autoban_enabled');
            }

            if (!Schema::hasColumn('security_settings', 'device_autoban_seconds')) {
                $table->unsignedInteger('device_autoban_seconds')->default(3600)->after('device_autoban_fail_threshold');
            }
        });
    }

    public function down(): void
    {
        Schema::table('security_settings', function (Blueprint $table): void {
            if (Schema::hasColumn('security_settings', 'device_autoban_seconds')) {
                $table->dropColumn('device_autoban_seconds');
            }

            if (Schema::hasColumn('security_settings', 'device_autoban_fail_threshold')) {
                $table->dropColumn('device_autoban_fail_threshold');
            }

            if (Schema::hasColumn('security_settings', 'device_autoban_enabled')) {
                $table->dropColumn('device_autoban_enabled');
            }
        });
    }
};
