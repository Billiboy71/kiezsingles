<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\public.php
// Purpose: Public routes
// Changed: 28-02-2026 01:02 (Europe/Berlin)
// Version: 0.3
// ============================================================================

use App\Http\Controllers\ContactController;
use App\Http\Controllers\DistrictPostcodeController;
use App\Support\KsMaintenance;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Public Routes
|--------------------------------------------------------------------------
*/
Route::get('/', function () {
    // During maintenance, "/" must NEVER redirect to "/profile"
    // (otherwise loop: "/" -> "/profile" -> "/").
    if (KsMaintenance::enabled()) {
        return view('landing');
    }

    if (auth()->check()) {
        return redirect('/profile');
    }

    return view('landing');
})->name('home');

/*
|--------------------------------------------------------------------------
| Contact (öffentlich)
|--------------------------------------------------------------------------
*/
Route::get('/contact', [ContactController::class, 'create'])->name('contact.create');
Route::post('/contact', [ContactController::class, 'store'])->name('contact.store');

/*
|--------------------------------------------------------------------------
| AJAX: District → Postcodes
|--------------------------------------------------------------------------
*/
Route::get('/districts/{district}/postcodes', [DistrictPostcodeController::class, 'index'])
    ->name('district.postcodes');