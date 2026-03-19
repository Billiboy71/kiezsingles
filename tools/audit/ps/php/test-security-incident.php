<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\tools\audit\ps\php\test-security-incident.php
// Purpose: Manual Security Incident Test (Audit Tool Integration)
// Changed: 18-03-2026 16:22 (Europe/Berlin)
// Version: 1.0
// ============================================================================

use App\Events\Security\SecurityEventTriggered;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

require __DIR__ . '/../../../../vendor/autoload.php';

$app = require_once __DIR__ . '/../../../../bootstrap/app.php';
$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

echo PHP_EOL;
echo '=== SECURITY INCIDENT TEST ===' . PHP_EOL;

$requiredTables = [
    'security_events',
    'security_incidents',
    'security_incident_events',
];

foreach ($requiredTables as $table) {
    if (!Schema::hasTable($table)) {
        echo 'RESULT: FAIL - Missing table: ' . $table . PHP_EOL;
        exit(1);
    }
}

Schema::disableForeignKeyConstraints();
DB::table('security_incident_events')->truncate();
DB::table('security_incidents')->truncate();
Schema::enableForeignKeyConstraints();

echo 'Tables cleared.' . PHP_EOL;

$device = 'test-device-001';
$runId = 'tool-security-incident-' . Str::lower((string) Str::uuid());

for ($i = 1; $i <= 15; $i++) {
    event(new SecurityEventTriggered(
        'login_failed',
        '198.51.100.' . (10 + ($i % 5)),
        null,
        'tool-test-' . $i . '@kiezsingles.local',
        $device,
        [
            'run_id' => $runId,
            'source' => 'tools/audit/ps/php/test-security-incident.php',
        ]
    ));
}

echo 'Events triggered.' . PHP_EOL;

$events = DB::table('security_events')
    ->where('run_id', $runId)
    ->count();

$incidents = DB::table('security_incidents as si')
    ->join('security_incident_events as sie', 'sie.incident_id', '=', 'si.id')
    ->join('security_events as se', 'se.id', '=', 'sie.security_event_id')
    ->where('se.run_id', $runId)
    ->distinct('si.id')
    ->count('si.id');

echo PHP_EOL;
echo 'Events:    ' . $events . PHP_EOL;
echo 'Incidents: ' . $incidents . PHP_EOL;
echo PHP_EOL;

if ($incidents > 0) {
    echo 'RESULT: OK - Detection funktioniert' . PHP_EOL;
    exit(0);
}

echo 'RESULT: FAIL - Keine Incidents erkannt' . PHP_EOL;
exit(1);
