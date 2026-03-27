<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Admin\Security\IncidentController.php
// Purpose: Admin Security incidents list controller (read-only monitoring UI)
// Created: 22-03-2026 21:30 (Europe/Berlin)
// Changed: 25-03-2026 02:01 (Europe/Berlin)
// Version: 2.5
// ============================================================================

namespace App\Http\Controllers\Admin\Security;

use App\Http\Controllers\Controller;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\View\View;

class IncidentController extends Controller
{
    public function index(Request $request): View
    {
        $perPage = (int) $request->query('per_page', 20);
        if (!in_array($perPage, [20, 50, 100], true)) {
            $perPage = 20;
        }

        $types = [];
        $incidents = new LengthAwarePaginator(
            collect(),
            0,
            $perPage,
            LengthAwarePaginator::resolveCurrentPage(),
            [
                'path' => $request->url(),
                'query' => $request->query(),
            ]
        );

        if (Schema::hasTable('security_incidents')) {
            $hasUpdatedAt = Schema::hasColumn('security_incidents', 'updated_at');
            $hasEventCount = Schema::hasColumn('security_incidents', 'event_count');
            $hasActionStatus = Schema::hasColumn('security_incidents', 'action_status');
            $hasAutoActionExecuted = Schema::hasColumn('security_incidents', 'auto_action_executed');
            $hasAutoActionDetails = Schema::hasColumn('security_incidents', 'auto_action_details');

            $query = DB::table('security_incidents')
                ->select('id', 'type', 'created_at')
                ->when(
                    $hasUpdatedAt,
                    fn ($builder) => $builder->addSelect('updated_at'),
                    fn ($builder) => $builder->selectRaw('NULL as updated_at')
                )
                ->when(
                    $hasEventCount,
                    fn ($builder) => $builder->selectRaw('event_count as events_count'),
                    fn ($builder) => $builder->selectRaw('NULL as events_count')
                )
                ->when(
                    $hasActionStatus,
                    fn ($builder) => $builder->addSelect('action_status'),
                    fn ($builder) => $builder->selectRaw('NULL as action_status')
                )
                ->when(
                    $hasAutoActionExecuted,
                    fn ($builder) => $builder->addSelect('auto_action_executed'),
                    fn ($builder) => $builder->selectRaw('0 as auto_action_executed')
                )
                ->when(
                    $hasAutoActionDetails,
                    fn ($builder) => $builder->addSelect('auto_action_details'),
                    fn ($builder) => $builder->selectRaw('NULL as auto_action_details')
                )
                ->orderByDesc('created_at')
                ->orderByDesc('id');

            if ($request->filled('type')) {
                $query->where('type', (string) $request->input('type'));
            }

            $status = $request->input('status');

            if (!$status) {
                $status = 'open';
            }

            if ($status === 'open') {
                $query->whereNull('action_status');
            } else {
                $query->where('action_status', (string) $status);
            }

            $types = DB::table('security_incidents')
                ->select('type')
                ->distinct()
                ->orderBy('type')
                ->pluck('type')
                ->all();

            $incidents = $query
                ->paginate($perPage)
                ->withQueryString();
        }

        return view('admin.security.incidents.index', [
            'adminTab' => 'security',
            'incidents' => $incidents,
            'perPage' => $perPage,
            'types' => $types,
        ]);
    }

    public function show(int $id): View
    {
        abort_unless(Schema::hasTable('security_incidents'), 404);

        $incident = $this->incidentBaseQuery()
            ->where('id', $id)
            ->first();

        abort_if($incident === null, 404);

        $events = \App\Models\SecurityEvent::query()
            ->join('security_incident_events', 'security_incident_events.security_event_id', '=', 'security_events.id')
            ->where('security_incident_events.incident_id', $incident->id)
            ->select('security_events.*')
            ->latest()
            ->limit(20)
            ->get();

        $topIps = DB::table('security_incident_events')
            ->join('security_events', 'security_events.id', '=', 'security_incident_events.security_event_id')
            ->where('security_incident_events.incident_id', $incident->id)
            ->select('security_events.ip', DB::raw('COUNT(*) as count'))
            ->groupBy('security_events.ip')
            ->orderByDesc('count')
            ->limit(5)
            ->get();

        $topDevices = DB::table('security_incident_events')
            ->join('security_events', 'security_events.id', '=', 'security_incident_events.security_event_id')
            ->where('security_incident_events.incident_id', $incident->id)
            ->select('security_events.device_hash', DB::raw('COUNT(*) as count'))
            ->groupBy('security_events.device_hash')
            ->orderByDesc('count')
            ->limit(5)
            ->get();

        $topEmails = DB::table('security_incident_events')
            ->join('security_events', 'security_events.id', '=', 'security_incident_events.security_event_id')
            ->where('security_incident_events.incident_id', $incident->id)
            ->select('security_events.email', DB::raw('COUNT(*) as count'))
            ->groupBy('security_events.email')
            ->orderByDesc('count')
            ->limit(5)
            ->get();

        $actions = collect();

        if (Schema::hasTable('security_incident_actions')) {
            $actions = DB::table('security_incident_actions')
                ->leftJoin('users', 'users.id', '=', 'security_incident_actions.user_id')
                ->where('incident_id', $incident->id)
                ->orderByDesc('security_incident_actions.created_at')
                ->limit(20)
                ->select(
                    'security_incident_actions.*',
                    'users.username as user_name',
                    'users.email as user_email'
                )
                ->get();
        }

        $severity = 'low';

        if (($incident->events_count ?? 0) >= 100) {
            $severity = 'high';
        } elseif (($incident->events_count ?? 0) >= 20) {
            $severity = 'medium';
        }

        $action = [
            'label' => 'observe',
            'description' => 'Beobachten',
        ];

        switch ($incident->type) {
            case 'credential_stuffing':
                $action = [
                    'label' => 'review',
                    'description' => 'Login-Verhalten prüfen',
                ];
                break;

            case 'account_sharing':
                $action = [
                    'label' => 'observe',
                    'description' => 'Account beobachten',
                ];
                break;

            case 'bot_pattern':
                $action = [
                    'label' => 'investigate',
                    'description' => 'Bot-Aktivität analysieren',
                ];
                break;

            case 'device_cluster':
                $action = [
                    'label' => 'suspicious',
                    'description' => 'Geräte-Cluster prüfen',
                ];
                break;
        }

        $recommendations = [];

        $type = $incident->type;
        $eventCount = $incident->events_count ?? 0;

        $topIp = $topIps->first()->ip ?? null;
        $topDevice = $topDevices->first()->device_hash ?? null;
        $topEmail = $topEmails->first()->email ?? null;

        switch ($type) {
            case 'device_cluster':
                $recommendations[] = [
                    'text' => "Viele Geräte aktiv ({$eventCount} Events)",
                ];
                if ($topDevice) {
                    $recommendations[] = [
                        'text' => 'Device sperren',
                        'type' => 'device',
                        'value' => $topDevice,
                    ];
                }
                if ($topIp) {
                    $recommendations[] = [
                        'text' => 'IP sperren',
                        'type' => 'ip',
                        'value' => $topIp,
                    ];
                }
                break;

            case 'bot_pattern':
                if ($topIp) {
                    $recommendations[] = [
                        'text' => 'Automatisierte Zugriffe erkannt',
                    ];
                    $recommendations[] = [
                        'text' => 'IP sperren',
                        'type' => 'ip',
                        'value' => $topIp,
                    ];
                }
                break;

            case 'credential_stuffing':
                if ($topEmail) {
                    $recommendations[] = [
                        'text' => 'Login-Angriffe erkannt',
                    ];
                    $recommendations[] = [
                        'text' => 'Identity sperren',
                        'type' => 'identity',
                        'value' => $topEmail,
                    ];
                }
                break;

            case 'account_sharing':
                if ($topEmail) {
                    $recommendations[] = [
                        'text' => 'Account wird von mehreren Geräten genutzt',
                    ];
                    $recommendations[] = [
                        'text' => "Account prüfen: {$topEmail}",
                    ];
                }
                break;
        }

        return view('admin.security.incidents.show', [
            'adminTab' => 'security',
            'incident' => $incident,
            'events' => $events,
            'topIps' => $topIps,
            'topDevices' => $topDevices,
            'topEmails' => $topEmails,
            'actions' => $actions,
            'severity' => $severity,
            'action' => $action,
            'recommendations' => $recommendations,
        ]);
    }

    public function applyActions(int $id): RedirectResponse
    {
        abort_unless(Schema::hasTable('security_incidents'), 404);

        $incident = DB::table('security_incidents')->where('id', $id)->first();

        if (!$incident) {
            return back();
        }

        $details = json_decode((string) ($incident->auto_action_details ?? ''), true) ?? [];

        $top = DB::table('security_incident_events')
            ->join('security_events', 'security_events.id', '=', 'security_incident_events.security_event_id')
            ->where('incident_id', $id)
            ->select('security_events.ip', 'security_events.email', 'security_events.device_hash')
            ->first();

        if (!$top) {
            return back();
        }

        if ($details === []) {
            if ($incident->type === 'device_cluster' && !empty($top->device_hash)) {
                $details[] = 'device';
            }

            if ($incident->type === 'bot_pattern' && !empty($top->ip)) {
                $details[] = 'ip';
            }

            if ($incident->type === 'credential_stuffing' && !empty($top->email)) {
                $details[] = 'identity';
            }
        }

        if (in_array('device', $details, true) && !empty($top->device_hash) && Schema::hasTable('security_device_bans')) {
            DB::table('security_device_bans')->insert([
                'device_hash' => trim((string) $top->device_hash),
                'reason' => 'Incident '.$id,
                'banned_until' => null,
                'revoked_at' => null,
                'is_active' => true,
                'created_by' => auth()->id(),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        if (in_array('ip', $details, true) && !empty($top->ip) && Schema::hasTable('security_ip_bans')) {
            DB::table('security_ip_bans')->insert([
                'ip' => trim((string) $top->ip),
                'reason' => 'Incident '.$id,
                'banned_until' => null,
                'created_by' => auth()->id(),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        if (in_array('identity', $details, true) && !empty($top->email) && Schema::hasTable('security_identity_bans')) {
            DB::table('security_identity_bans')->insert([
                'email' => mb_strtolower(trim((string) $top->email)),
                'reason' => 'Incident '.$id,
                'banned_until' => null,
                'created_by' => auth()->id(),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        if (Schema::hasColumn('security_incidents', 'action_status')) {
            $updatePayload = [
                'action_status' => 'reviewed',
            ];

            if (Schema::hasColumn('security_incidents', 'auto_action_executed')) {
                $updatePayload['auto_action_executed'] = true;
            }

            DB::table('security_incidents')
                ->where('id', $id)
                ->update($updatePayload);
        } elseif (Schema::hasColumn('security_incidents', 'auto_action_executed')) {
            DB::table('security_incidents')
                ->where('id', $id)
                ->update([
                    'auto_action_executed' => true,
                ]);
        }

        return back();
    }

    public function destroy(int $id): RedirectResponse
    {
        abort_unless(Schema::hasTable('security_incidents'), 404);

        $incident = DB::table('security_incidents')
            ->where('id', $id)
            ->first();

        abort_if($incident === null, 404);

        if (($incident->action_status ?? null) === 'reviewed') {
            abort(403, 'Incident mit Maßnahme kann nicht gelöscht werden.');
        }

        DB::table('security_incidents')
            ->where('id', $id)
            ->delete();

        return redirect()->back()->with('success', 'Incident gelöscht');
    }

    public function bulkDelete(Request $request): RedirectResponse
    {
        abort_unless(Schema::hasTable('security_incidents'), 404);

        $status = $request->input('status');
        $query = DB::table('security_incidents');

        if ($status === 'open') {
            $query->whereNull('action_status');
        } elseif ($status === 'reviewed') {
            return back()->with('error', 'Incidents mit Maßnahme können nicht gelöscht werden.');
        } else {
            $query->where('action_status', (string) $status);
            $query->where('action_status', '!=', 'reviewed');
        }

        $deleted = $query->delete();

        return back()->with('success', $deleted . ' Incidents gelöscht');
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        abort_unless(Schema::hasTable('security_incidents'), 404);
        abort_unless(Schema::hasColumn('security_incidents', 'action_status'), 404);

        $incident = DB::table('security_incidents')
            ->where('id', $id)
            ->first();

        abort_if($incident === null, 404);

        // 🔥 FIX: JSON + Form + Raw Body sicher verarbeiten
        $status = $request->input('status');

        if (!$status) {
            $status = $request->json('status');
        }

        if (!$status) {
            $payload = json_decode($request->getContent(), true);
            $status = $payload['status'] ?? null;
        }

        if (!in_array($status, ['reviewed', 'escalated', 'ignored'], true)) {
            return response()->json(['error' => 'invalid status'], 422);
        }

        $oldStatus = $incident->action_status ?? null;

        DB::table('security_incidents')
            ->where('id', $id)
            ->update(['action_status' => $status]);

        if (Schema::hasTable('security_incident_actions')) {
            DB::table('security_incident_actions')->insert([
                'incident_id' => $id,
                'user_id' => auth()->id(),
                'action' => 'status_change',
                'old_status' => $oldStatus,
                'new_status' => $status,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        return response()->json([
            'success' => true,
            'status' => $status,
        ]);
    }

    private function incidentBaseQuery(): Builder
    {
        $hasUpdatedAt = Schema::hasColumn('security_incidents', 'updated_at');
        $hasEventCount = Schema::hasColumn('security_incidents', 'event_count');
        $hasActionStatus = Schema::hasColumn('security_incidents', 'action_status');
        $hasAutoActionExecuted = Schema::hasColumn('security_incidents', 'auto_action_executed');
        $hasAutoActionDetails = Schema::hasColumn('security_incidents', 'auto_action_details');

        return DB::table('security_incidents')
            ->select('id', 'type', 'created_at')
            ->when(
                $hasUpdatedAt,
                fn ($builder) => $builder->addSelect('updated_at'),
                fn ($builder) => $builder->selectRaw('NULL as updated_at')
            )
            ->when(
                $hasEventCount,
                fn ($builder) => $builder->selectRaw('event_count as events_count'),
                fn ($builder) => $builder->selectRaw('NULL as events_count')
            )
            ->when(
                $hasActionStatus,
                fn ($builder) => $builder->addSelect('action_status'),
                fn ($builder) => $builder->selectRaw('NULL as action_status')
            )
            ->when(
                $hasAutoActionExecuted,
                fn ($builder) => $builder->addSelect('auto_action_executed'),
                fn ($builder) => $builder->selectRaw('0 as auto_action_executed')
            )
            ->when(
                $hasAutoActionDetails,
                fn ($builder) => $builder->addSelect('auto_action_details'),
                fn ($builder) => $builder->selectRaw('NULL as auto_action_details')
            );
    }
}
