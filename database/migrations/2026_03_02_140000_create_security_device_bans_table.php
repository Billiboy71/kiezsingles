<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_02_140000_create_security_device_bans_table.php
// Purpose: Create security_device_bans table for device-based blocking
// Created: 02-03-2026 (Europe/Berlin)
// Changed: 02-03-2026 14:00 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('security_device_bans', function (Blueprint $table): void {
            $table->id();
            $table->string('device_hash', 64);
            $table->text('reason')->nullable();
            $table->dateTime('banned_until')->nullable();
            $table->dateTime('revoked_at')->nullable();
            $table->boolean('is_active')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index('device_hash');
            $table->index('banned_until');
            $table->index('revoked_at');
            $table->index('is_active');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('security_device_bans');
    }
};
