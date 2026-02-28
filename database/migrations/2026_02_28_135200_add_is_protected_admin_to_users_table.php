<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_28_135200_add_is_protected_admin_to_users_table.php
// Purpose: Add DB-only protected admin flag to users table
// Created: 28-02-2026 14:08 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_protected_admin')
                ->default(false)
                ->after('role')
                ->comment('DB-only flag: protected superadmin cannot be downgraded or deleted');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('is_protected_admin');
        });
    }
};