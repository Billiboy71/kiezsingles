<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_01_220300_create_security_identity_bans_table.php
// Purpose: Create security_identity_bans table for email/identity blocking
// Changed: 02-03-2026 01:43 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('security_identity_bans', function (Blueprint $table): void {
            $table->id();
            $table->string('email')->index();
            $table->text('reason')->nullable();
            $table->dateTime('banned_until')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('security_identity_bans');
    }
};
