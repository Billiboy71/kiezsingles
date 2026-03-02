<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\vendor\pagination\tailwind.blade.php
// Purpose: Unified pagination view (max 10 page links, consistent ellipsis styling)
// Changed: 02-03-2026 01:09 (Europe/Berlin)
// Version: 0.1
// ============================================================================
?>

@if ($paginator->hasPages())
    @php
        $current = (int) $paginator->currentPage();
        $last = (int) $paginator->lastPage();
        $maxLinks = 10;

        $pages = [];

        if ($last <= $maxLinks) {
            $pages = range(1, $last);
        } else {
            $middleCount = $maxLinks - 2; // keep first + last
            $middleStart = max(2, $current - intdiv($middleCount, 2));
            $middleEnd = min($last - 1, $middleStart + $middleCount - 1);
            $middleStart = max(2, $middleEnd - $middleCount + 1);

            $pages[] = 1;
            foreach (range($middleStart, $middleEnd) as $p) {
                $pages[] = $p;
            }
            $pages[] = $last;
        }

        $pages = array_values(array_unique($pages));
    @endphp

    <nav role="navigation" aria-label="{{ __('Pagination Navigation') }}" class="flex items-center justify-between">
        <div class="flex flex-1 items-center justify-between sm:justify-end">
            <div>
                <span class="relative z-0 inline-flex flex-wrap items-center gap-1 rounded-md">
                    @if ($paginator->onFirstPage())
                        <span class="inline-flex items-center rounded-md border border-gray-300 px-3 py-2 text-sm leading-5 text-gray-400">
                            &lsaquo;
                        </span>
                    @else
                        <a href="{{ $paginator->previousPageUrl() }}" rel="prev" class="inline-flex items-center rounded-md border border-gray-300 px-3 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-50" aria-label="{{ __('pagination.previous') }}">
                            &lsaquo;
                        </a>
                    @endif

                    @php $prevRendered = null; @endphp
                    @foreach ($pages as $page)
                        @if($prevRendered !== null && $page > $prevRendered + 1)
                            <span class="inline-flex items-center rounded-md border border-gray-300 px-3 py-2 text-sm leading-5 text-gray-500">
                                ...
                            </span>
                        @endif

                        @if ($page == $paginator->currentPage())
                            <span aria-current="page" class="inline-flex items-center rounded-md border border-gray-900 bg-gray-900 px-3 py-2 text-sm leading-5 text-white">
                                {{ $page }}
                            </span>
                        @else
                            <a href="{{ $paginator->url($page) }}" class="inline-flex items-center rounded-md border border-gray-300 px-3 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-50" aria-label="{{ __('Go to page :page', ['page' => $page]) }}">
                                {{ $page }}
                            </a>
                        @endif

                        @php $prevRendered = $page; @endphp
                    @endforeach

                    @if ($paginator->hasMorePages())
                        <a href="{{ $paginator->nextPageUrl() }}" rel="next" class="inline-flex items-center rounded-md border border-gray-300 px-3 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-50" aria-label="{{ __('pagination.next') }}">
                            &rsaquo;
                        </a>
                    @else
                        <span class="inline-flex items-center rounded-md border border-gray-300 px-3 py-2 text-sm leading-5 text-gray-400">
                            &rsaquo;
                        </span>
                    @endif
                </span>
            </div>
        </div>
    </nav>
@endif
