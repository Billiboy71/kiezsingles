<?php

// ============================================================================
// File: C:\laragon\www\kiezsingles\app\Mail\MaintenanceEndedMail.php
// Purpose: Mailable for "maintenance ended" notification
// Changed: 10-02-2026 22:24
// Version: 0.1
// ============================================================================

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class MaintenanceEndedMail extends Mailable
{
    use Queueable, SerializesModels;

    public string $appName;
    public string $loginUrl;

    public function __construct()
    {
        $this->appName = (string) config('app.name', 'KiezSingles');
        $this->loginUrl = (string) url('/login');
    }

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: (string) __('mail.maintenance_ended.subject', ['app' => $this->appName]),
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.maintenance-ended',
            with: [
                'appName' => $this->appName,
                'loginUrl' => $this->loginUrl,
            ],
        );
    }

    public function attachments(): array
    {
        return [];
    }
}
