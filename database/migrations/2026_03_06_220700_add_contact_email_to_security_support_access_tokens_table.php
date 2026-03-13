<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_06_220700_add_contact_email_to_security_support_access_tokens_table.php
// Purpose: Add optional contact email to security support access tokens.
// Created: 06-03-2026 (Europe/Berlin)
// Changed: 06-03-2026 22:06 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn('security_support_access_tokens', 'contact_email')) {
            Schema::table('security_support_access_tokens', function (Blueprint $table) {
                $table->string('contact_email', 255)->nullable()->after('case_key');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('security_support_access_tokens', 'contact_email')) {
            Schema::table('security_support_access_tokens', function (Blueprint $table) {
                $table->dropColumn('contact_email');
            });
        }
    }
};
