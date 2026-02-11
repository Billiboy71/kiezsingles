<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\emails\maintenance-ended.blade.php
// Purpose: Inhalt der E-Mail „Wartungsmodus beendet“
// Changed: 10-02-2026 22:31
// Version: 0.1
// ============================================================================
?>
@extends('emails.layout')

@section('content')
    <h2 style="margin:0 0 12px 0; font-size:18px;">
        {{ __('mail.maintenance_ended.headline') }}
    </h2>

    <p style="margin:0 0 16px 0; font-size:14px; line-height:1.5;">
        {{ __('mail.maintenance_ended.text', ['app' => $appName]) }}
    </p>

    <p style="margin:0 0 20px 0;">
        <a href="{{ $loginUrl }}"
           style="
                display:inline-block;
                padding:10px 16px;
                border-radius:8px;
                background:#0ea5e9;
                color:#ffffff;
                text-decoration:none;
                font-weight:600;
                font-size:14px;
           ">
            {{ __('mail.maintenance_ended.cta') }}
        </a>
    </p>
@endsection
