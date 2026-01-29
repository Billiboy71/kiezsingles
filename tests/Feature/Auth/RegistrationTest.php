<?php

test('registration screen can be rendered', function () {
    $response = $this->get('/register');
    $response->assertStatus(200);
});

test('new users can register', function () {
    $response = $this->post('/register', [
        'match' => 'm_f',

        'first_name' => 'Max',
        'last_name'  => 'Mustermann',
        'nickname'   => 'Max_1234',

        'birthdate' => now()->subYears(25)->toDateString(),
        'location'  => 'Berlin',
        'kiez'      => 'Koepenick',

        'email' => 'test@example.com',
        'password' => 'G7!vQ3#zL9pA',
        'password_confirmation' => 'G7!vQ3#zL9pA',

        'privacy' => '1',
        'newsletter_opt_in' => '1',
    ]);

    $response->assertSessionHasNoErrors();
    $this->assertDatabaseHas('users', [
    'email' => 'test@example.com',
]);

    $this->assertAuthenticated();
    $response->assertRedirect(route('dashboard', absolute: false));
});
