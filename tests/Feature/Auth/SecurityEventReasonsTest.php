<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\tests\Feature\Auth\SecurityEventReasonsTest.php
// Purpose: Feature tests for collecting multiple reasons on one security incident
// Created: 17-03-2026 (Europe/Berlin)
// Changed: 17-03-2026 12:26 (Europe/Berlin)
// Version: 0.2
// ============================================================================

use App\Events\Security\SecurityEventTriggered;
use App\Models\SecurityEvent;

test('security event collects multiple unique reasons on the same incident key', function () {
    $expectedIncidentKey = hash('sha256', implode('|', [
        'reasonstest@example.com',
        '198.51.100.20',
        'device-reasons-001',
    ]));

    event(new SecurityEventTriggered(
        type: 'ip_blocked',
        ip: '198.51.100.20',
        email: 'reasonstest@example.com',
        deviceHash: 'device-reasons-001',
        meta: [
            'reason' => 'ip_ban',
            'path' => 'login',
        ],
    ));

    $initialEvent = SecurityEvent::query()
        ->where('meta->incident_key', $expectedIncidentKey)
        ->latest('id')
        ->first();

    expect($initialEvent)->not->toBeNull();

    $initialReference = $initialEvent->reference;

    event(new SecurityEventTriggered(
        type: 'identity_blocked',
        ip: '198.51.100.20',
        email: 'reasonstest@example.com',
        deviceHash: 'device-reasons-001',
        meta: [
            'reason' => 'identity_ban',
            'path' => 'login',
        ],
    ));

    event(new SecurityEventTriggered(
        type: 'identity_blocked',
        ip: '198.51.100.20',
        email: 'reasonstest@example.com',
        deviceHash: 'device-reasons-001',
        meta: [
            'reason' => 'identity_ban',
            'path' => 'login',
        ],
    ));

    $events = SecurityEvent::query()
        ->where('meta->incident_key', $expectedIncidentKey)
        ->get();

    expect($events)->toHaveCount(1);

    $event = $events->first();

    expect($event)->not->toBeNull();
    expect($event->reference)->toBe($initialReference);
    expect($event->reference)->toMatch('/^SEC-[A-Z0-9]{8}$/');
    expect($event->meta['incident_key'] ?? null)->toBe($expectedIncidentKey);
    expect($event->meta['support_ref'] ?? null)->toBe($initialReference);
    expect($event->reasons)->toBe(['ip_ban', 'identity_ban']);
});
