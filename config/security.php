<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\config\security.php
// Purpose: Security module config (incident action integration)
// Created: 23-03-2026 21:46 (Europe/Berlin)
// Changed: 23-03-2026 21:46 (Europe/Berlin)
// Version: 1.0
// ============================================================================

return [

    'incident_actions' => [

        'auto_update_incident_status' => true,

        'status_map' => [
            'ip_ban' => 'escalated',
            'identity_ban' => 'escalated',
            'device_ban' => 'escalated',
        ],

    ],

];
