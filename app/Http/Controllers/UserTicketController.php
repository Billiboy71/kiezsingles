<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Controllers\UserTicketController.php
// Purpose: User ticket endpoints (support + report + show + reply).
// Changed: 06-03-2026 13:00 (Europe/Berlin)
// Version: 0.3
// ============================================================================

namespace App\Http\Controllers;

use App\Models\Ticket;
use App\Models\User;
use App\Services\TicketService;
use Illuminate\Http\Request;

class UserTicketController extends Controller
{
    public function __construct(
        protected TicketService $ticketService
    ) {}

    public function index(Request $request)
    {
        $tickets = Ticket::where('created_by_user_id', auth()->id())
            ->orderByDesc('created_at')
            ->limit(100)
            ->get();

        return response()->json([
            'ok' => true,
            'tickets' => $tickets,
        ]);
    }

    public function show(string $publicId, Request $request)
    {
        $publicId = trim($publicId);

        if ($publicId === '' || strlen($publicId) > 64) {
            return response()->json(['ok' => false, 'message' => 'invalid ticket id'], 422);
        }

        $ticket = Ticket::where('public_id', $publicId)
            ->where('created_by_user_id', auth()->id())
            ->first();

        if (!$ticket) {
            return response()->json(['ok' => false, 'message' => 'not found'], 404);
        }

        $ticket->load('messages');

        return response()->json([
            'ok' => true,
            'ticket' => $ticket,
        ]);
    }

    public function reply(string $publicId, Request $request)
    {
        $publicId = trim($publicId);

        if ($publicId === '' || strlen($publicId) > 64) {
            return response()->json(['ok' => false, 'message' => 'invalid ticket id'], 422);
        }

        $ticket = Ticket::where('public_id', $publicId)
            ->where('created_by_user_id', auth()->id())
            ->first();

        if (!$ticket) {
            return response()->json(['ok' => false, 'message' => 'not found'], 404);
        }

        if ((string) ($ticket->status ?? '') === 'closed') {
            return response()->json(['ok' => false, 'message' => 'ticket closed'], 422);
        }

        $request->validate([
            'message' => ['required', 'string', 'min:2'],
        ]);

        $this->ticketService->addUserReply(
            $ticket,
            (int) auth()->id(),
            (string) $request->input('message')
        );

        return response()->json(['ok' => true]);
    }

    public function createSupport(Request $request)
    {
        $validated = $request->validate([
            'subject' => ['required', 'string', 'max:191'],
            'message' => ['required', 'string', 'min:10'],
            'support_reference' => ['nullable', 'string', 'regex:/^SEC-[A-Z0-9]{6}$/'],
            'source_context' => ['nullable', 'string', 'max:64'],
        ]);

        $supportReference = $validated['support_reference']
            ?? $request->query('support_reference');

        $sourceContext = $validated['source_context']
            ?? $request->query('source_context');

        $ticket = $this->ticketService->createSupportTicket(
            (int) auth()->id(),
            (string) $request->input('subject'),
            (string) $request->input('message'),
            $supportReference !== null ? (string) $supportReference : null,
            $sourceContext !== null ? (string) $sourceContext : null
        );

        return response()->json([
            'ok' => true,
            'public_id' => $ticket->public_id,
        ]);
    }

    public function createReport(User $user, Request $request)
    {
        if ($user->id === auth()->id()) {
            return response()->json(['ok' => false, 'message' => 'self report not allowed'], 422);
        }

        $request->validate([
            'message' => ['required', 'string', 'min:10'],
        ]);

        $ticket = $this->ticketService->createReportTicket(
            (int) auth()->id(),
            $user,
            (string) $request->input('message')
        );

        return response()->json([
            'ok' => true,
            'public_id' => $ticket->public_id,
        ]);
    }
}
