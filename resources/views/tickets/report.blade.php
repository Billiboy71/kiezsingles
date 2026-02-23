{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\tickets\report.blade.php
Purpose: Frontend Report User form (auth only) – moved from routes/web/tickets_frontend.php inline HTML
Changed: 19-02-2026 18:45 (Europe/Berlin)
Version: 0.1
============================================================================ --}}

<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>User melden</title>
    <style>
        body { font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; padding:24px; max-width:720px; margin:0 auto; }
        .card { border:1px solid #e5e7eb; border-radius:12px; background:#fff; padding:16px; }
        .btn { padding:10px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; cursor:pointer; }
        .btn:hover { background:#f8fafc; }
        .input, textarea { width:100%; padding:10px; border-radius:10px; border:1px solid #cbd5e1; margin-bottom:12px; }
        .notice { padding:10px; background:#eef7ee; border:1px solid #b6e0b6; border-radius:10px; margin-bottom:12px; }
    </style>
</head>
<body>

<h1>User melden</h1>
<p>Gemeldeter User: #{{ (string) ($user->id ?? '') }}</p>

@if(!empty($sent))
    <div class="notice">Meldung wurde erstellt.</div>
@endif

<div class="card">
    <form method="POST" action="{{ url('/report/' . (string) ($user->public_id ?? '')) }}">
        @csrf
        <textarea class="input" name="message" placeholder="Beschreibe das Problem..." required maxlength="5000"></textarea>
        <button type="submit" class="btn">Melden</button>
    </form>
</div>

</body>
</html>
