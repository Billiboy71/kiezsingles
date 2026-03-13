<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Http\Middleware\EncryptCookies.php
// Purpose: Disable encryption for specific cookies (ks_device_id)
// Created: 12-03-2026 00:45 (Europe/Berlin)
// Version: 0.1
// ============================================================================

namespace App\Http\Middleware;

use Illuminate\Cookie\Middleware\EncryptCookies as Middleware;

class EncryptCookies extends Middleware
{
    /**
     * Cookies that should NOT be encrypted.
     *
     * @var array<int, string>
     */
    protected $except = [
        'ks_device_id',
    ];
}