/* ============================================================================
File: C:\laragon\www\kiezsingles\resources\js\admin-header.js
Purpose: Admin header runtime (badge polling + nav sanitizing)
Created: 23-02-2026 18:09 (Europe/Berlin)
Changed: 25-02-2026 14:25 (Europe/Berlin)
Version: 0.3
============================================================================ */

(function () {
    function qs(id) {
        return document.getElementById(id);
    }

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
        el.classList.toggle('hidden', !isVisible);
    }

    function setDebugBadgeActive(isActive) {
        const el = qs('ks_admin_badge_debug');
        if (!el) return;

        if (!isActive) {
            el.dataset.active = '0';
            el.classList.remove('bg-red-500');
            el.classList.add('bg-green-600');
            el.classList.add('hidden');
            return;
        }

        el.dataset.active = isActive ? '1' : '0';

        el.classList.remove('bg-red-500', 'bg-green-600');
        el.classList.add(isActive ? 'bg-red-500' : 'bg-green-600');

        el.classList.remove('hidden');
    }

    function setDebugButtonVisible(isVisible) {
        const links = document.querySelectorAll('[data-ks-admin-nav-key="debug"]');
        if (!links || links.length < 1) return;
        links.forEach((el) => {
            el.classList.toggle('hidden', !isVisible);
        });
    }

    function setBreakGlassBadgeVisible(isVisible) {
        const el = qs('ks_admin_badge_break_glass');
        if (!el) return;

        el.dataset.active = isVisible ? '1' : '0';
        el.classList.toggle('hidden', !isVisible);
    }

    function setEnvBadge(mode) {
        const el = qs('ks_admin_badge_env');
        if (!el) return;

        const m = (mode || '').toLowerCase();
        el.dataset.env = m;

        el.classList.remove('bg-violet-500', 'bg-sky-500', 'bg-slate-500');

        if (m === 'prod-sim') {
            el.textContent = 'PROD-SIM';
            el.classList.add('bg-violet-500');
            return;
        }

        if (m === 'local') {
            el.textContent = 'LOCAL';
            el.classList.add('bg-sky-500');
            return;
        }

        el.textContent = 'PROD';
        el.classList.add('bg-slate-500');
    }

    window.KSAdminUI = window.KSAdminUI || {};
    window.KSAdminUI.setStatus = function (status) {
        const s = Object.assign({}, status || {});
        if (!s || typeof s !== 'object') return;

        if (typeof s.maintenance === 'boolean') {
            setMaintenanceBadgeVisible(s.maintenance);
        }

        if (typeof s.debug === 'boolean') {
            setDebugButtonVisible(s.debug);
        }

        if (typeof s.debug_any === 'boolean') {
            setDebugBadgeActive(s.debug_any);
        } else if (typeof s.debug_enabled === 'boolean') {
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

    async function pollStatusOnce(statusUrl, state) {
        if (!statusUrl || state.inFlight) return null;
        state.inFlight = true;

        try {
            const res = await fetch(statusUrl, {
                method: 'GET',
                headers: { 'Accept': 'application/json' },
                cache: 'no-store',
                credentials: 'same-origin',
            });

            if (!res.ok) return null;

            const data = await res.json();
            window.KSAdminUI.setStatus(data);
            return data || null;
        } catch (e) {
            return null;
        } finally {
            state.inFlight = false;
        }
    }

    document.addEventListener('DOMContentLoaded', function () {
        const nav = qs('ks_admin_nav');
        if (!nav) return;

        sanitizeAdminNavLinks();

        const statusUrl = nav.dataset.ksAdminStatusUrl || '';
        const state = { inFlight: false };

        if (!statusUrl) return;

        // Expose an on-demand refresh hook (no polling).
        // Keep existing implementation if already provided elsewhere.
        if (!window.KSAdminUI.refreshStatusOnce || typeof window.KSAdminUI.refreshStatusOnce !== 'function') {
            window.KSAdminUI.refreshStatusOnce = function () {
                return pollStatusOnce(statusUrl, state);
            };
        }

        // Initial one-shot status fetch on page load.
        try { window.KSAdminUI.refreshStatusOnce(); } catch (e) {}
    });
})();