<?php

namespace App\Support;

use Illuminate\Validation\Rules\Password;

class PasswordRules
{
    public static function strong(): Password
    {
        return Password::min(10)
            ->mixedCase()
            ->numbers()
            ->symbols()
            ->uncompromised();
    }
}
