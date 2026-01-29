<?php

use App\Models\User;
use Illuminate\Support\Facades\Hash;

test('correct password must be provided to update password', function () {
    $user = User::factory()->create([
    'password' => Hash::make('OldG7!vQ3#zL9pA'),
    ]);
        
    $response = $this
        ->actingAs($user)
        ->from('/profile')
        ->put('/password', [
            'current_password' => 'OldG7!vQ3#zL9pA',
                'password' => 'G7!vQ3#zL9pA',
                'password_confirmation' => 'G7!vQ3#zL9pA',
        ]);

    $response
    ->assertSessionHasNoErrors([], 'updatePassword')
    ->assertRedirect('/profile');

    $this->assertTrue(Hash::check('G7!vQ3#zL9pA', $user->refresh()->password));
});