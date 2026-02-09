<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_08_000000_create_system_settings_table.php
// Changed: 08-02-2026 00:41
// Purpose: DB-backed system settings (e.g., admin-toggleable debug flags)
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('system_settings', function (Blueprint $table) {
            $table->id();

            // Setting key, e.g. "debug.register_payload", "debug.captcha"
            $table->string('key', 191)->unique();

            // Raw value, stored as text (for booleans use "0"/"1")
            $table->text('value')->nullable();

            // Optional metadata for admin UI grouping / casting later
            $table->string('group', 50)->nullable();   // e.g. "debug", "features"
            $table->string('cast', 20)->nullable();    // e.g. "bool", "string", "int"

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('system_settings');
    }
};
