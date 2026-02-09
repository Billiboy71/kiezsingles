{{-- ========================================================================= --}}
{{-- File: C:\laragon\www\kiezsingles\resources\views\impressum.blade.php      --}}
{{-- Changed: 08-02-2026 01:57                                                --}}
{{-- Purpose: Public legal page (Impressum) - placeholder, UI-stabil           --}}
{{-- ========================================================================= --}}

<x-guest-layout>
    <div class="max-w-2xl mx-auto">
        <h1 class="text-2xl font-semibold text-gray-900">Impressum</h1>

        <div class="mt-6 space-y-4 text-sm text-gray-700 leading-relaxed">
            <p>
                <strong>Platzhalter:</strong> Diese Seite ist noch nicht final befüllt.
                (Hier später die gesetzlich erforderlichen Angaben eintragen.)
            </p>

            <p class="text-gray-600">
                Hinweis: Bis zur finalen Veröffentlichung bitte die Inhalte vollständig ergänzen
                (Anbieter, Kontakt, Vertretung, ggf. USt-ID, Verantwortliche/r i.S.d. § 18 MStV, etc.).
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
