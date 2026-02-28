<?php

// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Admin\AdminUserController.php
// Purpose: Admin user governance actions (list/detail/role-sync/delete) via central UserRoleService
// Changed: 28-02-2026 15:11 (Europe/Berlin)
// Version: 0.5
// ============================================================================

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Admin\UserRoleService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class AdminUserController extends Controller
{
    public function __construct(
        protected UserRoleService $userRoleService
    ) {}

    public function index(Request $request): View
    {
        $q = trim((string) $request->query('q', ''));
        $role = mb_strtolower(trim((string) $request->query('role', '')));
        $sort = mb_strtolower(trim((string) $request->query('sort', 'id')));
        $dir = mb_strtolower(trim((string) $request->query('dir', 'asc')));
        $perPage = (int) $request->query('per_page', 50);

        if (!in_array($perPage, [50, 100, 150, 200], true)) {
            $perPage = 50;
        }

        if (!in_array($role, ['superadmin', 'admin', 'moderator', 'user'], true)) {
            $role = '';
        }

        if (!in_array($sort, ['role', 'protected'], true)) {
            $sort = 'id';
        }

        if (!in_array($dir, ['asc', 'desc'], true)) {
            $dir = 'asc';
        }

        $query = User::query()
            ->with('roles:id,name')
            ->select(['id', 'public_id', 'username', 'email', 'is_protected_admin']);

        if ($q !== '') {
            $query->where(function ($sub) use ($q): void {
                $sub->where('username', 'like', '%' . $q . '%')
                    ->orWhere('email', 'like', '%' . $q . '%');
            });
        }

        if ($role !== '') {
            $query->role($role);
        }

        if ($sort === 'protected') {
            $query->orderBy('is_protected_admin', $dir);
        } elseif ($sort === 'role') {
            $query->leftJoin('model_has_roles as mhr', function ($join): void {
                $join->on('mhr.model_id', '=', 'users.id')
                    ->where('mhr.model_type', '=', User::class);
            })->leftJoin('roles as sort_roles', 'sort_roles.id', '=', 'mhr.role_id');

            $query->orderByRaw("
                CASE
                    WHEN sort_roles.name = 'superadmin' THEN 4
                    WHEN sort_roles.name = 'admin' THEN 3
                    WHEN sort_roles.name = 'moderator' THEN 2
                    WHEN sort_roles.name = 'user' THEN 1
                    ELSE 0
                END " . $dir
            )->groupBy('users.id', 'users.public_id', 'users.username', 'users.email', 'users.is_protected_admin');
        } else {
            $query->orderBy('id', 'asc');
        }

        $users = $query->paginate($perPage)->withQueryString();

        return view('admin.users.index', [
            'adminTab' => 'roles',
            'users' => $users,
            'notice' => session('admin_notice'),
            'q' => $q,
            'roleFilter' => $role,
            'sort' => $sort,
            'dir' => $dir,
            'perPage' => $perPage,
        ]);
    }

    public function show(Request $request, User $user): View
    {
        $user->load('roles:id,name');

        return view('admin.users.show', [
            'adminTab' => 'roles',
            'targetUser' => $user,
            'notice' => session('admin_notice'),
        ]);
    }

    public function updateRoles(Request $request, User $user): RedirectResponse
    {
        $validated = $request->validate([
            'roles' => ['nullable', 'array'],
            'roles.*' => ['string', 'in:moderator,admin,superadmin,user'],
            'role' => ['nullable', 'string', 'in:moderator,admin,superadmin,user'],
        ]);

        $roles = [];

        if (isset($validated['roles']) && is_array($validated['roles'])) {
            $roles = array_map(static fn ($v) => (string) $v, $validated['roles']);
        }

        if (count($roles) < 1 && isset($validated['role']) && is_string($validated['role'])) {
            $roles = [(string) $validated['role']];
        }

        if (count($roles) < 1) {
            throw ValidationException::withMessages([
                'roles' => 'At least one role is required.',
            ]);
        }

        try {
            $this->userRoleService->setRolesForUser($user, $roles);
        } catch (ValidationException $e) {
            return redirect()
                ->route('admin.users.show', $user)
                ->withErrors($e->errors())
                ->withInput();
        } catch (\Throwable $e) {
            return redirect()
                ->route('admin.users.show', $user)
                ->withErrors(['user' => 'Aktion fehlgeschlagen. Bitte erneut versuchen.']);
        }

        return redirect()
            ->route('admin.users.show', $user)
            ->with('admin_notice', 'Rollen gespeichert.');
    }

    public function destroy(Request $request, User $user): RedirectResponse
    {
        try {
            $this->userRoleService->deleteUser($user);
        } catch (ValidationException $e) {
            return redirect()
                ->route('admin.users.show', $user)
                ->withErrors($e->errors());
        } catch (\Throwable $e) {
            return redirect()
                ->route('admin.users.show', $user)
                ->withErrors(['user' => 'Aktion fehlgeschlagen. Bitte erneut versuchen.']);
        }

        return redirect()
            ->route('admin.users.index')
            ->with('admin_notice', 'User gelöscht.');
    }

    /**
     * Legacy endpoint for existing JS clients.
     */
    public function setRole(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => ['required', 'integer', 'exists:users,id'],
            'role' => ['required', 'string', 'in:moderator,admin,superadmin,user'],
        ]);

        $target = User::query()->findOrFail((int) $validated['user_id']);

        try {
            $this->userRoleService->setRolesForUser($target, [(string) $validated['role']]);

            return response()->json([
                'ok' => true,
                'message' => 'Role updated.',
                'data' => [
                    'target_user_id' => (int) $target->id,
                    'new_role' => (string) $validated['role'],
                ],
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'ok' => false,
                'message' => 'Blocked',
                'errors' => $e->errors(),
            ], 422);
        } catch (\Throwable $e) {
            return response()->json([
                'ok' => false,
                'message' => 'Error',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Legacy endpoint for existing JS clients.
     */
    public function deleteUser(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => ['required', 'integer', 'exists:users,id'],
        ]);

        $target = User::query()->findOrFail((int) $validated['user_id']);

        try {
            $this->userRoleService->deleteUser($target);

            return response()->json([
                'ok' => true,
                'message' => 'User deleted.',
                'data' => [
                    'target_user_id' => (int) $target->id,
                ],
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'ok' => false,
                'message' => 'Blocked',
                'errors' => $e->errors(),
            ], 422);
        } catch (\Throwable $e) {
            return response()->json([
                'ok' => false,
                'message' => 'Error',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}
