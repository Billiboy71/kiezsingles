<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Support\Admin\AdminSectionAccess.php
// Purpose: Server-side backend section access (superadmin full; admin/moderator via DB whitelist; fail-closed)
// Changed: 27-02-2026 00:58 (Europe/Berlin)
// Version: 2.0
// ============================================================================

namespace App\Support\Admin;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

final class AdminSectionAccess
{
    /**
     * NOTE (Architecture / SSOT):
     * This class is the Single Source of Truth for backend module authorization.
     * Route-level middleware stacks must enforce:
     * auth + staff/superadmin + section:*
     * Controllers must not implement additional role/security checks.
     */

    /**
     * Canonical role keys.
     */
    public const ROLE_USER = 'user';
    public const ROLE_ADMIN = 'admin';
    public const ROLE_SUPERADMIN = 'superadmin';
    public const ROLE_MODERATOR = 'moderator';

    /**
     * Canonical section keys (extendable).
     */
    public const SECTION_OVERVIEW = 'overview';
    public const SECTION_TICKETS = 'tickets';
    public const SECTION_MAINTENANCE = 'maintenance';
    public const SECTION_DEVELOP = 'develop';
    public const SECTION_DEBUG = 'debug';
    public const SECTION_MODERATION = 'moderation';
    public const SECTION_ROLES = 'roles';

    /**
     * All known section keys (fail-closed for unknown keys).
     */
    public static function knownSections(): array
    {
        return [
            self::SECTION_OVERVIEW,
            self::SECTION_TICKETS,
            self::SECTION_MAINTENANCE,
            self::SECTION_DEVELOP,
            self::SECTION_DEBUG,
            self::SECTION_MODERATION,
            self::SECTION_ROLES,
        ];
    }

    /**
     * Normalize section key (lowercase + trim). Empty -> overview.
     */
    public static function normalizeSectionKey(?string $sectionKey): string
    {
        $sectionKey = mb_strtolower(trim((string) ($sectionKey ?? '')));
        return $sectionKey === '' ? self::SECTION_OVERVIEW : $sectionKey;
    }

    /**
     * Normalize role (fail-closed to 'user').
     */
    public static function normalizeRole(?string $role): string
    {
        $role = mb_strtolower(trim((string) ($role ?? '')));

        if ($role === self::ROLE_ADMIN) {
            return self::ROLE_ADMIN;
        }
        if ($role === self::ROLE_SUPERADMIN) {
            return self::ROLE_SUPERADMIN;
        }
        if ($role === self::ROLE_MODERATOR) {
            return self::ROLE_MODERATOR;
        }

        return self::ROLE_USER;
    }

    /**
     * Admin-like roles (admin + superadmin).
     */
    public static function isAdminLike(?string $role): bool
    {
        $role = self::normalizeRole($role);
        return ($role === self::ROLE_ADMIN || $role === self::ROLE_SUPERADMIN);
    }

    /**
     * Staff roles (admin-like + moderator).
     */
    public static function isStaffRole(?string $role): bool
    {
        $role = self::normalizeRole($role);
        return self::isAdminLike($role) || $role === self::ROLE_MODERATOR;
    }

    /**
     * Backward-compat alias (older code used isStaffLike()).
     */
    public static function isStaffLike(?string $role): bool
    {
        return self::isStaffRole($role);
    }

    /**
     * Allowed staff keys for DB-managed sections (overview is always allowed server-side).
     */
    public static function allowedStaffManagedSectionKeys(): array
    {
        return [
            self::SECTION_TICKETS,
        ];
    }

    /**
     * Backward-compat alias.
     */
    public static function allowedModeratorSectionKeys(): array
    {
        return self::allowedStaffManagedSectionKeys();
    }

    /**
     * Default staff-managed sections if per-user whitelist missing/invalid.
     */
    public static function defaultStaffManagedSections(): array
    {
        return [];
    }

    /**
     * Backward-compat alias.
     */
    public static function defaultModeratorSections(): array
    {
        return self::defaultStaffManagedSections();
    }

    /**
     * Permission source availability for admin/moderator section checks.
     *
     * Fail-closed requirement:
     * - If permissions cannot be read (DB down / schema check fails / table missing) -> deny admin/moderator.
     */
    private static function permissionSourceAvailableFailClosed(): bool
    {
        try {
            return Schema::hasTable('staff_permissions');
        } catch (\Throwable $e) {
            return false;
        }
    }

    /**
     * Read per-user section whitelist from staff_permissions (SSOT).
     *
     * Fail-closed:
     * - If staff_permissions missing/unreadable -> defaultStaffManagedSections()
     */
    public static function staffManagedSectionsForUserFailClosed(string $role, $user): array
    {
        $role = self::normalizeRole($role);
        if ($role !== self::ROLE_ADMIN && $role !== self::ROLE_MODERATOR) {
            return [];
        }

        $allowed = self::allowedStaffManagedSectionKeys();

        try {
            if (!Schema::hasTable('staff_permissions')) {
                return self::defaultStaffManagedSections();
            }
        } catch (\Throwable $e) {
            return self::defaultStaffManagedSections();
        }

        $userId = null;

        try {
            if (is_object($user) && isset($user->id) && is_numeric($user->id)) {
                $userId = (int) $user->id;
            } elseif (is_array($user) && array_key_exists('id', $user) && is_numeric($user['id'])) {
                $userId = (int) $user['id'];
            }
        } catch (\Throwable $e) {
            $userId = null;
        }

        if ($userId === null || $userId < 1) {
            return self::defaultStaffManagedSections();
        }

        try {
            $out = DB::table('staff_permissions')
                ->where('user_id', $userId)
                ->where('allowed', true)
                ->whereIn('module_key', $allowed)
                ->pluck('module_key')
                ->map(static fn ($s) => mb_strtolower(trim((string) $s)))
                ->filter(static fn ($s) => $s !== '' && strlen($s) <= 64 && preg_match('/^[a-z0-9_]+$/', $s))
                ->unique()
                ->values()
                ->all();
        } catch (\Throwable $e) {
            return self::defaultStaffManagedSections();
        }

        return $out;
    }

    /**
     * Backward-compat alias for older call-sites.
     */
    public static function moderatorSectionsForUserFailClosed($user): array
    {
        return self::staffManagedSectionsForUserFailClosed(self::ROLE_MODERATOR, $user);
    }

    /**
     * Server-side check if current user (role) can access a backend section.
     * NOTE: $maintenanceEnabled is currently unused (reserved for future policy needs).
     */
    public static function canAccessSection(?string $role, string $sectionKey, bool $maintenanceEnabled = false, $user = null): bool
    {
        $role = self::normalizeRole($role);
        $sectionKey = self::normalizeSectionKey($sectionKey);

        // Fail-closed: unknown section keys are never allowed.
        if (!in_array($sectionKey, self::knownSections(), true)) {
            return false;
        }

        // Superadmin: full access.
        if ($role === self::ROLE_SUPERADMIN) {
            return true;
        }

        // Übersicht is mandatory and cannot be disabled for staff users.
        if (self::isStaffRole($role) && $sectionKey === self::SECTION_OVERVIEW) {
            return true;
        }

        // Fail-closed for admin/moderator if permission source cannot be read.
        if ($role === self::ROLE_ADMIN || $role === self::ROLE_MODERATOR) {
            if (!self::permissionSourceAvailableFailClosed()) {
                return false;
            }
        }

        if ($role !== self::ROLE_ADMIN && $role !== self::ROLE_MODERATOR) {
            return false;
        }

        // Admin/Moderator: admin-only sections are never accessible (hard-block).
        if ($sectionKey === self::SECTION_MAINTENANCE) {
            return false;
        }
        if ($sectionKey === self::SECTION_DEVELOP) {
            return false;
        }
        if ($sectionKey === self::SECTION_MODERATION) {
            return false;
        }
        if ($sectionKey === self::SECTION_DEBUG) {
            return false;
        }
        if ($sectionKey === self::SECTION_ROLES) {
            return false;
        }

        $resolvedUser = $user;
        if ($resolvedUser === null) {
            $resolvedUser = auth()->user();
        }

        $allowed = self::staffManagedSectionsForUserFailClosed($role, $resolvedUser);

        return in_array($sectionKey, $allowed, true);
    }

    /**
     * Enforce access; throws 403 (or 503 via global exception handler on DB failures).
     */
    public static function requireSection(?string $role, string $sectionKey, bool $maintenanceEnabled = false, $user = null): void
    {
        abort_unless(self::canAccessSection($role, $sectionKey, $maintenanceEnabled, $user), 403);
    }
}
