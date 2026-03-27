<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Providers\AppServiceProvider.php
// Purpose: App service provider (password defaults + user observer)
// Changed: 27-03-2026 00:25 (Europe/Berlin)
// Version: 0.7
// ============================================================================

namespace App\Providers;

use App\Models\User;
use App\Observers\UserObserver;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\View;
use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\Rules\Password;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

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

        View::composer('*', function ($view): void {
            $openIncidents = 0;
            $criticalIncidents = 0;
            $hasEventAlert = false;
            $hasCorrelationAlert = false;

            // =========================
            // INCIDENTS
            // =========================
            if (Schema::hasTable('security_incidents')) {
                $openIncidents = DB::table('security_incidents')
                    ->whereNull('action_status')
                    ->count();

                $criticalIncidents = DB::table('security_incidents')
                    ->whereNull('action_status')
                    ->where('event_count', '>=', 100)
                    ->count();
            }

            // =========================
            // EVENTS (FIX)
            // =========================
            if (Schema::hasTable('security_events')) {

                // Nur echte Security-Events zaehlen fuer Alerts.
                $hasEventAlert = DB::table('security_events')
                    ->where('created_at', '>=', now()->subHours(24))
                    ->whereIn('type', [
                        'login_failed',
                        'login_lockout',
                        'ip_blocked',
                        'device_blocked',
                        'identity_blocked',
                    ])
                    ->count() >= 5;

                // =========================
                // KORRELATIONEN
                // =========================
                $hasCorrelationAlert = DB::table('security_events')
                    ->select('device_hash')
                    ->whereNotNull('device_hash')
                    ->where('device_hash', '!=', '')
                    ->where('created_at', '>=', now()->subHours(24))
                    ->whereIn('type', [
                        'login_failed',
                        'login_lockout',
                    ])
                    ->groupBy('device_hash')
                    ->havingRaw('COUNT(*) >= 5 AND (COUNT(DISTINCT email) >= 2 OR COUNT(DISTINCT ip) >= 2)')
                    ->exists();
            }

            // =========================
            // FINAL FLAGS
            // =========================
            $hasIncidentAlert = $openIncidents > 0;
            $hasCriticalIncidentAlert = $criticalIncidents > 0;

            $hasEventAnalysisAlert = $hasEventAlert || $hasCorrelationAlert;

            $hasSecurityAlert = $hasIncidentAlert || $hasEventAnalysisAlert;

            // =========================
            // VIEW
            // =========================
            $view->with('hasIncidentAlert', $hasIncidentAlert);
            $view->with('hasCriticalIncidentAlert', $hasCriticalIncidentAlert);
            $view->with('hasEventAlert', $hasEventAlert);
            $view->with('hasCorrelationAlert', $hasCorrelationAlert);
            $view->with('hasEventAnalysisAlert', $hasEventAnalysisAlert);
            $view->with('hasSecurityAlert', $hasSecurityAlert);
            $view->with('hasCriticalSecurityAlert', $hasCriticalIncidentAlert || $hasEventAnalysisAlert);
        });
    }
}
