<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_06_170000_create_security_support_access_tokens_table.php
// Purpose: Create one-time, short-lived server-side access tokens for security support flow.
// Created: 06-03-2026 (Europe/Berlin)
// Changed: 06-03-2026 19:25 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('security_support_access_tokens', function (Blueprint $table) {
            $table->id();
            $table->string('token_hash', 64)->unique();
            $table->string('support_reference', 32);
            $table->string('security_event_type', 32);
            $table->string('source_context', 64)->nullable();
            $table->string('case_key', 128);
            $table->timestamp('expires_at');
            $table->timestamp('consumed_at')->nullable();
            $table->timestamps();

            $table->index(['support_reference', 'security_event_type'], 'ssat_support_ref_event_idx');
            $table->index(['expires_at', 'consumed_at'], 'ssat_expiry_consumed_idx');
            $table->index('case_key', 'ssat_case_key_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('security_support_access_tokens');
    }
};
