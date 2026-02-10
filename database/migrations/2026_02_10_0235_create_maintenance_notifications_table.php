<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_10_0235_create_maintenance_notifications_table.php
// Purpose: Store emails for "Notify me when maintenance ends" feature
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('maintenance_notifications', function (Blueprint $table) {
            $table->id();

            $table->string('email', 255)->unique();

            $table->timestamp('notified_at')->nullable();

            $table->string('created_ip', 45)->nullable();
            $table->text('created_user_agent')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('maintenance_notifications');
    }
};
