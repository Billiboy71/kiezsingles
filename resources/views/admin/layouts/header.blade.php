{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\layouts\header.blade.php
Purpose: Admin header (top area: title/status/actions + admin navigation include)
Changed: 22-02-2026 23:38 (Europe/Berlin)
Version: 1.2
============================================================================ --}}

@php
    $backToAppUrl = $backToAppUrl ?? url('/');
    $maintenanceEnabledFlag = $maintenanceEnabledFlag ?? false;
    $debugActiveFlag = $debugActiveFlag ?? false;
    $breakGlassActiveFlag = $breakGlassActiveFlag ?? false;
    $productionSimulationFlag = $productionSimulationFlag ?? false;
    $isLocalEnv = $isLocalEnv ?? false;

    $adminDebugUrl = \Illuminate\Support\Facades\Route::has('admin.debug') ? route('admin.debug') : '';

    $adminStatusUrl = \Illuminate\Support\Facades\Route::has('admin.status') ? route('admin.status') : url('/admin/status');

    // ---- ROLE LABEL (server-side) ----
    $ksRoleLabel = 'Admin';
    if (auth()->check()) {
        $ksRole = mb_strtolower(trim((string) (auth()->user()->role ?? '')));
        if ($ksRole === 'superadmin') {
            $ksRoleLabel = 'Super-Admin';
        } elseif ($ksRole === 'moderator') {
            $ksRoleLabel = 'Moderator';
        } elseif ($ksRole === 'admin') {
            $ksRoleLabel = 'Admin';
        }
    }

    // ---- ENV MODE SAFELY PRECOMPUTED ----
    if ($productionSimulationFlag) {
        $envMode = 'prod-sim';
        $envLabel = 'PROD-SIM';
        $envColor = '#8b5cf6';
    } elseif ($isLocalEnv) {
        $envMode = 'local';
        $envLabel = 'LOCAL';
        $envColor = '#0ea5e9';
    } else {
        $envMode = 'prod';
        $envLabel = 'PROD';
        $envColor = '#64748b';
    }
@endphp

<header class="bg-white border-b border-gray-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
        <div class="flex items-center justify-between gap-4 flex-wrap">
            <div class="min-w-0">
                <div class="text-sm font-semibold text-gray-900">
                    {{ $ksRoleLabel }}
                </div>
            </div>

            <div class="flex items-center gap-2 flex-wrap justify-end">
                {{-- WARTUNG --}}
                <span
                    id="ks_admin_badge_maintenance"
                    class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white"
                    style="{{ $maintenanceEnabledFlag ? '' : 'display:none; ' }}background:#ef4444;"
                >
                    WARTUNG
                </span>

                {{-- DEBUG --}}
                <span
                    id="ks_admin_badge_debug"
                    class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white"
                    style="{{ $debugActiveFlag ? '' : 'display:none; ' }}background: {{ $debugActiveFlag ? '#ef4444' : '#16a34a' }};"
                    data-active="{{ $debugActiveFlag ? '1' : '0' }}"
                >
                    DEBUG
                </span>

                {{-- BREAK-GLASS --}}
                <span
                    id="ks_admin_badge_break_glass"
                    class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white"
                    style="{{ $breakGlassActiveFlag ? '' : 'display:none; ' }}background:#f59e0b;"
                    data-active="{{ $breakGlassActiveFlag ? '1' : '0' }}"
                >
                    BREAK-GLASS
                </span>

                {{-- ENV --}}
                <span
                    id="ks_admin_badge_env"
                    class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white"
                    style="background: {{ $envColor }};"
                    data-env="{{ $envMode }}"
                >
                    {{ $envLabel }}
                </span>

                <a
                    href="{{ $backToAppUrl }}"
                    class="inline-flex items-center px-4 py-2 bg-white border border-gray-300 rounded-md font-semibold text-xs text-gray-700 uppercase tracking-widest hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                >
                    Dashboard
                </a>

                @if(\Illuminate\Support\Facades\Route::has('logout'))
                    <form method="POST" action="{{ route('logout') }}">
                        @csrf
                        <button
                            type="submit"
                            class="inline-flex items-center px-4 py-2 bg-gray-900 border border-gray-900 rounded-md font-semibold text-xs text-white uppercase tracking-widest hover:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                        >
                            Abmelden
                        </button>
                    </form>
                @endif
            </div>
        </div>

        <div class="mt-3" id="ks_admin_nav">
            @include('admin.layouts.navigation', [
                'adminNavInline' => false,
                'adminNavShowProfileLink' => false,
            ])
        </div>
    </div>

    <script>
        (function () {
            const statusUrl = @json($adminStatusUrl);

            function qs(id) { return document.getElementById(id); }

            function sanitizeAdminNavLinks() {
                const nav = qs('ks_admin_nav');
                if (!nav) return;

                const links = nav.querySelectorAll('a');
                if (!links || links.length < 1) return;

                links.forEach((a) => {
                    try {
                        // Ensure admin navigation never opens a new tab/window.
                        if (a.hasAttribute('target')) {
                            a.removeAttribute('target');
                        }
                        // Defensive: remove rel that might be tied to target="_blank"
                        if (a.hasAttribute('rel')) {
                            const rel = (a.getAttribute('rel') || '').toLowerCase();
                            if (rel.includes('noopener') || rel.includes('noreferrer')) {
                                a.removeAttribute('rel');
                            }
                        }
                    } catch (e) {
                        // ignore
                    }
                });
            }

            function setMaintenanceBadgeVisible(isVisible) {
                const el = qs('ks_admin_badge_maintenance');
                if (!el) return;
                el.style.display = isVisible ? '' : 'none';
            }

            function setDebugBadgeActive(isActive) {
                const el = qs('ks_admin_badge_debug');
                if (!el) return;
                el.dataset.active = isActive ? '1' : '0';
                el.style.background = isActive ? '#ef4444' : '#16a34a';
                el.style.display = '';
            }

            function setBreakGlassBadgeVisible(isVisible) {
                const el = qs('ks_admin_badge_break_glass');
                if (!el) return;
                el.dataset.active = isVisible ? '1' : '0';
                el.style.display = isVisible ? '' : 'none';
            }

            function setEnvBadge(mode) {
                const el = qs('ks_admin_badge_env');
                if (!el) return;

                const m = (mode || '').toLowerCase();
                el.dataset.env = m;

                if (m === 'prod-sim') {
                    el.textContent = 'PROD-SIM';
                    el.style.background = '#8b5cf6';
                    return;
                }
                if (m === 'local') {
                    el.textContent = 'LOCAL';
                    el.style.background = '#0ea5e9';
                    return;
                }

                el.textContent = 'PROD';
                el.style.background = '#64748b';
            }

            window.KSAdminUI = window.KSAdminUI || {};
            window.KSAdminUI.setStatus = function (status) {
                const s = Object.assign({}, status || {});
                if (!s || typeof s !== 'object') return;

                if (typeof s.maintenance === 'boolean') {
                    setMaintenanceBadgeVisible(s.maintenance);
                }

                // Debug-Badge: bevorzugt "debug_enabled" (tatsächlicher Setting-Schalter),
                // fallback auf "debug" falls legacy.
                if (typeof s.debug_enabled === 'boolean') {
                    setDebugBadgeActive(s.debug_enabled);
                } else if (typeof s.debug === 'boolean') {
                    setDebugBadgeActive(s.debug);
                }

                if (typeof s.break_glass === 'boolean') {
                    setBreakGlassBadgeVisible(s.break_glass);
                }

                if (typeof s.env === 'string') {
                    setEnvBadge(s.env);
                }
            };

            let inFlight = false;

            async function pollStatusOnce() {
                if (!statusUrl || inFlight) return;
                inFlight = true;

                try {
                    const res = await fetch(statusUrl, {
                        method: 'GET',
                        headers: {
                            'Accept': 'application/json',
                        },
                        cache: 'no-store',
                        credentials: 'same-origin',
                    });

                    if (!res.ok) {
                        inFlight = false;
                        return;
                    }

                    const data = await res.json();
                    window.KSAdminUI.setStatus(data);
                } catch (e) {
                    // ignore
                } finally {
                    inFlight = false;
                }
            }

            // Ensure nav links are same-tab (fixes accidental target="_blank"/new-window behavior).
            sanitizeAdminNavLinks();

            // Polling: every 3s (badges only; navigation is server-rendered and not toggled client-side)
            pollStatusOnce();
            setInterval(pollStatusOnce, 3000);
        })();
    </script>
</header>