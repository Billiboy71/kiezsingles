<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('last_name', 100)->after('id');
        });

        // Daten aus dem alten Feld übernehmen
        DB::table('users')->update([
            'last_name' => DB::raw('name')
        ]);

        // Optional: name entfernen (erst NACH Copy)
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('name');
        });
    }

    public function down(): void
    {
        // name wieder anlegen
        Schema::table('users', function (Blueprint $table) {
            $table->string('name', 255)->after('id');
        });

        DB::table('users')->update([
            'name' => DB::raw('last_name')
        ]);

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('last_name');
        });
    }
};
