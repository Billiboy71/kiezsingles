<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_16_221800_add_moderator_sections_to_users_table.php
// Purpose: Add per-user moderator section whitelist to users table (JSON, nullable).
// Changed: 16-02-2026 22:18 (Europe/Berlin)
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
            // Per-user whitelist for moderator backend sections (e.g. ["overview","tickets"])
            $table->json('moderator_sections')->nullable()->after('role');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('moderator_sections');
        });
    }
};
