{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\tickets\support.blade.php
Purpose: Frontend Support Ticket form (auth only) – moved from routes/web/tickets_frontend.php inline HTML
Changed: 07-03-2026 21:24 (Europe/Berlin)
Version: 0.8
============================================================================ --}}

<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Support</title>
    @vite(['resources/css/app.css'])
</head>
<body class="font-sans px-6 py-6 max-w-[720px] mx-auto">

<h1>Support</h1>

@php
    $formAction = (string) ($form_action ?? url('/support'));
    $prefillSupportReference = (string) old('support_reference', $prefill_support_reference ?? request()->query('support_reference', ''));
    $prefillSubject = (string) old('subject', request()->query('subject', ''));
    $prefillMessage = (string) old('message', request()->query('message', ''));
    $prefillSourceContext = (string) old('source_context', $prefill_source_context ?? request()->query('source_context', ''));
    $prefillSupportAccessToken = (string) old('support_access_token', $prefill_support_access_token ?? request()->query('support_access_token', ''));
    $prefillContactEmail = '';
    $oldContactEmail = mb_strtolower(trim((string) old('contact_email', '')));

    if ($oldContactEmail !== '' && filter_var($oldContactEmail, FILTER_VALIDATE_EMAIL) !== false) {
        $prefillContactEmail = $oldContactEmail;
    } elseif (isset($prefill_contact_email)) {
        $candidateContactEmail = mb_strtolower(trim((string) $prefill_contact_email));
        if ($candidateContactEmail !== '' && filter_var($candidateContactEmail, FILTER_VALIDATE_EMAIL) !== false) {
            $prefillContactEmail = $candidateContactEmail;
        }
    }

    $hasValidSupportReference = preg_match('/^SEC-[A-Z0-9]{6,8}$/', $prefillSupportReference) === 1;
    $isSecuritySupportFlow = $prefillSupportAccessToken !== '' && str_contains($formAction, '/support/security');

    if ($isSecuritySupportFlow) {
        $securityQuery = array_filter([
            'support_access_token' => $prefillSupportAccessToken !== '' ? $prefillSupportAccessToken : null,
            'support_reference' => $hasValidSupportReference ? $prefillSupportReference : null,
            'source_context' => $prefillSourceContext !== '' ? $prefillSourceContext : null,
        ], static fn ($value) => $value !== null && $value !== '');

        if (!empty($securityQuery)) {
            $separator = str_contains($formAction, '?') ? '&' : '?';
            $formAction .= $separator . http_build_query($securityQuery);
        }
    }
@endphp

@if(!empty($sent))
    <div class="p-2.5 bg-green-50 border border-green-200 rounded-xl mb-3">
        Support-Ticket wurde erstellt.
    </div>
@endif

<div class="border border-slate-200 rounded-xl bg-white p-4">
    <form method="POST" action="{{ $formAction }}">
        @csrf
        @if($hasValidSupportReference)
            <div class="mb-3 p-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm">
                Referenzcode: <strong>{{ $prefillSupportReference }}</strong>
            </div>
            <input type="hidden" name="support_reference" value="{{ $prefillSupportReference }}">
        @endif
        @if($isSecuritySupportFlow && $prefillContactEmail !== '')
            <div class="mb-3 p-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm">
                Wir melden uns an: <strong>{{ $prefillContactEmail }}</strong>
            </div>
            <input type="hidden" name="contact_email" value="{{ $prefillContactEmail }}">
        @endif
        @if($prefillSourceContext !== '')
            <input type="hidden" name="source_context" value="{{ $prefillSourceContext }}">
        @endif
        @if($prefillSupportAccessToken !== '')
            <input type="hidden" name="support_access_token" value="{{ $prefillSupportAccessToken }}">
        @endif
        <input
            type="text"
            name="subject"
            placeholder="Betreff"
            required
            maxlength="200"
            value="{{ $prefillSubject }}"
            class="w-full p-2.5 rounded-xl border border-slate-300 mb-3"
        >

        <textarea
            name="message"
            placeholder="Nachricht..."
            required
            maxlength="5000"
            class="w-full p-2.5 rounded-xl border border-slate-300 mb-3"
        >{{ $prefillMessage }}</textarea>

        <button
            type="submit"
            class="px-3.5 py-2.5 rounded-xl border border-slate-300 bg-white cursor-pointer"
        >
            Senden
        </button>
    </form>
</div>

</body>
</html>