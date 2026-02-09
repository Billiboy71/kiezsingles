<?php

return [

    'postcode' => [
        // Feld anzeigen / speichern
        'enabled' => env('FEATURE_POSTCODE_ENABLED', false),

        // Wenn enabled: Pflichtfeld oder optional
        'required' => env('FEATURE_POSTCODE_REQUIRED', false),
    ],

    'kiez_plausibility' => [
        // PLZ ↔ Kiez Warnung (kein Hard-Block)
        'enabled' => env('FEATURE_KIEZ_PLZ_PLAUSIBILITY_ENABLED', false),
    ],

];