<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_01_26_024940_rename_name_to_last_name_in_users_table.php
// Purpose: Safely rename users.name to users.last_name for legacy migration paths
// Changed: 09-03-2026 15:12 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('users')) {
            return;
        }

        $hasName = Schema::hasColumn('users', 'name');
        $hasLastName = Schema::hasColumn('users', 'last_name');

        if ($hasName && ! $hasLastName) {
            Schema::table('users', function (Blueprint $table) {
                $table->renameColumn('name', 'last_name');
            });
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('users')) {
            return;
        }

        $hasName = Schema::hasColumn('users', 'name');
        $hasLastName = Schema::hasColumn('users', 'last_name');

        if (! $hasName && $hasLastName) {
            Schema::table('users', function (Blueprint $table) {
                $table->renameColumn('last_name', 'name');
            });
        }
    }
};