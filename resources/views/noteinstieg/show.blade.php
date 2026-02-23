{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\noteinstieg\show.blade.php
Purpose: Noteinstieg (Ebene 3) – TOTP/Recovery input UI (public, maintenance-only)
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
    <p style="margin:0 0 16px 0; color:#444;">Notfallzugang im Wartungsmodus (Ebene 3).</p>

    @if(!empty($error))
        <div style="padding:12px 14px; border-radius:10px; border:1px solid #fecaca; background:#fff5f5; margin:0 0 16px 0;">
            {{ (string) $error }}
        </div>
    @endif

    <form id="bg_form" method="POST" action="{{ url('/noteinstieg') }}" autocomplete="off">
        @csrf

        <input type="hidden" name="next" value="{{ (string) ($next ?? '') }}">
        <input type="hidden" id="totp" name="totp" value="">

        <label style="display:block; margin:0 0 6px 0; font-weight:700;">TOTP-Code</label>

        <div id="bg_otp" style="display:flex; gap:10px;">
            @for($i = 0; $i < 6; $i++)
                <input
                    type="text"
                    inputmode="numeric"
                    pattern="[0-9]*"
                    maxlength="1"
                    autocomplete="one-time-code"
                    aria-label="Ziffer {{ $i + 1 }}"
                    style="width:54px; height:54px; text-align:center; font-size:22px; border:1px solid #ccc; border-radius:10px;"
                    data-idx="{{ $i }}"
                >
            @endfor
        </div>

        <div style="margin-top:10px; font-size:13px; color:#444; line-height:1.35;">
            <div style="font-weight:700; margin:0 0 4px 0;">Alternativ</div>
            <div>Du kannst auch einen Notfallcode verwenden (einmalig). Format: <code>XXXX-XXXX</code></div>

            <label style="display:block; margin:8px 0 6px 0; font-weight:700;">Notfallcode</label>

            <input
                type="text"
                name="recovery_code"
                inputmode="text"
                autocomplete="off"
                placeholder="ABCD-EFGH"
                style="width:100%; padding:12px 12px; border-radius:10px; border:1px solid #ccc; font-size:16px;"
            >

            <div style="margin-top:6px; color:#666;">Wenn Notfallcode ausgefüllt ist, wird TOTP ignoriert.</div>
        </div>

        <div style="margin-top:12px;">
            <button type="submit" id="bg_submit" style="padding:12px 14px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; cursor:pointer; width:100%;">
                Freischalten
            </button>
        </div>
    </form>

    <script>
        (() => {
            const form = document.getElementById("bg_form");
            const wrap = document.getElementById("bg_otp");
            const hidden = document.getElementById("totp");
            const btn = document.getElementById("bg_submit");
            if (!form || !wrap || !hidden || !btn) return;

            const inputs = Array.from(wrap.querySelectorAll("input[data-idx]"));
            if (inputs.length !== 6) return;

            const onlyDigit = (v) => (v || "").toString().replace(/\D+/g, "");

            const setFromString = (s) => {
                const digits = onlyDigit(s).slice(0, 6).split("");
                for (let i = 0; i < 6; i++) {
                    inputs[i].value = digits[i] || "";
                }
                updateHiddenAndMaybeSubmit();
            };

            const updateHiddenAndMaybeSubmit = () => {
                const code = inputs.map(i => onlyDigit(i.value).slice(0,1)).join("");
                hidden.value = code;

                if (code.length === 6) {
                    // Auto-Submit sobald vollständig
                    form.requestSubmit();
                }
            };

            inputs.forEach((inp, idx) => {
                inp.addEventListener("input", () => {
                    const d = onlyDigit(inp.value);
                    if (d.length > 1) {
                        // z.B. Paste in ein Feld
                        setFromString(d);
                        return;
                    }

                    inp.value = d.slice(0, 1);

                    if (inp.value !== "" && idx < 5) {
                        inputs[idx + 1].focus();
                        inputs[idx + 1].select();
                    }

                    updateHiddenAndMaybeSubmit();
                });

                inp.addEventListener("keydown", (e) => {
                    if (e.key === "Backspace") {
                        if (inp.value === "" && idx > 0) {
                            inputs[idx - 1].focus();
                            inputs[idx - 1].select();
                        }
                        return;
                    }

                    if (e.key === "ArrowLeft" && idx > 0) {
                        e.preventDefault();
                        inputs[idx - 1].focus();
                        inputs[idx - 1].select();
                        return;
                    }

                    if (e.key === "ArrowRight" && idx < 5) {
                        e.preventDefault();
                        inputs[idx + 1].focus();
                        inputs[idx + 1].select();
                        return;
                    }
                });

                inp.addEventListener("paste", (e) => {
                    e.preventDefault();
                    const t = (e.clipboardData || window.clipboardData).getData("text");
                    setFromString(t);
                });

                inp.addEventListener("focus", () => {
                    inp.select();
                });
            });

            // Initial focus
            inputs[0].focus();
        })();
    </script>

</body>
</html>
