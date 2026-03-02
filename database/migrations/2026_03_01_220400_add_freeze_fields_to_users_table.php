<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_01_220400_add_freeze_fields_to_users_table.php
// Purpose: Add freeze/ban marker fields to users table for security enforcement
// Changed: 02-03-2026 01:43 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            if (!Schema::hasColumn('users', 'is_frozen')) {
                $table->boolean('is_frozen')->default(false)->after('is_protected_admin');
            }

            if (!Schema::hasColumn('users', 'banned_at')) {
                $table->dateTime('banned_at')->nullable()->after('is_frozen');
            }
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            if (Schema::hasColumn('users', 'banned_at')) {
                $table->dropColumn('banned_at');
            }

            if (Schema::hasColumn('users', 'is_frozen')) {
                $table->dropColumn('is_frozen');
            }
        });
    }
};
