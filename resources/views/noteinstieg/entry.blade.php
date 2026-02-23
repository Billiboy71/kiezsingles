{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\noteinstieg\entry.blade.php
Purpose: Noteinstieg Entry/Hub (Ebene 3) – links + optional countdown
Changed: 19-02-2026 00:29 (Europe/Berlin)
Version: 0.1
============================================================================ --}}

<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Noteinstieg</title>
</head>
<body style="font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; padding:24px; max-width:520px; margin:0 auto;">

    <h1 style="margin:0 0 8px 0;">Noteinstieg</h1>
    <p style="margin:0 0 10px 0; color:#444;">Einstiegsseite (nur mit gültigem Noteinstieg-Cookie).</p>

    @if(($via ?? 'totp') === 'totp')
        <div style="margin:0 0 16px 0; padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff;">
            <div style="font-weight:700; margin:0 0 4px 0;">Countdown</div>
            <div style="color:#111;">läuft ab in <span id="bg_countdown" style="font-weight:800;">--:--</span></div>
        </div>
    @endif

    <div style="display:flex; flex-direction:column; gap:10px;">
        <a id="bg_login" href="{{ url('/login') }}" style="display:block; text-align:center; padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; text-decoration:none; color:#111;">Login</a>
        <a id="bg_register" href="{{ url('/register') }}" style="display:block; text-align:center; padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; text-decoration:none; color:#111;">Registrieren</a>
        <a id="bg_maintenance" href="{{ url('/noteinstieg-wartung') }}" style="display:block; text-align:center; padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; text-decoration:none; color:#111;">Wartungsseite ansehen</a>
        <a id="bg_reopen" href="{{ url('/noteinstieg?next=/noteinstieg-einstieg') }}" style="display:block; text-align:center; padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; text-decoration:none; color:#111;">Noteinstieg erneut öffnen</a>
    </div>

    @if(($via ?? 'totp') === 'totp')
        <script>
            (() => {
                let remaining = {{ (int) ($remainingSeconds ?? 0) }};
                const el = document.getElementById("bg_countdown");
                const aLogin = document.getElementById("bg_login");
                const aRegister = document.getElementById("bg_register");
                const aReopen = document.getElementById("bg_reopen");

                const pad2 = (n) => String(n).padStart(2, "0");

                const render = () => {
                    if (!el) return;

                    const sec = Math.max(0, remaining);
                    const m = Math.floor(sec / 60);
                    const s = sec % 60;

                    el.textContent = pad2(m) + ":" + pad2(s);

                    if (sec <= 0) {
                        if (aLogin) aLogin.setAttribute("aria-disabled", "true");
                        if (aRegister) aRegister.setAttribute("aria-disabled", "true");
                        if (aReopen) aReopen.setAttribute("aria-disabled", "true");
                    }
                };

                render();

                const t = window.setInterval(() => {
                    remaining -= 1;
                    render();

                    if (remaining <= 0) {
                        window.clearInterval(t);
                    }
                }, 1000);
            })();
        </script>
    @endif

</body>
</html>
