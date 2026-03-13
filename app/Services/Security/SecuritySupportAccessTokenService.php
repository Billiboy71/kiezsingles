<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\SecuritySupportAccessTokenService.php
// Purpose: Central SSOT service to issue/reuse security support access tokens by case key.
// Created: 09-03-2026 (Europe/Berlin)
// Changed: 09-03-2026 01:34 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Services\Security;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SecuritySupportAccessTokenService
{
    /**
     * @return array{plain_token: string, support_reference: string}
     */
    public function issueForCase(
        string $caseKey,
        string $securityEventType,
        string $sourceContext,
        ?string $contactEmail = null,
        ?string $preferredSupportReference = null
    ): array {
        return DB::transaction(function () use (
            $caseKey,
            $securityEventType,
            $sourceContext,
            $contactEmail,
            $preferredSupportReference
        ): array {
            $now = Carbon::now();

            $existingToken = DB::table('security_support_access_tokens')
                ->select(['id', 'support_reference'])
                ->where('case_key', $caseKey)
                ->whereNull('consumed_at')
                ->where('expires_at', '>', $now)
                ->orderByDesc('id')
                ->lockForUpdate()
                ->first();

            $plainToken = Str::random(64);
            $tokenHash = hash('sha256', $plainToken);

            if ($existingToken !== null) {
                DB::table('security_support_access_tokens')
                    ->where('id', (int) $existingToken->id)
                    ->update([
                        'token_hash' => $tokenHash,
                        'contact_email' => $contactEmail,
                        'updated_at' => $now,
                    ]);

                return [
                    'plain_token' => $plainToken,
                    'support_reference' => (string) $existingToken->support_reference,
                ];
            }

            $supportReference = trim((string) ($preferredSupportReference ?? ''));
            if ($supportReference === '') {
                $supportReference = 'SEC-'.Str::upper(Str::random(random_int(6, 8)));
            }

            DB::table('security_support_access_tokens')->insert([
                'token_hash' => $tokenHash,
                'support_reference' => $supportReference,
                'security_event_type' => $securityEventType,
                'source_context' => $sourceContext,
                'case_key' => $caseKey,
                'contact_email' => $contactEmail,
                'expires_at' => $now->copy()->addMinutes(30),
                'consumed_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            return [
                'plain_token' => $plainToken,
                'support_reference' => $supportReference,
            ];
        });
    }
}
