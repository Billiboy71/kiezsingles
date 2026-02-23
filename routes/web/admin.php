<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin.php
// Purpose: Admin routes (single backend; admin-only access; single source of truth)
// Changed: 22-02-2026 23:28 (Europe/Berlin)
// Version: 5.0
// ============================================================================

use App\Http\Controllers\Admin\AdminUserController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Admin Backend (Single Source of Truth)
|--------------------------------------------------------------------------
|
| Ziel:
| - EIN Backend unter /admin
| - Jede Section genau einmal registriert
| - Middleware nur im Gruppen-Wrapper
| - Keine versteckten Doppel-Definitionen
|
| Rollenmodell (serverseitig):
| - staff: admin + superadmin + moderator
| - superadmin: nur superadmin
|
| Sections:
| - overview + tickets: staff + section:*
| - moderation/maintenance/debug/roles: superadmin + section:*
|   (settings + noteinstieg laufen unter maintenance)
|
*/

/*
|--------------------------------------------------------------------------
| Staff Backend (Moderator darf hier rein)
|--------------------------------------------------------------------------
| Globaler Middleware-Stack:
| - auth
| - staff
| - section:*
*/
Route::prefix('admin')->name('admin.')->middleware(['auth', 'staff'])->group(function () {

    /*
     |--------------------------------------------------------------
     | Übersicht (Section: overview)  /admin
     |--------------------------------------------------------------
     */
    Route::middleware(['section:overview'])->group(function () {
        require __DIR__ . '/admin/home.php';
    });

    /*
     |--------------------------------------------------------------
     | Tickets (Section: tickets)  /admin/tickets/...
     |--------------------------------------------------------------
     */
    Route::middleware(['section:tickets'])->group(function () {
        require __DIR__ . '/admin/tickets.php';
    });
});

/*
|--------------------------------------------------------------------------
| Superadmin Backend (Admin + Moderator gesperrt)
|--------------------------------------------------------------------------
| Globaler Middleware-Stack:
| - auth
| - superadmin
| - section:*
|
| NOTE:
| - 'staff' ist hier bewusst NICHT mehr enthalten (redundant),
|   da superadmin bereits eine Teilmenge von staff ist.
*/
Route::prefix('admin')->name('admin.')->middleware(['auth', 'superadmin'])->group(function () {

    /*
     |--------------------------------------------------------------
     | Debug (Section: debug)  /admin/debug/...
     |--------------------------------------------------------------
     */
    Route::middleware(['section:debug'])->group(function () {

        // Infrastruktur / Status (Debug-only)
        require __DIR__ . '/admin/status.php';

        require __DIR__ . '/admin/debug.php';
    });

    /*
     |--------------------------------------------------------------
     | Moderation (Section: moderation)  /admin/moderation/...
     |--------------------------------------------------------------
     */
    Route::middleware(['section:moderation'])->group(function () {
        require __DIR__ . '/admin/moderation.php';
    });

    /*
     |--------------------------------------------------------------
     | Wartung / Settings / Noteinstieg (Section: maintenance)  /admin/maintenance/...
     |--------------------------------------------------------------
     */
    Route::middleware(['section:maintenance'])->group(function () {
        require __DIR__ . '/admin/maintenance_eta.php';

        require __DIR__ . '/admin/settings_ajax.php';

        require __DIR__ . '/admin/noteinstieg_recovery_ajax.php';
    });

    /*
     |--------------------------------------------------------------
     | Governance: Roles/Users (Section: roles) /admin/roles/...
     |--------------------------------------------------------------
     */
    Route::middleware(['section:roles'])->group(function () {
        Route::post('roles/set-role', [AdminUserController::class, 'setRole'])
            ->name('roles.set_role');

        Route::post('roles/delete-user', [AdminUserController::class, 'deleteUser'])
            ->name('roles.delete_user');
    });
});