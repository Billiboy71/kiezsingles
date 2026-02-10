<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_09_000002_create_noteinstieg_recovery_codes_table.php
// Purpose: Persistent Noteinstieg recovery codes (hash-only, one-time use) with
//          audit metadata (used_ip, used_user_agent).
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('noteinstieg_recovery_codes', function (Blueprint $table) {
            $table->id();

            // SHA-256 hex (64 chars). Stored as hash only (no plaintext).
            $table->string('hash', 64)->unique();

            // One-time use marker (NULL = unused).
            $table->dateTime('used_at')->nullable();

            // Audit metadata on successful use.
            $table->string('used_ip', 45)->nullable();       // IPv4/IPv6
            $table->text('used_user_agent')->nullable();     // can be longer than 255

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('noteinstieg_recovery_codes');
    }
};
