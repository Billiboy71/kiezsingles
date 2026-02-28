<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_28_145200_drop_role_from_users_table.php
// Purpose: Remove obsolete users.role column after Spatie role migration
// Created: 28-02-2026 14:49 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('users') || !Schema::hasColumn('users', 'role')) {
            return;
        }

        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn('role');
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('users') || Schema::hasColumn('users', 'role')) {
            return;
        }

        Schema::table('users', function (Blueprint $table): void {
            $table->string('role')->default('user')->after('email');
        });
    }
};