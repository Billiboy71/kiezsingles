<x-guest-layout>
    <div class="mb-4 text-sm text-gray-600">
        {{ __('Thanks for signing up! Before getting started, could you verify your email address by clicking on the link we just emailed to you? If you didn\'t receive the email, we will gladly send you another.') }}
    </div>

    @if (session('status') === 'verification-link-sent')
        <div class="mb-4 font-medium text-sm text-green-600">
            {{ __('A new verification link has been sent to the email address you provided during registration.') }}
        </div>
    @endif

    <div class="mt-4 flex items-center justify-between">
        <form method="POST" action="{{ route('verification.send') }}">
            @csrf

            {{-- Captcha --}}
            @if (config('captcha.enabled') && config('captcha.on_verify'))
                <div class="mb-4">
                    <div
                        class="cf-turnstile"
                        data-sitekey="{{ config('captcha.site_key') }}"
                        data-callback="onTurnstileSuccess"
                        data-expired-callback="onTurnstileExpired"
                        data-error-callback="onTurnstileError"
                    ></div>

                    <x-input-error :messages="$errors->get('cf-turnstile-response')" class="mt-2" />
                </div>
            @endif

            <x-primary-button
                id="verifyResendBtn"
                @if (config('captcha.enabled') && config('captcha.on_verify'))
                    class="opacity-50 cursor-not-allowed"
                    disabled
                @endif
            >
                {{ __('Resend Verification Email') }}
            </x-primary-button>
        </form>

        <form method="POST" action="{{ route('logout') }}">
            @csrf
            <button
                type="submit"
                class="underline text-sm text-gray-600 hover:text-gray-900
                       rounded-md focus:outline-none focus:ring-2
                       focus:ring-offset-2 focus:ring-indigo-500"
            >
                {{ __('Log Out') }}
            </button>
        </form>
    </div>

    <script>
        (() => {
            const btn = document.getElementById('verifyResendBtn');
            if (!btn) return;

            const captchaEnabled = @json((bool) (config('captcha.enabled') && config('captcha.on_verify')));
            let captchaOk = captchaEnabled ? false : true;

            const update = () => {
                // Wenn Captcha aus → Button immer aktiv
                if (!captchaEnabled) {
                    btn.disabled = false;
                    btn.classList.remove('opacity-50', 'cursor-not-allowed');
                    return;
                }

                const disabled = !captchaOk;
                btn.disabled = disabled;
                btn.classList.toggle('opacity-50', disabled);
                btn.classList.toggle('cursor-not-allowed', disabled);
            };

            window.onTurnstileSuccess = function () { captchaOk = true;  update(); };
            window.onTurnstileExpired = function () { captchaOk = false; update(); };
            window.onTurnstileError   = function () { captchaOk = false; update(); };

            document.addEventListener('DOMContentLoaded', update);
        })();
    </script>
</x-guest-layout>
