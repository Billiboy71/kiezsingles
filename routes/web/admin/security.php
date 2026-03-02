<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\security.php
// Purpose: Admin Security routes (overview, events, bans, settings)
// Changed: 02-03-2026 14:00 (Europe/Berlin)
// Version: 0.2
// ============================================================================

use App\Http\Controllers\Admin\AdminSecurityController;
use Illuminate\Support\Facades\Route;

Route::get('security', [AdminSecurityController::class, 'overview'])
    ->name('security.overview');

Route::get('security/events', [AdminSecurityController::class, 'events'])
    ->name('security.events.index');

Route::post('security/events/purge', [AdminSecurityController::class, 'purgeEvents'])
    ->middleware('ensure.admin.stepup')
    ->name('security.events.purge');

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

Route::get('security/device-bans', [AdminSecurityController::class, 'deviceBans'])
    ->name('security.device_bans.index');

Route::post('security/device-bans', [AdminSecurityController::class, 'storeDeviceBan'])
    ->name('security.device_bans.store');

Route::delete('security/device-bans/{id}', [AdminSecurityController::class, 'destroyDeviceBan'])
    ->name('security.device_bans.destroy');

Route::get('security/settings', [AdminSecurityController::class, 'editSettings'])
    ->name('security.settings.edit');

Route::put('security/settings', [AdminSecurityController::class, 'updateSettings'])
    ->middleware('ensure.admin.stepup')
    ->name('security.settings.update');
