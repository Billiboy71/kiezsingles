<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\admin\security\incidents\show.blade.php
// Purpose: Admin Security incident detail view (minimal read-only summary)
// Created: 22-03-2026 21:51 (Europe/Berlin)
// Changed: 25-03-2026 02:01 (Europe/Berlin)
// Version: 4.6
// ============================================================================

?>
@php
    use Illuminate\Support\Str;

    $typeMap = [
        'account_sharing' => 'Geteilter Account',
        'bot_pattern' => 'Bot-Muster',
        'device_cluster' => 'Geräte-Cluster',
        'credential_stuffing' => 'Login-Angriffe',
    ];

    $typeColorMap = [
        'account_sharing' => '#3b82f6',
        'bot_pattern' => '#ef4444',
        'device_cluster' => '#f97316',
        'credential_stuffing' => '#eab308',
    ];

    $typeStyles = [
        'account_sharing' => 'background:#3b82f6; color:#ffffff;',
        'bot_pattern' => 'background:#ef4444; color:#ffffff;',
        'device_cluster' => 'background:#f97316; color:#ffffff;',
        'credential_stuffing' => 'background:#eab308; color:#111827;',
    ];

    $severityStyles = [
        'high' => 'background:#dc3545; color:#ffffff;',
        'medium' => 'background:#fd7e14; color:#ffffff;',
        'low' => 'background:#198754; color:#ffffff;',
    ];

    $actionLabelMap = [
        'observe' => 'Beobachten',
        'review' => 'Prüfen',
        'investigate' => 'Analysieren',
        'suspicious' => 'Auffällig',
    ];

    $actionStyles = [
        'observe' => 'background:#0d6efd; color:#ffffff;',
        'review' => 'background:#6f42c1; color:#ffffff;',
        'investigate' => 'background:#fd7e14; color:#ffffff;',
        'suspicious' => 'background:#dc3545; color:#ffffff;',
    ];

    $statusMap = [
        null => 'Offen',
        'reviewed' => 'Maßnahme ergriffen',
        'escalated' => 'In Prüfung',
        'ignored' => 'Ignoriert',
    ];

    $actionStatusMap = [
        'reviewed' => 'Maßnahme ergriffen',
        'escalated' => 'In Prüfung',
        'ignored' => 'Ignoriert',
    ];

    $statusStyles = [
        null => 'background:#6c757d; color:#ffffff;',
        'reviewed' => 'background:#dc3545; color:#ffffff;',
        'escalated' => 'background:#fd7e14; color:#ffffff;',
        'ignored' => 'background:#198754; color:#ffffff;',
    ];
@endphp
@extends('admin.layouts.admin')

@section('content')
    @include('admin.security._tabs')

    @php
        $primaryIp = $topIps->first()?->ip ?? '';
        $primaryEmail = $topEmails->first()?->email ?? '';
        $primaryDevice = $topDevices->first()?->device_hash ?? '';
        $recommendedTypes = collect($recommendations ?? [])
            ->pluck('type')
            ->filter()
            ->toArray();
    @endphp

    <div class="space-y-6">
        <div style="
            padding:20px;
            border-radius:10px;
            margin-bottom:20px;
            background:
            @if($severity === 'high') #fff0f0
            @elseif($severity === 'medium') #fff8e6
            @else #f4f6f8
            @endif;
        ">
            <div style="display:flex; align-items:center; gap:15px;">
                <h2>Incident #{{ $incident->id }}</h2>

                <span style="
                    padding:4px 10px;
                    border-radius:999px;
                    font-size:12px;
                    font-weight:500;
                    {{ $severityStyles[$severity] ?? $severityStyles['low'] }}
                ">
                    {{ strtoupper($severity) }}
                </span>
            </div>

            <div style="display:flex; gap:40px; margin-top:10px;">
                <div>
                    <strong>Typ:</strong>
                    <span style="
                        display:inline-block;
                        padding:4px 10px;
                        border-radius:999px;
                        font-size:12px;
                        font-weight:500;
                        margin-left:6px;
                        {{ $typeStyles[$incident->type] ?? 'background:#f1f3f5; color:#495057;' }}
                    ">
                        {{ $typeMap[$incident->type] ?? $incident->type }}
                    </span>
                </div>
                <div><strong>Events:</strong> {{ $incident->events_count ?? '-' }}</div>
                <div><strong>Erstellt:</strong> {{ $incident->created_at ?? '-' }}</div>
                <div>
                    <strong>Aktion:</strong>
                    <span style="
                        display:inline-block;
                        padding:4px 10px;
                        border-radius:999px;
                        font-size:12px;
                        font-weight:500;
                        margin-left:6px;
                        {{ $actionStyles[$action['label']] ?? 'background:#6c757d; color:#ffffff;' }}
                    ">
                        {{ $actionLabelMap[$action['label']] ?? $action['label'] }}
                    </span>
                </div>
            </div>

            <div style="margin-top:10px; font-size:13px; color:#555;">
                {{ $action['description'] }}
            </div>

            <div style="margin-top:12px; padding:12px; border:1px solid #ddd; border-radius:8px; background:#fff;">
                <strong>Schnellaktionen</strong>

                <div style="margin-top:8px; display:flex; gap:10px; flex-wrap:wrap;">
                    @php $ipRecommended = in_array('ip', $recommendedTypes); @endphp
                    <form method="POST" action="{{ route('admin.security.ip_bans.store') }}">
                        @csrf
                        <input type="hidden" name="ip" value="{{ $primaryIp }}">
                        <input type="hidden" name="incident_id" value="{{ $incident->id }}">
                        <input type="hidden" name="reason" value="Incident {{ $incident->id }}">
                        <button type="submit" style="
                            background: {{ $ipRecommended ? '#dc3545' : '#0d6efd' }};
                            color:white;
                            border:none;
                            padding:8px 12px;
                            border-radius:6px;
                        ">
                            IP sperren
                        </button>
                    </form>

                    @php $identityRecommended = in_array('identity', $recommendedTypes); @endphp
                    <form method="POST" action="{{ route('admin.security.identity_bans.store') }}">
                        @csrf
                        <input type="hidden" name="email" value="{{ $primaryEmail }}">
                        <input type="hidden" name="incident_id" value="{{ $incident->id }}">
                        <input type="hidden" name="reason" value="Incident {{ $incident->id }}">
                        <button type="submit" style="
                            background: {{ $identityRecommended ? '#dc3545' : '#0d6efd' }};
                            color:white;
                            border:none;
                            padding:8px 12px;
                            border-radius:6px;
                        ">
                            Identity sperren
                        </button>
                    </form>

                    @php $deviceRecommended = in_array('device', $recommendedTypes); @endphp
                    <form method="POST" action="{{ route('admin.security.device_bans.store') }}">
                        @csrf
                        <input type="hidden" name="device_hash" value="{{ $primaryDevice }}">
                        <input type="hidden" name="incident_id" value="{{ $incident->id }}">
                        <input type="hidden" name="reason" value="Incident {{ $incident->id }}">
                        <button type="submit" style="
                            background: {{ $deviceRecommended ? '#dc3545' : '#0d6efd' }};
                            color:white;
                            border:none;
                            padding:8px 12px;
                            border-radius:6px;
                        ">
                            Device sperren
                        </button>
                    </form>

                    @if(count($recommendedTypes))
                        <div style="margin-left:auto;">
                            <form method="POST" action="{{ route('admin.security.incidents.applyActions', $incident->id) }}">
                                @csrf
                                <button style="
                                    background:#dc3545;
                                    color:white;
                                    padding:8px 12px;
                                    border-radius:6px;
                                ">
                                    ⚡ Empfohlene Maßnahmen anwenden
                                </button>
                            </form>
                        </div>
                    @endif
                </div>
            </div>

            <div style="margin-top:10px;">
                <div style="margin-bottom:6px; display:flex; justify-content:space-between; align-items:center; gap:12px;">
                    <div>
                        <strong>Status:</strong>
                        <span id="status-badge" style="
                            padding:4px 10px;
                            border-radius:999px;
                            font-size:12px;
                            font-weight:500;
                            {{ $statusStyles[$incident->action_status] ?? $statusStyles[null] }}
                        ">
                            {{ $statusMap[$incident->action_status] ?? 'Offen' }}
                        </span>
                    </div>

                    <div style="display:flex; gap:8px;">
                        <button type="button" onclick="setStatus('escalated')" style="background:#fd7e14;color:white;border:none;padding:5px 8px;border-radius:6px;cursor:pointer;">In Prüfung</button>
                        <button type="button" onclick="setStatus('ignored')" style="background:#198754;color:white;border:none;padding:5px 8px;border-radius:6px;cursor:pointer;">Ignoriert</button>
                    </div>

                    <button type="button" onclick="openActions()" style="
                        background:#0d6efd;
                        color:white;
                        border:none;
                        padding:6px 10px;
                        border-radius:6px;
                        cursor:pointer;
                    ">
                        Status Verlauf
                    </button>
                </div>
            </div>

            @php
                $autoActionDetails = json_decode($incident->auto_action_details ?? 'null', true) ?? [];
            @endphp

            @if($incident->auto_action_executed || !empty($autoActionDetails))
                <div style="
                    margin-top:10px;
                    padding:10px;
                    border-radius:8px;
                    background:#e6f7ff;
                    font-size:13px;
                ">
                    <strong>{{ $incident->auto_action_executed ? 'Automatische Maßnahme ausgeführt' : 'Automatische Maßnahme vorgeschlagen' }}</strong><br>

                    @if(in_array('ip', $autoActionDetails, true)) ✔ IP sperren<br>@endif
                    @if(in_array('device', $autoActionDetails, true)) ✔ Device sperren<br>@endif
                    @if(in_array('identity', $autoActionDetails, true)) ✔ Identity sperren<br>@endif
                </div>
            @endif

            @if(!$incident->auto_action_executed && !empty($autoActionDetails))
                <form method="POST" action="{{ route('admin.security.incidents.applyActions', $incident->id) }}">
                    @csrf
                    <button style="
                        margin-top:10px;
                        background:#dc3545;
                        color:white;
                        padding:8px 12px;
                        border-radius:6px;
                    ">
                        Empfohlene Maßnahmen anwenden
                    </button>
                </form>
            @endif

            <div id="incident-delete-panel" style="margin-top:10px;">
                <form id="incident-delete-form"
                      method="POST"
                      action="{{ route('admin.security.incidents.destroy', $incident->id) }}"
                      onsubmit="return confirm('Incident wirklich löschen?');"
                      style="{{ $incident->action_status === 'reviewed' ? 'display:none;' : '' }}">
                    @csrf
                    @method('DELETE')

                    <button style="
                        background:#dc3545;
                        color:white;
                        border:none;
                        padding:6px 10px;
                        border-radius:6px;
                        margin-top:10px;
                        cursor:pointer;
                    ">
                        Incident löschen
                    </button>
                </form>

                <div id="incident-delete-blocked" style="
                    margin-top:10px;
                    padding:8px 10px;
                    border-radius:6px;
                    background:#f8d7da;
                    color:#842029;
                    font-size:13px;
                    {{ $incident->action_status === 'reviewed' ? '' : 'display:none;' }}
                ">
                    Löschen nicht möglich (Maßnahme ergriffen)
                </div>
            </div>
        </div>

        <div style="margin-top:25px;">
            <h3>Letzte Events</h3>

            <div style="display:grid; grid-template-columns: repeat(auto-fill, minmax(420px, 1fr)); gap:12px;">
                @forelse($events as $event)
                    <div style="border:1px solid #ddd;border-radius:8px;padding:12px;background:#fff;">
                        <div style="display:flex; justify-content:space-between; margin-bottom:6px;">
                            <div>{{ $event->created_at }}</div>
                            <div>{{ $event->ip ?? '-' }}</div>
                        </div>

                        <div><strong>E-Mail:</strong> {{ $event->email ?? '-' }}</div>
                        <div><strong>Gerät-ID:</strong> {{ $event->device_hash ? \Illuminate\Support\Str::limit($event->device_hash, 16) : '-' }}</div>
                    </div>
                @empty
                    <div>Keine Events vorhanden</div>
                @endforelse
            </div>
        </div>

    </div>

    <div id="actions-modal" style="
        display:none;
        position:fixed;
        top:0;
        left:0;
        width:100%;
        height:100%;
        background:rgba(0,0,0,0.6);
        z-index:99999;
    ">
        <div style="
            background:white;
            width:600px;
            max-height:80%;
            overflow:auto;
            margin:5% auto;
            padding:20px;
            border-radius:10px;
        ">
            <div style="display:flex; justify-content:space-between; align-items:center; gap:12px;">
                <h3>Letzte Aktionen</h3>
                <button type="button" onclick="closeActions()" style="background:#6c757d;color:white;border:none;padding:6px 10px;border-radius:6px;cursor:pointer;">
                    Schließen
                </button>
            </div>

            @forelse($actions as $a)
                <div style="padding:8px; border-bottom:1px solid #eee; font-size:13px;">
                    <strong>{{ $a->created_at }}</strong><br>

                    @if($a->action === 'status_change')
                        Status:
                        {{ $actionStatusMap[$a->old_status] ?? 'Offen' }}
                        ->
                        {{ $actionStatusMap[$a->new_status] ?? '-' }}
                    @else
                        {{ $a->action }}
                    @endif

                    @if($a->user_name)
                        ({{ $a->user_name }})
                    @elseif($a->user_email)
                        ({{ $a->user_email }})
                    @else
                        (System)
                    @endif
                </div>
            @empty
                <div>Keine Aktionen vorhanden</div>
            @endforelse
        </div>
    </div>

    <script>
    function openActions() {
        document.getElementById("actions-modal").style.display = "block";
    }

    function closeActions() {
        document.getElementById("actions-modal").style.display = "none";
    }

    function setStatus(status) {

        const formData = new FormData();
        formData.append('status', status);

        fetch("{{ route('admin.security.incidents.updateStatus', $incident->id) }}", {
            method: "POST",
            headers: {
                "X-CSRF-TOKEN": "{{ csrf_token() }}"
            },
            body: formData
        })
        .then(res => res.json())
        .then(data => {

            const map = {
                reviewed: "Maßnahme ergriffen",
                escalated: "In Prüfung",
                ignored: "Ignoriert"
            };

            const color = {
                reviewed: {
                    background: "#dc3545",
                    color: "#ffffff"
                },
                escalated: {
                    background: "#fd7e14",
                    color: "#ffffff"
                },
                ignored: {
                    background: "#198754",
                    color: "#ffffff"
                }
            };

            if (data.status) {
                document.getElementById("status-badge").innerText = map[data.status];
                document.getElementById("status-badge").style.background = color[data.status].background;
                document.getElementById("status-badge").style.color = color[data.status].color;
                if (data.status === "reviewed") {
                    document.getElementById("incident-delete-form").style.display = "none";
                    document.getElementById("incident-delete-blocked").style.display = "block";
                } else {
                    document.getElementById("incident-delete-form").style.display = "block";
                    document.getElementById("incident-delete-blocked").style.display = "none";
                }
                sessionStorage.setItem("incident_status_{{ $incident->id }}", data.status);
            }
        });
    }
    </script>

    <div style="position:fixed; bottom:20px; right:80px; z-index:99999;">
        <a href="{{ route('admin.security.incidents.index') }}" style="
            background:#0d6efd;
            color:white;
            padding:10px 14px;
            border-radius:8px;
            text-decoration:none;
        ">
            ← Zurück
        </a>
    </div>
@endsection
