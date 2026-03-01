<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SecurityEvent extends Model
{
    protected $fillable = [
        'type',
        'ip',
        'user_id',
        'email',
        'device_hash',
        'meta',
    ];

    protected $casts = [
        'user_id' => 'integer',
        'meta' => 'array',
    ];
}
