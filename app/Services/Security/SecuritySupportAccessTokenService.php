<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\SecuritySupportAccessTokenService.php
// Purpose: Central SSOT service to issue/reuse security support access tokens by case key.
// Created: 09-03-2026 (Europe/Berlin)
// Changed: 17-03-2026 01:23 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Services\Security;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
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
        $now = Carbon::now();
        $plainToken = Str::random(64);
        $tokenHash = hash('sha256', $plainToken);

        $supportReference = trim((string) ($preferredSupportReference ?? ''));
        if ($supportReference === '' || $this->referenceExists($supportReference)) {
            $supportReference = $this->generateUniqueSupportReference();
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
    }

    private function generateUniqueSupportReference(): string
    {
        do {
            $reference = 'SEC-'.Str::upper(Str::random(8));
        } while ($this->referenceExists($reference));

        return $reference;
    }

    private function referenceExists(string $reference): bool
    {
        if (Schema::hasTable('security_support_access_tokens')) {
            $supportReferenceExists = DB::table('security_support_access_tokens')
                ->where('support_reference', $reference)
                ->exists();

            if ($supportReferenceExists) {
                return true;
            }
        }

        if (
            Schema::hasTable('security_events')
            && Schema::hasColumn('security_events', 'reference')
        ) {
            return DB::table('security_events')
                ->where('reference', $reference)
                ->exists();
        }

        return false;
    }
}
