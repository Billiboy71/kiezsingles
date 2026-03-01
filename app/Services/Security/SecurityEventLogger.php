<?php

namespace App\Services\Security;

use App\Events\Security\SecurityEventTriggered;

class SecurityEventLogger
{
    /**
     * @param array<string, mixed> $meta
     */
    public function log(
        string $type,
        ?string $ip = null,
        ?int $userId = null,
        ?string $email = null,
        ?string $deviceHash = null,
        array $meta = [],
    ): void {
        event(new SecurityEventTriggered(
            type: $type,
            ip: $ip,
            userId: $userId,
            email: $email,
            deviceHash: $deviceHash,
            meta: $meta,
        ));
    }
}
