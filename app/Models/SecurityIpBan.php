<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Models\SecurityIpBan.php
// Purpose: Eloquent model for IP bans
// Changed: 05-03-2026 23:32 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

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

    public function setBannedUntilAttribute($value): void
    {
        if ($value === null || $value === '') {
            $this->attributes['banned_until'] = null;
            return;
        }

        $tz = (string) (config('app.timezone') ?: 'UTC');

        try {
            if ($value instanceof \DateTimeInterface) {
                $dt = Carbon::instance($value)->timezone($tz);
                $this->attributes['banned_until'] = $dt->format($this->getDateFormat());
                return;
            }

            if (is_numeric($value)) {
                $dt = Carbon::createFromTimestamp((int) $value, $tz);
                $this->attributes['banned_until'] = $dt->format($this->getDateFormat());
                return;
            }

            $dt = Carbon::parse((string) $value, $tz)->timezone($tz);
            $this->attributes['banned_until'] = $dt->format($this->getDateFormat());
        } catch (\Throwable $ignore) {
            $this->attributes['banned_until'] = null;
        }
    }
}