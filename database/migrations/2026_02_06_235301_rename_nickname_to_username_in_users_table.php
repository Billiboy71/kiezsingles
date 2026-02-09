<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_06_235301_rename_nickname_to_username_in_users_table.php
// Purpose: Rename users.nickname to users.username (preserve unique index)
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // drop unique index on nickname
            $table->dropUnique(['nickname']);
        });

        Schema::table('users', function (Blueprint $table) {
            // rename column nickname -> username
            $table->renameColumn('nickname', 'username');
        });

        Schema::table('users', function (Blueprint $table) {
            // add unique index on username
            $table->unique('username');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // drop unique index on username
            $table->dropUnique(['username']);
        });

        Schema::table('users', function (Blueprint $table) {
            // rename column username -> nickname
            $table->renameColumn('username', 'nickname');
        });

        Schema::table('users', function (Blueprint $table) {
            // re-add unique index on nickname
            $table->unique('nickname');
        });
    }
};
