<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Requests\Auth\LoginRequest.php
// Purpose: Login request validation (rate limited, no user enumeration)
// Changed: 17-03-2026 12:26 (Europe/Berlin)
// Version: 1.2
// ============================================================================

namespace App\Http\Requests\Auth;

use App\Models\SecurityDeviceBan;
use App\Models\SecurityIpBan;
use App\Services\Security\SecurityAllowlistService;
use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use App\Services\Security\SecuritySettingsService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class LoginRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            // single login field: email OR username
            'email' => ['required', 'string', 'max:255'],
            'password' => ['required', 'string'],
        ];
    }

    /**
     * Attempt to authenticate the request's credentials.
     *
     * @throws \Illuminate\Validation\ValidationException
     */
    public function authenticate(): void
    {
        $this->ensureIsNotRateLimited();

        $login = (string) $this->input('email', '');
        $password = (string) $this->input('password', '');
        $remember = $this->boolean('remember');

        $authenticated = false;

        if (filter_var($login, FILTER_VALIDATE_EMAIL)) {
            $authenticated = Auth::attempt([
                'email' => $login,
                'password' => $password,
            ], $remember);
        } else {
            $authenticated = Auth::attempt([
                'username' => $login,
                'password' => $password,
            ], $remember);
        }

        if (! $authenticated) {
            $settings = app(SecuritySettingsService::class)->get();
            $deviceHash = app(DeviceHashService::class)->forRequest($this);
            $allowlistMatch = $this->resolveAllowlistMatch($deviceHash);

            if ($allowlistMatch === null) {
                RateLimiter::hit($this->throttleKey(), (int) $settings->lockout_seconds);
            } else {
                $this->logAllowlistMatch(
                    context: 'login_failed_throttle_bypass',
                    allowlistMatch: $allowlistMatch,
                    deviceHash: $deviceHash,
                );
            }

            $this->writeAutoBansForFailedLogin($settings, $deviceHash, $allowlistMatch);

            throw ValidationException::withMessages([
                'email' => trans('auth.failed'),
            ]);
        }

        RateLimiter::clear($this->throttleKey());
    }

    /**
     * Ensure the login request is not rate limited.
     *
     * @throws \Illuminate\Validation\ValidationException
     */
    public function ensureIsNotRateLimited(): void
    {
        $settings = app(SecuritySettingsService::class)->get();
        $attemptLimit = max(1, (int) $settings->login_attempt_limit);
        $allowlistMatch = $this->resolveAllowlistMatch();

        if ($allowlistMatch !== null) {
            return;
        }

        if (!RateLimiter::tooManyAttempts($this->throttleKey(), $attemptLimit)) {
            return;
        }

        $seconds = RateLimiter::availableIn($this->throttleKey());
        $displaySeconds = max(60, (int) (ceil(max(1, $seconds) / 60) * 60));

        /** @var SecurityEventLogger $logger */
        $logger = app(SecurityEventLogger::class);

        /** @var DeviceHashService $deviceHashService */
        $deviceHashService = app(DeviceHashService::class);

        $email = mb_strtolower(trim((string) $this->input('email', '')));
        $deviceHash = $deviceHashService->forRequest($this);
        $incidentKey = $this->buildSecurityIncidentKey(
            path: $this->path(),
            ip: $this->ip(),
            email: $email !== '' ? $email : null,
            deviceHash: $deviceHash,
        );

        $logger->log(
            type: 'login_lockout',
            ip: $this->ip(),
            email: $email !== '' ? $email : null,
            deviceHash: $deviceHash,
            meta: [
                'reason' => 'lockout',
                'incident_key' => $incidentKey,
                'seconds' => $seconds,
                'attempt_limit' => $attemptLimit,
            ],
        );

        $supportRef = $this->resolveLatestSecurityReference($incidentKey);

        $supportAccess = app(\App\Services\Security\SecuritySupportAccessTokenService::class)->issueForCase(
            caseKey: 'login_lockout:ip:'.trim((string) ($this->ip() ?? '')),
            securityEventType: 'login_lockout',
            sourceContext: 'security_login_block',
            contactEmail: $this->normalizedContactEmail((string) $this->input('email', '')),
            preferredSupportReference: $supportRef,
        );
        $supportAccessToken = (string) $supportAccess['plain_token'];

        $this->session()->flash('security_ban_support_ref', $supportRef);
        $this->session()->flash('security_ban_support_reference', $supportRef);
        $this->session()->flash('security_support_reference', $supportRef);
        $this->session()->flash('security_ban_support_access_token', $supportAccessToken);

        throw ValidationException::withMessages([
            'email' => [
                trans('auth.failed'),
                trans('auth.throttle', [
                    'seconds' => $displaySeconds,
                    'minutes' => ceil($displaySeconds / 60),
                ]),
            ],
        ]);
    }

    /**
     * Get the rate limiting throttle key for the request.
     */
    public function throttleKey(): string
    {
        $login = trim((string) $this->input('email', ''));
        $login = Str::lower($login);
        $login = Str::transliterate($login);

        $ip = (string) $this->ip();

        return $login.'|'.$ip;
    }

    /**
     * @param array{entry_id:int|null,type:string,value:string,autoban_only:bool,source:string}|null $allowlistMatch
     */
    private function writeAutoBansForFailedLogin(object $settings, ?string $deviceHash, ?array $allowlistMatch): void
    {
        $logger = app(SecurityEventLogger::class);

        $ip = trim((string) ($this->ip() ?? ''));
        $email = $this->normalizedContactEmail((string) $this->input('email', ''));

        if ($allowlistMatch !== null) {
            $this->logAllowlistMatch(
                context: 'login_failed_autoban_bypass',
                allowlistMatch: $allowlistMatch,
                deviceHash: $deviceHash,
            );

            return;
        }

        $this->writeIpAutoBan($settings, $ip, $email, $deviceHash, $logger);
        $this->writeDeviceAutoBan($settings, $deviceHash, $ip, $email, $logger);
    }

    private function writeIpAutoBan(
        object $settings,
        string $ip,
        ?string $email,
        ?string $deviceHash,
        SecurityEventLogger $logger,
    ): void {
        if (! (bool) ($settings->ip_autoban_enabled ?? false) || $ip === '') {
            return;
        }

        $threshold = max(1, (int) ($settings->ip_autoban_fail_threshold ?? 1));
        $seconds = (int) ($settings->ip_autoban_seconds ?? 0);
        $windowSeconds = max(60, (int) ($settings->lockout_seconds ?? 60));

        $counterKey = 'login-fail-autoban:ip:'.$ip;
        RateLimiter::hit($counterKey, $windowSeconds);
        $failCount = RateLimiter::attempts($counterKey);

        if ($failCount < $threshold) {
            return;
        }

        $newUntil = $seconds > 0 ? now()->addSeconds($seconds) : null;

        $existingActiveBan = SecurityIpBan::query()
            ->where('ip', $ip)
            ->where(function ($query): void {
                $query->whereNull('banned_until')
                    ->orWhere('banned_until', '>', now());
            })
            ->latest('id')
            ->first();

        if ($existingActiveBan !== null) {
            $existingActiveBan->fill([
                'reason' => 'autoban_login_fail',
                'banned_until' => $this->extendBanUntil($existingActiveBan->banned_until, $newUntil),
            ])->save();
        } else {
            SecurityIpBan::query()->create([
                'ip' => $ip,
                'reason' => 'autoban_login_fail',
                'banned_until' => $newUntil,
                'created_by' => null,
            ]);
        }

        RateLimiter::clear($counterKey);

        $logger->log(
            type: 'ip_autobanned',
            ip: $ip,
            email: $email,
            deviceHash: $deviceHash,
            meta: [
                'threshold' => $threshold,
                'seconds' => $seconds,
                'fail_count' => $failCount,
                'path' => $this->path(),
            ],
        );
    }

    private function writeDeviceAutoBan(
        object $settings,
        ?string $deviceHash,
        string $ip,
        ?string $email,
        SecurityEventLogger $logger,
    ): void {
        $deviceHash = $deviceHash !== null ? trim($deviceHash) : null;

        if (! (bool) ($settings->device_autoban_enabled ?? false) || $deviceHash === null || $deviceHash === '') {
            return;
        }

        $threshold = max(1, (int) ($settings->device_autoban_fail_threshold ?? 1));
        $seconds = (int) ($settings->device_autoban_seconds ?? 0);
        $windowSeconds = max(60, (int) ($settings->lockout_seconds ?? 60));

        $counterKey = 'login-fail-autoban:device:'.Str::lower($deviceHash);
        RateLimiter::hit($counterKey, $windowSeconds);
        $failCount = RateLimiter::attempts($counterKey);

        if ($failCount < $threshold) {
            return;
        }

        $newUntil = $seconds > 0 ? now()->addSeconds($seconds) : null;

        $existingActiveBan = SecurityDeviceBan::query()
            ->where('device_hash', $deviceHash)
            ->where('is_active', true)
            ->whereNull('revoked_at')
            ->where(function ($query): void {
                $query->whereNull('banned_until')
                    ->orWhere('banned_until', '>', now());
            })
            ->latest('id')
            ->first();

        if ($existingActiveBan !== null) {
            $existingActiveBan->fill([
                'reason' => 'autoban_login_fail',
                'is_active' => true,
                'revoked_at' => null,
                'banned_until' => $this->extendBanUntil($existingActiveBan->banned_until, $newUntil),
            ])->save();
        } else {
            SecurityDeviceBan::query()->create([
                'device_hash' => $deviceHash,
                'reason' => 'autoban_login_fail',
                'banned_until' => $newUntil,
                'revoked_at' => null,
                'is_active' => true,
                'created_by' => null,
            ]);
        }

        RateLimiter::clear($counterKey);

        $logger->log(
            type: 'device_autobanned',
            ip: $ip !== '' ? $ip : null,
            email: $email,
            deviceHash: $deviceHash,
            meta: [
                'threshold' => $threshold,
                'seconds' => $seconds,
                'fail_count' => $failCount,
                'path' => $this->path(),
            ],
        );
    }

    private function extendBanUntil(mixed $currentUntil, ?Carbon $newUntil): ?Carbon
    {
        if ($currentUntil === null || $newUntil === null) {
            return null;
        }

        $current = $currentUntil instanceof Carbon
            ? $currentUntil
            : Carbon::parse((string) $currentUntil);

        return $current->greaterThan($newUntil) ? $current : $newUntil;
    }

    private function normalizedContactEmail(string $email): ?string
    {
        $value = mb_strtolower(trim($email));

        if ($value === '') {
            return null;
        }

        return filter_var($value, FILTER_VALIDATE_EMAIL) !== false ? $value : null;
    }

    private function resolveLatestSecurityReference(string $incidentKey): string
    {
        $query = \App\Models\SecurityEvent::query()
            ->where('meta->incident_key', $incidentKey)
            ->latest('id');

        $event = $query->first(['reference']);

        if ($event === null || !is_string($event->reference) || trim($event->reference) === '') {
            throw ValidationException::withMessages([
                'email' => trans('auth.failed'),
            ]);
        }

        return trim($event->reference);
    }

    private function buildSecurityIncidentKey(
        string $path,
        ?string $ip,
        ?string $email,
        ?string $deviceHash,
    ): string {
        $normalizedPath = trim($path, '/');
        $normalizedPath = $normalizedPath !== '' ? $normalizedPath : '/';
        $normalizedIp = $ip !== null ? trim($ip) : '';
        $normalizedEmail = $email !== null ? trim($email) : '';
        $normalizedDeviceHash = $deviceHash !== null ? trim($deviceHash) : '';

        if ($normalizedDeviceHash !== '') {
            return 'security_login_block:path:'.$normalizedPath.':device:'.$normalizedDeviceHash;
        }

        if ($normalizedEmail !== '') {
            return 'security_login_block:path:'.$normalizedPath.':email:'.$normalizedEmail;
        }

        return 'security_login_block:path:'.$normalizedPath.':ip:'.$normalizedIp;
    }

    /**
     * @return array{entry_id:int|null,type:string,value:string,autoban_only:bool,source:string}|null
     */
    private function resolveAllowlistMatch(?string $deviceHash = null): ?array
    {
        $allowlistService = app(SecurityAllowlistService::class);

        return $allowlistService->matchForContext(
            ip: (string) ($this->ip() ?? ''),
            deviceHash: $deviceHash,
            identity: $this->normalizedContactEmail((string) $this->input('email', '')),
        );
    }

    /**
     * @param array{entry_id:int|null,type:string,value:string,autoban_only:bool,source:string} $allowlistMatch
     */
    private function logAllowlistMatch(string $context, array $allowlistMatch, ?string $deviceHash): void
    {
        $logger = app(SecurityEventLogger::class);

        $logger->log(
            type: 'security_allowlist_match',
            ip: $this->ip(),
            email: $this->normalizedContactEmail((string) $this->input('email', '')),
            deviceHash: $deviceHash,
            meta: array_merge([
                'context' => $context,
                'path' => $this->path(),
            ], $this->allowlistMeta($allowlistMatch)),
        );
    }

    /**
     * @param array{entry_id:int|null,type:string,value:string,autoban_only:bool,source:string} $allowlistMatch
     * @return array<string, mixed>
     */
    private function allowlistMeta(array $allowlistMatch): array
    {
        return [
            'allowlist_match' => true,
            'allowlist_type' => $allowlistMatch['type'],
            'allowlist_value' => $allowlistMatch['value'],
            'allowlist_entry_id' => $allowlistMatch['entry_id'],
            'allowlist_source' => $allowlistMatch['source'],
            'allowlist_autoban_only' => $allowlistMatch['autoban_only'],
        ];
    }
}
