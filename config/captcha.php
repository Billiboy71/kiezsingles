<?php
// ============================================================================
// File: config/captcha.php
// Purpose: Zentrale Konfiguration für Cloudflare Turnstile
// ============================================================================

return [
    'enabled'     => (bool) env('CAPTCHA_ENABLED', false),
    'on_login'    => (bool) env('CAPTCHA_ON_LOGIN', false),
    'on_reset'    => (bool) env('CAPTCHA_ON_RESET', false),
    'on_register' => (bool) env('CAPTCHA_ON_REGISTER', false),
    'on_verify'   => (bool) env('CAPTCHA_ON_VERIFY', false),
    'on_contact'  => (bool) env('CAPTCHA_ON_CONTACT', false),

    // EIN Debug-Schalter
    'debug' => (bool) (env('CAPTCHA_DEBUG', false) || env('DEBUG_TURNSTILE', false)),

    'site_key'   => env('TURNSTILE_SITE_KEY'),
    'secret_key' => env('TURNSTILE_SECRET_KEY'),
];
