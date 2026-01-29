<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        // Sicherheit: nur ausführen, wenn es Sinn ergibt
        if (Schema::hasColumn('users', 'kiez') && !Schema::hasColumn('users', 'district')) {
            // MySQL: Spalte umbenennen und Typ beibehalten (string/varchar)
            DB::statement("ALTER TABLE `users` CHANGE `kiez` `district` VARCHAR(255) NULL");
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('users', 'district') && !Schema::hasColumn('users', 'kiez')) {
            DB::statement("ALTER TABLE `users` CHANGE `district` `kiez` VARCHAR(255) NULL");
        }
    }
};
