<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\layouts\public.blade.php
// Purpose: Unified public layout (single frame) with growing copyright year
// ============================================================================
?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? 'KiezSingles' }}</title>
</head>
<body style="font-family: system-ui; margin: 0; background: #f5f5f5;">

    <!-- FIXED PUBLIC FRAME -->
    <div style="max-width: 900px; margin: 0 auto; padding: 40px; background: #ffffff; min-height: 100vh;">

        <!-- HEADER / BRAND -->
        <header style="margin-bottom: 30px;">
            <div style="display: flex; align-items: center; gap: 14px;">
                <img
                    src="/images/logo.png"
                    alt="KiezSingles Logo"
                    style="width: 44px; height: 44px; object-fit: contain; display: block;"
                >
                <div>
                    <h1 style="margin: 0;">KiezSingles</h1>
                    <p style="margin: 4px 0 0 0; color: #666;">Deine lokale Plattform (Beta)</p>
                </div>
            </div>
        </header>

        <!-- PUBLIC NAV -->
        <nav style="margin-bottom: 30px; font-size: 0.95em;">
            <a href="/">Home</a> |
            <a href="/contact">Kontakt</a> |
            <a href="/impressum">Impressum</a> |
            <a href="/datenschutz">Datenschutz</a> |
            <a href="/nutzungsbedingungen">Nutzungsbedingungen</a>
        </nav>

        <!-- CONTENT FRAME -->
        <main>
            {{ $slot }}
        </main>

        <!-- FOOTER -->
        <footer style="margin-top: 40px; font-size: 0.85em; color: #888;">
            © 2026–{{ date('Y') }} KiezSingles
        </footer>

    </div>

</body>
</html>
