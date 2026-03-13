<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Services\Security\SecurityEventWriter.php
// Purpose: Legacy stub (disabled). Security events must be written via
//          SecurityEventLogger → SecurityEventTriggered → StoreSecurityEvent.
// Changed: 10-03-2026 10:00 (Europe/Berlin)
// Version: 0.2
// ============================================================================

namespace App\Services\Security;

use RuntimeException;

class SecurityEventWriter
{
    public function record(): never
    {
        throw new RuntimeException(
            'SecurityEventWriter is deprecated. Use SecurityEventLogger instead.'
        );
    }
}