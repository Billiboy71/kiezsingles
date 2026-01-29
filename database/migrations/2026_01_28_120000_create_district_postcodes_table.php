<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('district_postcodes', function (Blueprint $table) {
            $table->id();
            $table->string('district', 80);
            $table->string('postcode', 10);
            $table->timestamps();

            $table->unique(['district', 'postcode']);
            $table->index('district');
            $table->index('postcode');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('district_postcodes');
    }
};
