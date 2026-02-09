<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_05_000000_add_public_id_to_users_table.php
// Purpose: Add users.public_id (public, non-sequential identifier) for all
//          public-facing URLs and references. Keeps users.id internal.
// Notes:   Column is nullable for now to avoid breaking existing rows.
//          Backfill + NOT NULL enforcement comes in the next step (next file).
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('public_id', 32)->nullable()->after('id');
            $table->unique('public_id');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['public_id']);
            $table->dropColumn('public_id');
        });
    }
};
