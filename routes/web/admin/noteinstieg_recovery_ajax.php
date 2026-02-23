<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\admin\noteinstieg_recovery_ajax.php
// Purpose: Admin noteinstieg recovery codes routes (AJAX)
// Changed: 19-02-2026 18:45 (Europe/Berlin)
// Version: 0.5
// ============================================================================

use App\Support\Admin\AdminSectionAccess;
use App\Support\SystemSettingHelper;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

/*
|--------------------------------------------------------------------------
| Noteinstieg Notfallcodes – AJAX (Admin) LIST
|--------------------------------------------------------------------------
| Listet alle Codes (auch verwendete), used=true => durchgestrichen.
|
| Erwartung: Wird innerhalb routes/web/admin.php im admin-only + section:maintenance Block eingebunden.
*/
Route::post('/noteinstieg/recovery-codes-list-ajax', function () {
    // Erwartung: Auth/Admin/Section-Guards laufen ausschließlich über Middleware im Admin-Router-Group.

    if (!Schema::hasTable('system_settings')) {
        return response()->json(['ok' => false, 'message' => 'system_settings fehlt'], 422);
    }

    if (!Schema::hasTable('noteinstieg_recovery_codes')) {
        return response()->json(['ok' => false, 'message' => 'noteinstieg_recovery_codes fehlt'], 422);
    }

    // Optional: nur sinnvoll bei Wartung an
    if (Schema::hasTable('app_settings')) {
        $s = DB::table('app_settings')->select(['maintenance_enabled'])->first();
        if (!$s || !(bool) $s->maintenance_enabled) {
            return response()->json(['ok' => false, 'message' => 'wartung aus'], 422);
        }
    }

    if (!(bool) SystemSettingHelper::get('debug.break_glass', false)) {
        return response()->json(['ok' => false, 'message' => 'noteinstieg aus'], 422);
    }

    $rows = DB::table('noteinstieg_recovery_codes')
        ->select(['code_encrypted', 'used_at', 'created_at', 'id'])
        ->orderByRaw('CASE WHEN used_at IS NULL THEN 0 ELSE 1 END ASC')
        ->orderBy('created_at', 'desc')
        ->orderBy('id', 'desc')
        ->limit(200)
        ->get();

    $out = [];
    foreach ($rows as $row) {
        $plain = '';
        if (isset($row->code_encrypted) && $row->code_encrypted !== null && (string) $row->code_encrypted !== '') {
            try {
                $plain = (string) decrypt((string) $row->code_encrypted);
            } catch (\Throwable $e) {
                $plain = '';
            }
        }

        if ($plain === '') {
            continue;
        }

        $out[] = [
            'code' => $plain,
            'used' => $row->used_at !== null,
        ];
    }

    return response()->json(['ok' => true, 'codes' => $out]);
})
    ->defaults('adminTab', 'maintenance')
    ->name('noteinstieg.recovery.list.ajax');

/*
|--------------------------------------------------------------------------
| Noteinstieg Notfallcodes – AJAX (Admin) GENERATE
|--------------------------------------------------------------------------
| Erzeugt 5 Codes (XXXX-XXXX), speichert Hash + code_encrypted (einmalig),
| gibt Klartext nur als Bestätigung zurück (UI lädt danach Liste).
|
| Regel:
| - Wenn noch unbenutzte Codes existieren: NICHT neu generieren.
| - Wenn nur benutzte Codes existieren: Tabelle leeren und 5 neue erzeugen.
|
| Erwartung: Wird innerhalb routes/web/admin.php im admin-only + section:maintenance Block eingebunden.
*/
Route::post('/noteinstieg/recovery-codes-generate-ajax', function (\Illuminate\Http\Request $request) {
    // Erwartung: Auth/Admin/Section-Guards laufen ausschließlich über Middleware im Admin-Router-Group.

    if (!Schema::hasTable('system_settings')) {
        return response()->json(['ok' => false, 'message' => 'system_settings fehlt'], 422);
    }

    if (!Schema::hasTable('noteinstieg_recovery_codes')) {
        return response()->json(['ok' => false, 'message' => 'noteinstieg_recovery_codes fehlt'], 422);
    }

    // Optional: nur sinnvoll bei Wartung an
    if (Schema::hasTable('app_settings')) {
        $s = DB::table('app_settings')->select(['maintenance_enabled'])->first();
        if (!$s || !(bool) $s->maintenance_enabled) {
            return response()->json(['ok' => false, 'message' => 'wartung aus'], 422);
        }
    }

    if (!(bool) SystemSettingHelper::get('debug.break_glass', false)) {
        return response()->json(['ok' => false, 'message' => 'noteinstieg aus'], 422);
    }

    $hasUnused = (int) DB::table('noteinstieg_recovery_codes')->whereNull('used_at')->count();
    if ($hasUnused > 0) {
        return response()->json(['ok' => false, 'message' => 'Es sind bereits unbenutzte Notfallcodes vorhanden.'], 422);
    }

    $total = (int) DB::table('noteinstieg_recovery_codes')->count();
    if ($total > 0) {
        // alle sind benutzt -> hart auf 5 begrenzen: alte Codes entfernen
        DB::table('noteinstieg_recovery_codes')->delete();
    }

    $targetUnused = 5;
    $maxTotal = 10;

    DB::beginTransaction();
    try {
        $unusedCount = (int) DB::table('noteinstieg_recovery_codes')
            ->whereNull('used_at')
            ->count();

        $missing = $targetUnused - $unusedCount;
        if ($missing < 0) {
            $missing = 0;
        }

        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $make = function () use ($alphabet): string {
            $out = '';
            $max = strlen($alphabet) - 1;
            for ($i = 0; $i < 8; $i++) {
                $out .= $alphabet[random_int(0, $max)];
            }
            return substr($out, 0, 4) . '-' . substr($out, 4, 4);
        };

        $now = now();
        $rows = [];

        for ($i = 0; $i < $missing; $i++) {
            $c = $make();

            $normalized = str_replace('-', '', $c);
            $hash = hash_hmac('sha256', $normalized, (string) config('app.key'));

            // Bei extrem unwahrscheinlichem Hash-Collision: neu versuchen
            $exists = DB::table('noteinstieg_recovery_codes')->where('hash', $hash)->exists();
            if ($exists) {
                $i--;
                continue;
            }

            $rows[] = [
                'hash' => $hash,
                'code_encrypted' => encrypt($c),
                'used_at' => null,
                'used_ip' => null,
                'used_user_agent' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        if (!empty($rows)) {
            DB::table('noteinstieg_recovery_codes')->insert($rows);
        }

        // Hard cap: max 10 Datensätze (zuerst alte benutzte löschen)
        $total = (int) DB::table('noteinstieg_recovery_codes')->count();
        if ($total > $maxTotal) {
            $toDelete = $total - $maxTotal;

            $ids = DB::table('noteinstieg_recovery_codes')
                ->whereNotNull('used_at')
                ->orderBy('used_at', 'asc')
                ->orderBy('id', 'asc')
                ->limit($toDelete)
                ->pluck('id')
                ->all();

            if (!empty($ids)) {
                DB::table('noteinstieg_recovery_codes')->whereIn('id', $ids)->delete();
            }

            // Falls immer noch > maxTotal (z.B. zu viele unbenutzte): älteste unbenutzte löschen
            $total = (int) DB::table('noteinstieg_recovery_codes')->count();
            if ($total > $maxTotal) {
                $toDelete = $total - $maxTotal;

                $ids2 = DB::table('noteinstieg_recovery_codes')
                    ->whereNull('used_at')
                    ->orderBy('created_at', 'asc')
                    ->orderBy('id', 'asc')
                    ->limit($toDelete)
                    ->pluck('id')
                    ->all();

                if (!empty($ids2)) {
                    DB::table('noteinstieg_recovery_codes')->whereIn('id', $ids2)->delete();
                }
            }
        }

        // Immer 5 Codes zurückgeben (für dein bestehendes JS)
        $rowsOut = DB::table('noteinstieg_recovery_codes')
            ->select(['code_encrypted', 'used_at', 'created_at', 'id'])
            ->orderByRaw('CASE WHEN used_at IS NULL THEN 0 ELSE 1 END ASC')
            ->orderBy('created_at', 'desc')
            ->orderBy('id', 'desc')
            ->limit(2000)
            ->get();

        $out = [];
        foreach ($rowsOut as $row) {
            $plain = '';
            if (isset($row->code_encrypted) && $row->code_encrypted !== null && (string) $row->code_encrypted !== '') {
                try {
                    $plain = (string) decrypt((string) $row->code_encrypted);
                } catch (\Throwable $e) {
                    $plain = '';
                }
            }
            if ($plain === '') {
                continue;
            }
            $out[] = $plain;
            if (count($out) >= 5) {
                break;
            }
        }

        // Safety: wenn durch alte Daten <5 da sind -> fehlende nachziehen
        while (count($out) < 5) {
            $c = $make();
            $normalized = str_replace('-', '', $c);
            $hash = hash_hmac('sha256', $normalized, (string) config('app.key'));
            $exists = DB::table('noteinstieg_recovery_codes')->where('hash', $hash)->exists();
            if ($exists) {
                continue;
            }

            DB::table('noteinstieg_recovery_codes')->insert([
                'hash' => $hash,
                'code_encrypted' => encrypt($c),
                'used_at' => null,
                'used_ip' => null,
                'used_user_agent' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $out[] = $c;
        }

        DB::commit();

        return response()->json(['ok' => true, 'codes' => $out]);
    } catch (\Throwable $e) {
        DB::rollBack();
        return response()->json(['ok' => false, 'message' => 'generate failed'], 500);
    }
})
    ->defaults('adminTab', 'maintenance')
    ->name('noteinstieg.recovery.generate.ajax');
