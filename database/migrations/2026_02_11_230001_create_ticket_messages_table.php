<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_11_230001_create_ticket_messages_table.php
// Purpose: Ticket message thread (user/admin/system) for unified ticket system.
// Changed: 11-02-2026 23:28 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ticket_messages', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('ticket_id');

            // Actor: user | admin | system
            $table->string('actor_type', 20);

            // Actor user id (nullable for system)
            $table->unsignedBigInteger('actor_user_id')->nullable();

            // Message content
            $table->text('message');

            // Internal admin note (not visible to user)
            $table->boolean('is_internal')->default(false);

            $table->timestamps();

            $table->index('ticket_id');
            $table->index(['ticket_id', 'created_at']);

            // Keep schema minimal: no FK constraints yet (controlled layer first).
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ticket_messages');
    }
};
