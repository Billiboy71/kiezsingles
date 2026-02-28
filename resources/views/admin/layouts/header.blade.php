{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\layouts\header.blade.php
Purpose: Admin header (top area: title/status/actions + admin navigation include)
Changed: 28-02-2026 13:03 (Europe/Berlin)
Version: 2.4
============================================================================ --}}

@php
    $backToAppUrl = $backToAppUrl ?? url('/');
    $maintenanceEnabledFlag = $maintenanceEnabledFlag ?? false;
    $debugActiveFlag = $debugActiveFlag ?? false;
    $breakGlassActiveFlag = $breakGlassActiveFlag ?? false;
    $productionSimulationFlag = $productionSimulationFlag ?? false;
    $isLocalEnv = $isLocalEnv ?? false;
    $showAdminOutlines = $showAdminOutlines ?? false;

    $adminDebugUrl = \Illuminate\Support\Facades\Route::has('admin.debug') ? route('admin.debug') : '';

    $adminStatusUrl = \Illuminate\Support\Facades\Route::has('admin.status') ? route('admin.status') : url('/admin/status');
    $breakGlassRouteEnabled = \Illuminate\Support\Facades\Route::has('noteinstieg.show');

    $adminTab = $adminTab ?? 'overview';
    $adminNavItems = $adminNavItems ?? [];
    $adminTopNavKeys = ['maintenance', 'develop', 'debug', 'moderation'];
    $adminNavItemsByKey = [];
    foreach ($adminNavItems as $item) {
        $key = (string) ($item['key'] ?? '');
        $key = ($key === 'home') ? 'overview' : $key;
        if ($key === '') {
            continue;
        }
        $adminNavItemsByKey[$key] = $item;
    }

    $currentRoleNormalized = auth()->check()
        ? mb_strtolower(trim((string) (auth()->user()->role ?? 'user')))
        : 'user';

    $adminTopNavFallback = [
        'maintenance' => ['label' => 'Wartung', 'route' => 'admin.maintenance', 'url' => url('/admin/maintenance')],
        'develop' => ['label' => 'Develop', 'route' => 'admin.develop', 'url' => url('/admin/develop')],
        'debug' => ['label' => 'Debug', 'route' => 'admin.debug', 'url' => url('/admin/debug')],
        'moderation' => ['label' => 'Moderation', 'route' => 'admin.moderation', 'url' => url('/admin/moderation')],
    ];

    $adminTopNavItems = [];
    foreach ($adminTopNavKeys as $key) {
        if (!$maintenanceEnabledFlag && $key === 'debug') {
            continue;
        }

        $allowed = false;
        if (class_exists(\App\Support\Admin\AdminSectionAccess::class)) {
            $allowed = \App\Support\Admin\AdminSectionAccess::canAccessSection(
                (string) $currentRoleNormalized,
                (string) $key,
                (bool) $maintenanceEnabledFlag
            );
        } else {
            $allowed = ($currentRoleNormalized === 'superadmin');
        }

        if (!$allowed) {
            continue;
        }

        $item = $adminNavItemsByKey[$key] ?? null;
        $fallback = $adminTopNavFallback[$key] ?? ['label' => ucfirst($key), 'route' => '', 'url' => '#'];

        $label = (string) ($item['label'] ?? $fallback['label']);
        $url = (string) ($item['url'] ?? '');
        if ($url === '') {
            $routeName = (string) ($fallback['route'] ?? '');
            if ($routeName !== '' && \Illuminate\Support\Facades\Route::has($routeName)) {
                $url = route($routeName);
            } else {
                $url = (string) ($fallback['url'] ?? '#');
            }
        }

        $adminTopNavItems[] = [
            'key' => $key,
            'label' => $label,
            'url' => $url,
        ];
    }
    $adminTopNavOrder = [
        'maintenance' => 10,
        'debug' => 20,
        'develop' => 30,
        'moderation' => 40,
    ];
    usort($adminTopNavItems, function ($a, $b) use ($adminTopNavOrder) {
        $ka = (string) ($a['key'] ?? '');
        $kb = (string) ($b['key'] ?? '');

        $ka = ($ka === 'home') ? 'overview' : $ka;
        $kb = ($kb === 'home') ? 'overview' : $kb;

        $oa = $adminTopNavOrder[$ka] ?? 999;
        $ob = $adminTopNavOrder[$kb] ?? 999;

        if ($oa === $ob) {
            return strcmp((string) $ka, (string) $kb);
        }

        return $oa <=> $ob;
    });

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
        $envBadgeClass = 'bg-violet-500';
    } elseif ($isLocalEnv) {
        $envMode = 'local';
        $envLabel = 'LOCAL';
        $envBadgeClass = 'bg-sky-500';
    } else {
        $envMode = 'prod';
        $envLabel = 'PROD';
        $envBadgeClass = 'bg-slate-500';
    }

    // NOTE:
    // Do not compute debug badge state via DB reads during render.
    // The client-side /admin/status endpoint updates the badge on page load.
    $debugBadgeActiveFlag = false;
@endphp

<header class="bg-white border-b border-gray-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
        <div class="{{ $showAdminOutlines ? 'relative border-2 border-dashed border-lime-400' : '' }}">
            @if($showAdminOutlines)
                <div class="absolute -top-3 left-2 bg-lime-500 text-white text-[10px] leading-none px-2 py-1 rounded">ADMIN-STATUSHEADER</div>
            @endif

            <div class="flex items-center justify-between gap-4 flex-wrap">
                <div class="min-w-0">
                    <div class="text-sm font-semibold text-gray-900">
                        {{ $ksRoleLabel }}
                    </div>
                </div>

                <div class="flex items-center justify-end gap-2 flex-wrap ml-auto">
                    @if($currentRoleNormalized === 'superadmin')
                        {{-- BREAK-GLASS --}}
                        <span
                            id="ks_admin_badge_break_glass"
                            class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white bg-amber-500 {{ ($breakGlassActiveFlag && $breakGlassRouteEnabled) ? '' : 'hidden' }}"
                            data-active="{{ ($breakGlassActiveFlag && $breakGlassRouteEnabled) ? '1' : '0' }}"
                        >
                            BREAK-GLASS
                        </span>

                        {{-- ENV (u.a. PROD-SIM) --}}
                        <span
                            id="ks_admin_badge_env"
                            class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white {{ $envBadgeClass }}"
                            data-env="{{ $envMode }}"
                        >
                            {{ $envLabel }}
                        </span>

                        {{-- DEBUG --}}
                        <span
                            id="ks_admin_badge_debug"
                            class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white bg-red-500 {{ ($debugBadgeActiveFlag && $maintenanceEnabledFlag) ? '' : 'hidden' }}"
                            data-active="{{ ($debugBadgeActiveFlag && $maintenanceEnabledFlag) ? '1' : '0' }}"
                        >
                            DEBUG
                        </span>
                    @endif

                    {{-- WARTUNG --}}
                    <span
                        id="ks_admin_badge_maintenance"
                        class="inline-flex items-center justify-center px-4 py-1 rounded-full text-xs font-extrabold text-white bg-red-500 {{ $maintenanceEnabledFlag ? '' : 'hidden' }}"
                    >
                        WARTUNG
                    </span>
                </div>
            </div>
        </div>

        <div class="mt-3 {{ $showAdminOutlines ? 'relative border-2 border-dashed border-cyan-400' : '' }}">
            @if($showAdminOutlines)
                <div class="absolute -top-3 left-2 bg-cyan-500 text-white text-[10px] leading-none px-2 py-1 rounded">ADMIN-TOPHEADER</div>
            @endif

            <div class="flex items-center justify-between gap-4 flex-wrap">
                <div class="min-w-0 flex items-center gap-3 flex-wrap">
                    @if(count($adminTopNavItems) > 0)
                        <div class="flex gap-2 flex-wrap">
                            @foreach($adminTopNavItems as $item)
                                @php
                                    $itemKey = (string) ($item['key'] ?? '');
                                    $itemKey = ($itemKey === 'home') ? 'overview' : $itemKey;

                                    $itemLabel = (string) ($item['label'] ?? '');
                                    $itemUrl = (string) ($item['url'] ?? '#');

                                    if ($itemKey === '' || $itemLabel === '') {
                                        continue;
                                    }
                                @endphp

                                <a
                                    href="{{ $itemUrl }}"
                                    data-ks-admin-nav-key="{{ $itemKey }}"
                                    class="inline-flex items-center px-4 py-2 border rounded-md font-semibold text-xs uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2
                                        {{ $adminTab === $itemKey ? 'bg-gray-900 text-white border-gray-900' : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50' }}
                                        {{ ($itemKey === 'debug' && !$debugActiveFlag) ? 'hidden' : '' }}"
                                >
                                    {{ $itemLabel }}
                                </a>
                            @endforeach
                        </div>
                    @endif
                </div>

                <div class="flex items-center gap-2 flex-wrap justify-end">
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
        </div>

        <div class="mt-3 {{ $showAdminOutlines ? 'relative border-2 border-dashed border-amber-400' : '' }}" id="ks_admin_nav" data-ks-admin-status-url="{{ $adminStatusUrl }}">
            @if($showAdminOutlines)
                <div class="absolute -top-3 left-2 bg-amber-500 text-white text-[10px] leading-none px-2 py-1 rounded">ADMIN-NAVHEADER</div>
            @endif

            @include('admin.layouts.navigation', [
                'adminNavInline' => false,
                'adminNavShowProfileLink' => false,
                'adminNavExcludeKeys' => $adminTopNavKeys,
            ])
        </div>
    </div>
</header>
