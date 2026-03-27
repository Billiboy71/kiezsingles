<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_23_233153_add_action_status_to_security_incidents_table.php
// Purpose: Add manual action status to security incidents for admin workflow.
// Created: 23-03-2026 23:31 (Europe/Berlin)
// Changed: 23-03-2026 23:31 (Europe/Berlin)
// Version: 1.0
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('security_incidents') && !Schema::hasColumn('security_incidents', 'action_status')) {
            Schema::table('security_incidents', function (Blueprint $table): void {
                $table->string('action_status', 32)->nullable()->after('last_seen_at');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('security_incidents') && Schema::hasColumn('security_incidents', 'action_status')) {
            Schema::table('security_incidents', function (Blueprint $table): void {
                $table->dropColumn('action_status');
            });
        }
    }
};
