<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">

    <title>{{ config('app.name', 'Laravel') }}</title>

    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.bunny.net">
    <link href="https://fonts.bunny.net/css?family=figtree:400,500,600&display=swap" rel="stylesheet" />

    <!-- App -->
    @vite(['resources/css/app.css', 'resources/js/app.js'])

    {{-- Cloudflare Turnstile: global, auto-render --}}
    @if (config('captcha.enabled'))
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
    @endif
</head>

<body class="font-sans text-gray-900 antialiased">
    <div class="min-h-screen flex flex-col sm:justify-center items-center pt-6 sm:pt-0 bg-gray-100">
        <div>
            <a href="/">
                <x-application-logo class="w-20 h-20 fill-current text-gray-500" />
            </a>
        </div>

        <div class="w-full sm:max-w-md mt-6 px-6 py-4 bg-white shadow-md overflow-hidden sm:rounded-lg">
            {{ $slot }}
        </div>
    </div>

    {{-- optional: global password toggle --}}
    <script>
        function togglePassword(id, btn) {
            const input = document.getElementById(id);
            if (!input) return;

            const show = input.type === 'password';
            input.type = show ? 'text' : 'password';

            btn.textContent = show ? '🔓' : '🔒';
            btn.setAttribute('aria-label', show ? 'Passwort verbergen' : 'Passwort anzeigen');
        }
    </script>
</body>
</html>
