<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_11_230000_create_tickets_table.php
// Purpose: Unified ticket system (user reports + support requests).
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tickets', function (Blueprint $table) {
            $table->id();

            // Public ID (non-enumerable reference for URLs)
            $table->string('public_id', 36)->unique();

            // Type: report | support
            $table->string('type', 20);

            // Status: open | in_progress | closed
            $table->string('status', 20)->default('open');

            // Optional classification
            $table->string('category', 50)->nullable();
            $table->integer('priority')->nullable();

            // Main content
            $table->string('subject', 191)->nullable();
            $table->text('message')->nullable();

            // Relations
            $table->unsignedBigInteger('created_by_user_id');
            $table->unsignedBigInteger('reported_user_id')->nullable();
            $table->unsignedBigInteger('assigned_admin_user_id')->nullable();

            // Closed timestamp
            $table->timestamp('closed_at')->nullable();

            $table->timestamps();

            // Optional indexes (no FK constraints yet – controlled layer first)
            $table->index('type');
            $table->index('status');
            $table->index('created_by_user_id');
            $table->index('reported_user_id');
            $table->index('assigned_admin_user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tickets');
    }
};
