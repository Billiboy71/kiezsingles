<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            DistrictPostcodesSeeder::class,
        ]);

        User::factory()->create([
            'email' => 'test@example.com',
        ]);
    }
}
