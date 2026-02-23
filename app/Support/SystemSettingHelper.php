<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Support\SystemSettingHelper.php
// Purpose: Central accessor for DB-backed system settings
// Changed: 19-02-2026 17:23 (Europe/Berlin)
// Version: 0.5
// ============================================================================

namespace App\Support;

use App\Models\SystemSetting;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

class SystemSettingHelper
{
    /**
     * Get raw setting value by key.
     */
    public static function get(string $key, $default = null): mixed
    {
        try {
            $setting = SystemSetting::where('key', $key)->first();
        } catch (\Throwable $e) {
            Log::error('SystemSettingHelper::get: DB access failed (returning default).', [
                'key' => $key,
                'exception' => get_class($e),
                'message' => $e->getMessage(),
            ]);

            return $default;
        }

        if (!$setting) {
            return $default;
        }

        return self::castValue($setting->value, $setting->cast, $default);
    }

    /**
     * Set a DB-backed setting value by key.
     *
     * - Arrays are stored as JSON with cast "json"
     * - Bool/int/string are stored with matching cast
     */
    public static function set(string $key, mixed $value, ?string $cast = null): void
    {
        $storedCast = $cast;

        if ($storedCast === null) {
            if (is_array($value)) {
                $storedCast = 'json';
            } elseif (is_bool($value)) {
                $storedCast = 'bool';
            } elseif (is_int($value)) {
                $storedCast = 'int';
            } else {
                $storedCast = 'string';
            }
        }

        $storedValue = $value;

        if ($storedCast === 'json') {
            if (!is_array($storedValue)) {
                $storedValue = [];
            }
            $storedValue = json_encode($storedValue);
        }

        if ($storedCast === 'bool') {
            $storedValue = ((bool) $storedValue) ? '1' : '0';
        }

        if ($storedCast === 'int') {
            $storedValue = (string) ((int) $storedValue);
        }

        if ($storedCast === 'string') {
            $storedValue = (string) $storedValue;
        }

        try {
            SystemSetting::updateOrCreate(
                ['key' => $key],
                ['value' => $storedValue, 'cast' => $storedCast]
            );
        } catch (\Throwable $e) {
            Log::error('SystemSettingHelper::set: DB access failed (setting not saved).', [
                'key' => $key,
                'cast' => $storedCast,
                'exception' => get_class($e),
                'message' => $e->getMessage(),
            ]);

            throw $e;
        }
    }

    /**
     * Convenience boolean getter (DB only).
     *
     * If the key is missing, returns the provided default.
     */
    public static function bool(string $key, bool $default = false): bool
    {
        $value = self::get($key, null);

        if ($value === null) {
            return $default;
        }

        return (bool) $value;
    }

    /**
     * Get a DB-backed debug toggle.
     *
     * Reads the boolean value from SystemSettings (key: debug.<name>).
     * If not present, falls back to the provided default.
     *
     * Intended for replacing former .env debug flags with DB-backed toggles.
     */
    public static function debugFlag(string $name, bool $default = false): bool
    {
        return self::bool('debug.' . $name, $default);
    }

    /**
     * Get a DB-backed debug toggle with fallback to config() value.
     *
     * Reads the boolean value from SystemSettings (key: debug.<name>).
     * If not present, falls back to the provided config value.
     */
    public static function debugBool(string $name, bool $configFallback): bool
    {
        $key = 'debug.' . $name;

        $value = self::get($key, null);

        if ($value === null) {
            return (bool) $configFallback;
        }

        return (bool) $value;
    }

    /**
     * Whether UI-debug output is allowed in the current environment.
     *
     * Default behavior:
     * - Allowed environments: local + staging
     *
     * Production "break-glass" (explicit):
     * - Allowed only if: debug.break_glass = true
     *
     * Additionally requires always:
     * - maintenance mode enabled (DB-driven app_settings)
     * - explicit DB toggle: debug.ui_enabled = true
     */
    public static function debugUiAllowed(): bool
    {
        $simulateProd = (bool) self::get('debug.simulate_production', false);

        // IMPORTANT SECURITY: simulate_production must never broaden access in non-production.
        // Effective-production gates are only relevant when the app is actually in production.
        $isProd = app()->environment('production');
        $isProdEffective = $isProd && $simulateProd;

        $isAllowedEnv = (!$isProd && app()->environment(['local', 'staging']))
            || ($isProdEffective && (bool) self::get('debug.break_glass', false))
            || ($isProd && (bool) self::get('debug.break_glass', false));

        if (!$isAllowedEnv) {
            return false;
        }

        try {
            if (!Schema::hasTable('app_settings')) {
                return false;
            }

            // Fail-closed: if maintenance column is missing, debug UI must be disabled.
            if (!Schema::hasColumn('app_settings', 'maintenance_enabled')) {
                return false;
            }

            $settings = DB::table('app_settings')->select(['maintenance_enabled'])->first();
        } catch (\Throwable $e) {
            Log::error('SystemSettingHelper::debugUiAllowed: DB access failed (disabling debug UI).', [
                'exception' => get_class($e),
                'message' => $e->getMessage(),
            ]);

            return false;
        }

        if (!$settings) {
            return false;
        }

        if (!(bool) $settings->maintenance_enabled) {
            return false;
        }

        // Default: AUS. Muss explizit im Backend per SystemSetting gesetzt werden.
        return (bool) self::get('debug.ui_enabled', false);
    }

    /**
     * Cast value based on stored cast type.
     */
    protected static function castValue($value, ?string $cast, $default): mixed
    {
        if ($value === null) {
            return $default;
        }

        return match ($cast) {
            'bool'   => (bool) ((int) $value),
            'int'    => (int) $value,
            'string' => (string) $value,
            'json'   => (is_array($tmp = json_decode((string) $value, true)) ? $tmp : $default),
            default  => $value,
        };
    }
}
