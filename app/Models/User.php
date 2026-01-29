<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    use HasFactory, Notifiable;

    protected $fillable = [
    'match_type',
    'gender',
    'looking_for',

    'first_name',
    'last_name',
    'nickname',

    'email',
    'password',

    'birthdate',

    'location',
    'district',
    'postcode',

    'newsletter_opt_in',
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
        'newsletter_opt_in' => 'boolean',
        'privacy_accepted_at' => 'datetime',
    ];
}
