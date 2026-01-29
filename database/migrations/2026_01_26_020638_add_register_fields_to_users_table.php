<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->date('birthdate')->after('email');

            $table->string('gender', 20)->after('birthdate');
            $table->string('looking_for', 20)->after('gender');

            $table->string('location', 120)->after('looking_for');
            $table->string('kiez', 120)->after('location');

            $table->string('nickname', 20)->unique()->after('kiez');

            $table->boolean('newsletter_opt_in')->default(false)->after('nickname');
            $table->timestamp('privacy_accepted_at')->nullable()->after('newsletter_opt_in');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['nickname']);

            $table->dropColumn([
                'birthdate',
                'gender',
                'looking_for',
                'location',
                'kiez',
                'nickname',
                'newsletter_opt_in',
                'privacy_accepted_at',
            ]);
        });
    }
};