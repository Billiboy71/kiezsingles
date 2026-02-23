<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_13_000000_create_ticket_audit_logs_table.php
// Purpose: Ticket audit log table for event-based tracking (created/replied/closed).
// Changed: 13-02-2026 00:02 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ticket_audit_logs', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('ticket_id')->index();
            $table->string('event', 32)->index(); // created|replied|closed
            $table->string('actor_type', 16)->index(); // user|admin
            $table->unsignedBigInteger('actor_user_id')->nullable()->index();

            $table->json('meta')->nullable();

            $table->timestamp('created_at')->useCurrent();

            $table->foreign('ticket_id')
                ->references('id')
                ->on('tickets')
                ->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ticket_audit_logs');
    }
};
