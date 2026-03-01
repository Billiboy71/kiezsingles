<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class SecurityIpBan extends Model
{
    protected $fillable = [
        'ip',
        'reason',
        'banned_until',
        'created_by',
    ];

    protected $casts = [
        'banned_until' => 'datetime',
        'created_by' => 'integer',
    ];

    public function scopeActive(Builder $query): Builder
    {
        return $query->where(function (Builder $sub): void {
            $sub->whereNull('banned_until')
                ->orWhere('banned_until', '>', now());
        });
    }
}
