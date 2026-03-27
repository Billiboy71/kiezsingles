<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_24_002400_create_security_incident_actions_table.php
// Purpose: Create append-only action history table for security incident admin actions.
// Created: 24-03-2026 00:24 (Europe/Berlin)
// Changed: 24-03-2026 00:24 (Europe/Berlin)
// Version: 1.0
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('security_incident_actions')) {
            Schema::create('security_incident_actions', function (Blueprint $table): void {
                $table->id();
                $table->unsignedBigInteger('incident_id');
                $table->unsignedBigInteger('user_id')->nullable();
                $table->string('action');
                $table->string('old_status')->nullable();
                $table->string('new_status')->nullable();
                $table->timestamps();
                $table->index('incident_id');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('security_incident_actions')) {
            Schema::dropIfExists('security_incident_actions');
        }
    }
};
