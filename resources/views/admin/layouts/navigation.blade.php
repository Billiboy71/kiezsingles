{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\layouts\navigation.blade.php
Purpose: Admin navigation bar (admin layout only; uses adminNavItems/adminTab + optional badges/header)
// Changed: 28-02-2026 14:49 (Europe/Berlin)
Version: 2.5
============================================================================ --}}

@php
    $adminTab = $adminTab ?? 'overview';

    // If not explicitly set by the caller, keep Debug tab visible (when present in adminNavItems).
    $adminShowDebugTab = $adminShowDebugTab ?? null;

    $adminNavItems = $adminNavItems ?? [];

    // determine current role and maintenance flag for SectionAccess filtering
    $currentRoleNormalized = auth()->check()
        ? mb_strtolower(trim((string) (auth()->user()->role ?? 'user')))
        : 'user';
    $maintenanceEnabledFlag = $maintenanceEnabledFlag ?? false;

    // Optional render variants:
    // - inline: for embedding (e.g. inside dashboard header). No <nav> wrapper by default.
    $adminNavInline = $adminNavInline ?? false;

    // In inline mode, default: hide profile link (because Breeze header already has Profile/Logout).
    $adminNavShowProfileLink = $adminNavShowProfileLink ?? (!$adminNavInline);

    // Optional: remove keys from nav (e.g. items rendered in top header).
    $adminNavExcludeKeys = $adminNavExcludeKeys ?? [];

    // IMPORTANT:
    // Badges (Wartung/Debug/Env) must be rendered in the top app header (Dashboard bar)
    // next to the profile dropdown. They are intentionally NOT rendered here anymore.
    $adminNavShowBadges = false;

    if ($adminShowDebugTab === null) {
        $adminShowDebugTab = false;
    }

    $adminNavItems = array_values(array_filter($adminNavItems, function ($item) use ($adminShowDebugTab, $adminNavExcludeKeys, $currentRoleNormalized, $maintenanceEnabledFlag) {
        $k = (string) ($item['key'] ?? '');
        $k = ($k === 'home') ? 'overview' : $k;

        if (!empty($adminNavExcludeKeys) && in_array($k, $adminNavExcludeKeys, true)) {
            return false;
        }

        if ($k === 'debug') {
            if (!(bool) $adminShowDebugTab) {
                return false;
            }
        }

        // enforce section access for the current role (fail-closed)
        if (class_exists(\App\Support\Admin\AdminSectionAccess::class)) {
            if (!\App\Support\Admin\AdminSectionAccess::canAccessSection($currentRoleNormalized, $k, $maintenanceEnabledFlag)) {
                return false;
            }
        } else {
            // fallback to superadmin only
            if ($currentRoleNormalized !== 'superadmin') {
                return false;
            }
        }

        return true;
    }));

    // Enforce canonical order: Übersicht, Wartung, Debug, Tickets, Moderation
    $orderMap = [
        'overview' => 10,
        'maintenance' => 20,
        'debug' => 30,
        'tickets' => 40,
        'moderation' => 50,
        'roles' => 60,
    ];

    usort($adminNavItems, function ($a, $b) use ($orderMap) {
        $ka = (string) ($a['key'] ?? '');
        $kb = (string) ($b['key'] ?? '');

        $ka = ($ka === 'home') ? 'overview' : $ka;
        $kb = ($kb === 'home') ? 'overview' : $kb;

        $oa = $orderMap[$ka] ?? 999;
        $ob = $orderMap[$kb] ?? 999;

        if ($oa === $ob) {
            return strcmp((string) $ka, (string) $kb);
        }

        return $oa <=> $ob;
    });
@endphp

@if($adminNavInline)

    <div class="flex items-center gap-2 flex-wrap justify-end" data-ks-admin-nav>
        <div class="flex gap-2 flex-wrap">
            @foreach($adminNavItems as $item)
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
                    class="inline-flex items-center px-4 py-2 border rounded-md font-semibold text-xs uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2
                        {{ $adminTab === $itemKey ? 'bg-gray-900 text-white border-gray-900' : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50' }}"
                >
                    {{ $itemLabel }}
                </a>
            @endforeach

            @hasSection('adminNavExtra')
                @yield('adminNavExtra')
            @endif
        </div>

        @if($adminNavShowProfileLink)
            <a
                href="{{ route('profile.edit') }}"
                class="inline-flex items-center px-4 py-2 bg-white border border-gray-300 rounded-md font-semibold text-xs text-gray-700 uppercase tracking-widest hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            >
                Zurück zum Profil
            </a>
        @endif
    </div>

    @hasSection('adminHeader')
        <div class="mt-3">
            @yield('adminHeader')
        </div>
    @endif

@else

    <nav class="bg-white border-b border-gray-200" data-ks-admin-nav>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
            <div class="flex items-center justify-between gap-4 flex-wrap">
                <div class="flex gap-2 flex-wrap">
                    @foreach($adminNavItems as $item)
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
                            class="inline-flex items-center px-4 py-2 border rounded-md font-semibold text-xs uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2
                                {{ $adminTab === $itemKey ? 'bg-gray-900 text-white border-gray-900' : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50' }}"
                        >
                            {{ $itemLabel }}
                        </a>
                    @endforeach

                    @hasSection('adminNavExtra')
                        @yield('adminNavExtra')
                    @endif
                </div>

                <div class="flex items-center gap-2 flex-wrap justify-end">
                    @if($adminNavShowProfileLink)
                        <a
                            href="{{ route('profile.edit') }}"
                            class="inline-flex items-center px-4 py-2 bg-white border border-gray-300 rounded-md font-semibold text-xs text-gray-700 uppercase tracking-widest hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                        >
                            Zurück zum Profil
                        </a>
                    @endif
                </div>
            </div>

            @hasSection('adminHeader')
                <div class="mt-3">
                    @yield('adminHeader')
                </div>
            @endif
        </div>
    </nav>

@endif
