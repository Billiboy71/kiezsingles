<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\User.php
// Purpose: User model (enables Laravel email verification)
// Changed: 28-02-2026 14:49 (Europe/Berlin)
// Version: 0.5
// ============================================================================
namespace App\Models;

use Illuminate\Auth\MustVerifyEmail as MustVerifyEmailTrait;
use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Spatie\Permission\Traits\HasRoles;

class User extends Authenticatable implements MustVerifyEmail
{
    use HasFactory, Notifiable, MustVerifyEmailTrait, HasRoles;

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

        // Protected admin (DB-only flag; no UI toggle)
        'is_protected_admin',

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

        // Protected admin (DB-only flag; no UI toggle)
        'is_protected_admin'           => 'boolean',

        // B4 – Moderation
        'moderation_warned_at'         => 'datetime',
        'moderation_warn_count'        => 'integer',
        'moderation_blocked_at'        => 'datetime',
        'moderation_blocked_until'     => 'datetime',
        'moderation_blocked_permanent' => 'boolean',
    ];

    public function isSuperadmin(): bool
    {
        return $this->hasRole('superadmin');
    }

    public function isAdmin(): bool
    {
        return $this->hasRole('admin');
    }

    public function isModerator(): bool
    {
        return $this->hasRole('moderator');
    }

    public function isProtectedAdmin(): bool
    {
        return (bool) $this->is_protected_admin;
    }

    public function primaryRoleName(): string
    {
        if ($this->hasRole('superadmin')) {
            return 'superadmin';
        }

        if ($this->hasRole('admin')) {
            return 'admin';
        }

        if ($this->hasRole('moderator')) {
            return 'moderator';
        }

        return 'user';
    }

    public function getRoleAttribute(): string
    {
        return $this->primaryRoleName();
    }

    /**
     * Use public_id for route-model binding instead of numeric id.
     */
    public function getRouteKeyName(): string
    {
        return 'public_id';
    }
}