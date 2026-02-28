<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Observers\UserObserver.php
// Purpose: User observer (registration IP + protected/superadmin fail-safe)
// Changed: 28-02-2026 14:18 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Observers;

use App\Models\User;
use Illuminate\Validation\ValidationException;

class UserObserver
{
    public function created(User $user): void
    {
        if (!config('security.ip_logging.registration')) {
            return;
        }

        if (!empty($user->registration_ip)) {
            return;
        }

        if (!app()->bound('request')) {
            return;
        }

        $ip = request()->ip();

        if (empty($ip)) {
            return;
        }

        // forceFill: unabhängig von $fillable (Security!)
        $user->forceFill([
            'registration_ip'    => $ip,
            'registration_ip_at' => now(),
        ])->saveQuietly();
    }

    /**
     * Global guardrail before updating a user.
     */
    public function updating(User $user): void
    {
        // 1) Protected admin darf nicht von superadmin heruntergestuft werden
        if ($user->isDirty('role')) {
            $originalRole = $user->getOriginal('role');
            $newRole      = $user->role;

            // Protected + versucht von superadmin wegzugehen
            if (
                $user->is_protected_admin &&
                $originalRole === 'superadmin' &&
                $newRole !== 'superadmin'
            ) {
                throw ValidationException::withMessages([
                    'role' => 'Protected superadmin cannot be downgraded.',
                ]);
            }

            // 2) Mindestens 1 Superadmin muss existieren
            if ($originalRole === 'superadmin' && $newRole !== 'superadmin') {
                $superadminCount = User::where('role', 'superadmin')->count();

                // Wenn dieser User aktuell noch superadmin ist,
                // würde die Änderung die Anzahl um 1 reduzieren.
                if ($superadminCount <= 1) {
                    throw ValidationException::withMessages([
                        'role' => 'At least one superadmin must exist.',
                    ]);
                }
            }
        }
    }

    /**
     * Global guardrail before deleting a user.
     */
    public function deleting(User $user): void
    {
        // 1) Protected admin darf nicht gelöscht werden
        if ($user->is_protected_admin) {
            throw ValidationException::withMessages([
                'user' => 'Protected superadmin cannot be deleted.',
            ]);
        }

        // 2) Letzter Superadmin darf nicht gelöscht werden
        if ($user->role === 'superadmin') {
            $superadminCount = User::where('role', 'superadmin')->count();

            if ($superadminCount <= 1) {
                throw ValidationException::withMessages([
                    'user' => 'At least one superadmin must exist.',
                ]);
            }
        }
    }
}