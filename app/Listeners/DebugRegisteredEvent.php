<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Listeners\DebugRegisteredEvent.php
// Purpose: Debug how often the Registered event is fired (temporary)
// ============================================================================

namespace App\Listeners;

use Illuminate\Auth\Events\Registered;

class DebugRegisteredEvent
{
    public function handle(Registered $event): void
    {
        logger()->info('DEBUG REGISTERED EVENT FIRED', [
            'user_id' => $event->user->id ?? null,
            'email'   => $event->user->email ?? null,
            'ts'      => now()->toDateTimeString(),
            'pid'     => getmypid(),
        ]);
    }
}
