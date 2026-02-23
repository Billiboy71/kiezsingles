<?php

// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Admin\AdminUserController.php
// Purpose: Admin user governance actions (set role, delete user) with Superadmin fail-safe
// Changed: 22-02-2026 00:49 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminUserController extends Controller
{
    /**
     * Set role for a user (server-side enforced).
     *
     * Rules:
     * - Only superadmin may change roles
     * - Last remaining superadmin must never lose role (must keep >= 1 superadmin in DB)
     *
     * Expected input:
     * - user_id (int)
     * - role (string: moderator|admin|superadmin)
     */
    public function setRole(Request $request)
    {
        // Server-side enforcement (UI is not security).
        if (!auth()->check() || ((string) auth()->user()->role !== 'superadmin')) {
            return response()->json(['ok' => false, 'message' => 'Forbidden'], 403);
        }

        $validated = $request->validate([
            'user_id' => ['required', 'integer', 'exists:users,id'],
            'role'    => ['required', 'string', 'in:moderator,admin,superadmin'],
        ]);

        /** @var int $userId */
        $userId = (int) $validated['user_id'];
        /** @var string $role */
        $role = (string) $validated['role'];

        try {
            $result = DB::transaction(function () use ($userId, $role) {
                /** @var User $target */
                $target = User::query()->lockForUpdate()->findOrFail($userId);

                $currentRole = (string) $target->role;

                // Fail-safe: last remaining superadmin may not lose role.
                if ($currentRole === 'superadmin' && $role !== 'superadmin') {
                    $superadmins = (int) User::query()
                        ->where('role', 'superadmin')
                        ->lockForUpdate()
                        ->count();

                    if ($superadmins <= 1) {
                        return [
                            'ok' => false,
                            'status' => 422,
                            'message' => 'Blocked: last superadmin cannot lose role.',
                            'data' => [
                                'superadmins' => $superadmins,
                                'target_user_id' => $target->id,
                                'target_role' => $currentRole,
                                'requested_role' => $role,
                            ],
                        ];
                    }
                }

                // Apply
                $target->role = $role;
                $target->save();

                return [
                    'ok' => true,
                    'status' => 200,
                    'message' => 'Role updated.',
                    'data' => [
                        'target_user_id' => $target->id,
                        'old_role' => $currentRole,
                        'new_role' => $role,
                    ],
                ];
            });

            if (!(bool) ($result['ok'] ?? false)) {
                $status = (int) ($result['status'] ?? 422);
                return response()->json(['ok' => false, 'message' => (string) ($result['message'] ?? 'Blocked'), 'data' => $result['data'] ?? []], $status);
            }

            return response()->json(['ok' => true, 'message' => (string) ($result['message'] ?? 'OK'), 'data' => $result['data'] ?? []], 200);
        } catch (\Throwable $e) {
            return response()->json(['ok' => false, 'message' => 'Error', 'error' => $e->getMessage()], 500);
        }
    }

    /**
     * Delete a user (server-side enforced).
     *
     * Rules:
     * - Only superadmin may delete users
     * - Last remaining superadmin must never be deleted (must keep >= 1 superadmin in DB)
     *
     * Expected input:
     * - user_id (int)
     */
    public function deleteUser(Request $request)
    {
        // Server-side enforcement (UI is not security).
        if (!auth()->check() || ((string) auth()->user()->role !== 'superadmin')) {
            return response()->json(['ok' => false, 'message' => 'Forbidden'], 403);
        }

        $validated = $request->validate([
            'user_id' => ['required', 'integer', 'exists:users,id'],
        ]);

        /** @var int $userId */
        $userId = (int) $validated['user_id'];

        try {
            $result = DB::transaction(function () use ($userId) {
                /** @var User $target */
                $target = User::query()->lockForUpdate()->findOrFail($userId);

                $currentRole = (string) $target->role;

                // Fail-safe: last remaining superadmin may not be deleted.
                if ($currentRole === 'superadmin') {
                    $superadmins = (int) User::query()
                        ->where('role', 'superadmin')
                        ->lockForUpdate()
                        ->count();

                    if ($superadmins <= 1) {
                        return [
                            'ok' => false,
                            'status' => 422,
                            'message' => 'Blocked: last superadmin cannot be deleted.',
                            'data' => [
                                'superadmins' => $superadmins,
                                'target_user_id' => $target->id,
                                'target_role' => $currentRole,
                            ],
                        ];
                    }
                }

                $targetId = (int) $target->id;
                $target->delete();

                return [
                    'ok' => true,
                    'status' => 200,
                    'message' => 'User deleted.',
                    'data' => [
                        'target_user_id' => $targetId,
                        'target_role' => $currentRole,
                    ],
                ];
            });

            if (!(bool) ($result['ok'] ?? false)) {
                $status = (int) ($result['status'] ?? 422);
                return response()->json(['ok' => false, 'message' => (string) ($result['message'] ?? 'Blocked'), 'data' => $result['data'] ?? []], $status);
            }

            return response()->json(['ok' => true, 'message' => (string) ($result['message'] ?? 'OK'), 'data' => $result['data'] ?? []], 200);
        } catch (\Throwable $e) {
            return response()->json(['ok' => false, 'message' => 'Error', 'error' => $e->getMessage()], 500);
        }
    }
}