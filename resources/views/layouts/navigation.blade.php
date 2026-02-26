{{-- ==========================================================================
File: C:\laragon\www\kiezsingles\resources\views\layouts\navigation.blade.php
Purpose: Navigation layout (guest-safe; no Auth::user() when not logged in)
Changed: 25-02-2026 21:20 (Europe/Berlin)
Version: 1.2
========================================================================== --}}

@php
    $profileUrl = \Illuminate\Support\Facades\Route::has('profile.edit')
        ? route('profile.edit')
        : (\Illuminate\Support\Facades\Route::has('profile')
            ? route('profile')
            : (\Illuminate\Support\Facades\Route::has('dashboard') ? route('dashboard') : '#'));

    $backendUrl = \Illuminate\Support\Facades\Route::has('admin.home')
        ? route('admin.home')
        : url('/admin');

    $showBackendLink = false;

    if (isset($showBackendButton)) {
        $showBackendLink = (bool) $showBackendButton;
    } else {
        if (auth()->check()) {
            $role = (string) (auth()->user()->role ?? 'user');
            $showBackendLink = in_array($role, ['admin', 'superadmin'], true);
        }
    }

    $showFrontendOutlines = $showFrontendOutlines ?? false;
    $isAdminHeaderContext = request()->is('admin*');
    $topHeaderDebugLabel = $isAdminHeaderContext ? 'ADMIN-TOPHEADER' : 'FRONTEND-HEADER';
@endphp

<div class="{{ $showFrontendOutlines ? 'relative border-2 border-dashed border-amber-400' : '' }}">
    @if($showFrontendOutlines)
        <div class="absolute -top-3 left-2 bg-amber-500 text-white text-[10px] leading-none px-2 py-1 rounded">{{ $topHeaderDebugLabel }}</div>
    @endif

<nav x-data="{ open: false }" class="bg-white border-b border-gray-100">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
            <div class="flex">
                <div class="shrink-0 flex items-center">
                    <a href="{{ route('dashboard') }}">
                        <x-application-logo class="block h-9 w-auto fill-current text-gray-800" />
                    </a>
                </div>

                <div class="hidden space-x-8 sm:-my-px sm:ms-10 sm:flex">
                    <x-nav-link :href="route('dashboard')" :active="request()->routeIs('dashboard')">
                        {{ __('Dashboard') }}
                    </x-nav-link>

                    @if($showBackendLink)
                        <x-nav-link :href="$backendUrl" :active="request()->is('admin*')">
                            {{ __('Backend') }}
                        </x-nav-link>
                    @endif
                </div>
            </div>

            @auth
                <div class="hidden sm:flex sm:items-center sm:ms-6">
                    <x-dropdown align="right" width="48">
                        <x-slot name="trigger">
                            <button class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-gray-500 bg-white hover:text-gray-700 focus:outline-none transition ease-in-out duration-150">
                                <div>{{ Auth::user()->name }}</div>

                                <div class="ms-1">
                                    <svg class="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                                        <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                                    </svg>
                                </div>
                            </button>
                        </x-slot>

                        <x-slot name="content">
                            @if($profileUrl !== '#')
                                <x-dropdown-link :href="$profileUrl">
                                    {{ __('Profile') }}
                                </x-dropdown-link>
                            @endif

                            <form method="POST" action="{{ route('logout') }}">
                                @csrf
                                <x-dropdown-link
                                    :href="route('logout')"
                                    data-ks-logout-link="1"
                                >
                                    {{ __('Log Out') }}
                                </x-dropdown-link>
                            </form>
                        </x-slot>
                    </x-dropdown>
                </div>
            @else
                <div class="hidden sm:flex sm:items-center sm:ms-6 space-x-4">
                    <a href="{{ route('login') }}" class="text-sm text-gray-600 hover:text-gray-900">
                        {{ __('Log in') }}
                    </a>

                    <a href="{{ route('register') }}" class="text-sm text-gray-600 hover:text-gray-900">
                        {{ __('Register') }}
                    </a>
                </div>
            @endauth

            <div class="-me-2 flex items-center sm:hidden">
                <button @click="open = ! open"
                        class="inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:bg-gray-100 focus:text-gray-500 transition duration-150 ease-in-out">
                    <svg class="h-6 w-6" stroke="currentColor" fill="none" viewBox="0 0 24 24">
                        <path :class="{'hidden': open, 'inline-flex': ! open }"
                              class="inline-flex"
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M4 6h16M4 12h16M4 18h16" />
                        <path :class="{'hidden': ! open, 'inline-flex': open }"
                              class="hidden"
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M6 18L18 6M6 6l12 12" />
                    </svg>
                </button>
            </div>
        </div>
    </div>

    <div :class="{'block': open, 'hidden': ! open}" class="hidden sm:hidden">
        <div class="pt-2 pb-3 space-y-1">
            <x-responsive-nav-link :href="route('dashboard')" :active="request()->routeIs('dashboard')">
                {{ __('Dashboard') }}
            </x-responsive-nav-link>

            @if($showBackendLink)
                <x-responsive-nav-link :href="$backendUrl" :active="request()->is('admin*')">
                    {{ __('Backend') }}
                </x-responsive-nav-link>
            @endif
        </div>

        @auth
            <div class="pt-4 pb-1 border-t border-gray-200">
                <div class="px-4">
                    <div class="font-medium text-base text-gray-800">{{ Auth::user()->name }}</div>
                    <div class="font-medium text-sm text-gray-500">{{ Auth::user()->email }}</div>
                </div>

                <div class="mt-3 space-y-1">
                    @if($profileUrl !== '#')
                        <x-responsive-nav-link :href="$profileUrl">
                            {{ __('Profile') }}
                        </x-responsive-nav-link>
                    @endif

                    <form method="POST" action="{{ route('logout') }}">
                        @csrf
                        <x-responsive-nav-link
                            :href="route('logout')"
                            data-ks-logout-link="1"
                        >
                            {{ __('Log Out') }}
                        </x-responsive-nav-link>
                    </form>
                </div>
            </div>
        @endauth
    </div>
</nav>
</div>
