<?php

use App\Http\Controllers\ContactController;
use App\Http\Controllers\DistrictPostcodeController;
use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

require __DIR__ . '/auth.php';
Route::get('/__whoami', fn () => base_path());
/*
|--------------------------------------------------------------------------
| DEBUG: Beweis, dass web.php geladen wird
|--------------------------------------------------------------------------
| Diese Route ist NUR zum Testen.
| URL: http://127.0.0.1:8000/__web_loaded
*/
Route::get('/__web_loaded', fn () => 'WEB ROUTES LOADED: ' . base_path());

/*
|--------------------------------------------------------------------------
| Public Routes
|--------------------------------------------------------------------------
*/
Route::get('/', function () {
    if (auth()->check()) {
        return redirect('/profile');
    }

    return view('home');
})->name('home');

Route::get('/dashboard', function () {
    return view('dashboard');
})->middleware(['auth', 'verified'])->name('dashboard');

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

/*
|--------------------------------------------------------------------------
| Authenticated Routes
|--------------------------------------------------------------------------
*/
Route::middleware('auth')->group(function () {
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
});

/*
|--------------------------------------------------------------------------
| Auth Routes (Login / Register / Password / Verify)
|--------------------------------------------------------------------------
*/

