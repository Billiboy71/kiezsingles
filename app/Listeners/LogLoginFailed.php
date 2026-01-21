<?php

namespace App\Listeners;

use App\Models\SecurityEvent;
use Illuminate\Auth\Events\Failed;

class LogLoginFailed
{
    public function handle(Failed $event): void
    {
        SecurityEvent::create([
            'user_id' => $event->user?->id,
            'event_type' => 'login_failed',
            'ip' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'metadata' => [
                'email' => request()->input('email'),
                'guard' => $event->guard,
            ],
        ]);
    }
}
