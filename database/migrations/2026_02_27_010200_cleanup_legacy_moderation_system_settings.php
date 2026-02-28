<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_27_010200_cleanup_legacy_moderation_debug_settings.php
// Purpose: Remove legacy moderation.* keys from debug_settings after staff_permissions SSOT migration.
// Changed: 27-02-2026 19:15 (Europe/Berlin)
// Version: 0.2
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('debug_settings')) {
            return;
        }

        DB::table('debug_settings')
            ->where('key', 'like', 'moderation.%')
            ->delete();
    }

    public function down(): void
    {
        // No-op: deleted legacy settings cannot be reconstructed safely.
    }
};
