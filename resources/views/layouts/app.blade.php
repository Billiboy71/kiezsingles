{{-- ============================================================================
File: C:\laragon\www\kiezsingles\resources\views\layouts\app.blade.php
Purpose: Base application layout (navigation + optional leader/header/footer + slot)
Changed: 28-02-2026 01:31 (Europe/Berlin)
Version: 1.0
============================================================================ --}}

@php
    $layoutOutlinesIsSuperadmin = auth()->check() && ((string) (auth()->user()->role ?? 'user') === 'superadmin');

    $simulateProd = false;
    $layoutOutlinesAllowProduction = false;
    $layoutOutlinesFrontendEnabled = false;

    if ($layoutOutlinesIsSuperadmin) {
        try {
            if (\Illuminate\Support\Facades\Schema::hasTable('debug_settings')) {
                $rows = \Illuminate\Support\Facades\DB::table('debug_settings')
                    ->select(['key', 'value'])
                    ->whereIn('key', [
                        'debug.simulate_production',
                        'debug.layout_outlines_allow_production',
                        'debug.layout_outlines_frontend_enabled',
                    ])
                    ->get()
                    ->keyBy('key');

                $simulateProd = ((string) ($rows['debug.simulate_production']->value ?? '0') === '1');
                $layoutOutlinesAllowProduction = ((string) ($rows['debug.layout_outlines_allow_production']->value ?? '0') === '1');
                $layoutOutlinesFrontendEnabled = ((string) ($rows['debug.layout_outlines_frontend_enabled']->value ?? '0') === '1');
            }
        } catch (\Throwable $e) {
            $simulateProd = false;
            $layoutOutlinesAllowProduction = false;
            $layoutOutlinesFrontendEnabled = false;
        }
    }

    // Effective "production" for gating:
    // - real production OR local simulation flag
    $layoutOutlinesEffectiveIsProd = app()->environment('production') || $simulateProd;

    // In production (real or simulated), outlines require explicit allow_production.
    $layoutOutlinesEnvOk = (!$layoutOutlinesEffectiveIsProd) || $layoutOutlinesAllowProduction;

    $showFrontendOutlines = $layoutOutlinesIsSuperadmin && $layoutOutlinesEnvOk && $layoutOutlinesFrontendEnabled;
@endphp

<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="csrf-token" content="{{ csrf_token() }}">

       
        <title>{{ request()->getHost() }}</title>

        <!-- Fonts -->
        <link rel="preconnect" href="https://fonts.bunny.net">
        <link href="https://fonts.bunny.net/css?family=figtree:400,500,600&display=swap" rel="stylesheet" />

        <!-- Scripts -->
        @vite(['resources/css/app.css', 'resources/js/app.js'])
    </head>
    <body class="font-sans antialiased">
        <div class="min-h-screen flex flex-col bg-gray-100 {{ $showFrontendOutlines ? 'relative border-2 border-dashed border-indigo-400' : '' }}">
            @if($showFrontendOutlines)
                <div class="absolute -top-3 left-2 bg-indigo-500 text-white text-[10px] leading-none px-2 py-1 rounded">APP</div>
            @endif

            <div class="{{ $showFrontendOutlines ? 'relative border-2 border-dashed border-sky-400 m-2 mt-4' : '' }}">
                @if($showFrontendOutlines)
                    <div class="absolute -top-3 left-2 bg-sky-500 text-white text-[10px] leading-none px-2 py-1 rounded">HEADER</div>
                @endif

                @include('layouts.header', [
                    'leader' => $leader ?? null,
                    'header' => $header ?? null,
                ])
            </div>

            <!-- Page Content -->
            <main class="flex-1 {{ $showFrontendOutlines ? 'relative border-2 border-dashed border-emerald-400 m-2' : '' }}">
                @if($showFrontendOutlines)
                    <div class="absolute -top-3 left-2 bg-emerald-500 text-white text-[10px] leading-none px-2 py-1 rounded">MAIN</div>
                @endif

                <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                    <div class="bg-white rounded-xl shadow-sm p-6">
                        {{ $slot }}
                    </div>
                </div>
            </main>

            <div class="{{ $showFrontendOutlines ? 'relative border-2 border-dashed border-rose-400 m-2 mb-4' : '' }}">
                @if($showFrontendOutlines)
                    <div class="absolute -top-3 left-2 bg-rose-500 text-white text-[10px] leading-none px-2 py-1 rounded">FOOTER</div>
                @endif

                @include('layouts.footer', [
                    'footer' => $footer ?? null,
                ])
            </div>
        </div>
    </body>
</html>