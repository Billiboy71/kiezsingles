<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_01_220000_create_security_settings_table.php
// Purpose: Create security_settings SSOT table
// Changed: 02-03-2026 01:43 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('security_settings', function (Blueprint $table): void {
            $table->id();
            $table->unsignedInteger('login_attempt_limit')->default(8);
            $table->unsignedInteger('lockout_seconds')->default(900);
            $table->boolean('ip_autoban_enabled')->default(false);
            $table->unsignedInteger('ip_autoban_fail_threshold')->default(100);
            $table->unsignedInteger('ip_autoban_seconds')->default(3600);
            $table->boolean('admin_stricter_limits_enabled')->default(true);
            $table->boolean('stepup_required_enabled')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('security_settings');
    }
};
