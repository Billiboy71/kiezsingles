<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::hasTable('district_postcodes')
            && Schema::hasColumn('district_postcodes', 'kiez')
            && !Schema::hasColumn('district_postcodes', 'district')) {

            DB::statement("ALTER TABLE `district_postcodes` CHANGE `kiez` `district` VARCHAR(80) NOT NULL");
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('district_postcodes')
            && Schema::hasColumn('district_postcodes', 'district')
            && !Schema::hasColumn('district_postcodes', 'kiez')) {

            DB::statement("ALTER TABLE `district_postcodes` CHANGE `district` `kiez` VARCHAR(80) NOT NULL");
        }
    }
};
