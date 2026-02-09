{{-- ========================================================================= --}}
{{-- File: C:\laragon\www\kiezsingles\resources\views\nutzungsbedingungen.blade.php --}}
{{-- Changed: 08-02-2026 02:01                                                --}}
{{-- Purpose: Public legal page (Nutzungsbedingungen) - placeholder, UI-stabil --}}
{{-- ========================================================================= --}}

<x-guest-layout>
    <div class="max-w-2xl mx-auto">
        <h1 class="text-2xl font-semibold text-gray-900">Nutzungsbedingungen</h1>

        <div class="mt-6 space-y-4 text-sm text-gray-700 leading-relaxed">
            <p>
                <strong>Platzhalter:</strong> Diese Nutzungsbedingungen sind noch nicht final befüllt.
            </p>

            <p class="text-gray-600">
                Hinweis: Vor Veröffentlichung vollständig ergänzen (Geltungsbereich, Teilnahmevoraussetzungen,
                Pflichten der Nutzer, verbotene Inhalte, Sperrung von Accounts, Haftung,
                Änderungen der Bedingungen, anwendbares Recht, Gerichtsstand etc.).
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

