<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\Admin\AdminTicketController.php
// Purpose: Admin ticket inbox + detail + actions (controller-based).
// Changed: 27-02-2026 14:37 (Europe/Berlin)
// Version: 4.0
// ============================================================================

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Ticket;
use App\Models\User;
use App\Services\TicketService;
use App\Support\Admin\AdminModuleRegistry;
use App\Support\KsMaintenance;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;

class AdminTicketController extends Controller
{
    public function __construct(
        protected TicketService $ticketService
    ) {}

    private function buildAdminLayoutContext(Request $request, string $fallbackTab = 'tickets'): array
    {
        $role = mb_strtolower(trim((string) (auth()->user()?->role ?? 'user')));
        $isSuperadminRole = ($role === 'superadmin');

        $adminTab = (string) ($request->route('adminTab') ?? $fallbackTab);
        if ($adminTab === '') {
            $adminTab = $fallbackTab;
        }

        $maintenanceEnabled = KsMaintenance::enabled();

        $modules = [];

        try {
            $modules = (array) AdminModuleRegistry::modulesForRole($role, $maintenanceEnabled);
        } catch (\Throwable $e) {
            $modules = [];
        }

        if (!is_array($modules) || count($modules) === 0) {
            $modules = [
                'home' => [
                    'label' => 'Übersicht',
                    'route' => 'admin.home',
                    'access' => 'staff',
                ],
                'tickets' => [
                    'label' => 'Tickets',
                    'route' => 'admin.tickets.index',
                    'access' => 'staff',
                ],
            ];

            if ($isSuperadminRole) {
                $modules['maintenance'] = [
                    'label' => 'Wartung',
                    'route' => 'admin.maintenance',
                    'access' => 'superadmin',
                ];

                if ($maintenanceEnabled) {
                    $modules['debug'] = [
                        'label' => 'Debug',
                        'route' => 'admin.debug',
                        'access' => 'superadmin',
                    ];
                }

                $modules['moderation'] = [
                    'label' => 'Moderation',
                    'route' => 'admin.moderation',
                    'access' => 'superadmin',
                ];
            }
        }

        $fallbackUrls = [
            'admin.home' => url('/admin'),
            'admin.tickets.index' => url('/admin/tickets'),
            'admin.maintenance' => url('/admin/maintenance'),
            'admin.debug' => url('/admin/debug'),
            'admin.moderation' => url('/admin/moderation'),
        ];

        $adminNavItems = [];

        foreach ($modules as $key => $module) {
            if ((string) $key === 'debug' && !$maintenanceEnabled) {
                continue;
            }

            $routeName = (string) ($module['route'] ?? '');
            $fallbackUrl = $fallbackUrls[$routeName] ?? url('/admin');

            $url = $fallbackUrl;
            if ($routeName !== '' && Route::has($routeName)) {
                $url = route($routeName);
            }

            $adminNavItems[] = [
                'key' => (string) $key,
                'label' => (string) ($module['label'] ?? $key),
                'url' => (string) $url,
            ];
        }

        return [
            'adminTab' => $adminTab,
            'adminNavItems' => $adminNavItems,
            'adminShowDebugTab' => ($isSuperadminRole ? $maintenanceEnabled : false),
            'maintenanceEnabled' => $maintenanceEnabled,
        ];
    }

    private function labelForType(string $type): string
    {
        return match ($type) {
            'report' => 'Meldung',
            'support' => 'Support',
            default => $type,
        };
    }

    private function labelForStatus(string $status): string
    {
        return match ($status) {
            'open' => 'Offen',
            'in_progress' => 'In Bearbeitung',
            'closed' => 'Geschlossen',
            'rejected' => 'Abgelehnt',
            'escalated' => 'Eskaliert',
            default => $status,
        };
    }

    private function labelForCategory(?string $category): string
    {
        $category = (string) ($category ?? '');
        return match ($category) {
            '' => '',
            'support' => 'Support',
            'abuse' => 'Missbrauch',
            'spam' => 'Spam',
            'billing' => 'Abrechnung',
            'bug' => 'Fehler',
            default => $category,
        };
    }

    private function labelForPriority(?string $priority): string
    {
        $priority = (string) ($priority ?? '');
        return match ($priority) {
            '' => '',
            'low' => 'Niedrig',
            'normal' => 'Normal',
            'high' => 'Hoch',
            'critical' => 'Kritisch',

            '1' => 'Niedrig',
            '2' => 'Normal',
            '3' => 'Hoch',
            '4' => 'Kritisch',

            default => $priority,
        };
    }

    private function labelForAuditEvent(string $event): string
    {
        return match ($event) {
            'ticket_created' => 'Ticket erstellt',
            'ticket_closed' => 'Ticket geschlossen',
            'ticket_reopened' => 'Ticket wieder geöffnet',

            'status_changed' => 'Status geändert',
            'assigned_admin_changed' => 'Zuweisung geändert',
            'category_changed' => 'Kategorie geändert',
            'priority_changed' => 'Priorität geändert',
            'subject_changed' => 'Betreff geändert',

            'admin_reply_added' => 'Admin-Antwort',
            'internal_note_added' => 'Interne Notiz',

            'moderation_warn' => 'Moderation: Verwarnung',
            'moderation_temp_ban' => 'Moderation: Temporäre Sperre',
            'moderation_perm_ban' => 'Moderation: Dauerhafte Sperre',
            'moderation_unfounded' => 'Moderation: Unbegründet',

            default => $event,
        };
    }

    private function displayForUserId(int $userId, array $userDisplayById): string
    {
        if ($userId <= 0) {
            return '-';
        }

        return $userDisplayById[$userId] ?? ('#' . $userId);
    }

    private function classForPriority(string $priorityRaw): string
    {
        $p = (string) ($priorityRaw ?? '');
        if ($p === '') {
            return 'prio-none';
        }

        return match ($p) {
            'low', '1' => 'prio-low',
            'normal', '2' => 'prio-normal',
            'high', '3' => 'prio-high',
            'critical', '4' => 'prio-critical',
            default => 'prio-other',
        };
    }

    private function classForStatus(string $status): string
    {
        return match ((string) ($status ?? '')) {
            'open' => 'st-open',
            'in_progress' => 'st-inprogress',
            'closed' => 'st-closed',
            'rejected' => 'st-rejected',
            'escalated' => 'st-escalated',
            default => 'st-other',
        };
    }

    private function classForCategory(string $category): string
    {
        return match ((string) ($category ?? '')) {
            '' => 'cat-none',
            'support' => 'cat-support',
            'abuse' => 'cat-abuse',
            'spam' => 'cat-spam',
            'billing' => 'cat-billing',
            'bug' => 'cat-bug',
            default => 'cat-other',
        };
    }

    private function buildUserDisplayById(array $userIds): array
    {
        $userIds = array_values(array_unique(array_map(static fn ($v) => (int) $v, $userIds)));
        $userIds = array_values(array_filter($userIds, static fn ($v) => $v > 0));

        $userDisplayById = [];
        if (count($userIds) > 0) {
            $users = User::query()
                ->whereIn('id', $userIds)
                ->get(['id', 'username', 'email']);

            foreach ($users as $u) {
                $uid = isset($u->id) ? (int) $u->id : 0;
                $uUsername = isset($u->username) ? (string) ($u->username ?? '') : '';
                $uEmail = isset($u->email) ? (string) ($u->email ?? '') : '';

                $display = '#' . $uid;
                if ($uUsername !== '') {
                    $display = $uUsername;
                } elseif ($uEmail !== '') {
                    $display = $uEmail;
                }

                $userDisplayById[$uid] = $display;
            }
        }

        return $userDisplayById;
    }

    private function buildUserMetaById(array $userIds): array
    {
        $userIds = array_values(array_unique(array_map(static fn ($v) => (int) $v, $userIds)));
        $userIds = array_values(array_filter($userIds, static fn ($v) => $v > 0));

        $out = [];
        if (count($userIds) < 1) {
            return $out;
        }

        $users = User::query()
            ->whereIn('id', $userIds)
            ->get(['id', 'public_id', 'role', 'username', 'email']);

        foreach ($users as $u) {
            $uid = isset($u->id) ? (int) $u->id : 0;
            if ($uid < 1) {
                continue;
            }

            $uUsername = isset($u->username) ? trim((string) ($u->username ?? '')) : '';
            $uEmail = isset($u->email) ? trim((string) ($u->email ?? '')) : '';
            $uPublicId = isset($u->public_id) ? trim((string) ($u->public_id ?? '')) : '';
            $uRole = mb_strtolower(trim((string) ($u->role ?? '')));

            $display = '#' . $uid;
            if ($uUsername !== '') {
                $display = $uUsername;
            } elseif ($uEmail !== '') {
                $display = $uEmail;
            }

            $out[$uid] = [
                'display' => $display,
                'public_id' => $uPublicId,
                'role' => $uRole,
            ];
        }

        return $out;
    }

    // =========================================================================
    // Draft persistence helpers (server-side)
    // Strategy:
    // 1) Prefer tickets-table columns if present: draft_reply_message, draft_internal_note
    // 2) Else, use ticket_drafts table if present (ticket_id, reply_message, internal_note, created_at, updated_at)
    // 3) Else: no-op / return false
    // =========================================================================

    private function draftSupportMode(): string
    {
        try {
            if (Schema::hasTable('tickets')
                && Schema::hasColumn('tickets', 'draft_reply_message')
                && Schema::hasColumn('tickets', 'draft_internal_note')
            ) {
                return 'ticket_columns';
            }
        } catch (\Throwable $e) {
            // ignore
        }

        try {
            if (Schema::hasTable('ticket_drafts')) {
                return 'ticket_drafts_table';
            }
        } catch (\Throwable $e) {
            // ignore
        }

        return 'none';
    }

    private function getDraftForTicketId(int $ticketId): array
    {
        $ticketId = (int) $ticketId;
        if ($ticketId <= 0) {
            return ['reply_message' => '', 'internal_note' => ''];
        }

        $mode = $this->draftSupportMode();

        if ($mode === 'ticket_columns') {
            try {
                $row = DB::table('tickets')->where('id', $ticketId)->first(['draft_reply_message', 'draft_internal_note']);
                $reply = ($row && isset($row->draft_reply_message) && $row->draft_reply_message !== null) ? (string) $row->draft_reply_message : '';
                $note = ($row && isset($row->draft_internal_note) && $row->draft_internal_note !== null) ? (string) $row->draft_internal_note : '';
                return ['reply_message' => $reply, 'internal_note' => $note];
            } catch (\Throwable $e) {
                return ['reply_message' => '', 'internal_note' => ''];
            }
        }

        if ($mode === 'ticket_drafts_table') {
            try {
                $row = DB::table('ticket_drafts')->where('ticket_id', $ticketId)->first(['reply_message', 'internal_note']);
                $reply = ($row && isset($row->reply_message) && $row->reply_message !== null) ? (string) $row->reply_message : '';
                $note = ($row && isset($row->internal_note) && $row->internal_note !== null) ? (string) $row->internal_note : '';
                return ['reply_message' => $reply, 'internal_note' => $note];
            } catch (\Throwable $e) {
                return ['reply_message' => '', 'internal_note' => ''];
            }
        }

        return ['reply_message' => '', 'internal_note' => ''];
    }

    private function saveDraftForTicketId(int $ticketId, string $replyMessage, string $internalNote): bool
    {
        $ticketId = (int) $ticketId;
        if ($ticketId <= 0) {
            return false;
        }

        $mode = $this->draftSupportMode();

        if ($mode === 'ticket_columns') {
            try {
                DB::table('tickets')
                    ->where('id', $ticketId)
                    ->update([
                        'draft_reply_message' => $replyMessage,
                        'draft_internal_note' => $internalNote,
                        'updated_at' => now(),
                    ]);
                return true;
            } catch (\Throwable $e) {
                return false;
            }
        }

        if ($mode === 'ticket_drafts_table') {
            try {
                $exists = DB::table('ticket_drafts')->where('ticket_id', $ticketId)->exists();
                if ($exists) {
                    DB::table('ticket_drafts')
                        ->where('ticket_id', $ticketId)
                        ->update([
                            'reply_message' => $replyMessage,
                            'internal_note' => $internalNote,
                            'updated_at' => now(),
                        ]);
                } else {
                    DB::table('ticket_drafts')
                        ->insert([
                            'ticket_id' => $ticketId,
                            'reply_message' => $replyMessage,
                            'internal_note' => $internalNote,
                            'created_at' => now(),
                            'updated_at' => now(),
                        ]);
                }
                return true;
            } catch (\Throwable $e) {
                return false;
            }
        }

        return false;
    }

    private function clearDraftForTicketId(int $ticketId): void
    {
        $ticketId = (int) $ticketId;
        if ($ticketId <= 0) {
            return;
        }

        $mode = $this->draftSupportMode();

        if ($mode === 'ticket_columns') {
            try {
                DB::table('tickets')
                    ->where('id', $ticketId)
                    ->update([
                        'draft_reply_message' => '',
                        'draft_internal_note' => '',
                        'updated_at' => now(),
                    ]);
            } catch (\Throwable $e) {
                // ignore
            }
            return;
        }

        if ($mode === 'ticket_drafts_table') {
            try {
                DB::table('ticket_drafts')->where('ticket_id', $ticketId)->delete();
            } catch (\Throwable $e) {
                // ignore
            }
        }
    }

    public function index(Request $request)
    {
        $type = (string) $request->input('type', '');
        $status = (string) $request->input('status', '');

        $query = Ticket::query();

        if ($type !== '') {
            $query->where('type', $type);
        }

        if ($status !== '') {
            $query->where('status', $status);
        }

        $tickets = $query
            ->orderByDesc('created_at')
            ->limit(200)
            ->get();

        if ($request->expectsJson()) {
            return response()->json([
                'ok' => true,
                'tickets' => $tickets,
            ]);
        }

        $userIds = [];
        foreach ($tickets as $t) {
            if ($t->created_by_user_id !== null && (string) $t->created_by_user_id !== '') {
                $userIds[] = (int) $t->created_by_user_id;
            }
            if ($t->reported_user_id !== null && (string) $t->reported_user_id !== '') {
                $userIds[] = (int) $t->reported_user_id;
            }
        }

        $userDisplayById = $this->buildUserDisplayById($userIds);

        $ticketRows = [];
        foreach ($tickets as $t) {
            $id = (int) $t->id;
            $tType = (string) ($t->type ?? '');
            $tStatus = (string) ($t->status ?? '');
            $tCategory = (string) ($t->category ?? '');
            $tPriorityRaw = $t->priority !== null ? (string) $t->priority : '';
            $tPriorityLabel = $tPriorityRaw !== '' ? $this->labelForPriority($tPriorityRaw) : '';
            $subjectText = (string) ($t->subject ?? '');
            $creatorIdInt = ($t->created_by_user_id !== null && (string) $t->created_by_user_id !== '') ? (int) $t->created_by_user_id : 0;
            $reportedIdInt = ($t->reported_user_id !== null && (string) $t->reported_user_id !== '') ? (int) $t->reported_user_id : 0;
            $createdAt = $t->created_at ? (string) $t->created_at : '';

            $creatorDisplay = $this->displayForUserId($creatorIdInt, $userDisplayById);
            $reportedDisplay = $reportedIdInt > 0 ? $this->displayForUserId($reportedIdInt, $userDisplayById) : '-';

            $rowHref = route('admin.tickets.show', $id);

            $statusClass = $this->classForStatus($tStatus);
            $categoryClass = $this->classForCategory($tCategory);
            $priorityClass = $this->classForPriority($tPriorityRaw);

            $ticketRows[] = [
                'id' => $id,
                'href' => (string) $rowHref,

                'type_raw' => $tType,
                'type_label' => $this->labelForType($tType),

                'category_raw' => $tCategory,
                'category_label' => ($tCategory !== '' ? $this->labelForCategory($tCategory) : ''),
                'category_class' => $categoryClass,

                'priority_raw' => $tPriorityRaw,
                'priority_label' => $tPriorityLabel,
                'priority_class' => $priorityClass,

                'status_raw' => $tStatus,
                'status_label' => $this->labelForStatus($tStatus),
                'status_class' => $statusClass,

                'subject' => $subjectText,

                'creator_display' => $creatorDisplay,
                'reported_display' => $reportedDisplay,

                'created_at' => $createdAt,
            ];
        }

        $adminCtx = $this->buildAdminLayoutContext($request, 'tickets');

        return view('admin.tickets.index', array_merge($adminCtx, [
            'type' => $type,
            'status' => $status,
            'ticketRows' => $ticketRows,
        ]));
    }

    public function show(Ticket $ticket, Request $request)
    {
        $messages = $ticket->messages()
            ->orderBy('created_at', 'asc')
            ->orderBy('id', 'asc')
            ->get();

        $auditLogs = DB::table('ticket_audit_logs')
            ->where('ticket_id', $ticket->id)
            ->orderBy('created_at', 'asc')
            ->orderBy('id', 'asc')
            ->get();

        $admins = User::query()
            ->whereIn('role', ['moderator', 'admin', 'superadmin'])
            ->orderBy('id', 'asc')
            ->get(['id', 'public_id', 'username', 'email', 'role']);

        $ticket->setRelation('messages', $messages);

        if ($request->expectsJson()) {
            return response()->json([
                'ok' => true,
                'ticket' => $ticket,
                'audit' => $auditLogs,
                'admins' => $admins,
            ]);
        }

        $id = (int) $ticket->id;
        $type = (string) ($ticket->type ?? '');
        $status = (string) ($ticket->status ?? '');
        $category = (string) ($ticket->category ?? '');
        $priorityRaw = $ticket->priority !== null ? (string) $ticket->priority : '';
        $priorityLabel = $priorityRaw !== '' ? $this->labelForPriority($priorityRaw) : '';
        $subjectText = (string) ($ticket->subject ?? '');
        $messageText = (string) ($ticket->message ?? '');
        $creatorIdInt = ($ticket->created_by_user_id !== null && (string) $ticket->created_by_user_id !== '') ? (int) $ticket->created_by_user_id : 0;
        $reportedIdInt = ($ticket->reported_user_id !== null && (string) $ticket->reported_user_id !== '') ? (int) $ticket->reported_user_id : 0;
        $assignedAdminIdInt = ($ticket->assigned_admin_user_id !== null && (string) $ticket->assigned_admin_user_id !== '') ? (int) $ticket->assigned_admin_user_id : 0;
        $createdAt = $ticket->created_at ? (string) $ticket->created_at : '';
        $closedAt = $ticket->closed_at ? (string) $ticket->closed_at : '';

        $userIds = [];
        if ($creatorIdInt > 0) {
            $userIds[] = $creatorIdInt;
        }
        if ($reportedIdInt > 0) {
            $userIds[] = $reportedIdInt;
        }
        if ($assignedAdminIdInt > 0) {
            $userIds[] = $assignedAdminIdInt;
        }

        foreach ($messages as $m) {
            if (isset($m->actor_user_id) && $m->actor_user_id !== null && (string) $m->actor_user_id !== '') {
                $userIds[] = (int) $m->actor_user_id;
            }
        }

        foreach ($auditLogs as $a) {
            if (isset($a->actor_user_id) && $a->actor_user_id !== null && (string) $a->actor_user_id !== '') {
                $userIds[] = (int) $a->actor_user_id;
            }
        }

        $userMetaById = $this->buildUserMetaById($userIds);
        $userDisplayById = [];
        foreach ($userMetaById as $uid => $meta) {
            $userDisplayById[(int) $uid] = (string) ($meta['display'] ?? ('#' . (int) $uid));
        }

        $creatorDisplay = $this->displayForUserId($creatorIdInt, $userDisplayById);
        $reportedDisplay = $reportedIdInt > 0 ? $this->displayForUserId($reportedIdInt, $userDisplayById) : '-';
        $assignedAdminDisplay = $assignedAdminIdInt > 0 ? $this->displayForUserId($assignedAdminIdInt, $userDisplayById) : '-';
        $assignedAdminRole = '';
        $assignedAdminProfileUrl = '';

        $creatorRole = '';
        $reportedRole = '';
        $creatorProfileUrl = '';
        $reportedProfileUrl = '';

        if ($creatorIdInt > 0 && isset($userMetaById[$creatorIdInt])) {
            $creatorRole = (string) ($userMetaById[$creatorIdInt]['role'] ?? '');
            $creatorPublicId = (string) ($userMetaById[$creatorIdInt]['public_id'] ?? '');
            if ($creatorRole !== 'superadmin' && $creatorPublicId !== '' && Route::has('profile.show')) {
                $creatorProfileUrl = (string) route('profile.show', ['user' => $creatorPublicId]);
            }
        }

        if ($reportedIdInt > 0 && isset($userMetaById[$reportedIdInt])) {
            $reportedRole = (string) ($userMetaById[$reportedIdInt]['role'] ?? '');
            $reportedPublicId = (string) ($userMetaById[$reportedIdInt]['public_id'] ?? '');
            if ($reportedRole !== 'superadmin' && $reportedPublicId !== '' && Route::has('profile.show')) {
                $reportedProfileUrl = (string) route('profile.show', ['user' => $reportedPublicId]);
            }
        }

        if ($assignedAdminIdInt > 0 && isset($userMetaById[$assignedAdminIdInt])) {
            $assignedAdminRole = (string) ($userMetaById[$assignedAdminIdInt]['role'] ?? '');
            $assignedPublicId = (string) ($userMetaById[$assignedAdminIdInt]['public_id'] ?? '');
            if ($assignedAdminRole !== 'superadmin' && $assignedPublicId !== '' && Route::has('profile.show')) {
                $assignedAdminProfileUrl = (string) route('profile.show', ['user' => $assignedPublicId]);
            }
        }

        $statusClass = $this->classForStatus($status);
        $categoryClass = $this->classForCategory($category);
        $priorityClass = $this->classForPriority($priorityRaw);

        $notice = session('admin_ticket_notice');

        $adminOptions = [];
        $seenAdminIds = [];
        $adminOptions[] = [
            'id' => null,
            'label' => '(keiner)',
            'display' => '(keiner)',
            'role' => '',
            'role_label' => 'User',
            'profile_url' => '',
            'selected' => ($assignedAdminIdInt === 0),
        ];
        foreach ($admins as $a) {
            $aid = isset($a->id) ? (int) $a->id : 0;
            if ($aid > 0 && isset($seenAdminIds[$aid])) {
                continue;
            }
            if ($aid > 0) {
                $seenAdminIds[$aid] = true;
            }
            $aUsername = isset($a->username) ? (string) ($a->username ?? '') : '';
            $aEmail = isset($a->email) ? (string) ($a->email ?? '') : '';
            $aRole = mb_strtolower(trim((string) ($a->role ?? '')));
            $aPublicId = trim((string) ($a->public_id ?? ''));
            $label = $aUsername !== '' ? $aUsername : ($aEmail !== '' ? $aEmail : ('#' . $aid));
            $roleLabel = match ($aRole) {
                'superadmin' => 'Superadmin',
                'admin' => 'Admin',
                'moderator' => 'Moderator',
                default => 'User',
            };
            $labelWithRole = $label;
            if (mb_strtolower(trim($label)) !== mb_strtolower(trim($roleLabel))) {
                $labelWithRole = $label . ' (' . $roleLabel . ')';
            }

            $adminOptions[] = [
                'id' => $aid,
                'label' => $labelWithRole,
                'display' => $label,
                'role' => $aRole,
                'role_label' => $roleLabel,
                'profile_url' => ($aRole !== 'superadmin' && $aPublicId !== '' && Route::has('profile.show'))
                    ? (string) route('profile.show', ['user' => $aPublicId])
                    : '',
                'selected' => ($aid === $assignedAdminIdInt),
            ];
        }

        $categoryOptions = [];
        $categoryOptions[] = [
            'value' => '',
            'label' => '(keine)',
            'selected' => ($category === ''),
        ];
        foreach (['support', 'abuse', 'spam', 'billing', 'bug'] as $c) {
            $categoryOptions[] = [
                'value' => $c,
                'label' => $this->labelForCategory($c),
                'selected' => ($category === $c),
            ];
        }

        $priorityOptions = [];
        $priorityOptions[] = [
            'value' => '',
            'label' => '(keine)',
            'selected' => ($priorityRaw === ''),
        ];
        foreach (['low', 'normal', 'high', 'critical'] as $p) {
            $priorityOptions[] = [
                'value' => $p,
                'label' => $this->labelForPriority($p),
                'selected' => ($priorityRaw === $p),
            ];
        }

        $statusOptions = [];
        foreach (['open', 'in_progress', 'closed', 'rejected', 'escalated'] as $s) {
            $statusOptions[] = [
                'value' => $s,
                'label' => $this->labelForStatus($s),
                'selected' => ($status === $s),
            ];
        }

        $messageRows = [];
        foreach ($messages as $m) {
            $actorTypeMsg = (string) ($m->actor_type ?? '');
            $actorUserIdMsgInt = ($m->actor_user_id !== null && (string) $m->actor_user_id !== '') ? (int) $m->actor_user_id : 0;
            $isInternal = (bool) ($m->is_internal ?? false);
            $msgText = (string) ($m->message ?? '');
            $ts = $m->created_at ? (string) $m->created_at : '';

            $who = '-';
            if ($actorUserIdMsgInt > 0) {
                $disp = $this->displayForUserId($actorUserIdMsgInt, $userDisplayById);
                $who = ($disp !== '' ? $disp : ('#' . $actorUserIdMsgInt));
            } elseif ($actorTypeMsg !== '') {
                $who = ucfirst($actorTypeMsg);
            }

            $actorRole = '';
            $actorRoleLabel = 'User';
            if ($actorUserIdMsgInt > 0 && isset($userMetaById[$actorUserIdMsgInt])) {
                $actorRole = (string) ($userMetaById[$actorUserIdMsgInt]['role'] ?? '');
            }

            $actorRoleClass = 'bg-slate-100 border-slate-200 text-slate-900';
            if ($actorRole === 'superadmin') {
                $actorRoleLabel = 'Superadmin';
                $actorRoleClass = 'bg-red-100 border-red-200 text-slate-900';
            } elseif ($actorRole === 'admin') {
                $actorRoleLabel = 'Admin';
                $actorRoleClass = 'bg-yellow-100 border-yellow-200 text-slate-900';
            } elseif ($actorRole === 'moderator') {
                $actorRoleLabel = 'Moderator';
                $actorRoleClass = 'bg-green-100 border-green-200 text-slate-900';
            } elseif ($actorTypeMsg === 'admin') {
                $actorRoleLabel = 'Admin';
                $actorRoleClass = 'bg-yellow-100 border-yellow-200 text-slate-900';
            } elseif ($actorTypeMsg === 'user') {
                $actorRoleLabel = 'User';
                $actorRoleClass = 'bg-slate-100 border-slate-200 text-slate-900';
            }

            $messageRows[] = [
                'who' => $who,
                'pill_class' => 'ks-pill',
                'is_internal' => $isInternal,
                'message' => $msgText,
                'created_at' => $ts,
                'actor_type' => $actorTypeMsg,
                'actor_user_id' => $actorUserIdMsgInt,
                'actor_role_label' => $actorRoleLabel,
                'actor_role_class' => $actorRoleClass,
            ];
        }

        $auditRows = [];
        foreach ($auditLogs as $a) {
            $ts = isset($a->created_at) ? (string) $a->created_at : '';
            $ev = isset($a->event) ? (string) $a->event : '';
            $actorType = isset($a->actor_type) ? (string) $a->actor_type : '';
            $actorUserIdInt = (isset($a->actor_user_id) && $a->actor_user_id !== null && (string) $a->actor_user_id !== '') ? (int) $a->actor_user_id : 0;
            $meta = isset($a->meta) && $a->meta !== null ? (string) $a->meta : '';

            $who = '-';
            if ($actorUserIdInt > 0) {
                $disp = $this->displayForUserId($actorUserIdInt, $userDisplayById);
                $who = ($disp !== '' ? $disp : ('#' . $actorUserIdInt));
            } elseif ($actorType !== '') {
                $who = ucfirst($actorType);
            }

            $auditRole = '';
            $auditRoleLabel = 'User';
            if ($actorUserIdInt > 0 && isset($userMetaById[$actorUserIdInt])) {
                $auditRole = (string) ($userMetaById[$actorUserIdInt]['role'] ?? '');
            }

            $auditRoleClass = 'bg-slate-100 border-slate-200 text-slate-900';
            if ($auditRole === 'superadmin') {
                $auditRoleLabel = 'Superadmin';
                $auditRoleClass = 'bg-red-100 border-red-200 text-slate-900';
            } elseif ($auditRole === 'admin') {
                $auditRoleLabel = 'Admin';
                $auditRoleClass = 'bg-yellow-100 border-yellow-200 text-slate-900';
            } elseif ($auditRole === 'moderator') {
                $auditRoleLabel = 'Moderator';
                $auditRoleClass = 'bg-green-100 border-green-200 text-slate-900';
            } elseif (mb_strtolower($actorType) === 'admin') {
                $auditRoleLabel = 'Admin';
                $auditRoleClass = 'bg-yellow-100 border-yellow-200 text-slate-900';
            }

            $auditRows[] = [
                'created_at' => $ts,
                'event' => $ev,
                'event_label' => $this->labelForAuditEvent($ev),
                'who' => $who,
                'actor_role_label' => $auditRoleLabel,
                'actor_role_class' => $auditRoleClass,
                'meta' => $meta,
            ];
        }

        $draft = $this->getDraftForTicketId($id);

        $draftSaveUrl = '';
        if (Route::has('admin.tickets.draftSave')) {
            $draftSaveUrl = (string) route('admin.tickets.draftSave', $id);
        } else {
            // fallback (requires matching route path to be defined)
            $draftSaveUrl = (string) url('/admin/tickets/' . $id . '/draft-save');
        }

        $adminCtx = $this->buildAdminLayoutContext($request, 'tickets');

        return view('admin.tickets.show', array_merge($adminCtx, [
            'ticketId' => $id,

            'type' => $type,
            'typeLabel' => $this->labelForType($type),

            'status' => $status,
            'statusLabel' => $this->labelForStatus($status),
            'statusClass' => $statusClass,

            'category' => $category,
            'categoryLabel' => ($category !== '' ? $this->labelForCategory($category) : ''),
            'categoryClass' => $categoryClass,

            'priorityRaw' => $priorityRaw,
            'priorityLabel' => $priorityLabel,
            'priorityClass' => $priorityClass,

            'subjectText' => $subjectText,
            'messageText' => $messageText,

            'creatorDisplay' => $creatorDisplay,
            'reportedDisplay' => $reportedDisplay,
            'assignedAdminDisplay' => $assignedAdminDisplay,
            'assignedAdminRole' => $assignedAdminRole,
            'assignedAdminProfileUrl' => $assignedAdminProfileUrl,
            'creatorRole' => $creatorRole,
            'reportedRole' => $reportedRole,
            'creatorProfileUrl' => $creatorProfileUrl,
            'reportedProfileUrl' => $reportedProfileUrl,

            'createdAt' => $createdAt,
            'closedAt' => $closedAt,

            'notice' => $notice,

            'adminOptions' => $adminOptions,
            'categoryOptions' => $categoryOptions,
            'priorityOptions' => $priorityOptions,
            'statusOptions' => $statusOptions,

            'messageRows' => $messageRows,
            'auditRows' => $auditRows,

            'isReport' => ($type === 'report'),

            'draftSaveUrl' => $draftSaveUrl,
            'draftReplyText' => (string) ($draft['reply_message'] ?? ''),
            'draftInternalText' => (string) ($draft['internal_note'] ?? ''),
        ]));
    }

    public function reply(Ticket $ticket, Request $request)
    {
        $request->validate([
            'reply_message' => ['nullable', 'string', 'min:2', 'required_without:internal_note'],
            'internal_note' => ['nullable', 'string', 'min:2', 'required_without:reply_message'],
        ]);

        $actorUserId = (int) auth()->id();
        if ($actorUserId < 1) {
            if ($request->expectsJson()) {
                return response()->json(['ok' => false, 'message' => 'Not authenticated.'], 401);
            }

            return redirect()->route('admin.tickets.show', (int) $ticket->id)
                ->with('admin_ticket_notice', 'Fehler: Nicht angemeldet.');
        }

        $replyMessage = $request->filled('reply_message') ? trim((string) $request->input('reply_message')) : null;
        $internalNote = $request->filled('internal_note') ? trim((string) $request->input('internal_note')) : null;

        if ($replyMessage === '') {
            $replyMessage = null;
        }
        if ($internalNote === '') {
            $internalNote = null;
        }

        $beforeCount = null;
        $hasMsgTable = false;
        try {
            $hasMsgTable = Schema::hasTable('ticket_messages');
        } catch (\Throwable $e) {
            $hasMsgTable = false;
        }

        if ($hasMsgTable) {
            try {
                $beforeCount = (int) DB::table('ticket_messages')->where('ticket_id', (int) $ticket->id)->count();
            } catch (\Throwable $e) {
                $beforeCount = null;
            }
        }

        try {
            if ($replyMessage !== null) {
                $this->ticketService->addAdminReply(
                    $ticket,
                    $actorUserId,
                    (string) $replyMessage,
                    false
                );
            }

            if ($internalNote !== null) {
                $this->ticketService->addAdminReply(
                    $ticket,
                    $actorUserId,
                    (string) $internalNote,
                    true
                );
            }
        } catch (\Throwable $e) {
            if ($request->expectsJson()) {
                return response()->json(['ok' => false, 'message' => 'Save failed.'], 500);
            }

            return redirect()->route('admin.tickets.show', (int) $ticket->id)
                ->with('admin_ticket_notice', 'Fehler beim Speichern.');
        }

        // Fallback: if TicketService does not persist for some reason, write directly (only if tables exist).
        if ($hasMsgTable && $beforeCount !== null) {
            try {
                $afterCount = (int) DB::table('ticket_messages')->where('ticket_id', (int) $ticket->id)->count();

                if ($afterCount <= $beforeCount) {
                    $now = now();

                    if ($replyMessage !== null) {
                        DB::table('ticket_messages')->insert([
                            'ticket_id' => (int) $ticket->id,
                            'actor_type' => 'admin',
                            'actor_user_id' => $actorUserId,
                            'is_internal' => 0,
                            'message' => (string) $replyMessage,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ]);

                        if (Schema::hasTable('ticket_audit_logs')) {
                            DB::table('ticket_audit_logs')->insert([
                                'ticket_id' => (int) $ticket->id,
                                'event' => 'admin_reply_added',
                                'actor_type' => 'admin',
                                'actor_user_id' => $actorUserId,
                                'meta' => '',
                                'created_at' => $now,
                                'updated_at' => $now,
                            ]);
                        }
                    }

                    if ($internalNote !== null) {
                        DB::table('ticket_messages')->insert([
                            'ticket_id' => (int) $ticket->id,
                            'actor_type' => 'admin',
                            'actor_user_id' => $actorUserId,
                            'is_internal' => 1,
                            'message' => (string) $internalNote,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ]);

                        if (Schema::hasTable('ticket_audit_logs')) {
                            DB::table('ticket_audit_logs')->insert([
                                'ticket_id' => (int) $ticket->id,
                                'event' => 'internal_note_added',
                                'actor_type' => 'admin',
                                'actor_user_id' => $actorUserId,
                                'meta' => '',
                                'created_at' => $now,
                                'updated_at' => $now,
                            ]);
                        }
                    }
                }
            } catch (\Throwable $e) {
                // ignore
            }
        }

        // Drafts must not count as replies; when sending, clear drafts.
        $this->clearDraftForTicketId((int) $ticket->id);

        if ($request->expectsJson()) {
            return response()->json(['ok' => true]);
        }

        return redirect()->route('admin.tickets.show', (int) $ticket->id)
            ->with('admin_ticket_notice', 'Eintrag gespeichert.');
    }

    public function close(Ticket $ticket, Request $request)
    {
        $this->ticketService->closeTicket(
            $ticket,
            (int) auth()->id()
        );

        if ($request->expectsJson()) {
            return response()->json(['ok' => true]);
        }

        return redirect()->route('admin.tickets.show', (int) $ticket->id)
            ->with('admin_ticket_notice', 'Ticket geschlossen.');
    }

    // =========================================================================
    // B3 – Meta Update (assign/category/priority/status)
    // =========================================================================

    public function updateMeta(Ticket $ticket, Request $request)
    {
        $request->validate([
            'assigned_admin_user_id' => ['nullable'],
            'category' => ['nullable', 'string'],
            'priority' => ['nullable', 'string'],
            'status' => ['required', 'string'],
        ]);

        $assignedRaw = $request->input('assigned_admin_user_id', null);
        $assignedAdminUserId = null;

        if ($assignedRaw !== null && (string) $assignedRaw !== '') {
            $assignedAdminUserId = (int) $assignedRaw;
        }

        $this->ticketService->assignAdmin(
            $ticket,
            (int) auth()->id(),
            $assignedAdminUserId
        );

        $this->ticketService->setCategory(
            $ticket,
            (int) auth()->id(),
            $request->filled('category') ? (string) $request->input('category') : null
        );

        $this->ticketService->setPriority(
            $ticket,
            (int) auth()->id(),
            $request->filled('priority') ? (string) $request->input('priority') : null
        );

        $this->ticketService->setStatus(
            $ticket,
            (int) auth()->id(),
            (string) $request->input('status')
        );

        if ($request->expectsJson()) {
            return response()->json(['ok' => true]);
        }

        return redirect()->route('admin.tickets.show', (int) $ticket->id)
            ->with('admin_ticket_notice', 'Ticket aktualisiert.');
    }

    // =========================================================================
    // Draft autosave (reply + internal note) - MUST NOT create messages/events
    // =========================================================================

    public function draftSave(Ticket $ticket, Request $request)
    {
        $request->validate([
            'reply_message' => ['nullable', 'string'],
            'internal_note' => ['nullable', 'string'],
        ]);

        $replyMessage = $request->filled('reply_message') ? (string) $request->input('reply_message') : '';
        $internalNote = $request->filled('internal_note') ? (string) $request->input('internal_note') : '';

        $ok = $this->saveDraftForTicketId((int) $ticket->id, $replyMessage, $internalNote);

        if ($request->expectsJson()) {
            return response()->json([
                'ok' => $ok,
                'draft_mode' => $this->draftSupportMode(),
            ]);
        }

        return redirect()->route('admin.tickets.show', (int) $ticket->id)
            ->with('admin_ticket_notice', $ok ? 'Entwurf gespeichert.' : 'Entwurf konnte nicht gespeichert werden.');
    }

    // =========================================================================
    // B4 – Moderation Quick Actions
    // =========================================================================

    public function moderateWarn(Ticket $ticket, Request $request)
    {
        $request->validate([
            'note' => ['nullable', 'string'],
        ]);

        $this->ticketService->reportWarnUser(
            $ticket,
            (int) auth()->id(),
            $request->filled('note') ? (string) $request->input('note') : null
        );

        if ($request->expectsJson()) {
            return response()->json(['ok' => true]);
        }

        return redirect()->route('admin.tickets.show', (int) $ticket->id)
            ->with('admin_ticket_notice', 'Moderation: Verwarnung ausgeführt. Ticket geschlossen.');
    }

    public function moderateTempBan(Ticket $ticket, Request $request)
    {
        $request->validate([
            'days' => ['required', 'integer', 'min:1', 'max:365'],
            'note' => ['nullable', 'string'],
        ]);

        $this->ticketService->reportTempBanUser(
            $ticket,
            (int) auth()->id(),
            (int) $request->input('days'),
            $request->filled('note') ? (string) $request->input('note') : null
        );

        if ($request->expectsJson()) {
            return response()->json(['ok' => true]);
        }

        return redirect()->route('admin.tickets.show', (int) $ticket->id)
            ->with('admin_ticket_notice', 'Moderation: Temporäre Sperre ausgeführt. Ticket geschlossen.');
    }

    public function moderatePermBan(Ticket $ticket, Request $request)
    {
        $request->validate([
            'note' => ['nullable', 'string'],
        ]);

        $this->ticketService->reportPermBanUser(
            $ticket,
            (int) auth()->id(),
            $request->filled('note') ? (string) $request->input('note') : null
        );

        if ($request->expectsJson()) {
            return response()->json(['ok' => true]);
        }

        return redirect()->route('admin.tickets.show', (int) $ticket->id)
            ->with('admin_ticket_notice', 'Moderation: Dauerhafte Sperre ausgeführt. Ticket geschlossen.');
    }

    public function moderateUnfounded(Ticket $ticket, Request $request)
    {
        $request->validate([
            'note' => ['nullable', 'string'],
        ]);

        $this->ticketService->reportMarkUnfounded(
            $ticket,
            (int) auth()->id(),
            $request->filled('note') ? (string) $request->input('note') : null
        );

        if ($request->expectsJson()) {
            return response()->json(['ok' => true]);
        }

        return redirect()->route('admin.tickets.show', (int) $ticket->id)
            ->with('admin_ticket_notice', 'Moderation: Als unbegründet markiert. Ticket geschlossen.');
    }
}