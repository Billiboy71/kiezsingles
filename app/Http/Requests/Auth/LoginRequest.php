<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Requests\Auth\LoginRequest.php
// Purpose: Login request validation (rate limited, no user enumeration)
// ============================================================================

namespace App\Http\Requests\Auth;

use App\Services\Security\DeviceHashService;
use App\Services\Security\SecurityEventLogger;
use App\Services\Security\SecuritySettingsService;
use Illuminate\Foundation\Http\FormRequest;
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
}
