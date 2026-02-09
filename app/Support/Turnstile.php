<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Support\Turnstile.php
// Changed: 08-02-2026 01:17
// Purpose: Cloudflare Turnstile verification (server-side) with optional debug logging
// ============================================================================

namespace App\Support;

use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;

class Turnstile
{
    public static function verify(?string $token): void
    {
        // Nur prüfen, wenn Captcha wirklich aktiv ist (enabled + flow)
        // Hinweis: im Controller steuerst du es ohnehin über $captchaActive,
        // aber das hier macht Turnstile robust, falls jemand es anderswo aufruft.
        if (!(bool) config('captcha.enabled')) {
            return;
        }

        // Debug (DB -> config fallback), erlaubte Envs: local + staging
        $debugEnabled = SystemSettingHelper::debugUiAllowed()
            && SystemSettingHelper::debugBool('turnstile', (bool) config('captcha.debug'));

        // Token fehlt
        if (!is_string($token) || trim($token) === '') {
            throw ValidationException::withMessages([
                'cf-turnstile-response' => 'Captcha fehlt.',
            ]);
        }

        $secret = (string) config('captcha.secret_key');

        // Hard-Fail bei fehlendem Secret (sonst debuggt man ewig)
        if ($secret === '') {
            if ($debugEnabled) {
                logger()->error('TURNSTILE MISCONFIG: secret_key missing', [
                    'config_key_used' => 'captcha.secret_key',
                    'request_host' => request()->getHost(),
                ]);
            }

            throw ValidationException::withMessages([
                'cf-turnstile-response' => 'Captcha ist falsch konfiguriert (Secret fehlt).',
            ]);
        }

        $resp = Http::asForm()
            ->timeout(8)
            ->post('https://challenges.cloudflare.com/turnstile/v0/siteverify', [
                'secret'   => $secret,
                'response' => $token,
                'remoteip' => request()->ip(),
            ]);

        $json = $resp->json();

        // Debug: Cloudflare Antwort loggen
        if ($debugEnabled) {
            logger()->warning('TURNSTILE SITEVERIFY', [
                'http_status' => $resp->status(),
                'success'     => $json['success'] ?? null,
                'error_codes' => $json['error-codes'] ?? null,
                'hostname'    => $json['hostname'] ?? null,
                'action'      => $json['action'] ?? null,
                'cdata'       => $json['cdata'] ?? null,
                'host'        => request()->getHost(),
                'token_len'   => strlen($token),
            ]);
        }

        if (!($json['success'] ?? false)) {
            $msg = 'Captcha-Überprüfung fehlgeschlagen.';

            // Optional: Error-Codes nur im Debugtext anhängen
            $codes = $json['error-codes'] ?? [];
            if ($debugEnabled && !empty($codes)) {
                $msg .= ' (' . implode(',', (array) $codes) . ')';
            }

            throw ValidationException::withMessages([
                'cf-turnstile-response' => $msg,
            ]);
        }
    }
}
