<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_01_28_100000_rename_users_kiez_to_district.php
// Purpose: Safely rename users.kiez to users.district across supported test/dev databases
// Changed: 10-03-2026 00:34 (Europe/Berlin)
// Version: 0.2
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('users')) {
            return;
        }

        // Normalfall: alte Spalte umbenennen
        if (Schema::hasColumn('users', 'kiez') && !Schema::hasColumn('users', 'district')) {
            Schema::table('users', function (Blueprint $table) {
                $table->renameColumn('kiez', 'district');
            });
            return;
        }

        // Testschema / frische Migration:
        // Wenn district noch gar nicht existiert, anlegen
        if (!Schema::hasColumn('users', 'district')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('district', 80)->nullable()->after('location');
            });
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('users')) {
            return;
        }

        if (Schema::hasColumn('users', 'district') && !Schema::hasColumn('users', 'kiez')) {
            Schema::table('users', function (Blueprint $table) {
                $table->renameColumn('district', 'kiez');
            });
        }
    }
};