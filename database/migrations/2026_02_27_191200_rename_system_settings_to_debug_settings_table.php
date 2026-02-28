<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_27_191200_rename_settings_table.php
// Purpose: Rename debug settings table.
// Changed: 27-02-2026 19:15 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $fromTable = 'system' . '_settings';

        if (Schema::hasTable($fromTable) && !Schema::hasTable('debug_settings')) {
            Schema::rename($fromTable, 'debug_settings');
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('debug_settings') && !Schema::hasTable('system_settings')) {
            Schema::rename('debug_settings', 'system_settings');
        }
    }
};
