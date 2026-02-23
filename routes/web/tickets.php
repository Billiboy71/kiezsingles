<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\tickets.php
// Purpose: User ticket routes (report + support).
// Changed: 13-02-2026 00:06 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use App\Http\Controllers\UserTicketController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Authenticated Ticket Routes (User)
|--------------------------------------------------------------------------
*/

Route::middleware(['auth', 'verified'])->group(function () {

    // List own tickets
    Route::get('/tickets', [UserTicketController::class, 'index'])
        ->name('tickets.index');

    // Show own ticket by public_id (with messages)
    Route::get('/tickets/{publicId}', [UserTicketController::class, 'show'])
        ->name('tickets.show');

    // Reply to own ticket by public_id
    Route::post('/tickets/{publicId}/reply', [UserTicketController::class, 'reply'])
        ->name('tickets.reply');

    // Create support ticket
    Route::post('/tickets/support', [UserTicketController::class, 'createSupport'])
        ->name('tickets.support.create');

    // Create report ticket (report a user)
    Route::post('/tickets/report/{user}', [UserTicketController::class, 'createReport'])
        ->name('tickets.report.create');

});
