<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Support\SystemSettingHelper.php
// Changed: 09-02-2026 00:40
// Purpose: Central accessor for DB-backed system settings
// ============================================================================

namespace App\Support;

use App\Models\SystemSetting;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class SystemSettingHelper
{
    /**
     * Get raw setting value by key.
     */
    public static function get(string $key, $default = null): mixed
    {
        $setting = SystemSetting::where('key', $key)->first();

        if (!$setting) {
            return $default;
        }

        return self::castValue($setting->value, $setting->cast, $default);
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

        $isProd = app()->environment('production');
        $isProdEffective = $isProd || $simulateProd;

        $isAllowedEnv = (!$isProdEffective && app()->environment(['local', 'staging']))
            || ($isProdEffective && (bool) self::get('debug.break_glass', false));

        if (!$isAllowedEnv) {
            return false;
        }

        if (!Schema::hasTable('app_settings')) {
            return false;
        }

        $settings = DB::table('app_settings')->select(['maintenance_enabled'])->first();

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
            default  => $value,
        };
    }
}
