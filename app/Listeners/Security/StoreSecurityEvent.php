<?php

namespace App\Listeners\Security;

use App\Events\Security\SecurityEventTriggered;
use App\Models\SecurityEvent;
use Illuminate\Support\Facades\RateLimiter;

class StoreSecurityEvent
{
    public function handle(SecurityEventTriggered $event): void
    {
        if ($event->type === 'ip_blocked' && $event->ip !== null) {
            $key = 'security:event:ip_blocked:'.strtolower($event->ip);

            if (RateLimiter::tooManyAttempts($key, 1)) {
                return;
            }

            RateLimiter::hit($key, 60);
        }

        SecurityEvent::query()->create([
            'type' => $event->type,
            'ip' => $event->ip,
            'user_id' => $event->userId,
            'email' => $event->email,
            'device_hash' => $event->deviceHash,
            'meta' => $event->meta,
        ]);
    }
}
