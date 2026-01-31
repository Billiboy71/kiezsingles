<?php
// ============================================================================
// File: app/Models/User.php
// Purpose: User model (enables Laravel email verification)
// ============================================================================

namespace App\Models;

use Illuminate\Auth\MustVerifyEmail as MustVerifyEmailTrait;
use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable implements MustVerifyEmail
{
    use HasFactory, Notifiable, MustVerifyEmailTrait;

    protected $fillable = [
    'match_type',
    'gender',
    'looking_for',

    'nickname',

    'email',
    'password',

    'birthdate',

    'location',
    'district',
    'postcode',

    'privacy_accepted_at',

    'email_verified_at',
    'remember_token',
];


    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'birthdate' => 'date',
        'privacy_accepted_at' => 'datetime',
    ];
}
