<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_06_000001_create_app_settings_table.php
// Purpose: Application-wide settings (maintenance mode + display-only ETA)
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('app_settings', function (Blueprint $table) {
            $table->id();

            // Wartungsmodus: EIN/AUS (einzige Logik-Quelle)
            $table->boolean('maintenance_enabled')->default(false);

            // Reine Anzeige: Datum/Uhrzeit "voraussichtlich bis"
            $table->dateTime('maintenance_eta_at')->nullable();

            // Reine Anzeige: ETA anzeigen ja/nein
            $table->boolean('maintenance_show_eta')->default(false);

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_settings');
    }
};
