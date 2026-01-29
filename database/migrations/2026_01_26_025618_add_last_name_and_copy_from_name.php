<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Falls schon erledigt: nichts tun
        if (Schema::hasColumn('users', 'last_name')) {
            return;
        }

        // last_name hinzufügen
        Schema::table('users', function (Blueprint $table) {
            $table->string('last_name', 100)->after('id');
        });

        // Daten aus name übernehmen (nur wenn name existiert)
        if (Schema::hasColumn('users', 'name')) {
            DB::table('users')->update([
                'last_name' => DB::raw('name'),
            ]);

            // altes Feld entfernen
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('name');
            });
        }
    }

    public function down(): void
    {
        // name wieder anlegen, aber nur wenn es nicht existiert
        if (!Schema::hasColumn('users', 'name')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('name', 255)->after('id');
            });

            if (Schema::hasColumn('users', 'last_name')) {
                DB::table('users')->update([
                    'name' => DB::raw('last_name'),
                ]);
            }
        }

        // last_name entfernen, falls vorhanden
        if (Schema::hasColumn('users', 'last_name')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('last_name');
            });
        }
    }
};
