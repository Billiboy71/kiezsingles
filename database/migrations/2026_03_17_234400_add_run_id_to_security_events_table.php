<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_17_234400_add_run_id_to_security_events_table.php
// Purpose: Add run_id isolation field to security_events for deterministic audit runs.
// Created: 17-03-2026 (Europe/Berlin)
// Changed: 17-03-2026 23:44 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('security_events')) {
            return;
        }

        if (!Schema::hasColumn('security_events', 'run_id')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->string('run_id', 64)->default('')->after('reference');
            });
        }

        DB::table('security_events')
            ->whereNull('run_id')
            ->update([
                'run_id' => '',
            ]);

        if (!Schema::hasIndex('security_events', 'security_events_run_id_idx')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->index('run_id', 'security_events_run_id_idx');
            });
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('security_events')) {
            return;
        }

        if (Schema::hasIndex('security_events', 'security_events_run_id_idx')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->dropIndex('security_events_run_id_idx');
            });
        }

        if (Schema::hasColumn('security_events', 'run_id')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->dropColumn('run_id');
            });
        }
    }
};
