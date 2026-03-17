<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web\tickets_frontend.php
// Purpose: Minimal frontend routes for support + report tickets (dev-ready).
// Changed: 17-03-2026 11:36 (Europe/Berlin)
// Version: 0.9
// ============================================================================

use App\Events\TicketCreated;
use App\Models\Ticket;
use App\Models\TicketMessage;
use App\Models\User;
use App\Services\TicketService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;

$resolveSecuritySupportAccess = function (Request $request): ?object {
    $plainToken = trim((string) $request->input('support_access_token', ''));
    if ($plainToken === '') {
        $plainToken = trim((string) $request->query('support_access_token', ''));
    }

    if ($plainToken === '') {
        return null;
    }

    $tokenHash = hash('sha256', $plainToken);

    $row = DB::table('security_support_access_tokens')
        ->where('token_hash', $tokenHash)
        ->whereNull('consumed_at')
        ->where('expires_at', '>', Carbon::now())
        ->first();

    if ($row === null) {
        return null;
    }

    $supportReferenceInput = trim((string) $request->input('support_reference', ''));
    if ($supportReferenceInput === '') {
        $supportReferenceInput = trim((string) $request->query('support_reference', ''));
    }

    if ($supportReferenceInput !== '' && !hash_equals((string) $row->support_reference, $supportReferenceInput)) {
        return null;
    }

    return (object) [
        'row' => $row,
        'plain_token' => $plainToken,
        'token_hash' => $tokenHash,
    ];
};

Route::middleware('guest')->group(function () use ($resolveSecuritySupportAccess) {

    /*
    |--------------------------------------------------------------------------
    | Security Support (Guest via one-time short-lived server token)
    |--------------------------------------------------------------------------
    */

    Route::get('/support/security', function (Request $request) use ($resolveSecuritySupportAccess) {
        $access = $resolveSecuritySupportAccess($request);

        if ($access === null) {
            abort(403);
        }

        $sent = (string) $request->query('sent', '') === '1';

        $resolvedContactEmail = '';
        $tokenContactEmail = mb_strtolower(trim((string) ($access->row->contact_email ?? '')));
        if ($tokenContactEmail !== '' && filter_var($tokenContactEmail, FILTER_VALIDATE_EMAIL) !== false) {
            $resolvedContactEmail = $tokenContactEmail;
        }

        if ($resolvedContactEmail === '') {
            $requestContactEmail = mb_strtolower(trim((string) $request->query('contact_email', '')));
            if ($requestContactEmail !== '' && filter_var($requestContactEmail, FILTER_VALIDATE_EMAIL) !== false) {
                $resolvedContactEmail = $requestContactEmail;
            }
        }

        return view('tickets.support', [
            'sent' => $sent,
            'form_action' => url('/support/security'),
            'prefill_support_access_token' => (string) $access->plain_token,
            'prefill_support_reference' => (string) $access->row->support_reference,
            'prefill_source_context' => (string) ($access->row->source_context ?? 'security_login_block'),
            'prefill_contact_email' => $resolvedContactEmail !== '' ? $resolvedContactEmail : null,
        ]);
    });

    Route::post('/support/security', function (Request $request) use ($resolveSecuritySupportAccess) {
        $validated = $request->validate([
            'subject' => ['required', 'string', 'min:2', 'max:200'],
            'message' => ['required', 'string', 'min:2', 'max:5000'],
            'support_reference' => ['required', 'string', 'regex:/^SEC-[A-Z0-9]{6,8}$/'],
            'source_context' => ['nullable', 'string', 'max:64'],
            'support_access_token' => ['required', 'string', 'min:32', 'max:255'],
            'contact_email' => ['nullable', 'email:rfc,dns', 'max:255'],
        ]);

        $access = $resolveSecuritySupportAccess($request);

        if ($access === null) {
            abort(403);
        }

        $created = false;
        $ticketPublicId = '';
        $ticketSupportReference = '';
        $contactEmail = '';

        DB::transaction(function () use ($validated, $access, &$created, &$ticketPublicId, &$ticketSupportReference, &$contactEmail) {
            $now = Carbon::now();

            $tokenRow = DB::table('security_support_access_tokens')
                ->where('token_hash', (string) $access->token_hash)
                ->lockForUpdate()
                ->first();

            if ($tokenRow === null) {
                return;
            }

            if ($tokenRow->consumed_at !== null) {
                return;
            }

            if (Carbon::parse((string) $tokenRow->expires_at)->lessThanOrEqualTo($now)) {
                return;
            }

            if (!hash_equals((string) $tokenRow->support_reference, (string) $validated['support_reference'])) {
                return;
            }

            $sourceContext = isset($validated['source_context']) ? trim((string) $validated['source_context']) : '';

            if ($tokenRow->source_context !== null && $sourceContext !== '' && !hash_equals((string) $tokenRow->source_context, $sourceContext)) {
                return;
            }

            $resolvedContactEmail = '';
            $submittedContactEmail = isset($validated['contact_email'])
                ? mb_strtolower(trim((string) $validated['contact_email']))
                : '';

            if ($submittedContactEmail !== '' && filter_var($submittedContactEmail, FILTER_VALIDATE_EMAIL) !== false) {
                $resolvedContactEmail = $submittedContactEmail;
            }

            if ($resolvedContactEmail === '') {
                $tokenContactEmail = mb_strtolower(trim((string) ($tokenRow->contact_email ?? '')));
                if ($tokenContactEmail !== '' && filter_var($tokenContactEmail, FILTER_VALIDATE_EMAIL) !== false) {
                    $resolvedContactEmail = $tokenContactEmail;
                }
            }
            $ticketCaseKey = trim((string) ($tokenRow->case_key ?? ''));

            $ticket = Ticket::create([
                'public_id' => (string) Str::uuid(),
                'type' => 'support',
                'status' => 'open',
                'subject' => (string) $validated['subject'],
                'message' => (string) $validated['message'],
                'support_reference' => (string) $validated['support_reference'],
                'source_context' => $sourceContext !== '' ? $sourceContext : (string) ($tokenRow->source_context ?? 'security_login_block'),
                'case_key' => $ticketCaseKey !== '' ? $ticketCaseKey : null,
                'contact_email' => $resolvedContactEmail !== '' ? $resolvedContactEmail : null,
                'created_by_user_id' => 0,
                'reported_user_id' => null,
            ]);

            $firstMsg = TicketMessage::create([
                'ticket_id' => (int) $ticket->id,
                'actor_type' => 'user',
                'actor_user_id' => null,
                'message' => (string) $validated['message'],
                'is_internal' => false,
            ]);

            event(new TicketCreated($ticket, 'user', 0));

            Log::info('ticket.created', [
                'ticket_id' => (int) $ticket->id,
                'ticket_public_id' => (string) ($ticket->public_id ?? ''),
                'type' => (string) ($ticket->type ?? ''),
                'status' => (string) ($ticket->status ?? ''),
                'actor_type' => 'user',
                'actor_user_id' => 0,
                'message_id' => (int) $firstMsg->id,
                'security_special_access' => true,
                'security_event_type' => (string) ($tokenRow->security_event_type ?? ''),
                'case_key' => (string) ($tokenRow->case_key ?? ''),
                'contact_email' => $resolvedContactEmail !== '' ? $resolvedContactEmail : null,
            ]);

            DB::table('security_support_access_tokens')
                ->where('id', (int) $tokenRow->id)
                ->update([
                    'consumed_at' => $now,
                    'updated_at' => $now,
                    'contact_email' => $resolvedContactEmail !== '' ? $resolvedContactEmail : ($tokenRow->contact_email ?? null),
                ]);

            $created = true;
            $ticketPublicId = (string) ($ticket->public_id ?? '');
            $ticketSupportReference = (string) ($ticket->support_reference ?? '');
            $contactEmail = $resolvedContactEmail;
        });

        if (!$created) {
            abort(403);
        }

        if ((bool) env('SECURITY_SUPPORT_TICKET_CONFIRMATION_MAIL', false) && $contactEmail !== '') {
            try {
                $subject = 'Support-Anfrage eingegangen';
                $lines = [
                    'Ihre Support-Anfrage ist bei uns eingegangen.',
                ];

                if ($ticketSupportReference !== '') {
                    $lines[] = 'Referenz: '.$ticketSupportReference;
                } elseif ($ticketPublicId !== '') {
                    $lines[] = 'Ticket: '.$ticketPublicId;
                }

                $lines[] = 'Unser Support meldet sich bei Ihnen.';

                Mail::raw(implode("\n", $lines), function ($message) use ($contactEmail, $subject): void {
                    $message->to($contactEmail)->subject($subject);
                });
            } catch (\Throwable $e) {
                Log::warning('ticket.security_support_confirmation_mail_failed', [
                    'contact_email' => $contactEmail,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return redirect('/login')->with('status', 'Support-Anfrage wurde gesendet.');
    });
});

Route::middleware('auth')->group(function () {

    /*
    |--------------------------------------------------------------------------
    | Support Ticket (User)
    |--------------------------------------------------------------------------
    */

    Route::get('/support', function (Request $request) {
        $sent = (string) $request->query('sent', '') === '1';

        return view('tickets.support', [
            'sent' => $sent,
            'form_action' => url('/support'),
        ]);
    });

    Route::post('/support', function (Request $request, TicketService $ticketService) {

        $validated = $request->validate([
            'subject' => ['required', 'string', 'min:2', 'max:200'],
            'message' => ['required', 'string', 'min:2', 'max:5000'],
            'support_reference' => ['nullable', 'string', 'regex:/^SEC-[A-Z0-9]{6,8}$/'],
            'source_context' => ['nullable', 'string', 'max:64'],
        ]);

        $ticketService->createSupportTicket(
            (int) auth()->id(),
            (string) $validated['subject'],
            (string) $validated['message'],
            isset($validated['support_reference']) ? (string) $validated['support_reference'] : null,
            isset($validated['source_context']) ? (string) $validated['source_context'] : null
        );

        return redirect('/support?sent=1');
    });


    /*
    |--------------------------------------------------------------------------
    | Report User (User)
    |--------------------------------------------------------------------------
    */

    Route::get('/report/{user}', function (User $user, Request $request) {

        if ((int) $user->id === (int) auth()->id()) {
            abort(403);
        }

        $sent = (string) $request->query('sent', '') === '1';

        return view('tickets.report', [
            'user' => $user,
            'sent' => $sent,
        ]);
    });

    Route::post('/report/{user}', function (User $user, Request $request, TicketService $ticketService) {

        if ((int) $user->id === (int) auth()->id()) {
            abort(403);
        }

        $validated = $request->validate([
            'message' => ['required', 'string', 'min:2', 'max:5000'],
        ]);

        $ticketService->createReportTicket(
            (int) auth()->id(),
            $user,
            (string) $validated['message']
        );

        return redirect('/report/' . $user->public_id . '?sent=1');
    });

});
