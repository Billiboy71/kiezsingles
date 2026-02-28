<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_28_003500_drop_app_settings_table.php
// Purpose: Remove legacy app_settings table (replaced by maintenance_settings SSOT)
// Created: 28-02-2026 00:35 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::dropIfExists('app_settings');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::create('app_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('maintenance_enabled')->default(false);
            $table->boolean('debug_routes_enabled')->default(false);
            $table->dateTime('maintenance_eta_at')->nullable();
            $table->boolean('maintenance_show_eta')->default(false);
            $table->timestamps();
        });
    }
};