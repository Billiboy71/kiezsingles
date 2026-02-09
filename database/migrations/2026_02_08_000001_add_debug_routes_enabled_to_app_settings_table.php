<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_08_000001_add_debug_routes_enabled_to_app_settings_table.php
// Changed: 08-02-2026 00:45
// Purpose: Add backend-toggle for debug/web routes (DB-driven, no env toggle)
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('app_settings', function (Blueprint $table) {
            // Backend-Schalter für Debug-/Web-Debug-Routen
            // (Wird später zusätzlich nur wirksam, wenn maintenance_enabled = 1)
            $table->boolean('debug_routes_enabled')->default(false)->after('maintenance_enabled');
        });
    }

    public function down(): void
    {
        Schema::table('app_settings', function (Blueprint $table) {
            $table->dropColumn('debug_routes_enabled');
        });
    }
};

