<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\authenticated.php
// Purpose: Authenticated routes (non-admin)
// Changed: 12-02-2026 23:29 (Europe/Berlin)
// Version: 0.4
// ============================================================================

use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| User Profile (über public_id) – NUR für eingeloggte + verifizierte Nutzer
|--------------------------------------------------------------------------
*/
Route::get('/u/{user}', [ProfileController::class, 'show'])
    ->middleware(['auth', 'verified'])
    ->name('profile.show');

Route::get('/dashboard', function () {
    return view('dashboard');
})->middleware(['auth', 'verified'])->name('dashboard');

/*
|--------------------------------------------------------------------------
| Authenticated Routes
|--------------------------------------------------------------------------
*/
Route::middleware(['auth', 'verified'])->group(function () {

    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
});

/*
|--------------------------------------------------------------------------
| Ticket System (User: Support + Reports)
|--------------------------------------------------------------------------
*/
require __DIR__ . '/tickets.php';
