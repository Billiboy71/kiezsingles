<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\database\migrations\2026_02_05_000001_backfill_public_id_on_users_table.php
// Purpose: Backfill users.public_id for existing users (non-sequential, url-safe)
// Notes:   Generates lowercase [a-z0-9] codes server-side, not derived from id.
//          Does NOT enforce NOT NULL at DB level (handled in later step).
// ============================================================================

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        // Only backfill rows that don't have a public_id yet.
        $users = DB::table('users')->select('id')->whereNull('public_id')->get();

        foreach ($users as $user) {
            // Generate a unique, url-safe, lowercase code.
            do {
                $publicId = Str::lower(Str::random(12)); // a-z0-9, no / + =
                $exists = DB::table('users')->where('public_id', $publicId)->exists();
            } while ($exists);

            // Update defensively: only if still NULL.
            DB::table('users')
                ->where('id', $user->id)
                ->whereNull('public_id')
                ->update(['public_id' => $publicId]);
        }
    }

    public function down(): void
    {
        // Revert backfill (does not drop the column; that is handled by the other migration).
        DB::table('users')->update(['public_id' => null]);
    }
};
