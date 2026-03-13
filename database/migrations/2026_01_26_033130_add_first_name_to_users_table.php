<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_01_26_033130_add_first_name_to_users_table.php
// Purpose: Add first_name to users table
// Changed: 09-03-2026 15:22 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('users')) {
            return;
        }

        if (!Schema::hasColumn('users', 'first_name')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('first_name', 100)->after('id');
            });
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('users')) {
            return;
        }

        if (Schema::hasColumn('users', 'first_name')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('first_name');
            });
        }
    }
};