<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Requests\Auth\LoginRequest.php
// Purpose: Login request validation (rate limited, no user enumeration)
// Changed: 02-03-2026 17:39 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Http\Requests\Auth;

use App\Models\SecurityDeviceBan;
use App\Models\SecurityIpBan;
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
            RateLimiter::hit($this->throttleKey(), (int) $settings->lockout_seconds);
            $this->writeAutoBansForFailedLogin($settings);

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

        if (!RateLimiter::tooManyAttempts($this->throttleKey(), $attemptLimit)) {
            return;
        }

        $seconds = RateLimiter::availableIn($this->throttleKey());

        /** @var SecurityEventLogger $logger */
        $logger = app(SecurityEventLogger::class);

        /** @var DeviceHashService $deviceHashService */
        $deviceHashService = app(DeviceHashService::class);

        $email = mb_strtolower(trim((string) $this->input('email', '')));

        $logger->log(
            type: 'login_lockout',
            ip: $this->ip(),
            email: $email !== '' ? $email : null,
            deviceHash: $deviceHashService->forRequest($this),
            meta: [
                'seconds' => $seconds,
                'attempt_limit' => $attemptLimit,
            ],
        );

        throw ValidationException::withMessages([
            'email' => trans('auth.throttle', [
                'seconds' => $seconds,
                'minutes' => ceil($seconds / 60),
            ]),
        ]);
    }

    /**
     * Get the rate limiting throttle key for the request.
     */
    public function throttleKey(): string
    {
        return Str::transliterate(
            Str::lower($this->string('email')).'|'.$this->ip()
        );
    }

    private function writeAutoBansForFailedLogin(object $settings): void
    {
        $logger = app(SecurityEventLogger::class);
        $deviceHashService = app(DeviceHashService::class);

        $ip = trim((string) ($this->ip() ?? ''));
        $deviceHash = $deviceHashService->forRequest($this);

        $this->writeIpAutoBan($settings, $ip, $deviceHash, $logger);
        $this->writeDeviceAutoBan($settings, $deviceHash, $ip, $logger);
    }

    private function writeIpAutoBan(
        object $settings,
        string $ip,
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
            deviceHash: $deviceHash,
            meta: [
                'threshold' => $threshold,
                'seconds' => $seconds,
                'fail_count' => $failCount,
                'path' => '/'.$this->path(),
            ],
        );
    }

    private function writeDeviceAutoBan(
        object $settings,
        ?string $deviceHash,
        string $ip,
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
            deviceHash: $deviceHash,
            meta: [
                'threshold' => $threshold,
                'seconds' => $seconds,
                'fail_count' => $failCount,
                'path' => '/'.$this->path(),
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
}
