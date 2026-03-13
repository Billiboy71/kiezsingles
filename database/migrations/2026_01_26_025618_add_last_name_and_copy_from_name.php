<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_01_26_025618_add_last_name_and_copy_from_name.php
// Purpose: Transitional migration to copy legacy users.name into users.last_name safely
// Changed: 09-03-2026 15:05 (Europe/Berlin)
// Version: 1.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('users')) {
            return;
        }

        $hasName = Schema::hasColumn('users', 'name');
        $hasLastName = Schema::hasColumn('users', 'last_name');

        if (! $hasLastName) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('last_name', 100)->after('id');
            });

            $hasLastName = true;
        }

        if ($hasName && $hasLastName) {
            DB::table('users')->update([
                'last_name' => DB::raw('name'),
            ]);
        }

        if ($hasName) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('name');
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

        if (! $hasName) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('name', 255)->after('id');
            });

            $hasName = true;
        }

        if ($hasName && $hasLastName) {
            DB::table('users')->update([
                'name' => DB::raw('last_name'),
            ]);
        }

        if ($hasLastName) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('last_name');
            });
        }
    }
};