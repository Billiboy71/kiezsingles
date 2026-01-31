<?php
// ============================================================================
// File: database/migrations/2026_01_31_000000_add_ip_fields_to_users_table.php
// Purpose: Add optional IP + timestamp fields to users table (no history)
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->ipAddress('registration_ip')->nullable()->after('email_verified_at');
            $table->timestamp('registration_ip_at')->nullable()->after('registration_ip');

            $table->ipAddress('last_login_ip')->nullable()->after('registration_ip_at');
            $table->timestamp('last_login_ip_at')->nullable()->after('last_login_ip');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'registration_ip',
                'registration_ip_at',
                'last_login_ip',
                'last_login_ip_at',
            ]);
        });
    }
};
