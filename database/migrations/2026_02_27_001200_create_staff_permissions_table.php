<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_27_001200_create_staff_permissions_table.php
// Purpose: Create staff_permissions SSOT table for per-user backend module access.
// Changed: 27-02-2026 00:18 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('staff_permissions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('module_key', 64);
            $table->boolean('allowed')->default(false);
            $table->timestamps();

            $table->unique(['user_id', 'module_key']);
            $table->index(['module_key', 'allowed']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('staff_permissions');
    }
};