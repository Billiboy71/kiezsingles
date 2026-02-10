<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_10_000001_add_code_encrypted_to_noteinstieg_recovery_codes_table.php
// Changed: 10-02-2026 00:58
// Purpose: Add encrypted plaintext storage for recovery codes to enable
//          admin display/print after reload (nullable).
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('noteinstieg_recovery_codes', function (Blueprint $table) {
            $table->text('code_encrypted')->nullable()->after('hash');
        });
    }

    public function down(): void
    {
        Schema::table('noteinstieg_recovery_codes', function (Blueprint $table) {
            $table->dropColumn('code_encrypted');
        });
    }
};
