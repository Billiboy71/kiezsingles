<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\TicketService.php
// Purpose: Central domain/service layer for Ticket workflows (create/reply/close).
// Changed: 20-02-2026 17:35 (Europe/Berlin)
// Version: 0.8
// ============================================================================

namespace App\Services;

use App\Events\TicketAssignedAdmin;
use App\Events\TicketCategoryChanged;
use App\Events\TicketClosed;
use App\Events\TicketCreated;
use App\Events\TicketPriorityChanged;
use App\Events\TicketReplied;
use App\Events\TicketReportMarkedUnfounded;
use App\Events\TicketReportUserPermanentlyBanned;
use App\Events\TicketReportUserTemporarilyBanned;
use App\Events\TicketReportUserWarned;
use App\Events\TicketStatusChanged;
use App\Models\Ticket;
use App\Models\TicketMessage;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use RuntimeException;

class TicketService
{
    private const TICKET_TYPES = [
        'support',
        'report',
    ];

    private const TICKET_STATUSES = [
        'open',
        'in_progress',
        'closed',
        'rejected',
        'escalated',
    ];

    private const TICKET_CATEGORIES = [
        'support',
        'abuse',
        'spam',
        'billing',
        'bug',
    ];

    private const TICKET_PRIORITIES = [
        'low',
        'normal',
        'high',
        'critical',
    ];

    private const PRIORITY_TO_INT = [
        'low' => 1,
        'normal' => 2,
        'high' => 3,
        'critical' => 4,
    ];

    private const INT_TO_PRIORITY = [
        1 => 'low',
        2 => 'normal',
        3 => 'high',
        4 => 'critical',
    ];

    public function createSupportTicket(int $actorUserId, string $subject, string $message): Ticket
    {
        $subject = (string) $subject;
        $message = (string) $message;

        return DB::transaction(function () use ($actorUserId, $subject, $message) {
            $ticket = Ticket::create([
                'public_id' => (string) Str::uuid(),
                'type' => 'support',
                'status' => 'open',
                'subject' => $subject,
                'message' => $message,
                'created_by_user_id' => $actorUserId,
                'reported_user_id' => null,
            ]);

            $firstMsg = TicketMessage::create([
                'ticket_id' => $ticket->id,
                'actor_type' => 'user',
                'actor_user_id' => $actorUserId,
                'message' => $message,
                'is_internal' => false,
            ]);

            // A) Domain Event
            event(new TicketCreated($ticket, 'user', (int) $actorUserId));

            // D) Audit Log (server-side)
            Log::info('ticket.created', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'user',
                'actor_user_id' => (int) $actorUserId,
                'message_id' => (int) $firstMsg->id,
            ]);

            return $ticket;
        });
    }

    public function createReportTicket(int $actorUserId, User $reportedUser, string $message): Ticket
    {
        $message = (string) $message;

        return DB::transaction(function () use ($actorUserId, $reportedUser, $message) {
            $ticket = Ticket::create([
                'public_id' => (string) Str::uuid(),
                'type' => 'report',
                'status' => 'open',
                'subject' => 'Meldung',
                'message' => $message,
                'created_by_user_id' => $actorUserId,
                'reported_user_id' => (int) $reportedUser->id,
            ]);

            $firstMsg = TicketMessage::create([
                'ticket_id' => $ticket->id,
                'actor_type' => 'user',
                'actor_user_id' => $actorUserId,
                'message' => $message,
                'is_internal' => false,
            ]);

            // A) Domain Event
            event(new TicketCreated($ticket, 'user', (int) $actorUserId));

            // D) Audit Log (server-side)
            Log::info('ticket.created', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'user',
                'actor_user_id' => (int) $actorUserId,
                'reported_user_id' => (int) $reportedUser->id,
                'message_id' => (int) $firstMsg->id,
            ]);

            return $ticket;
        });
    }

    public function addUserReply(Ticket $ticket, int $actorUserId, string $message): void
    {
        $message = (string) $message;

        DB::transaction(function () use ($ticket, $actorUserId, $message) {
            $msg = TicketMessage::create([
                'ticket_id' => $ticket->id,
                'actor_type' => 'user',
                'actor_user_id' => $actorUserId,
                'message' => $message,
                'is_internal' => false,
            ]);

            if ((string) ($ticket->status ?? '') === 'open') {
                $ticket->update(['status' => 'in_progress']);
            }

            // A) Domain Event
            event(new TicketReplied($ticket, $msg, 'user'));

            // D) Audit Log (server-side)
            Log::info('ticket.replied', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'user',
                'actor_user_id' => (int) $actorUserId,
                'message_id' => (int) $msg->id,
                'is_internal' => false,
            ]);
        });
    }

    public function addAdminReply(Ticket $ticket, int $actorAdminUserId, string $message, bool $isInternal): void
    {
        $message = (string) $message;

        DB::transaction(function () use ($ticket, $actorAdminUserId, $message, $isInternal) {
            $this->assertAdminUserId($actorAdminUserId);

            $msg = TicketMessage::create([
                'ticket_id' => $ticket->id,
                'actor_type' => 'admin',
                'actor_user_id' => $actorAdminUserId,
                'message' => $message,
                'is_internal' => (bool) $isInternal,
            ]);

            if ((string) ($ticket->status ?? '') === 'open') {
                $ticket->update(['status' => 'in_progress']);
            }

            // A) Domain Event
            event(new TicketReplied($ticket, $msg, 'admin'));

            // D) Audit Log (server-side)
            Log::info('ticket.replied', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'admin',
                'actor_user_id' => (int) $actorAdminUserId,
                'message_id' => (int) $msg->id,
                'is_internal' => (bool) $isInternal,
            ]);
        });
    }

    public function closeTicket(Ticket $ticket, int $actorAdminUserId): void
    {
        DB::transaction(function () use ($ticket, $actorAdminUserId) {
            $this->assertAdminUserId($actorAdminUserId);

            $ticket->update([
                'status' => 'closed',
                'closed_at' => now(),
            ]);

            // A) Domain Event
            event(new TicketClosed($ticket, 'admin', (int) $actorAdminUserId));

            // D) Audit Log (server-side)
            Log::info('ticket.closed', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'admin',
                'actor_user_id' => (int) $actorAdminUserId,
            ]);
        });
    }

    // =========================================================================
    // B3: Admin Assignment / Category / Priority / Status Management
    // =========================================================================

    public function assignAdmin(Ticket $ticket, int $actorAdminUserId, ?int $assignedAdminUserId): void
    {
        DB::transaction(function () use ($ticket, $actorAdminUserId, $assignedAdminUserId) {
            $this->assertAdminUserId($actorAdminUserId);

            $assignedAdmin = null;
            if ($assignedAdminUserId !== null) {
                $assignedAdmin = $this->assertAdminUserId($assignedAdminUserId);
            }

            $oldAssigned = $ticket->assigned_admin_user_id ?? null;
            $newAssigned = $assignedAdmin ? (int) $assignedAdmin->id : null;

            if ((int) ($oldAssigned ?? 0) === (int) ($newAssigned ?? 0)) {
                return;
            }

            $ticket->update([
                'assigned_admin_user_id' => $newAssigned,
            ]);

            // A) Domain Event
            event(new TicketAssignedAdmin($ticket, (int) $actorAdminUserId, $oldAssigned !== null ? (int) $oldAssigned : null, $newAssigned));

            // D) Audit Log
            Log::info('ticket.assigned', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'admin',
                'actor_user_id' => (int) $actorAdminUserId,
                'old_assigned_admin_user_id' => $oldAssigned !== null ? (int) $oldAssigned : null,
                'new_assigned_admin_user_id' => $newAssigned,
            ]);
        });
    }

    public function setCategory(Ticket $ticket, int $actorAdminUserId, ?string $category): void
    {
        $category = $category !== null ? trim((string) $category) : null;
        $category = $category === '' ? null : $category;

        DB::transaction(function () use ($ticket, $actorAdminUserId, $category) {
            $this->assertAdminUserId($actorAdminUserId);

            if ($category !== null && !in_array($category, self::TICKET_CATEGORIES, true)) {
                throw new RuntimeException('Invalid ticket category.');
            }

            $old = $ticket->category ?? null;
            $new = $category;

            if ((string) ($old ?? '') === (string) ($new ?? '')) {
                return;
            }

            $ticket->update([
                'category' => $new,
            ]);

            // A) Domain Event
            event(new TicketCategoryChanged($ticket, (int) $actorAdminUserId, $old !== null ? (string) $old : null, $new));

            // D) Audit Log
            Log::info('ticket.category_changed', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'admin',
                'actor_user_id' => (int) $actorAdminUserId,
                'old_category' => $old !== null ? (string) $old : null,
                'new_category' => $new,
            ]);
        });
    }

    public function setPriority(Ticket $ticket, int $actorAdminUserId, ?string $priority): void
    {
        $priority = $priority !== null ? trim((string) $priority) : null;
        $priority = $priority === '' ? null : $priority;

        DB::transaction(function () use ($ticket, $actorAdminUserId, $priority) {
            $this->assertAdminUserId($actorAdminUserId);

            if ($priority !== null && !in_array($priority, self::TICKET_PRIORITIES, true)) {
                throw new RuntimeException('Invalid ticket priority.');
            }

            $oldRaw = $ticket->priority ?? null;
            $oldKey = $this->normalizePriorityKey($oldRaw);
            $newKey = $priority;

            if ((string) ($oldKey ?? '') === (string) ($newKey ?? '')) {
                return;
            }

            $dbValue = $this->priorityKeyToDbValue($newKey);

            $ticket->update([
                'priority' => $dbValue,
            ]);

            // A) Domain Event
            event(new TicketPriorityChanged(
                $ticket,
                (int) $actorAdminUserId,
                $oldKey !== null ? (string) $oldKey : null,
                $newKey
            ));

            // D) Audit Log
            Log::info('ticket.priority_changed', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'admin',
                'actor_user_id' => (int) $actorAdminUserId,
                'old_priority' => $oldKey !== null ? (string) $oldKey : null,
                'new_priority' => $newKey,
            ]);
        });
    }

    public function setStatus(Ticket $ticket, int $actorAdminUserId, string $status): void
    {
        $status = trim((string) $status);

        DB::transaction(function () use ($ticket, $actorAdminUserId, $status) {
            $this->assertAdminUserId($actorAdminUserId);

            if (!in_array($status, self::TICKET_STATUSES, true)) {
                throw new RuntimeException('Invalid ticket status.');
            }

            $old = (string) ($ticket->status ?? '');
            $new = (string) $status;

            if ($old === $new) {
                return;
            }

            $update = ['status' => $new];

            if ($new === 'closed') {
                $update['closed_at'] = now();
            } else {
                $update['closed_at'] = null;
            }

            $ticket->update($update);

            // A) Domain Event
            event(new TicketStatusChanged($ticket, (int) $actorAdminUserId, $old, $new));

            // D) Audit Log
            Log::info('ticket.status_changed', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'actor_type' => 'admin',
                'actor_user_id' => (int) $actorAdminUserId,
                'old_status' => $old,
                'new_status' => $new,
            ]);

            if ($new === 'closed') {
                event(new TicketClosed($ticket, 'admin', (int) $actorAdminUserId));

                Log::info('ticket.closed', [
                    'ticket_id' => (int) $ticket->id,
                    'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                    'type' => (string) ($ticket->type ?? ''),
                    'status' => (string) ($ticket->status ?? ''),
                    'actor_type' => 'admin',
                    'actor_user_id' => (int) $actorAdminUserId,
                    'via' => 'status_change',
                ]);
            }
        });
    }

    // =========================================================================
    // B4: Moderation Quick Actions for report tickets
    // =========================================================================

    public function reportWarnUser(Ticket $ticket, int $actorAdminUserId, ?string $note = null): void
    {
        $note = $note !== null ? trim((string) $note) : null;
        $note = $note === '' ? null : $note;

        DB::transaction(function () use ($ticket, $actorAdminUserId, $note) {
            $actor = $this->assertAdminUserId($actorAdminUserId);
            $reported = $this->getReportedUserForReportTicket($ticket);

            if ((int) $reported->id === (int) $actor->id) {
                throw new RuntimeException('Self-action is not allowed.');
            }

            $reported->update([
                'moderation_warned_at' => now(),
                'moderation_warn_count' => (int) ($reported->moderation_warn_count ?? 0) + 1,
            ]);

            event(new TicketReportUserWarned($ticket, (int) $actorAdminUserId, (int) $reported->id));

            Log::info('ticket.moderation.warned', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'admin',
                'actor_user_id' => (int) $actorAdminUserId,
                'reported_user_id' => (int) $reported->id,
                'note' => $note,
            ]);

            $this->closeTicketInternal($ticket, (int) $actorAdminUserId, 'moderation_warn');
        });
    }

    public function reportTempBanUser(Ticket $ticket, int $actorAdminUserId, int $days, ?string $note = null): void
    {
        $days = (int) $days;
        $note = $note !== null ? trim((string) $note) : null;
        $note = $note === '' ? null : $note;

        if ($days < 1 || $days > 365) {
            throw new RuntimeException('Invalid ban duration.');
        }

        DB::transaction(function () use ($ticket, $actorAdminUserId, $days, $note) {
            $actor = $this->assertAdminUserId($actorAdminUserId);
            $reported = $this->getReportedUserForReportTicket($ticket);

            if ((int) $reported->id === (int) $actor->id) {
                throw new RuntimeException('Self-action is not allowed.');
            }

            $reported->update([
                'moderation_blocked_at' => now(),
                'moderation_blocked_until' => now()->addDays($days),
                'moderation_blocked_permanent' => false,
                'moderation_blocked_reason' => $note,
            ]);

            event(new TicketReportUserTemporarilyBanned($ticket, (int) $actorAdminUserId, (int) $reported->id, (int) $days));

            Log::info('ticket.moderation.temp_banned', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'admin',
                'actor_user_id' => (int) $actorAdminUserId,
                'reported_user_id' => (int) $reported->id,
                'days' => (int) $days,
                'note' => $note,
            ]);

            $this->closeTicketInternal($ticket, (int) $actorAdminUserId, 'moderation_temp_ban');
        });
    }

    public function reportPermBanUser(Ticket $ticket, int $actorAdminUserId, ?string $note = null): void
    {
        $note = $note !== null ? trim((string) $note) : null;
        $note = $note === '' ? null : $note;

        DB::transaction(function () use ($ticket, $actorAdminUserId, $note) {
            $actor = $this->assertAdminUserId($actorAdminUserId);
            $reported = $this->getReportedUserForReportTicket($ticket);

            if ((int) $reported->id === (int) $actor->id) {
                throw new RuntimeException('Self-action is not allowed.');
            }

            $reported->update([
                'moderation_blocked_at' => now(),
                'moderation_blocked_until' => null,
                'moderation_blocked_permanent' => true,
                'moderation_blocked_reason' => $note,
            ]);

            event(new TicketReportUserPermanentlyBanned($ticket, (int) $actorAdminUserId, (int) $reported->id));

            Log::info('ticket.moderation.perm_banned', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'admin',
                'actor_user_id' => (int) $actorAdminUserId,
                'reported_user_id' => (int) $reported->id,
                'note' => $note,
            ]);

            $this->closeTicketInternal($ticket, (int) $actorAdminUserId, 'moderation_perm_ban');
        });
    }

    public function reportMarkUnfounded(Ticket $ticket, int $actorAdminUserId, ?string $note = null): void
    {
        $note = $note !== null ? trim((string) $note) : null;
        $note = $note === '' ? null : $note;

        DB::transaction(function () use ($ticket, $actorAdminUserId, $note) {
            $this->assertAdminUserId($actorAdminUserId);
            $this->assertIsReportTicket($ticket);

            event(new TicketReportMarkedUnfounded($ticket, (int) $actorAdminUserId));

            Log::info('ticket.moderation.unfounded', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'admin',
                'actor_user_id' => (int) $actorAdminUserId,
                'reported_user_id' => $ticket->reported_user_id !== null ? (int) $ticket->reported_user_id : null,
                'note' => $note,
            ]);

            $this->closeTicketInternal($ticket, (int) $actorAdminUserId, 'moderation_unfounded');
        });
    }

    // =========================================================================
    // Internals
    // =========================================================================

    private function assertAdminUserId(int $userId): User
    {
        $user = User::query()->findOrFail((int) $userId);

        $role = mb_strtolower(trim((string) ($user->role ?? '')));
        if (!in_array($role, ['admin', 'superadmin'], true)) {
            throw new RuntimeException('Admin privileges required.');
        }

        return $user;
    }

    private function assertIsReportTicket(Ticket $ticket): void
    {
        if ((string) ($ticket->type ?? '') !== 'report') {
            throw new RuntimeException('Ticket is not a report ticket.');
        }

        if ($ticket->reported_user_id === null) {
            throw new RuntimeException('Report ticket has no reported user.');
        }
    }

    private function getReportedUserForReportTicket(Ticket $ticket): User
    {
        $this->assertIsReportTicket($ticket);

        return User::query()->findOrFail((int) $ticket->reported_user_id);
    }

    private function closeTicketInternal(Ticket $ticket, int $actorAdminUserId, string $via): void
    {
        if ((string) ($ticket->status ?? '') === 'closed') {
            return;
        }

        $ticket->update([
            'status' => 'closed',
            'closed_at' => now(),
        ]);

        event(new TicketClosed($ticket, 'admin', (int) $actorAdminUserId));

        Log::info('ticket.closed', [
            'ticket_id' => (int) $ticket->id,
            'ticket_public_id' => (string) ($ticket->public_id ?? ''),
            'type' => (string) ($ticket->type ?? ''),
            'status' => (string) ($ticket->status ?? ''),
            'actor_type' => 'admin',
            'actor_user_id' => (int) $actorAdminUserId,
            'via' => (string) $via,
        ]);
    }

    private function normalizePriorityKey($raw): ?string
    {
        if ($raw === null) {
            return null;
        }

        if (is_int($raw)) {
            return self::INT_TO_PRIORITY[$raw] ?? null;
        }

        if (is_string($raw) && $raw !== '' && ctype_digit($raw)) {
            $int = (int) $raw;
            return self::INT_TO_PRIORITY[$int] ?? null;
        }

        if (is_string($raw)) {
            $key = trim($raw);
            if ($key === '') {
                return null;
            }
            if (in_array($key, self::TICKET_PRIORITIES, true)) {
                return $key;
            }
        }

        return null;
    }

    private function priorityKeyToDbValue(?string $key): ?int
    {
        if ($key === null) {
            return null;
        }

        return self::PRIORITY_TO_INT[$key] ?? null;
    }
}