<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_09_013500_add_case_key_to_tickets_table.php
// Purpose: Add optional case key field to tickets for security support correlation.
// Created: 09-03-2026 (Europe/Berlin)
// Changed: 09-03-2026 01:34 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn('tickets', 'case_key')) {
            Schema::table('tickets', function (Blueprint $table) {
                $table->string('case_key', 128)->nullable()->after('source_context');
                $table->index('case_key', 'tickets_case_key_idx');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('tickets', 'case_key')) {
            Schema::table('tickets', function (Blueprint $table) {
                $table->dropIndex('tickets_case_key_idx');
                $table->dropColumn('case_key');
            });
        }
    }
};
