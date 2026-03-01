<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            if (!Schema::hasColumn('users', 'is_frozen')) {
                $table->boolean('is_frozen')->default(false)->after('is_protected_admin');
            }

            if (!Schema::hasColumn('users', 'banned_at')) {
                $table->dateTime('banned_at')->nullable()->after('is_frozen');
            }
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            if (Schema::hasColumn('users', 'banned_at')) {
                $table->dropColumn('banned_at');
            }

            if (Schema::hasColumn('users', 'is_frozen')) {
                $table->dropColumn('is_frozen');
            }
        });
    }
};
