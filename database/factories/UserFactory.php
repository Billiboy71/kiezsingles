<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\factories\UserFactory.php
// Changed: 10-03-2026 00:08 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'public_id' => (string) Str::uuid(),
            'match_type' => 'm_f',
            'gender' => 'm',
            'looking_for' => 'f',
            'username' => fake()->unique()->userName(),
            'email' => fake()->unique()->safeEmail(),
            'password' => static::$password ??= Hash::make('password'),
            'birthdate' => now()->subYears(30)->toDateString(),
            'location' => 'Berlin',
            'district' => 'Koepenick',
            'postcode' => '12555',
            'privacy_accepted_at' => now(),
            'email_verified_at' => now(),
            'remember_token' => Str::random(10),
        ];
    }

    /**
     * Indicate that the model's email address should be unverified.
     */
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }
}