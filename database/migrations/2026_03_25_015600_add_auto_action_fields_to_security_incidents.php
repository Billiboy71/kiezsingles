<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_25_015600_add_auto_action_fields_to_security_incidents.php
// Purpose: Add auto action visibility fields to security_incidents
// Created: 25-03-2026 (Europe/Berlin)
// Changed: 25-03-2026 01:56 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('security_incidents')) {
            Schema::table('security_incidents', function (Blueprint $table): void {
                if (!Schema::hasColumn('security_incidents', 'auto_action_executed')) {
                    $table->boolean('auto_action_executed')->default(false)->after('action_status');
                }

                if (!Schema::hasColumn('security_incidents', 'auto_action_details')) {
                    $table->json('auto_action_details')->nullable()->after('auto_action_executed');
                }
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('security_incidents')) {
            Schema::table('security_incidents', function (Blueprint $table): void {
                if (Schema::hasColumn('security_incidents', 'auto_action_details')) {
                    $table->dropColumn('auto_action_details');
                }

                if (Schema::hasColumn('security_incidents', 'auto_action_executed')) {
                    $table->dropColumn('auto_action_executed');
                }
            });
        }
    }
};
