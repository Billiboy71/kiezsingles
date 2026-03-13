<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_01_29_221109_drop_first_name_last_name_newsletter_from_users_table.php
// Purpose: Drop obsolete first_name, last_name and newsletter_opt_in columns from users table
// Changed: 09-03-2026 15:25 (Europe/Berlin)
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

        if (Schema::hasColumn('users', 'first_name')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('first_name');
            });
        }

        if (Schema::hasColumn('users', 'last_name')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('last_name');
            });
        }

        if (Schema::hasColumn('users', 'newsletter_opt_in')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('newsletter_opt_in');
            });
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('users')) {
            return;
        }

        if (!Schema::hasColumn('users', 'first_name')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('first_name', 100)->nullable()->after('id');
            });
        }

        if (!Schema::hasColumn('users', 'last_name')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('last_name', 100)->nullable()->after('first_name');
            });
        }

        if (!Schema::hasColumn('users', 'newsletter_opt_in')) {
            Schema::table('users', function (Blueprint $table) {
                $table->boolean('newsletter_opt_in')->default(false)->after('last_name');
            });
        }
    }
};