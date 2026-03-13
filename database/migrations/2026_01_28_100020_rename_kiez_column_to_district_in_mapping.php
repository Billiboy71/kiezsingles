<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_01_28_100020_rename_kiez_column_to_district_in_mapping.php
// Purpose: Safely rename district_postcodes.kiez to district_postcodes.district across supported test/dev databases
// Changed: 09-03-2026 16:03 (Europe/Berlin)
/// Version: 0.1
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('district_postcodes')) {
            return;
        }

        if (Schema::hasColumn('district_postcodes', 'kiez') && !Schema::hasColumn('district_postcodes', 'district')) {
            Schema::table('district_postcodes', function (Blueprint $table) {
                $table->renameColumn('kiez', 'district');
            });
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('district_postcodes')) {
            return;
        }

        if (Schema::hasColumn('district_postcodes', 'district') && !Schema::hasColumn('district_postcodes', 'kiez')) {
            Schema::table('district_postcodes', function (Blueprint $table) {
                $table->renameColumn('district', 'kiez');
            });
        }
    }
};