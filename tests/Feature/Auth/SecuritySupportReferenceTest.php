<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\tests\Feature\Auth\SecuritySupportReferenceTest.php
// Purpose: Feature tests for security support reference SSOT flows
// Created: 17-03-2026 (Europe/Berlin)
// Changed: 17-03-2026 11:36 (Europe/Berlin)
// Version: 0.1
// ============================================================================

use App\Models\SecurityEvent;
use App\Models\SecurityIdentityBan;
use App\Models\SecurityIpBan;
use App\Models\User;
use App\Services\Security\SecuritySettingsService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;

test('identity blocked login uses the persisted security event reference for the support token', function () {
    SecurityIdentityBan::query()->create([
        'email' => 'blocked@example.com',
        'reason' => 'test_identity_ban',
        'banned_until' => now()->addHour(),
        'created_by' => null,
    ]);

    $response = $this->from('/login')->post('/login', [
        'email' => 'blocked@example.com',
        'password' => 'password',
    ]);

    $response->assertRedirect('/login');

    $event = SecurityEvent::query()
        ->where('type', 'identity_blocked')
        ->latest('id')
        ->first();

    expect($event)->not->toBeNull();
    expect($event->reference)->toMatch('/^SEC-[A-Z0-9]{8}$/');

    $token = DB::table('security_support_access_tokens')
        ->where('support_reference', $event->reference)
        ->latest('id')
        ->first();

    expect($token)->not->toBeNull();
    $response->assertSessionHas('security_ban_support_ref', $event->reference);
    $response->assertSessionHas('security_ban_support_access_token');
});

test('login lockout uses the persisted security event reference for the support token', function () {
    /** @var SecuritySettingsService $settingsService */
    $settingsService = app(SecuritySettingsService::class);
    $settings = $settingsService->get();
    $settings->update([
        'login_attempt_limit' => 1,
        'lockout_seconds' => 900,
        'ip_autoban_enabled' => false,
        'device_autoban_enabled' => false,
    ]);

    $user = User::factory()->create([
        'email' => 'lockout@example.com',
        'password' => bcrypt('password'),
    ]);

    $this->from('/login')->post('/login', [
        'email' => $user->email,
        'password' => 'wrong-password',
    ])->assertRedirect('/login');

    $response = $this->from('/login')->post('/login', [
        'email' => $user->email,
        'password' => 'wrong-password',
    ]);

    $response->assertRedirect('/login');
    $response->assertSessionHasErrors('email');

    $event = SecurityEvent::query()
        ->where('type', 'login_lockout')
        ->latest('id')
        ->first();

    expect($event)->not->toBeNull();
    expect($event->reference)->toMatch('/^SEC-[A-Z0-9]{8}$/');

    $token = DB::table('security_support_access_tokens')
        ->where('support_reference', $event->reference)
        ->where('security_event_type', 'login_lockout')
        ->latest('id')
        ->first();

    expect($token)->not->toBeNull();
    $response->assertSessionHas('security_ban_support_ref', $event->reference);
    $response->assertSessionHas('security_ban_support_reference', $event->reference);
    $response->assertSessionHas('security_support_reference', $event->reference);
    $response->assertSessionHas('security_ban_support_access_token');

    RateLimiter::clear('lockout@example.com|127.0.0.1');
});

test('ip blocked login uses the persisted security event reference for the support token', function () {
    SecurityIpBan::query()->create([
        'ip' => '198.51.100.10',
        'reason' => 'test_ip_ban',
        'banned_until' => now()->addHour(),
        'created_by' => null,
    ]);

    $response = $this
        ->withHeader('X-Forwarded-For', '198.51.100.10')
        ->from('/login')
        ->get('/login');

    $response->assertOk();
    $response->assertSee('Referenz:');

    $event = SecurityEvent::query()
        ->where('type', 'ip_blocked')
        ->latest('id')
        ->first();

    expect($event)->not->toBeNull();
    expect($event->reference)->toMatch('/^SEC-[A-Z0-9]{8}$/');

    $token = DB::table('security_support_access_tokens')
        ->where('support_reference', $event->reference)
        ->where('security_event_type', 'ip_blocked')
        ->latest('id')
        ->first();

    expect($token)->not->toBeNull();
    $response->assertSessionHas('security_ban_support_ref', $event->reference);
    $response->assertSessionHas('security_ban_support_reference', $event->reference);
    $response->assertSessionHas('security_support_reference', $event->reference);
    $response->assertSessionHas('security_ban_support_access_token');
});

test('security support page requires query token and event reference instead of session fallback', function () {
    SecurityIdentityBan::query()->create([
        'email' => 'supportflow@example.com',
        'reason' => 'test_support_flow',
        'banned_until' => now()->addHour(),
        'created_by' => null,
    ]);

    $loginResponse = $this->from('/login')->post('/login', [
        'email' => 'supportflow@example.com',
        'password' => 'password',
    ]);

    $loginResponse->assertRedirect('/login');

    $event = SecurityEvent::query()
        ->where('type', 'identity_blocked')
        ->latest('id')
        ->first();

    expect($event)->not->toBeNull();

    $supportRef = session('security_ban_support_ref');
    $token = session('security_ban_support_access_token');

    expect($supportRef)->toBe($event->reference);
    expect(is_string($token) && trim($token) !== '')->toBeTrue();

    $sessionOnlyResponse = $this
        ->withSession([
            'security_ban_support_ref' => $supportRef,
            'security_ban_support_access_token' => $token,
        ])
        ->get('/support/security');

    $sessionOnlyResponse->assertForbidden();

    $getResponse = $this->get('/support/security?'.http_build_query([
        'support_access_token' => $token,
        'support_reference' => $supportRef,
    ]));

    $getResponse->assertOk();
    $getResponse->assertSee($supportRef);
});
