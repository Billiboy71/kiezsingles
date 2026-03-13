<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_09_041500_create_security_allowlist_entries_table.php
// Purpose: Create security_allowlist_entries table for central autoban exclusions
// Created: 09-03-2026 (Europe/Berlin)
// Changed: 09-03-2026 04:14 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('security_allowlist_entries', function (Blueprint $table): void {
            $table->id();
            $table->string('type', 32);
            $table->string('value', 255);
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->boolean('autoban_only')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['type', 'value']);
            $table->index(['type', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('security_allowlist_entries');
    }
};
