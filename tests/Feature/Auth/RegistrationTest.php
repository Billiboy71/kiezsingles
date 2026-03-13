<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\tests\Feature\Auth\RegistrationTest.php
// Purpose: Feature tests for registration
// Changed: 10-03-2026 00:59 (Europe/Berlin)
// Version: 0.3
// ============================================================================

use Illuminate\Support\Facades\DB;

test('registration screen can be rendered', function () {
    $response = $this->get('/register');

    $response->assertStatus(200);
});

test('new users can register', function () {
    config()->set('captcha.enabled', false);
    config()->set('captcha.on_register', false);
    config()->set('features.postcode.enabled', true);
    config()->set('features.postcode.required', true);

    DB::table('district_postcodes')->insert([
        'district' => 'Koepenick',
        'postcode' => '12555',
    ]);

    $response = $this->post('/register', [
        'match_type' => 'm_f',
        'username' => 'Max_1234',
        'birthdate' => now()->subYears(25)->toDateString(),
        'district' => 'Koepenick',
        'postcode' => '12555',
        'email' => 'test@example.com',
        'password' => 'G7!vQ3#zL9pA',
        'password_confirmation' => 'G7!vQ3#zL9pA',
        'privacy' => '1',
    ]);

    $response->assertSessionHasNoErrors();

    $this->assertDatabaseHas('users', [
        'email' => 'test@example.com',
        'username' => 'Max_1234',
        'match_type' => 'm_f',
        'district' => 'Koepenick',
        'postcode' => '12555',
    ]);

    $this->assertGuest();
    $response->assertRedirect(route('login', absolute: false));
});