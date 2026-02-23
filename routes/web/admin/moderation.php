<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\moderation.php
// Purpose: Admin moderation routes (configure moderator/admin section whitelist in DB)
// Changed: 23-02-2026 00:43 (Europe/Berlin)
// Version: 1.7
// ============================================================================

use App\Models\SystemSetting;
use App\Models\User;
use App\Support\Admin\AdminSectionAccess;
use App\Support\SystemSettingHelper;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

/*
|--------------------------------------------------------------------------
| Admin: Moderation (Rechteverwaltung)
|--------------------------------------------------------------------------
| - Zugriff wird über routes/web/admin.php erzwungen (auth + superadmin + section:moderation).
| - Pro User speichern (SystemSetting-Key pro User):
|     moderation.moderator_sections.user_{id}
|     moderation.admin_sections.user_{id}
| - Backward-Compat Read:
|     moderation.moderator_sections (global) wird gelesen, falls per-user key leer ist (moderator).
|     moderation.admin_sections (global) wird gelesen, falls per-user key leer ist (admin).
|
| Erwartung:
| - Datei wird innerhalb von routes/web/admin.php in einem
|   Route::prefix('admin')->name('admin.')->group(...) eingebunden.
|
*/

Route::get('/moderation', function (Request $request) {

    $hasSystemSettingsTable = Schema::hasTable('system_settings');
    $hasUsersTable = Schema::hasTable('users');

    $hasUserNameColumn = false;
    $hasUserUsernameColumn = false;

    if ($hasUsersTable) {
        try {
            $hasUserNameColumn = Schema::hasColumn('users', 'name');
        } catch (\Throwable $e) {
            $hasUserNameColumn = false;
        }

        try {
            $hasUserUsernameColumn = Schema::hasColumn('users', 'username');
        } catch (\Throwable $e) {
            $hasUserUsernameColumn = false;
        }
    }

    $defaultModerator = AdminSectionAccess::defaultModeratorSections();
    $notice = session('admin_notice');

    $targetRole = $request->query('role', 'moderator');
    if (is_string($targetRole)) {
        $targetRole = mb_strtolower(trim($targetRole));
    } else {
        $targetRole = 'moderator';
    }
    if ($targetRole !== 'admin') {
        $targetRole = 'moderator';
    }

    $roleLabel = ($targetRole === 'admin') ? 'Admin' : 'Moderator';

    // Only sections that can ever be granted for the selected role.
    // Server-side enforcement happens exclusively via middleware (auth + staff/superadmin + section:*).
    if ($targetRole === 'admin') {
        $options = [
            AdminSectionAccess::SECTION_OVERVIEW => 'Übersicht',
            AdminSectionAccess::SECTION_TICKETS => 'Tickets',
        ];
        $default = array_values(array_unique(array_keys($options)));
    } else {
        $options = [
            AdminSectionAccess::SECTION_OVERVIEW => 'Übersicht',
            AdminSectionAccess::SECTION_TICKETS => 'Tickets',
            // admin-only (absichtlich NICHT auswählbar für Moderatoren):
            // maintenance, debug, moderation
        ];
        $default = $defaultModerator;
    }

    $users = [];
    $selectedUserId = null;

    if ($hasUsersTable) {
        $selectCols = ['id', 'email', 'role'];
        if ($hasUserNameColumn) {
            $selectCols[] = 'name';
        }
        if ($hasUserUsernameColumn) {
            $selectCols[] = 'username';
        }

        $query = User::query()
            ->whereRaw('LOWER(TRIM(COALESCE(role, ""))) = ?', [$targetRole]);

        if ($hasUserNameColumn) {
            $query->orderBy('name');
        } elseif ($hasUserUsernameColumn) {
            $query->orderBy('username');
        } else {
            $query->orderBy('email');
        }

        $users = $query
            ->orderBy('id')
            ->get($selectCols)
            ->all();

        $selectedUserId = $request->query('user_id');
        if (is_string($selectedUserId)) {
            $selectedUserId = trim($selectedUserId);
        }
        if (is_numeric($selectedUserId)) {
            $selectedUserId = (int) $selectedUserId;
        } else {
            $selectedUserId = null;
        }

        if ($selectedUserId === null && count($users) > 0) {
            $selectedUserId = (int) $users[0]->id;
        }

        if ($selectedUserId !== null) {
            $found = false;
            foreach ($users as $u) {
                if ((int) $u->id === (int) $selectedUserId) {
                    $found = true;
                    break;
                }
            }
            if (!$found) {
                $selectedUserId = count($users) > 0 ? (int) $users[0]->id : null;
            }
        }
    }

    $current = $default;

    if ($hasSystemSettingsTable) {
        $rawValue = null;

        if ($selectedUserId !== null) {
            if ($targetRole === 'admin') {
                $perUserKey = 'moderation.admin_sections.user_' . (string) $selectedUserId;
            } else {
                $perUserKey = 'moderation.moderator_sections.user_' . (string) $selectedUserId;
            }
            $rawValue = SystemSettingHelper::get($perUserKey, '');
        }

        // Backward-compat: fall back to old global key if per-user is empty
        $isEmpty =
            $rawValue === null
            || $rawValue === ''
            || (is_array($rawValue) && count($rawValue) < 1);

        if ($isEmpty) {
            if ($targetRole === 'admin') {
                $rawValue = SystemSettingHelper::get('moderation.admin_sections', '');
            } else {
                $rawValue = SystemSettingHelper::get('moderation.moderator_sections', '');
            }
        }

        // SystemSettingHelper::get kann je nach "cast" bereits ein Array liefern.
        $decoded = null;

        if (is_array($rawValue)) {
            $decoded = $rawValue;
        } elseif (is_string($rawValue)) {
            $raw = trim($rawValue);
            if ($raw !== '') {
                $tmp = json_decode($raw, true);
                if (is_array($tmp)) {
                    $decoded = $tmp;
                }
            }
        } elseif ($rawValue !== null) {
            $raw = trim((string) $rawValue);
            if ($raw !== '') {
                $tmp = json_decode($raw, true);
                if (is_array($tmp)) {
                    $decoded = $tmp;
                }
            }
        }

        if (is_array($decoded)) {
            $tmp = [];
            $allowedKeys = array_values(array_unique(array_keys($options)));

            foreach ($decoded as $s) {
                if (!is_string($s)) {
                    continue;
                }
                $s = trim($s);
                if ($s === '' || strlen($s) > 64) {
                    continue;
                }
                if (!preg_match('/^[a-z0-9_]+$/', $s)) {
                    continue;
                }

                if (!in_array($s, $allowedKeys, true)) {
                    continue;
                }

                $tmp[] = $s;
            }

            $tmp = array_values(array_unique($tmp));
            if (count($tmp) > 0) {
                $current = $tmp;
            }
        }
    }

    $localRouteDebug = null;
    if (app()->isLocal()) {
        $currentRoute = Route::current();
        $localRouteDebug = [
            'route_name' => Route::currentRouteName(),
            'url' => url()->current(),
            'middleware' => $currentRoute ? (array) ($currentRoute->gatherMiddleware() ?? []) : [],
        ];
    }

    return view('admin.moderation', [
        'tab' => 'moderation',
        'adminTab' => 'moderation',
        'notice' => $notice,
        'hasSystemSettingsTable' => $hasSystemSettingsTable,
        'hasUsersTable' => $hasUsersTable,
        'hasUserNameColumn' => $hasUserNameColumn,
        'hasUserUsernameColumn' => $hasUserUsernameColumn,
        'targetRole' => $targetRole,
        'roleLabel' => $roleLabel,
        'users' => $users,
        'selectedUserId' => $selectedUserId,
        'options' => $options,
        'current' => $current,
        'localRouteDebug' => $localRouteDebug,

        // UI-Hinweise (falls admin.moderation.blade.php diese unterstützt)
        'uiAutoLoadOnSelectChange' => true,
        'uiAutoSaveOnSectionChange' => true,
    ]);
})
    ->defaults('adminTab', 'moderation')
    ->name('moderation');

Route::post('/moderation/save', function (Request $request) {

    if (!Schema::hasTable('system_settings')) {
        return redirect()->route('admin.moderation')->with('admin_notice', 'system_settings fehlt – Speichern nicht möglich.');
    }

    if (!Schema::hasTable('users')) {
        return redirect()->route('admin.moderation')->with('admin_notice', 'users fehlt – Speichern nicht möglich.');
    }

    $role = $request->input('role', 'moderator');
    if (is_string($role)) {
        $role = mb_strtolower(trim($role));
    } else {
        $role = 'moderator';
    }
    if ($role !== 'admin') {
        $role = 'moderator';
    }

    $userId = $request->input('user_id', null);
    if (is_string($userId)) {
        $userId = trim($userId);
    }
    if (!is_numeric($userId)) {
        return redirect()->route('admin.moderation', ['role' => $role])->with('admin_notice', 'Kein User ausgewählt.');
    }
    $userId = (int) $userId;

    $user = User::query()
        ->where('id', $userId)
        ->whereRaw('LOWER(TRIM(COALESCE(role, ""))) = ?', [$role])
        ->first(['id']);

    if (!$user) {
        return redirect()->route('admin.moderation', ['role' => $role])->with('admin_notice', 'User nicht gefunden oder Rolle passt nicht.');
    }

    $sections = $request->input('sections', []);
    if (!is_array($sections)) {
        $sections = [];
    }

    // Only sections that can ever be granted for the selected role.
    // Server-side enforcement happens exclusively via middleware (auth + staff/superadmin + section:*).
    // Current server rules allow admin only: overview + tickets.
    if ($role === 'admin') {
        $allowedKeys = [
            AdminSectionAccess::SECTION_OVERVIEW,
            AdminSectionAccess::SECTION_TICKETS,
        ];
    } else {
        $allowedKeys = [
            AdminSectionAccess::SECTION_OVERVIEW,
            AdminSectionAccess::SECTION_TICKETS,
        ];
    }

    $out = [];

    foreach ($sections as $s) {
        if (!is_string($s)) {
            continue;
        }
        $s = trim($s);
        if ($s === '' || strlen($s) > 64) {
            continue;
        }
        if (!preg_match('/^[a-z0-9_]+$/', $s)) {
            continue;
        }
        if (!in_array($s, $allowedKeys, true)) {
            continue;
        }
        $out[] = $s;
    }

    $out = array_values(array_unique($out));

    // Fail-closed defaults:
    // - moderator: Defaults (damit Moderatoren nicht aus Versehen komplett ausgesperrt werden)
    // - admin: Defaults (aktuell: overview + tickets)
    if (count($out) < 1) {
        if ($role === 'admin') {
            $out = array_values(array_unique($allowedKeys));
        } else {
            $out = AdminSectionAccess::defaultModeratorSections();
        }
    }

    $json = json_encode($out);

    if ($role === 'admin') {
        $key = 'moderation.admin_sections.user_' . (string) $userId;
        $group = 'moderation';
        $cast = 'json';
    } else {
        $key = 'moderation.moderator_sections.user_' . (string) $userId;
        $group = 'moderation';
        $cast = 'json';
    }

    SystemSetting::updateOrCreate(
        ['key' => $key],
        ['value' => (string) $json, 'group' => (string) $group, 'cast' => (string) $cast]
    );

    return redirect()->route('admin.moderation', ['role' => $role, 'user_id' => $userId])->with('admin_notice', 'Rechte gespeichert.');
})
    ->defaults('adminTab', 'moderation')
    ->name('moderation.save');