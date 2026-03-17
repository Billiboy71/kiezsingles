<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_17_122600_add_reasons_to_security_events_table.php
// Purpose: Add reasons array to security_events for multi-cause incidents.
// Created: 17-03-2026 (Europe/Berlin)
// Changed: 17-03-2026 12:26 (Europe/Berlin)
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
        if (!Schema::hasTable('security_events')) {
            return;
        }

        if (!Schema::hasColumn('security_events', 'reasons')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->text('reasons')->nullable()->after('meta');
            });
        }

        DB::table('security_events')
            ->whereNull('reasons')
            ->update([
                'reasons' => '[]',
            ]);
    }

    public function down(): void
    {
        if (!Schema::hasTable('security_events')) {
            return;
        }

        if (Schema::hasColumn('security_events', 'reasons')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->dropColumn('reasons');
            });
        }
    }
};
