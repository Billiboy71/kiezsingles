<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\tests\Feature\Auth\PasswordResetTest.php
// Changed: 10-03-2026 01:08 (Europe/Berlin)
// Version: 0.2
// ============================================================================

use App\Models\User;
use Illuminate\Support\Facades\Password;

test('reset password link screen can be rendered', function () {
    $response = $this->get('/forgot-password');

    $response->assertStatus(200);
});

test('reset password link can be requested', function () {
    config()->set('captcha.enabled', false);
    config()->set('captcha.on_password_reset', false);
    config()->set('captcha.on_forgot_password', false);

    $user = User::factory()->create();

    $response = $this->post('/forgot-password', [
        'email' => $user->email,
    ]);

    $response->assertSessionHasNoErrors();
});

test('reset password screen can be rendered', function () {
    $user = User::factory()->create();
    $token = Password::broker()->createToken($user);

    $response = $this->get('/reset-password/'.$token);

    $response->assertStatus(200);
});

test('password can be reset with valid token', function () {
    config()->set('captcha.enabled', false);
    config()->set('captcha.on_password_reset', false);
    config()->set('captcha.on_forgot_password', false);

    $user = User::factory()->create();
    $token = Password::broker()->createToken($user);

    $response = $this->post('/reset-password', [
        'token' => $token,
        'email' => $user->email,
        'password' => 'G7!vQ3#zL9pA',
        'password_confirmation' => 'G7!vQ3#zL9pA',
    ]);

    $response
        ->assertSessionHasNoErrors()
        ->assertRedirect(route('login'));
});