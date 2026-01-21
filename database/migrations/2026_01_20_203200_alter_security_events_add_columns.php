<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('security_events', function (Blueprint $table) {
            $table->foreignId('user_id')->nullable()->after('id')->constrained()->nullOnDelete();
            $table->string('event_type', 64)->after('user_id');
            $table->string('ip', 45)->nullable()->after('event_type');
            $table->text('user_agent')->nullable()->after('ip');
            $table->json('metadata')->nullable()->after('user_agent');

            $table->index(['event_type', 'created_at']);
            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::table('security_events', function (Blueprint $table) {
            $table->dropIndex(['event_type', 'created_at']);
            $table->dropIndex(['user_id', 'created_at']);
            $table->dropColumn(['metadata', 'user_agent', 'ip', 'event_type']);
            $table->dropConstrainedForeignId('user_id');
        });
    }
};
