<?php

// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Support\KsMaintenance.php
// Purpose: Maintenance SSOT helper (reads maintenance_settings only, fail-closed)
// Created: 26-02-2026 22:41 (Europe/Berlin)
// Changed: 27-02-2026 18:44 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

final class KsMaintenance
{
    private static function row(): ?object
    {
        if (!Schema::hasTable('maintenance_settings')) {
            return null;
        }

        try {
            return DB::table('maintenance_settings')
                ->orderBy('id', 'asc')
                ->first();
        } catch (\Throwable $e) {
            return null;
        }
    }

    public static function enabled(): bool
    {
        $row = self::row();
        return $row ? ((int) ($row->enabled ?? 0) === 1) : false;
    }

    public static function showEta(): bool
    {
        $row = self::row();
        return $row ? ((int) ($row->show_eta ?? 0) === 1) : false;
    }

    public static function etaAt(): ?string
    {
        $row = self::row();
        if (!$row) {
            return null;
        }

        $value = $row->eta_at ?? null;
        if ($value === null) {
            return null;
        }

        $value = trim((string) $value);
        return $value !== '' ? $value : null;
    }

    public static function notifyEnabled(): bool
    {
        $row = self::row();
        return $row ? ((int) ($row->notify_enabled ?? 0) === 1) : false;
    }

    public static function allowAdmins(): bool
    {
        $row = self::row();
        return $row ? ((int) ($row->allow_admins ?? 0) === 1) : false;
    }

    public static function allowModerators(): bool
    {
        $row = self::row();
        return $row ? ((int) ($row->allow_moderators ?? 0) === 1) : false;
    }
}
