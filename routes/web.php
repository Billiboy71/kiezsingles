<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\routes\web.php
// Purpose: Web routes (public + authenticated)
// Changed: 23-02-2026 15:50 (Europe/Berlin)
// Version: 2.0
// ============================================================================

require __DIR__ . '/auth.php';

// SYSTEM/INFRA: Debug + Noteinstieg + Wartungs-preview + maintenance-notify
// (NOT admin backend debug page at /admin/debug)
require __DIR__ . '/web/debug_system.php';

require __DIR__ . '/web/public.php';
require __DIR__ . '/web/authenticated.php';

// Admin-Bereich: require_once verhindert Doppel-Includes, falls irgendwo anders ebenfalls eingebunden.
require_once __DIR__ . '/web/admin.php';

// Ticket Frontend (minimal, for end-to-end testing)
require __DIR__ . '/web/tickets_frontend.php';