<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_03_01_220100_update_security_events_for_core_module.php
// Purpose: Align security_events schema with security core module requirements
// Changed: 09-03-2026 16:17 (Europe/Berlin)
// Version: 0.2
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('security_events')) {
            return;
        }

        Schema::table('security_events', function (Blueprint $table): void {
            if (!Schema::hasColumn('security_events', 'user_id')) {
                $table->foreignId('user_id')->nullable()->after('id')->constrained('users')->nullOnDelete();
            }

            if (!Schema::hasColumn('security_events', 'type')) {
                $table->string('type', 64)->nullable()->after('user_id');
            }

            if (!Schema::hasColumn('security_events', 'ip')) {
                $table->string('ip', 45)->nullable()->after('type');
            }

            if (!Schema::hasColumn('security_events', 'email')) {
                $table->string('email')->nullable()->after('ip');
            }

            if (!Schema::hasColumn('security_events', 'device_hash')) {
                $table->string('device_hash', 64)->nullable()->after('email');
            }

            if (!Schema::hasColumn('security_events', 'meta')) {
                $table->json('meta')->nullable()->after('device_hash');
            }
        });

        if (Schema::hasColumn('security_events', 'event_type') && Schema::hasColumn('security_events', 'type')) {
            DB::statement("UPDATE security_events SET type = event_type WHERE type IS NULL AND event_type IS NOT NULL");
        }

        if (Schema::hasColumn('security_events', 'metadata') && Schema::hasColumn('security_events', 'meta')) {
            DB::statement("UPDATE security_events SET meta = metadata WHERE meta IS NULL AND metadata IS NOT NULL");
        }

        if (Schema::hasColumn('security_events', 'event_type')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->dropIndex(['event_type', 'created_at']);
            });

            Schema::table('security_events', function (Blueprint $table): void {
                $table->dropColumn('event_type');
            });
        }

        if (Schema::hasColumn('security_events', 'metadata')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->dropColumn('metadata');
            });
        }

        if (Schema::hasColumn('security_events', 'user_agent')) {
            Schema::table('security_events', function (Blueprint $table): void {
                $table->dropColumn('user_agent');
            });
        }

        Schema::table('security_events', function (Blueprint $table): void {
            $table->index(['type', 'created_at'], 'security_events_type_created_at_idx');
            $table->index('ip', 'security_events_ip_idx');
            $table->index('user_id', 'security_events_user_id_idx');
            $table->index('device_hash', 'security_events_device_hash_idx');
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('security_events')) {
            return;
        }

        Schema::table('security_events', function (Blueprint $table): void {
            $table->dropIndex('security_events_type_created_at_idx');
            $table->dropIndex('security_events_ip_idx');
            $table->dropIndex('security_events_user_id_idx');
            $table->dropIndex('security_events_device_hash_idx');

            if (!Schema::hasColumn('security_events', 'event_type')) {
                $table->string('event_type', 64)->nullable();
            }

            if (!Schema::hasColumn('security_events', 'metadata')) {
                $table->json('metadata')->nullable();
            }

            if (!Schema::hasColumn('security_events', 'user_agent')) {
                $table->text('user_agent')->nullable();
            }
        });

        if (Schema::hasColumn('security_events', 'type') && Schema::hasColumn('security_events', 'event_type')) {
            DB::statement("UPDATE security_events SET event_type = type WHERE event_type IS NULL AND type IS NOT NULL");
        }

        if (Schema::hasColumn('security_events', 'meta') && Schema::hasColumn('security_events', 'metadata')) {
            DB::statement("UPDATE security_events SET metadata = meta WHERE metadata IS NULL AND meta IS NOT NULL");
        }

        Schema::table('security_events', function (Blueprint $table): void {
            if (Schema::hasColumn('security_events', 'type')) {
                $table->dropColumn('type');
            }

            if (Schema::hasColumn('security_events', 'email')) {
                $table->dropColumn('email');
            }

            if (Schema::hasColumn('security_events', 'device_hash')) {
                $table->dropColumn('device_hash');
            }

            if (Schema::hasColumn('security_events', 'meta')) {
                $table->dropColumn('meta');
            }
        });
    }
};