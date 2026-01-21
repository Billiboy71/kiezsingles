<?php

namespace App\Listeners;

use App\Models\SecurityEvent;
use Illuminate\Auth\Events\PasswordReset;
use App\Models\SecurityEvent as SecurityEventModel;

class LogPasswordResetCompleted
{
    public function handle(PasswordReset $event): void
    {
        SecurityEventModel::create([
            'user_id' => $event->user->id ?? null,
            'event_type' => 'password_reset_completed',
            'ip' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'metadata' => [],
        ]);
    }
}
