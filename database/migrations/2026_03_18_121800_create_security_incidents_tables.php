<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_18_121800_create_security_incidents_tables.php
// Purpose: Create passive incident detection tables for security correlations.
// Created: 18-03-2026 12:18 (Europe/Berlin)
// Changed: 18-03-2026 12:18 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use App\Enums\SecurityIncidentType;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('security_incidents')) {
            Schema::create('security_incidents', function (Blueprint $table): void {
                $table->id();
                $table->enum('type', SecurityIncidentType::values());
                $table->string('device_hash', 64)->nullable();
                $table->string('contact_email', 255)->nullable();
                $table->string('ip', 45)->nullable();
                $table->integer('score');
                $table->json('meta')->nullable();
                $table->timestamp('created_at')->nullable();

                $table->index(['type', 'created_at'], 'security_incidents_type_created_at_idx');
                $table->index('device_hash', 'security_incidents_device_hash_idx');
                $table->index('contact_email', 'security_incidents_contact_email_idx');
                $table->index('ip', 'security_incidents_ip_idx');
            });
        }

        if (!Schema::hasTable('security_incident_events')) {
            Schema::create('security_incident_events', function (Blueprint $table): void {
                $table->id();
                $table->foreignId('incident_id')->constrained('security_incidents')->cascadeOnDelete();
                $table->foreignId('security_event_id')->constrained('security_events')->cascadeOnDelete();

                $table->unique(['incident_id', 'security_event_id'], 'security_incident_events_unique_idx');
                $table->index('security_event_id', 'security_incident_events_event_idx');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('security_incident_events')) {
            Schema::drop('security_incident_events');
        }

        if (Schema::hasTable('security_incidents')) {
            Schema::drop('security_incidents');
        }
    }
};
