<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Admin\UserRoleService.php
// Purpose: Central superadmin governance for user role changes and user deletion
// Created: 28-02-2026 14:49 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Services\Admin;

use App\Events\Admin\AdminAuditEvent;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class UserRoleService
{
    /** @var array<int, string> */
    private array $allowedRoles = ['superadmin', 'admin', 'moderator', 'user'];

    /**
     * @param array<int, string> $roles
     */
    public function setRolesForUser(User $target, array $roles): void
    {
        $this->syncRoles($target, $roles);
    }

    public function assignRole(User $target, string $role): void
    {
        $current = $target->roles()->pluck('name')->all();
        $current[] = $role;

        $this->syncRoles($target, $current);
    }

    public function removeRole(User $target, string $role): void
    {
        $role = mb_strtolower(trim((string) $role));

        $current = $target->roles()
            ->pluck('name')
            ->map(static fn ($name) => mb_strtolower(trim((string) $name)))
            ->filter(static fn ($name) => $name !== '')
            ->reject(static fn ($name) => $name === $role)
            ->values()
            ->all();

        $this->syncRoles($target, $current);
    }

    /**
     * @param array<int, string> $roles
     */
    public function syncRoles(User $target, array $roles): void
    {
        $requestedRoles = $this->normalizeRoles($roles);
        if (count($requestedRoles) < 1) {
            $requestedRoles = ['user'];
        }

        $targetId = (int) $target->id;

        DB::transaction(function () use ($targetId, $requestedRoles): void {
            /** @var User $lockedTarget */
            $lockedTarget = User::query()
                ->with('roles:id,name')
                ->lockForUpdate()
                ->findOrFail($targetId);

            $oldRoles = $this->normalizeRoles($lockedTarget->roles->pluck('name')->all());
            $newRoles = $requestedRoles;

            try {
                if ($lockedTarget->is_protected_admin && in_array('superadmin', $oldRoles, true) && !in_array('superadmin', $newRoles, true)) {
                    $this->auditBlocked('user.roles.sync', $lockedTarget, $oldRoles, $newRoles, 'protected_superadmin_cannot_be_downgraded');

                    throw ValidationException::withMessages([
                        'roles' => 'Protected superadmin cannot be downgraded.',
                    ]);
                }

                if (in_array('superadmin', $oldRoles, true) && !in_array('superadmin', $newRoles, true)) {
                    $superadminCount = (int) User::query()->role('superadmin')->lockForUpdate()->count();

                    if ($superadminCount <= 1) {
                        $this->auditBlocked('user.roles.sync', $lockedTarget, $oldRoles, $newRoles, 'last_superadmin_must_remain');

                        throw ValidationException::withMessages([
                            'roles' => 'At least one superadmin must exist.',
                        ]);
                    }
                }

                $lockedTarget->syncRoles($newRoles);

                $this->dispatchAudit('user.roles.sync', 'allowed', $lockedTarget, [
                    'old_roles' => $oldRoles,
                    'new_roles' => $newRoles,
                    'target_public_id' => (string) ($lockedTarget->public_id ?? ''),
                    'target_email' => (string) ($lockedTarget->email ?? ''),
                ]);
            } catch (ValidationException $e) {
                throw $e;
            } catch (\Throwable $e) {
                $this->dispatchAudit('user.roles.sync', 'failed', $lockedTarget, [
                    'old_roles' => $oldRoles,
                    'new_roles' => $newRoles,
                    'reason' => 'exception',
                    'exception' => get_class($e),
                    'target_public_id' => (string) ($lockedTarget->public_id ?? ''),
                    'target_email' => (string) ($lockedTarget->email ?? ''),
                ]);

                throw $e;
            }
        });
    }

    public function deleteUser(User $target): void
    {
        $targetId = (int) $target->id;

        DB::transaction(function () use ($targetId): void {
            /** @var User $lockedTarget */
            $lockedTarget = User::query()
                ->with('roles:id,name')
                ->lockForUpdate()
                ->findOrFail($targetId);

            $oldRoles = $this->normalizeRoles($lockedTarget->roles->pluck('name')->all());

            try {
                if ($lockedTarget->is_protected_admin) {
                    $this->auditBlocked('user.delete', $lockedTarget, $oldRoles, [], 'protected_superadmin_cannot_be_deleted');

                    throw ValidationException::withMessages([
                        'user' => 'Protected superadmin cannot be deleted.',
                    ]);
                }

                if (in_array('superadmin', $oldRoles, true)) {
                    $superadminCount = (int) User::query()->role('superadmin')->lockForUpdate()->count();

                    if ($superadminCount <= 1) {
                        $this->auditBlocked('user.delete', $lockedTarget, $oldRoles, [], 'last_superadmin_must_remain');

                        throw ValidationException::withMessages([
                            'user' => 'At least one superadmin must exist.',
                        ]);
                    }
                }

                $this->dispatchAudit('user.delete', 'allowed', $lockedTarget, [
                    'old_roles' => $oldRoles,
                    'new_roles' => [],
                    'target_public_id' => (string) ($lockedTarget->public_id ?? ''),
                    'target_email' => (string) ($lockedTarget->email ?? ''),
                ]);

                $lockedTarget->delete();
            } catch (ValidationException $e) {
                throw $e;
            } catch (\Throwable $e) {
                $this->dispatchAudit('user.delete', 'failed', $lockedTarget, [
                    'old_roles' => $oldRoles,
                    'new_roles' => [],
                    'reason' => 'exception',
                    'exception' => get_class($e),
                    'target_public_id' => (string) ($lockedTarget->public_id ?? ''),
                    'target_email' => (string) ($lockedTarget->email ?? ''),
                ]);

                throw $e;
            }
        });
    }

    /**
     * @param array<int, string> $oldRoles
     * @param array<int, string> $newRoles
     */
    private function auditBlocked(string $event, User $target, array $oldRoles, array $newRoles, string $reason): void
    {
        $this->dispatchAudit($event, 'blocked', $target, [
            'old_roles' => $oldRoles,
            'new_roles' => $newRoles,
            'reason' => $reason,
            'target_public_id' => (string) ($target->public_id ?? ''),
            'target_email' => (string) ($target->email ?? ''),
        ]);
    }

    /**
     * @param array<int, string> $roles
     * @return array<int, string>
     */
    private function normalizeRoles(array $roles): array
    {
        $out = [];

        foreach ($roles as $role) {
            $name = mb_strtolower(trim((string) $role));
            if ($name === '') {
                continue;
            }
            if (!in_array($name, $this->allowedRoles, true)) {
                continue;
            }
            $out[] = $name;
        }

        return array_values(array_unique($out));
    }

    /**
     * @param array<string, mixed> $meta
     */
    private function dispatchAudit(string $event, string $result, ?User $target, array $meta): void
    {
        $actorUserId = null;
        if (auth()->check()) {
            $actorUserId = (int) auth()->id();
        }

        $ip = null;
        $userAgent = null;
        if (app()->bound('request')) {
            $req = request();
            $ip = $req->ip();
            $userAgent = $req->userAgent();
        }

        event(new AdminAuditEvent(
            event: $event,
            result: $result,
            actorUserId: $actorUserId,
            targetUserId: $target ? (int) $target->id : null,
            ip: $ip,
            userAgent: $userAgent,
            meta: $meta,
        ));
    }
}