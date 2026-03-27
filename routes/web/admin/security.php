<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\security.php
// Purpose: Admin Security routes (overview, events, bans, settings)
// Changed: 25-03-2026 02:01 (Europe/Berlin)
// Version: 1.5
// ============================================================================

use App\Http\Controllers\Admin\AdminSecurityController;
use App\Http\Controllers\Admin\Security\IncidentController;
use Illuminate\Support\Facades\Route;

Route::get('security', [AdminSecurityController::class, 'overview'])
    ->name('security.overview');

Route::get('security/events', [AdminSecurityController::class, 'events'])
    ->name('security.events.index');

Route::get('security/ip-bans', [AdminSecurityController::class, 'ipBans'])
    ->name('security.ip_bans.index');

Route::post('security/ip-bans', [AdminSecurityController::class, 'storeIpBan'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.ip_bans.store');

Route::delete('security/ip-bans/{id}', [AdminSecurityController::class, 'destroyIpBan'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.ip_bans.destroy');

Route::get('security/identity-bans', [AdminSecurityController::class, 'identityBans'])
    ->name('security.identity_bans.index');

Route::post('security/identity-bans', [AdminSecurityController::class, 'storeIdentityBan'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.identity_bans.store');

Route::delete('security/identity-bans/{id}', [AdminSecurityController::class, 'destroyIdentityBan'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.identity_bans.destroy');

Route::get('security/device-bans', [AdminSecurityController::class, 'deviceBans'])
    ->name('security.device_bans.index');

Route::post('security/device-bans', [AdminSecurityController::class, 'storeDeviceBan'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.device_bans.store');

Route::post('security/incidents/{id}/apply-actions', [IncidentController::class, 'applyActions'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.incidents.applyActions');

Route::delete('security/incidents/{id}', [IncidentController::class, 'destroy'])
    ->name('security.incidents.destroy');

Route::post('security/incidents/bulk-delete', [IncidentController::class, 'bulkDelete'])
    ->name('security.incidents.bulkDelete');

Route::delete('security/device-bans/{id}', [AdminSecurityController::class, 'destroyDeviceBan'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.device_bans.destroy');

Route::get('security/allowlist/ip', [AdminSecurityController::class, 'allowlistIp'])
    ->name('security.allowlist.ip.index');

Route::post('security/allowlist/ip', [AdminSecurityController::class, 'storeAllowlistIp'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.allowlist.ip.store');

Route::patch('security/allowlist/ip/{id}', [AdminSecurityController::class, 'updateAllowlistIp'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.allowlist.ip.update');

Route::delete('security/allowlist/ip/{id}', [AdminSecurityController::class, 'destroyAllowlistIp'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.allowlist.ip.destroy');

Route::get('security/allowlist/device', [AdminSecurityController::class, 'allowlistDevice'])
    ->name('security.allowlist.device.index');

Route::post('security/allowlist/device', [AdminSecurityController::class, 'storeAllowlistDevice'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.allowlist.device.store');

Route::patch('security/allowlist/device/{id}', [AdminSecurityController::class, 'updateAllowlistDevice'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.allowlist.device.update');

Route::delete('security/allowlist/device/{id}', [AdminSecurityController::class, 'destroyAllowlistDevice'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.allowlist.device.destroy');

Route::get('security/allowlist/identity', [AdminSecurityController::class, 'allowlistIdentity'])
    ->name('security.allowlist.identity.index');

Route::post('security/allowlist/identity', [AdminSecurityController::class, 'storeAllowlistIdentity'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.allowlist.identity.store');

Route::patch('security/allowlist/identity/{id}', [AdminSecurityController::class, 'updateAllowlistIdentity'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.allowlist.identity.update');

Route::delete('security/allowlist/identity/{id}', [AdminSecurityController::class, 'destroyAllowlistIdentity'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.allowlist.identity.destroy');

Route::get('security/settings', [AdminSecurityController::class, 'editSettings'])
    ->name('security.settings.edit');

Route::put('security/settings', [AdminSecurityController::class, 'updateSettings'])
    ->middleware(['ensure.admin.stepup', 'password.confirm'])
    ->name('security.settings.update');
