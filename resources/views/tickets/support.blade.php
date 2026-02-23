{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\tickets\support.blade.php
Purpose: Frontend Support Ticket form (auth only) – moved from routes/web/tickets_frontend.php inline HTML
Changed: 23-02-2026 23:34 (Europe/Berlin)
Version: 0.3
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

@if(!empty($sent))
    <div class="p-2.5 bg-green-50 border border-green-200 rounded-xl mb-3">
        Support-Ticket wurde erstellt.
    </div>
@endif

<div class="border border-slate-200 rounded-xl bg-white p-4">
    <form method="POST" action="{{ url('/support') }}">
        @csrf
        <input
            type="text"
            name="subject"
            placeholder="Betreff"
            required
            maxlength="200"
            class="w-full p-2.5 rounded-xl border border-slate-300 mb-3"
        >

        <textarea
            name="message"
            placeholder="Nachricht..."
            required
            maxlength="5000"
            class="w-full p-2.5 rounded-xl border border-slate-300 mb-3"
        ></textarea>

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