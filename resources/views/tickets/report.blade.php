{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\tickets\report.blade.php
Purpose: Frontend Report User form (auth only) – moved from routes/web/tickets_frontend.php inline HTML
Changed: 23-02-2026 21:12 (Europe/Berlin)
Version: 0.2
============================================================================ --}}

<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>User melden</title>
    @vite('resources/css/app.css')
</head>
<body class="ks-fe-support-body">

<h1>User melden</h1>
<p>Gemeldeter User: #{{ (string) ($user->id ?? '') }}</p>

@if(!empty($sent))
    <div class="ks-fe-notice">Meldung wurde erstellt.</div>
@endif

<div class="ks-fe-card">
    <form method="POST" action="{{ url('/report/' . (string) ($user->public_id ?? '')) }}">
        @csrf
        <textarea class="ks-fe-input" name="message" placeholder="Beschreibe das Problem..." required maxlength="5000"></textarea>
        <button type="submit" class="ks-fe-btn">Melden</button>
    </form>
</div>

</body>
</html>