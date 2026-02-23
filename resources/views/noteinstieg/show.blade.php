{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\noteinstieg\show.blade.php
Purpose: Noteinstieg (Ebene 3) – TOTP/Recovery input UI (public, maintenance-only)
Changed: 23-02-2026 23:43 (Europe/Berlin)
Version: 0.3
============================================================================ --}}

<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Noteinstieg</title>

    {{-- Frontend assets (no admin.css here) --}}
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="font-sans px-6 py-6 max-w-[520px] mx-auto">

    @php
        $nextValue = (string) ($next ?? '');
        $errorValue = !empty($error) ? (string) $error : '';
    @endphp

    <div id="ks_noteinstieg_show" data-ks-noteinstieg-show="1">
        <h1 class="m-0 mb-2">Noteinstieg</h1>
        <p class="m-0 mb-4 text-slate-700">Notfallzugang im Wartungsmodus (Ebene 3).</p>

        @if($errorValue !== '')
            <div class="p-3.5 rounded-xl border border-red-200 bg-red-50 mb-4">
                {{ $errorValue }}
            </div>
        @endif

        <form
            id="bg_form"
            method="POST"
            action="{{ url('/noteinstieg') }}"
            autocomplete="off"
            data-ks-noteinstieg-form="1"
        >
            @csrf

            <input type="hidden" name="next" value="{{ $nextValue }}">
            <input type="hidden" id="totp" name="totp" value="">

            <label class="block mb-1.5 font-bold">TOTP-Code</label>

            <div id="bg_otp" class="flex gap-2.5">
                @for($i = 0; $i < 6; $i++)
                    <input
                        type="text"
                        inputmode="numeric"
                        pattern="[0-9]*"
                        maxlength="1"
                        autocomplete="one-time-code"
                        aria-label="Ziffer {{ $i + 1 }}"
                        class="w-[54px] h-[54px] text-center text-[22px] border border-slate-300 rounded-xl"
                        data-idx="{{ $i }}"
                    >
                @endfor
            </div>

            <div class="mt-2.5 text-[13px] text-slate-700 leading-[1.35]">
                <div class="font-bold mb-1">Alternativ</div>
                <div>Du kannst auch einen Notfallcode verwenden (einmalig). Format: <code>XXXX-XXXX</code></div>

                <label class="block mt-2 mb-1.5 font-bold">Notfallcode</label>

                <input
                    type="text"
                    name="recovery_code"
                    inputmode="text"
                    autocomplete="off"
                    placeholder="ABCD-EFGH"
                    class="w-full px-3 py-3 rounded-xl border border-slate-300 text-[16px]"
                >

                <div class="mt-1.5 text-slate-500">Wenn Notfallcode ausgefüllt ist, wird TOTP ignoriert.</div>
            </div>

            <div class="mt-3">
                <button
                    type="submit"
                    id="bg_submit"
                    class="w-full px-3.5 py-3 rounded-xl border border-slate-300 bg-white cursor-pointer"
                >
                    Freischalten
                </button>
            </div>
        </form>
    </div>

</body>
</html>