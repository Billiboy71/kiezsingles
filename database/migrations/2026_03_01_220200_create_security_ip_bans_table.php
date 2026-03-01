<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('security_ip_bans', function (Blueprint $table): void {
            $table->id();
            $table->string('ip', 45);
            $table->text('reason')->nullable();
            $table->dateTime('banned_until')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index('ip');
            $table->index('banned_until');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('security_ip_bans');
    }
};
