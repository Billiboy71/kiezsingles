<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\User.php
// Purpose: User model (enables Laravel email verification)
// Changed: 14-02-2026 15:07 (Europe/Berlin)
// Version: 0.3
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
        'public_id',          // ← Public User Identifier (extern)
        'match_type',
        'gender',
        'looking_for',
        'username',
        'email',
        'password',
        'birthdate',
        'location',
        'district',
        'postcode',
        'privacy_accepted_at',

        // Role
        'role',

        // B4 – Moderation
        'moderation_warned_at',
        'moderation_warn_count',
        'moderation_blocked_at',
        'moderation_blocked_until',
        'moderation_blocked_permanent',
        'moderation_blocked_reason',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at'            => 'datetime',
        'birthdate'                    => 'date',
        'privacy_accepted_at'          => 'datetime',

        // B4 – Moderation
        'moderation_warned_at'         => 'datetime',
        'moderation_warn_count'        => 'integer',
        'moderation_blocked_at'        => 'datetime',
        'moderation_blocked_until'     => 'datetime',
        'moderation_blocked_permanent' => 'boolean',
    ];

    /**
     * Use public_id for route-model binding instead of numeric id.
     */
    public function getRouteKeyName(): string
    {
        return 'public_id';
    }
}
