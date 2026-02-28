<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\moderation.php
// Purpose: Admin moderation routes (configure per-user staff_permissions SSOT in DB)
// Changed: 28-02-2026 14:49 (Europe/Berlin)
// Version: 2.3
// ============================================================================

use App\Support\KsMaintenance;
use App\Models\StaffPermission;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

/*
|--------------------------------------------------------------------------
| Admin: Moderation (Rechteverwaltung)
|--------------------------------------------------------------------------
| - Zugriff wird über routes/web/admin.php erzwungen (auth + superadmin + section:moderation).
| - Pro User speichern in staff_permissions (SSOT):
|     user_id + module_key + allowed
|
| Erwartung:
| - Datei wird innerhalb von routes/web/admin.php in einem
|   Route::prefix('admin')->name('admin.')->group(...) eingebunden.
|
*/

Route::get('/moderation', function (Request $request) {

    $hasStaffPermissionsTable = Schema::hasTable('staff_permissions');
    $hasUsersTable = Schema::hasTable('users');
    $maintenanceEnabled = false;

    $maintenanceEnabled = KsMaintenance::enabled();

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
    $options = [
        'tickets' => 'Tickets',
    ];

    $users = [];
    $selectedUserId = null;

    if ($hasUsersTable) {
        $selectCols = ['id', 'email'];
        if ($hasUserNameColumn) {
            $selectCols[] = 'name';
        }
        if ($hasUserUsernameColumn) {
            $selectCols[] = 'username';
        }

        $query = User::query()
            ->role($targetRole);

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

    $current = [];

    if ($hasStaffPermissionsTable && $selectedUserId !== null) {
        $allowedKeys = array_values(array_unique(array_keys($options)));
        $current = StaffPermission::query()
            ->where('user_id', (int) $selectedUserId)
            ->where('allowed', true)
            ->whereIn('module_key', $allowedKeys)
            ->pluck('module_key')
            ->map(static fn ($key) => mb_strtolower(trim((string) $key)))
            ->filter(static fn ($key) => $key !== '')
            ->unique()
            ->values()
            ->all();
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
        'maintenanceEnabled' => $maintenanceEnabled,
        'adminShowDebugTab' => (bool) $maintenanceEnabled,
        'notice' => $notice,
        'hasStaffPermissionsTable' => $hasStaffPermissionsTable,
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

    if (!Schema::hasTable('staff_permissions')) {
        return redirect()->route('admin.moderation')->with('admin_notice', 'staff_permissions fehlt – Speichern nicht möglich.');
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
        ->role($role)
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
    $allowedKeys = [
        'tickets',
    ];

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

    // no automatic re‑activation of sections when the form posts an empty
    // list. unless an explicit policy exists that at least one section must
    // be selected, we simply persist whatever the user sent (including an
    // empty array). if you enable the policy via configuration the request
    // will be rejected with an error message instead of silently falling back.
    if (count($out) < 1) {
        if (config('admin.require_section_selection', false)) {
            return redirect()->route('admin.moderation', ['role' => $role, 'user_id' => $userId])
                ->with('admin_notice', 'Mindestens eine Section muss ausgewählt werden.');
        }
    }

    \Illuminate\Support\Facades\DB::transaction(function () use ($userId, $allowedKeys, $out) {
        StaffPermission::query()
            ->where('user_id', $userId)
            ->whereIn('module_key', $allowedKeys)
            ->delete();

        foreach ($out as $moduleKey) {
            StaffPermission::query()->create([
                'user_id' => $userId,
                'module_key' => (string) $moduleKey,
                'allowed' => true,
            ]);
        }
    });

    return redirect()->route('admin.moderation', ['role' => $role, 'user_id' => $userId])->with('admin_notice', 'Rechte gespeichert.');
})
    ->defaults('adminTab', 'moderation')
    ->name('moderation.save');
