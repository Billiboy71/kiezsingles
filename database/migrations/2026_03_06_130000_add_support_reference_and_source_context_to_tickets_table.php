<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_06_130000_add_support_reference_and_source_context_to_tickets_table.php
// Purpose: Add optional support reference/context fields to tickets.
// Created: 06-03-2026 (Europe/Berlin)
// Changed: 06-03-2026 13:00 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tickets', function (Blueprint $table) {
            $table->string('support_reference', 32)->nullable()->after('message');
            $table->string('source_context', 64)->nullable()->after('support_reference');
        });
    }

    public function down(): void
    {
        Schema::table('tickets', function (Blueprint $table) {
            $table->dropColumn(['support_reference', 'source_context']);
        });
    }
};
