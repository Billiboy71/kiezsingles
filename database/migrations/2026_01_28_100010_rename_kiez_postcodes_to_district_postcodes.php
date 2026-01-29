<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::hasTable('kiez_postcodes') && !Schema::hasTable('district_postcodes')) {
            Schema::rename('kiez_postcodes', 'district_postcodes');
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('district_postcodes') && !Schema::hasTable('kiez_postcodes')) {
            Schema::rename('district_postcodes', 'kiez_postcodes');
        }
    }
};
