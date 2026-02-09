<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_05_000002_make_public_id_not_nullable_on_users_table.php
// Purpose: Enforce NOT NULL constraint on users.public_id after backfill
// ============================================================================
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('public_id', 32)->nullable(false)->change();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('public_id', 32)->nullable()->change();
        });
    }
};
