<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_12_020800_add_moderation_fields_to_users_table.php
// Purpose: Add moderation fields to users table (B4 – Ticket Moderation).
// Changed: 12-02-2026 02:12 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Warnsystem
            $table->timestamp('moderation_warned_at')->nullable()->after('privacy_accepted_at');
            $table->unsignedInteger('moderation_warn_count')->default(0)->after('moderation_warned_at');

            // Sperren
            $table->timestamp('moderation_blocked_at')->nullable()->after('moderation_warn_count');
            $table->timestamp('moderation_blocked_until')->nullable()->after('moderation_blocked_at');
            $table->boolean('moderation_blocked_permanent')->default(false)->after('moderation_blocked_until');
            $table->string('moderation_blocked_reason', 500)->nullable()->after('moderation_blocked_permanent');

            // Optional: Index für Performance (z. B. Login-Checks)
            $table->index('moderation_blocked_permanent');
            $table->index('moderation_blocked_until');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['moderation_blocked_permanent']);
            $table->dropIndex(['moderation_blocked_until']);

            $table->dropColumn([
                'moderation_warned_at',
                'moderation_warn_count',
                'moderation_blocked_at',
                'moderation_blocked_until',
                'moderation_blocked_permanent',
                'moderation_blocked_reason',
            ]);
        });
    }
};
