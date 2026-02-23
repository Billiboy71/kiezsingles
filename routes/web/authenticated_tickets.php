<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\authenticated_tickets.php
// Purpose: User ticket routes (report + support).
// Changed: 11-02-2026 23:58 (Europe/Berlin)
// Version: 0.2
// ============================================================================

use App\Models\Ticket;
use App\Models\TicketMessage;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;

/*
|--------------------------------------------------------------------------
| Authenticated Ticket Routes (User)
|--------------------------------------------------------------------------
*/

Route::middleware(['auth', 'verified'])->group(function () {

    // List own tickets
    Route::get('/tickets', function () {
        $tickets = Ticket::where('created_by_user_id', auth()->id())
            ->orderByDesc('created_at')
            ->limit(100)
            ->get();

        return response()->json([
            'ok' => true,
            'tickets' => $tickets,
        ]);
    })->name('tickets.index');

    // Show own ticket by public_id (with messages)
    Route::get('/tickets/{publicId}', function (string $publicId) {
        $publicId = trim($publicId);

        if ($publicId === '' || strlen($publicId) > 64) {
            return response()->json(['ok' => false, 'message' => 'invalid ticket id'], 422);
        }

        $ticket = Ticket::where('public_id', $publicId)
            ->where('created_by_user_id', auth()->id())
            ->first();

        if (!$ticket) {
            return response()->json(['ok' => false, 'message' => 'not found'], 404);
        }

        $ticket->load('messages');

        return response()->json([
            'ok' => true,
            'ticket' => $ticket,
        ]);
    })->name('tickets.show');

    // Reply to own ticket by public_id
    Route::post('/tickets/{publicId}/reply', function (string $publicId, \Illuminate\Http\Request $request) {
        $publicId = trim($publicId);

        if ($publicId === '' || strlen($publicId) > 64) {
            return response()->json(['ok' => false, 'message' => 'invalid ticket id'], 422);
        }

        $ticket = Ticket::where('public_id', $publicId)
            ->where('created_by_user_id', auth()->id())
            ->first();

        if (!$ticket) {
            return response()->json(['ok' => false, 'message' => 'not found'], 404);
        }

        if ((string) ($ticket->status ?? '') === 'closed') {
            return response()->json(['ok' => false, 'message' => 'ticket closed'], 422);
        }

        $request->validate([
            'message' => ['required', 'string', 'min:2'],
        ]);

        $msg = (string) $request->input('message', '');

        TicketMessage::create([
            'ticket_id' => $ticket->id,
            'actor_type' => 'user',
            'actor_user_id' => auth()->id(),
            'message' => $msg,
            'is_internal' => false,
        ]);

        if ((string) ($ticket->status ?? '') === 'open') {
            $ticket->update(['status' => 'in_progress']);
        }

        return response()->json(['ok' => true]);
    })->name('tickets.reply');

    // Create support ticket
    Route::post('/tickets/support', function (\Illuminate\Http\Request $request) {
        $request->validate([
            'subject' => ['required', 'string', 'max:191'],
            'message' => ['required', 'string', 'min:10'],
        ]);

        $subject = (string) $request->input('subject', '');
        $message = (string) $request->input('message', '');

        $ticket = Ticket::create([
            'public_id' => (string) Str::uuid(),
            'type' => 'support',
            'status' => 'open',
            'subject' => $subject,
            'message' => $message,
            'created_by_user_id' => auth()->id(),
            'reported_user_id' => null,
        ]);

        TicketMessage::create([
            'ticket_id' => $ticket->id,
            'actor_type' => 'user',
            'actor_user_id' => auth()->id(),
            'message' => $message,
            'is_internal' => false,
        ]);

        return response()->json(['ok' => true, 'public_id' => $ticket->public_id]);
    })->name('tickets.support.create');

    // Create report ticket (report a user)
    Route::post('/tickets/report/{user}', function (\App\Models\User $user, \Illuminate\Http\Request $request) {
        if ($user->id === auth()->id()) {
            return response()->json(['ok' => false, 'message' => 'self report not allowed'], 422);
        }

        $request->validate([
            'message' => ['required', 'string', 'min:10'],
        ]);

        $message = (string) $request->input('message', '');

        $ticket = Ticket::create([
            'public_id' => (string) Str::uuid(),
            'type' => 'report',
            'status' => 'open',
            'subject' => 'Meldung',
            'message' => $message,
            'created_by_user_id' => auth()->id(),
            'reported_user_id' => $user->id,
        ]);

        TicketMessage::create([
            'ticket_id' => $ticket->id,
            'actor_type' => 'user',
            'actor_user_id' => auth()->id(),
            'message' => $message,
            'is_internal' => false,
        ]);

        return response()->json(['ok' => true, 'public_id' => $ticket->public_id]);
    })->name('tickets.report.create');

});
