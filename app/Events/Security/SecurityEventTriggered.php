<?php

namespace App\Events\Security;

use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class SecurityEventTriggered
{
    use Dispatchable;
    use SerializesModels;

    /**
     * @param array<string, mixed> $meta
     */
    public function __construct(
        public readonly string $type,
        public readonly ?string $ip = null,
        public readonly ?int $userId = null,
        public readonly ?string $email = null,
        public readonly ?string $deviceHash = null,
        public readonly array $meta = [],
    ) {}
}
