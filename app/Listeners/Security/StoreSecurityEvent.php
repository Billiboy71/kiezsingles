<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\Security\StoreSecurityEvent.php
// Purpose: Persist SecurityEventTriggered events into security_events (with minimal de-duplication)
// Changed: 01-03-2026 23:18 (Europe/Berlin)
// Version: 0.1
// ============================================================================

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

        if ($event->type === 'login_failed' && $event->ip !== null) {
            $key = 'security:event:login_failed:'
                .strtolower($event->ip)
                .':'.($event->email !== null && trim($event->email) !== '' ? strtolower(trim($event->email)) : '-');

            if (RateLimiter::tooManyAttempts($key, 1)) {
                return;
            }

            // De-dupe short bursts (some flows may fire multiple Failed events per single attempt)
            RateLimiter::hit($key, 2);
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