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
        static $hit = 0;
        $hit++;

        $trace = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 20);

        $traceSlim = [];
        foreach ($trace as $frame) {
            $traceSlim[] = [
                'file'     => $frame['file'] ?? null,
                'line'     => $frame['line'] ?? null,
                'function' => $frame['function'] ?? null,
                'class'    => $frame['class'] ?? null,
            ];
        }

        logger()->info('DEBUG REGISTERED EVENT FIRED', [
            'hit'     => $hit,
            'user_id' => $event->user->id ?? null,
            'email'   => $event->user->email ?? null,
            'ts'      => now()->toDateTimeString(),
            'pid'     => getmypid(),
            'trace'   => $traceSlim,
        ]);
    }
}
