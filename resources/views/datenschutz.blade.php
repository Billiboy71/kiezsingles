{{-- ========================================================================= --}}
{{-- File: C:\laragon\www\kiezsingles\resources\views\datenschutz.blade.php     --}}
{{-- Changed: 08-02-2026 01:58                                                --}}
{{-- Purpose: Public legal page (Datenschutz) - placeholder, UI-stabil         --}}
{{-- ========================================================================= --}}

<x-guest-layout>
    <div class="max-w-2xl mx-auto">
        <h1 class="text-2xl font-semibold text-gray-900">Datenschutz</h1>

        <div class="mt-6 space-y-4 text-sm text-gray-700 leading-relaxed">
            <p>
                <strong>Platzhalter:</strong> Diese Datenschutzerklärung ist noch nicht final befüllt.
            </p>

            <p class="text-gray-600">
                Hinweis: Vor Veröffentlichung vollständig ergänzen (Verantwortliche Stelle, Zwecke,
                Rechtsgrundlagen, Speicherdauer, Betroffenenrechte, Cookies/Tracking, Drittanbieter,
                Hosting, Kontaktformular, Login/Registrierung, IP-Logging, etc.).
            </p>
        </div>

        <div class="mt-8 flex gap-4 text-sm">
            <a href="{{ route('home') }}" class="underline text-gray-700 hover:text-gray-900">
                Zur Startseite
            </a>
            <a href="{{ route('contact.create') }}" class="underline text-gray-700 hover:text-gray-900">
                Kontakt
            </a>
        </div>
    </div>
</x-guest-layout>
