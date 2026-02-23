<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\public.php
// Purpose: Public routes
// Changed: 13-02-2026 01:10 (Europe/Berlin)
// Version: 0.2
// ============================================================================

use App\Http\Controllers\ContactController;
use App\Http\Controllers\DistrictPostcodeController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Public Routes
|--------------------------------------------------------------------------
*/
Route::get('/', function () {
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
