<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_03_033800_ensure_device_autoban_schema.php
// Purpose: Ensure device autoban schema exists for runtime expectations
// Created: 03-03-2026 (Europe/Berlin)
// Changed: 03-03-2026 03:37 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('security_device_bans')) {
            Schema::create('security_device_bans', function (Blueprint $table): void {
                $table->id();
                $table->string('device_hash', 64);
                $table->text('reason')->nullable();
                $table->dateTime('banned_until')->nullable();
                $table->dateTime('revoked_at')->nullable();
                $table->boolean('is_active')->default(true);
                $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamps();

                $table->index('device_hash');
                $table->index('banned_until');
                $table->index('revoked_at');
                $table->index('is_active');
            });
        }

        if (Schema::hasTable('security_settings')) {
            Schema::table('security_settings', function (Blueprint $table): void {
                if (! Schema::hasColumn('security_settings', 'device_autoban_enabled')) {
                    $table->boolean('device_autoban_enabled')->default(false);
                }

                if (! Schema::hasColumn('security_settings', 'device_autoban_fail_threshold')) {
                    $table->unsignedInteger('device_autoban_fail_threshold')->default(100);
                }

                if (! Schema::hasColumn('security_settings', 'device_autoban_seconds')) {
                    $table->unsignedInteger('device_autoban_seconds')->default(3600);
                }
            });
        }
    }

    public function down(): void
    {
        // No-op on purpose: repair migration for existing installations.
    }
};

