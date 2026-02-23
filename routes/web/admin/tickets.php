<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\tickets.php
// Purpose: Admin ticket inbox + detail + actions.
// Changed: 20-02-2026 02:15 (Europe/Berlin)
// Version: 1.2
// ============================================================================

use App\Http\Controllers\Admin\AdminTicketController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Admin Ticket Routes
|--------------------------------------------------------------------------
| Erwartung:
| - Wird innerhalb routes/web/admin.php geladen.
| - Absicherung erfolgt ausschließlich dort über:
|     prefix('admin')
|     middleware(['auth','staff'])
|     + Section-Middleware wird ausschließlich im zentralen Admin-Router gesetzt.
|
| Struktur-Vorbereitung:
| - Route-Defaults setzen, damit Views/Controller zentral den Admin-Tab ableiten können.
| - Keine DB-Toggles, keine Middleware-Änderungen, keine UI.
*/

Route::get('/tickets', [AdminTicketController::class, 'index'])
    ->defaults('adminTab', 'tickets')
    ->name('tickets.index');

Route::get('/tickets/{ticket}', [AdminTicketController::class, 'show'])
    ->defaults('adminTab', 'tickets')
    ->name('tickets.show');

Route::post('/tickets/{ticket}/reply', [AdminTicketController::class, 'reply'])
    ->defaults('adminTab', 'tickets')
    ->name('tickets.reply');

Route::post('/tickets/{ticket}/close', [AdminTicketController::class, 'close'])
    ->defaults('adminTab', 'tickets')
    ->name('tickets.close');

// B3 – Meta Update (assign/category/priority/status)
Route::post('/tickets/{ticket}/update-meta', [AdminTicketController::class, 'updateMeta'])
    ->defaults('adminTab', 'tickets')
    ->name('tickets.updateMeta');

// B3b – Draft / Autosave (server-side, user-invisible)
// - Drafts erzeugen KEINE TicketMessages und triggern keine Reply-Events.
// - Persistenz wird serverseitig entschieden (DB-Spalten oder ticket_drafts-Tabelle, falls vorhanden).
Route::post('/tickets/{ticket}/draft-save', [AdminTicketController::class, 'draftSave'])
    ->defaults('adminTab', 'tickets')
    ->name('tickets.draftSave');

// B4 – Moderation Quick Actions (report tickets)
Route::post('/tickets/{ticket}/moderate/warn', [AdminTicketController::class, 'moderateWarn'])
    ->defaults('adminTab', 'tickets')
    ->name('tickets.moderate.warn');

Route::post('/tickets/{ticket}/moderate/temp-ban', [AdminTicketController::class, 'moderateTempBan'])
    ->defaults('adminTab', 'tickets')
    ->name('tickets.moderate.tempBan');

Route::post('/tickets/{ticket}/moderate/perm-ban', [AdminTicketController::class, 'moderatePermBan'])
    ->defaults('adminTab', 'tickets')
    ->name('tickets.moderate.permBan');

Route::post('/tickets/{ticket}/moderate/unfounded', [AdminTicketController::class, 'moderateUnfounded'])
    ->defaults('adminTab', 'tickets')
    ->name('tickets.moderate.unfounded');