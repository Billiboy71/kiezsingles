<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_17_012345_add_reference_to_security_events_table.php
// Purpose: Add unique SEC incident references directly to security_events.
// Created: 17-03-2026 (Europe/Berlin)
// Changed: 17-03-2026 01:23 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('security_events')) {
            return;
        }

        if (!Schema::hasColumn('security_events', 'reference')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->string('reference', 32)->nullable()->after('id');
            });
        }

        if (!Schema::hasIndex('security_events', 'security_events_reference_unique', 'unique')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->unique('reference', 'security_events_reference_unique');
            });
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('security_events')) {
            return;
        }

        if (Schema::hasIndex('security_events', 'security_events_reference_unique', 'unique')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->dropUnique('security_events_reference_unique');
            });
        }

        if (Schema::hasColumn('security_events', 'reference')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->dropColumn('reference');
            });
        }
    }
};
