<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Providers\AppServiceProvider.php
// Purpose: App service provider (password defaults + user observer)
// Changed: 28-02-2026 14:12 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Providers;

use App\Models\User;
use App\Observers\UserObserver;
use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\Rules\Password;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Password::defaults(function () {
            $rule = Password::min(10)
                ->mixedCase()
                ->numbers()
                ->symbols();

            if (! app()->environment('testing')) {
                $rule->uncompromised();
            }

            return $rule;
        });

        User::observe(UserObserver::class);
    }
}