<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\SecurityAllowlistService.php
// Purpose: Central SSOT matcher for autoban allowlist exclusions
// Created: 09-03-2026 (Europe/Berlin)
// Changed: 09-03-2026 04:14 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Services\Security;

use App\Models\SecurityAllowlistEntry;
use Illuminate\Support\Str;

class SecurityAllowlistService
{
    /**
     * @return array{entry_id:int|null,type:string,value:string,autoban_only:bool,source:string}|null
     */
    public function matchForContext(?string $ip = null, ?string $deviceHash = null, ?string $identity = null): ?array
    {
        $ipNormalized = $this->normalize('ip', $ip);
        if ($ipNormalized !== null) {
            $ipMatch = $this->matchByType('ip', $ipNormalized);
            if ($ipMatch !== null) {
                return $ipMatch;
            }
        }

        $deviceNormalized = $this->normalize('device', $deviceHash);
        if ($deviceNormalized !== null) {
            $deviceMatch = $this->matchByType('device', $deviceNormalized);
            if ($deviceMatch !== null) {
                return $deviceMatch;
            }
        }

        $identityNormalized = $this->normalize('identity', $identity);
        if ($identityNormalized !== null) {
            $identityMatch = $this->matchByType('identity', $identityNormalized);
            if ($identityMatch !== null) {
                return $identityMatch;
            }
        }

        return null;
    }

    public function normalize(string $type, ?string $value): ?string
    {
        $normalized = trim((string) $value);
        if ($normalized === '') {
            return null;
        }

        if (in_array($type, ['ip', 'device', 'identity'], true)) {
            return mb_strtolower($normalized);
        }

        return $normalized;
    }

    /**
     * @return array{entry_id:int|null,type:string,value:string,autoban_only:bool,source:string}|null
     */
    private function matchByType(string $type, string $candidate): ?array
    {
        if ($type === 'ip' && app()->environment('local') && in_array($candidate, ['::1', '127.0.0.1'], true)) {
            return [
                'entry_id' => null,
                'type' => 'ip',
                'value' => $candidate,
                'autoban_only' => true,
                'source' => 'env_local_default',
            ];
        }

        $entries = SecurityAllowlistEntry::query()
            ->type($type)
            ->active()
            ->orderBy('id')
            ->get();

        foreach ($entries as $entry) {
            $storedValue = $this->normalize($type, (string) $entry->value);
            if ($storedValue === null) {
                continue;
            }

            if ($this->valueMatches($storedValue, $candidate)) {
                return [
                    'entry_id' => (int) $entry->id,
                    'type' => $type,
                    'value' => $storedValue,
                    'autoban_only' => (bool) $entry->autoban_only,
                    'source' => 'db',
                ];
            }
        }

        return null;
    }

    private function valueMatches(string $storedValue, string $candidate): bool
    {
        if (str_contains($storedValue, '*')) {
            return Str::is($storedValue, $candidate);
        }

        return hash_equals($storedValue, $candidate);
    }
}
