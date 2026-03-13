<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_06_220800_add_contact_email_to_tickets_table.php
// Purpose: Add optional contact email field for support tickets.
// Created: 06-03-2026 (Europe/Berlin)
// Changed: 06-03-2026 22:06 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn('tickets', 'contact_email')) {
            Schema::table('tickets', function (Blueprint $table) {
                $table->string('contact_email', 255)->nullable()->after('source_context');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('tickets', 'contact_email')) {
            Schema::table('tickets', function (Blueprint $table) {
                $table->dropColumn('contact_email');
            });
        }
    }
};
