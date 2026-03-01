<?php

namespace App\Services\Security;

use App\Models\SecuritySetting;
use Illuminate\Support\Facades\DB;

class SecuritySettingsService
{
    public function get(): SecuritySetting
    {
        return DB::transaction(function (): SecuritySetting {
            $first = SecuritySetting::query()->lockForUpdate()->orderBy('id')->first();

            if (!$first) {
                return SecuritySetting::query()->create($this->defaults());
            }

            SecuritySetting::query()
                ->where('id', '!=', $first->id)
                ->delete();

            $changed = false;

            foreach ($this->defaults() as $key => $defaultValue) {
                if ($first->{$key} === null) {
                    $first->{$key} = $defaultValue;
                    $changed = true;
                }
            }

            if ($changed) {
                $first->save();
                $first->refresh();
            }

            return $first;
        });
    }

    /**
     * @return array<string, int|bool>
     */
    private function defaults(): array
    {
        return [
            'login_attempt_limit' => 8,
            'lockout_seconds' => 900,
            'ip_autoban_enabled' => false,
            'ip_autoban_fail_threshold' => 100,
            'ip_autoban_seconds' => 3600,
            'admin_stricter_limits_enabled' => true,
            'stepup_required_enabled' => true,
        ];
    }
}
