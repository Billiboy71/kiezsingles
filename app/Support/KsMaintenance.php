<?php

// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Support\KsMaintenance.php
// Purpose: Maintenance SSOT helper (reads app_settings.maintenance_enabled, fail-closed)
// Created: 26-02-2026 22:41 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

final class KsMaintenance
{
    /**
     * Single Source of Truth: Wartungsmodus ist ausschließlich app_settings.maintenance_enabled.
     * Fail-closed: Bei fehlender Tabelle / fehlender Zeile / Fehlern => false.
     */
    public static function enabled(): bool
    {
        if (!Schema::hasTable('app_settings')) {
            return false;
        }

        try {
            // Erwartung: genau eine Konfig-Zeile (oder die erste)
            $value = DB::table('app_settings')
                ->orderBy('id', 'asc')
                ->value('maintenance_enabled');

            return ((int) $value === 1);
        } catch (\Throwable $e) {
            return false;
        }
    }
}