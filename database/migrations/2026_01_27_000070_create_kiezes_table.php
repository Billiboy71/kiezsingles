<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('kiezes', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();         // Dropdown-Text & gespeicherter Wert
            $table->boolean('active')->default(true); // später Admin an/aus
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('kiezes');
    }
};
