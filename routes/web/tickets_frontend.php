<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\tickets_frontend.php
// Purpose: Minimal frontend routes for support + report tickets (dev-ready).
// Changed: 19-02-2026 18:45 (Europe/Berlin)
// Version: 0.2
// ============================================================================

use App\Models\User;
use App\Services\TicketService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::middleware('auth')->group(function () {

    /*
    |--------------------------------------------------------------------------
    | Support Ticket (User)
    |--------------------------------------------------------------------------
    */

    Route::get('/support', function (Request $request) {
        $sent = (string) $request->query('sent', '') === '1';

        return view('tickets.support', [
            'sent' => $sent,
        ]);
    });

    Route::post('/support', function (Request $request, TicketService $ticketService) {

        $validated = $request->validate([
            'subject' => ['required', 'string', 'min:2', 'max:200'],
            'message' => ['required', 'string', 'min:2', 'max:5000'],
        ]);

        $ticketService->createSupportTicket(
            (int) auth()->id(),
            (string) $validated['subject'],
            (string) $validated['message']
        );

        return redirect('/support?sent=1');
    });


    /*
    |--------------------------------------------------------------------------
    | Report User (User)
    |--------------------------------------------------------------------------
    */

    Route::get('/report/{user}', function (User $user, Request $request) {

        if ((int) $user->id === (int) auth()->id()) {
            abort(403);
        }

        $sent = (string) $request->query('sent', '') === '1';

        return view('tickets.report', [
            'user' => $user,
            'sent' => $sent,
        ]);
    });

    Route::post('/report/{user}', function (User $user, Request $request, TicketService $ticketService) {

        if ((int) $user->id === (int) auth()->id()) {
            abort(403);
        }

        $validated = $request->validate([
            'message' => ['required', 'string', 'min:2', 'max:5000'],
        ]);

        $ticketService->createReportTicket(
            (int) auth()->id(),
            $user,
            (string) $validated['message']
        );

        return redirect('/report/' . $user->public_id . '?sent=1');
    });

});
