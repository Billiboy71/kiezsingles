<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_28_145100_backfill_spatie_roles_from_users_role.php
// Purpose: Deterministic one-time mapping users.role -> Spatie roles
// Created: 28-02-2026 14:49 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use App\Models\User;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('roles') || !Schema::hasTable('users')) {
            return;
        }

        DB::transaction(function (): void {
            $guardName = config('auth.defaults.guard', 'web');

            Role::findOrCreate('superadmin', $guardName);
            Role::findOrCreate('admin', $guardName);
            Role::findOrCreate('moderator', $guardName);
            Role::findOrCreate('user', $guardName);

            $hasLegacyRoleColumn = Schema::hasColumn('users', 'role');

            if ($hasLegacyRoleColumn) {
                User::query()
                    ->select(['id', 'role'])
                    ->orderBy('id')
                    ->chunkById(200, function ($users) use ($guardName): void {
                        foreach ($users as $user) {
                            $legacyRole = mb_strtolower(trim((string) ($user->getAttribute('role') ?? '')));

                            $targetRole = match ($legacyRole) {
                                'superadmin' => 'superadmin',
                                'admin' => 'admin',
                                'moderator' => 'moderator',
                                'user' => 'user',
                                default => 'user',
                            };

                            Role::findOrCreate($targetRole, $guardName);

                            $user->syncRoles([$targetRole]);
                        }
                    });
            } else {
                User::query()
                    ->orderBy('id')
                    ->chunkById(200, function ($users) use ($guardName): void {
                        foreach ($users as $user) {
                            if ($user->roles()->count() > 0) {
                                continue;
                            }

                            Role::findOrCreate('user', $guardName);
                            $user->syncRoles(['user']);
                        }
                    });
            }
        });

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }

    public function down(): void
    {
        // Intentionally no rollback for role assignments.
    }
};