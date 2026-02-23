<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Support\Admin\AdminModuleRegistry.php
// Purpose: Central admin module registry (structure-only; role filter; no DB toggles)
// Changed: 23-02-2026 00:10 (Europe/Berlin)
// Version: 0.8
// ============================================================================

namespace App\Support\Admin;

final class AdminModuleRegistry
{
    /**
     * Canonical section keys (must stay in sync with AdminSectionAccess).
     */
    public const SECTION_OVERVIEW    = 'overview';
    public const SECTION_TICKETS     = 'tickets';
    public const SECTION_MAINTENANCE = 'maintenance';
    public const SECTION_DEBUG       = 'debug';
    public const SECTION_MODERATION  = 'moderation';
    public const SECTION_ROLES       = 'roles';

    /**
     * Central registry definition.
     *
     * IMPORTANT:
     * - SECTION_ROLES is intentionally NOT registered here unless a matching GET route exists.
     * - Governance endpoints can exist without a navigation module.
     *
     * Access semantics:
     * - staff: moderator/admin/superadmin
     * - superadmin: superadmin only
     */
    public static function registry(): array
    {
        return [
            self::SECTION_OVERVIEW => [
                'label' => 'Übersicht',
                'route' => 'admin.home',
                'access' => 'staff',
            ],
            self::SECTION_TICKETS => [
                'label' => 'Tickets',
                'route' => 'admin.tickets.index',
                'access' => 'staff',
            ],
            self::SECTION_MAINTENANCE => [
                'label' => 'Wartung',
                'route' => 'admin.maintenance',
                'access' => 'superadmin',
            ],
            self::SECTION_DEBUG => [
                'label' => 'Debug',
                'route' => 'admin.debug',
                'access' => 'superadmin',
            ],
            self::SECTION_MODERATION => [
                'label' => 'Moderation',
                'route' => 'admin.moderation',
                'access' => 'superadmin',
            ],
        ];
    }

    /**
     * Return modules filtered by role + maintenance flag.
     * NOTE: This is UI-level filtering only. Route protection is enforced separately.
     */
    public static function modulesForRole(string $role, bool $maintenanceEnabled = false): array
    {
        $role = mb_strtolower(trim((string) $role));

        $isSuperadminRole = ($role === 'superadmin');
        $isStaffRole = in_array($role, ['admin', 'superadmin', 'moderator'], true);

        $modules = self::registry();
        $out = [];

        foreach ($modules as $key => $module) {
            $access = (string) ($module['access'] ?? 'staff');

            if ($access === 'superadmin' && !$isSuperadminRole) {
                continue;
            }

            if ($access === 'staff' && !$isStaffRole) {
                continue;
            }

            $out[$key] = $module;
        }

        return $out;
    }

    /**
     * Canonical list of valid section keys.
     * Used for fail-closed validation.
     */
    public static function validSectionKeys(): array
    {
        return array_keys(self::registry());
    }
}