<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\config\security_incidents.php
// Purpose: Configurable thresholds for passive security incident detection.
// Created: 18-03-2026 12:18 (Europe/Berlin)
// Changed: 19-03-2026 00:13 (Europe/Berlin)
// Version: 0.9
// ============================================================================

return [
    'enabled' => (bool) env('SECURITY_INCIDENTS_ENABLED', true),

    'types' => [
        'credential_stuffing' => [
            'enabled' => true,
            'window_minutes' => (int) env('SECURITY_INCIDENTS_CREDENTIAL_STUFFING_WINDOW_MINUTES', 15),
            'cooldown_minutes' => (int) env('SECURITY_INCIDENTS_CREDENTIAL_STUFFING_COOLDOWN_MINUTES', 60),
            'min_distinct_emails' => (int) env('SECURITY_INCIDENTS_CREDENTIAL_STUFFING_MIN_DISTINCT_EMAILS', 5),
            'min_distinct_ips' => (int) env('SECURITY_INCIDENTS_CREDENTIAL_STUFFING_MIN_DISTINCT_IPS', 3),
            'linked_events_limit' => (int) env('SECURITY_INCIDENTS_CREDENTIAL_STUFFING_LINKED_EVENTS_LIMIT', 50),
            'meta_sample_limit' => (int) env('SECURITY_INCIDENTS_CREDENTIAL_STUFFING_META_SAMPLE_LIMIT', 10),
            'score_base' => (int) env('SECURITY_INCIDENTS_CREDENTIAL_STUFFING_SCORE_BASE', 50),
            'score_max' => (int) env('SECURITY_INCIDENTS_CREDENTIAL_STUFFING_SCORE_MAX', 100),
        ],

        'account_sharing' => [
            'enabled' => true,
            'window_minutes' => (int) env('SECURITY_INCIDENTS_ACCOUNT_SHARING_WINDOW_MINUTES', 60),
            'cooldown_minutes' => (int) env('SECURITY_INCIDENTS_ACCOUNT_SHARING_COOLDOWN_MINUTES', 180),
            'min_distinct_devices' => (int) env('SECURITY_INCIDENTS_ACCOUNT_SHARING_MIN_DISTINCT_DEVICES', 3),
            'min_distinct_ips' => (int) env('SECURITY_INCIDENTS_ACCOUNT_SHARING_MIN_DISTINCT_IPS', 3),
            'linked_events_limit' => (int) env('SECURITY_INCIDENTS_ACCOUNT_SHARING_LINKED_EVENTS_LIMIT', 50),
            'meta_sample_limit' => (int) env('SECURITY_INCIDENTS_ACCOUNT_SHARING_META_SAMPLE_LIMIT', 10),
            'score_base' => (int) env('SECURITY_INCIDENTS_ACCOUNT_SHARING_SCORE_BASE', 40),
            'score_max' => (int) env('SECURITY_INCIDENTS_ACCOUNT_SHARING_SCORE_MAX', 100),
        ],

        'bot_pattern' => [
            'enabled' => true,
            'window_minutes' => (int) env('SECURITY_INCIDENTS_BOT_PATTERN_WINDOW_MINUTES', 5),
            'cooldown_minutes' => (int) env('SECURITY_INCIDENTS_BOT_PATTERN_COOLDOWN_MINUTES', 30),
            'min_events' => (int) env('SECURITY_INCIDENTS_BOT_PATTERN_MIN_EVENTS', 110),
            'linked_events_limit' => (int) env('SECURITY_INCIDENTS_BOT_PATTERN_LINKED_EVENTS_LIMIT', 50),
            'meta_sample_limit' => (int) env('SECURITY_INCIDENTS_BOT_PATTERN_META_SAMPLE_LIMIT', 10),
            'score_base' => (int) env('SECURITY_INCIDENTS_BOT_PATTERN_SCORE_BASE', 30),
            'score_max' => (int) env('SECURITY_INCIDENTS_BOT_PATTERN_SCORE_MAX', 100),
        ],

        'device_cluster' => [
            'enabled' => true,
            'window_minutes' => (int) env('SECURITY_INCIDENTS_DEVICE_CLUSTER_WINDOW_MINUTES', 120),
            'cooldown_minutes' => (int) env('SECURITY_INCIDENTS_DEVICE_CLUSTER_COOLDOWN_MINUTES', 240),
            'min_events' => (int) env('SECURITY_INCIDENTS_DEVICE_CLUSTER_MIN_EVENTS', 18),
            'min_distinct_devices' => (int) env('SECURITY_INCIDENTS_DEVICE_CLUSTER_MIN_DISTINCT_DEVICES', 7),
            'min_distinct_emails' => (int) env('SECURITY_INCIDENTS_DEVICE_CLUSTER_MIN_DISTINCT_EMAILS', 4),
            'min_distinct_ips' => (int) env('SECURITY_INCIDENTS_DEVICE_CLUSTER_MIN_DISTINCT_IPS', 4),
            'linked_events_limit' => (int) env('SECURITY_INCIDENTS_DEVICE_CLUSTER_LINKED_EVENTS_LIMIT', 100),
            'meta_sample_limit' => (int) env('SECURITY_INCIDENTS_DEVICE_CLUSTER_META_SAMPLE_LIMIT', 10),
            'score_base' => (int) env('SECURITY_INCIDENTS_DEVICE_CLUSTER_SCORE_BASE', 60),
            'score_max' => (int) env('SECURITY_INCIDENTS_DEVICE_CLUSTER_SCORE_MAX', 100),
        ],
    ],
];
