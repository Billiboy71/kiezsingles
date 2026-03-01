<?php

use App\Http\Controllers\Admin\AdminSecurityController;
use Illuminate\Support\Facades\Route;

Route::get('security', [AdminSecurityController::class, 'overview'])
    ->name('security.overview');

Route::get('security/events', [AdminSecurityController::class, 'events'])
    ->name('security.events.index');

Route::get('security/ip-bans', [AdminSecurityController::class, 'ipBans'])
    ->name('security.ip_bans.index');

Route::post('security/ip-bans', [AdminSecurityController::class, 'storeIpBan'])
    ->name('security.ip_bans.store');

Route::delete('security/ip-bans/{id}', [AdminSecurityController::class, 'destroyIpBan'])
    ->name('security.ip_bans.destroy');

Route::get('security/identity-bans', [AdminSecurityController::class, 'identityBans'])
    ->name('security.identity_bans.index');

Route::post('security/identity-bans', [AdminSecurityController::class, 'storeIdentityBan'])
    ->name('security.identity_bans.store');

Route::delete('security/identity-bans/{id}', [AdminSecurityController::class, 'destroyIdentityBan'])
    ->name('security.identity_bans.destroy');

Route::get('security/settings', [AdminSecurityController::class, 'editSettings'])
    ->name('security.settings.edit');

Route::put('security/settings', [AdminSecurityController::class, 'updateSettings'])
    ->middleware('ensure.admin.stepup')
    ->name('security.settings.update');
