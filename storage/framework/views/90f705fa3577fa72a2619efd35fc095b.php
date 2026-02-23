<!-- =========================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\tickets\show.blade.php
Purpose: Admin – Ticket Detail (Blade)
Changed: 18-02-2026 20:45 (Europe/Berlin)
Version: 1.0
============================================================================= -->



<?php
    $ticketId = (int) ($ticketId ?? 0);

    $type = (string) ($type ?? '');
    $typeLabel = (string) ($typeLabel ?? '');

    $status = (string) ($status ?? '');
    $statusLabel = (string) ($statusLabel ?? '');
    $statusClass = (string) ($statusClass ?? '');

    $category = (string) ($category ?? '');
    $categoryLabel = (string) ($categoryLabel ?? '');
    $categoryClass = (string) ($categoryClass ?? '');

    $priorityRaw = (string) ($priorityRaw ?? '');
    $priorityLabel = (string) ($priorityLabel ?? '');
    $priorityClass = (string) ($priorityClass ?? '');

    $subjectText = (string) ($subjectText ?? '');
    $messageText = (string) ($messageText ?? '');

    $creatorDisplay = (string) ($creatorDisplay ?? '-');
    $reportedDisplay = (string) ($reportedDisplay ?? '-');
    $assignedAdminDisplay = (string) ($assignedAdminDisplay ?? '-');

    $createdAt = (string) ($createdAt ?? '');
    $closedAt = (string) ($closedAt ?? '');

    $notice = $notice ?? null;

    $adminOptions = $adminOptions ?? [];
    $categoryOptions = $categoryOptions ?? [];
    $priorityOptions = $priorityOptions ?? [];
    $statusOptions = $statusOptions ?? [];

    $messageRows = $messageRows ?? [];
    $auditRows = $auditRows ?? [];

    $isReport = (bool) ($isReport ?? false);

    // Optional: server-side draft support (controller can pass these)
    $draftSaveUrl = (string) ($draftSaveUrl ?? '');
    $draftReplyText = (string) ($draftReplyText ?? '');
    $draftInternalText = (string) ($draftInternalText ?? '');

    // Global Header (layouts/navigation.blade.php) – Admin Tabs
    $adminTab = $adminTab ?? 'tickets';
    $adminShowDebugTab = $adminShowDebugTab ?? (isset($maintenanceEnabled) ? (bool) $maintenanceEnabled : false);
?>

<?php $__env->startSection('content'); ?>
    <style>
        *, *::before, *::after { box-sizing:border-box; }

        /*
         * Layout kommt aus admin.layouts.admin (Container + Padding + Card).
         * Ticket-Detail darf hier keine eigene max-width/padding am <body> erzwingen.
         */

        .ks-top { display:flex; align-items:center; justify-content:space-between; gap:12px; flex-wrap:wrap; margin:0 0 14px 0; }
        .ks-h1 { margin:0; }
        .ks-badge { display:inline-flex; align-items:center; justify-content:center; padding:4px 9px; border-radius:999px; font-weight:900; font-size:12px; letter-spacing:.2px; color:#111; background:#e5e7eb; border:1px solid #e5e7eb; }
        .ks-card { border:1px solid #e5e7eb; border-radius:12px; background:#fff; padding:14px 14px; margin:0 0 14px 0; }
        .ks-row { display:flex; gap:10px; flex-wrap:wrap; align-items:center; }
        .ks-btn { padding:8px 10px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; cursor:pointer; user-select:none; font-weight:700; font-size:13px; }
        .ks-btn:hover { background:#f8fafc; }
        .ks-btn:active { background:#f1f5f9; }

        .ks-input { padding:8px 10px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; font-size:13px; }
        .ks-select { appearance:none; -webkit-appearance:none; -moz-appearance:none; padding-right:28px; background-image: linear-gradient(45deg, transparent 50%, #64748b 50%), linear-gradient(135deg, #64748b 50%, transparent 50%); background-position: calc(100% - 16px) 50%, calc(100% - 11px) 50%; background-size: 6px 6px, 6px 6px; background-repeat: no-repeat; }
        .ks-textarea { width:100%; max-width:100%; display:block; min-height:160px; padding:10px 12px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; font-family:inherit; font-size:14px; }

        .ks-muted { color:#666; font-size:13px; }
        .ks-label { color:#111; font-weight:900; font-size:13px; margin:0 0 6px 0; }

        .ks-kvline { display:flex; gap:10px; align-items:stretch; flex-wrap:wrap; }
        .ks-kvbox { background:#f8fafc; border:1px solid #e5e7eb; border-radius:10px; padding:6px 8px; min-width:96px; flex: 1 1 96px; }
        .ks-kvbox b { display:block; font-size:11px; color:#555; letter-spacing:.25px; text-transform:uppercase; margin:0 0 2px 0; }
        .ks-kvbox span { color:#111; font-weight:800; }

        .ks-kvbox.creator { background:#fef9c3; border-color:#fde68a; }
        .ks-kvbox.reported { background:#fee2e2; border-color:#fecaca; }
        .ks-kvbox.assigned { background:#dcfce7; border-color:#bbf7d0; }

        .ks-kvbox.ctime { background:#f1f5f9; border-color:#e2e8f0; flex: 0 0 180px; }
        .ks-kvbox.closedtime { background:#ecfdf5; border-color:#bbf7d0; flex: 0 0 180px; }

        .ks-pill { display:inline-flex; align-items:center; padding:3px 8px; border-radius:999px; font-size:12px; font-weight:900; border:1px solid #e5e7eb; background:#f1f5f9; color:#111; }
        .ks-pill.user { background:#fef9c3; border-color:#fde68a; }
        .ks-pill.admin { background:#fee2e2; border-color:#fecaca; }
        .ks-pill.internal { background:#0b1220; color:#e5e7eb; border-color:#0b1220; }

        .ks-msg { border:1px solid #e5e7eb; border-radius:12px; padding:12px 12px; background:#fff; margin:0 0 10px 0; }
        .ks-msg-head { display:flex; justify-content:space-between; gap:10px; flex-wrap:wrap; margin:0 0 6px 0; }

        .ks-notice { padding:12px 14px; border-radius:10px; border:1px solid #b6e0b6; background:#eef7ee; margin:0 0 14px 0; }
        a { color:#0ea5e9; text-decoration:underline; }
        pre { white-space:pre-wrap; margin:0; font-family:inherit; font-size:14px; }

        .ks-audit { border:1px solid #e5e7eb; border-radius:12px; background:#fff; overflow:hidden; }
        .ks-audit table { width:100%; border-collapse:separate; border-spacing:0; }
        .ks-audit th, .ks-audit td { text-align:left; padding:10px 12px; border-bottom:1px solid #e5e7eb; vertical-align:top; }
        .ks-audit th { font-size:12px; color:#555; letter-spacing:.3px; text-transform:uppercase; background:#f8fafc; }
        .ks-audit tr:last-child td { border-bottom:none; }

        .ks-split { display:flex; gap:12px; flex-wrap:wrap; align-items:flex-end; }
        .ks-split > div { min-width:210px; }

        .ks-info { display:inline-flex; align-items:center; justify-content:center; width:18px; height:18px; border-radius:999px; border:1px solid #cbd5e1; background:#fff; color:#111; font-weight:900; font-size:12px; cursor:help; position:relative; }
        .ks-info:hover::after {
            content: attr(data-tip);
            position:absolute;
            left: 24px;
            top: -6px;
            min-width: 260px;
            max-width: 360px;
            padding:10px 12px;
            border:1px solid #cbd5e1;
            background:#0b1220;
            color:#e5e7eb;
            border-radius:10px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.12);
            z-index: 10;
            font-weight: 700;
            font-size: 12px;
            line-height: 1.3;
            white-space: normal;
        }

        .st-open { background:#fef9c3; border-color:#fde68a; }
        .st-inprogress { background:#e0f2fe; border-color:#bae6fd; }
        .st-closed { background:#dcfce7; border-color:#bbf7d0; }
        .st-rejected { background:#f1f5f9; border-color:#e2e8f0; }
        .st-escalated { background:#fee2e2; border-color:#fecaca; }
        .st-other { background:#e5e7eb; border-color:#e5e7eb; }

        .cat-none { background:#f1f5f9; border-color:#e2e8f0; }
        .cat-support { background:#e0f2fe; border-color:#bae6fd; }
        .cat-abuse { background:#fee2e2; border-color:#fecaca; }
        .cat-spam { background:#ffedd5; border-color:#fed7aa; }
        .cat-billing { background:#ede9fe; border-color:#ddd6fe; }
        .cat-bug { background:#ccfbf1; border-color:#99f6e4; }
        .cat-other { background:#e5e7eb; border-color:#e5e7eb; }

        .prio-none { background:#dcfce7; border-color:#bbf7d0; }
        .prio-low { background:#ecfccb; border-color:#d9f99d; }
        .prio-normal { background:#fef9c3; border-color:#fde68a; }
        .prio-high { background:#ffedd5; border-color:#fed7aa; }
        .prio-critical { background:#fee2e2; border-color:#fecaca; }
        .prio-other { background:#e5e7eb; border-color:#e5e7eb; }
    </style>

    <div id="ks_ticket_page" data-ticket-id="<?php echo e($ticketId); ?>" data-draft-save-url="<?php echo e($draftSaveUrl); ?>">

        <div class="ks-top">
            <div class="ks-row">
                <h1 class="ks-h1">Ticket <?php echo e($ticketId); ?></h1>
            </div>

            <div style="flex:1; display:flex; justify-content:center;">
                <span id="js-status-badge" class="ks-badge <?php echo e($statusClass); ?>"><?php echo e($statusLabel); ?></span>
            </div>

            <div class="ks-row">
                <a class="ks-btn" href="<?php echo e(route('admin.tickets.index')); ?>" style="text-decoration:none; color:#111;">Zurück zur Liste</a>
            </div>
        </div>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($notice): ?>
            <div class="ks-notice"><?php echo e((string) $notice); ?></div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <div class="ks-card">

            <div class="ks-kvline" style="margin:0 0 10px 0;">
                <div class="ks-kvbox"><b>Typ</b><span><?php echo e($typeLabel); ?></span></div>

                <div class="ks-kvbox">
                    <b>Kategorie</b>
                    <span>
                        <span id="js-head-category-badge" class="ks-badge <?php echo e($categoryClass); ?>"><?php echo e($category !== '' ? $categoryLabel : '-'); ?></span>
                    </span>
                </div>

                <div class="ks-kvbox">
                    <b>Priorität</b>
                    <span>
                        <span id="js-head-priority-badge" class="ks-badge <?php echo e($priorityClass); ?>"><?php echo e($priorityLabel !== '' ? $priorityLabel : '-'); ?></span>
                    </span>
                </div>

                <div class="ks-kvbox creator"><b>Ersteller</b><span><?php echo e($creatorDisplay); ?></span></div>
                <div class="ks-kvbox reported"><b>Gemeldet</b><span><?php echo e($reportedDisplay); ?></span></div>
                <div class="ks-kvbox assigned"><b>Zugewiesen</b><span id="js-head-assigned"><?php echo e($assignedAdminDisplay); ?></span></div>
            </div>

            <div class="ks-row" style="margin:0 0 0 0;">
                <div class="ks-kvbox ctime"><b>Erstellt</b><span><?php echo e($createdAt); ?></span></div>
                <div class="ks-kvbox closedtime"><b>Geschlossen</b><span><?php echo $closedAt !== '' ? e($closedAt) : '<span style="color:#666;">-</span>'; ?></span></div>
            </div>

        </div>

        <h2 style="margin:18px 0 10px 0; font-size:18px;">Admin – Verwaltung</h2>
        <div class="ks-card">
            <form id="js-meta-form" method="POST" action="<?php echo e(route('admin.tickets.updateMeta', $ticketId)); ?>">
                <?php echo csrf_field(); ?>

                <div class="ks-row" style="justify-content:space-between; align-items:flex-end; margin:0 0 10px 0;">
                    <div class="ks-muted">Autospeichern aktiv (bei Änderung).</div>
                    <div class="ks-muted" id="js-meta-status"></div>
                </div>

                <div class="ks-split">

                    <div>
                        <div class="ks-muted" style="margin:0 0 6px 0;">Zuweisen (Admin)</div>
                        <select id="js-assigned-admin-select" class="ks-input ks-select js-meta-field" name="assigned_admin_user_id">
                            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $adminOptions; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $o): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                                <?php
                                    $id = $o['id'] ?? null;
                                    $label = (string) ($o['label'] ?? '');
                                    $selected = (bool) ($o['selected'] ?? false);
                                    $value = ($id === null) ? '' : (string) (int) $id;
                                ?>
                                <option value="<?php echo e($value); ?>" <?php if($selected): echo 'selected'; endif; ?>><?php echo e($label); ?></option>
                            <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                        </select>
                    </div>

                    <div>
                        <div class="ks-muted" style="margin:0 0 6px 0;">Kategorie</div>
                        <select id="js-category-select" class="ks-input ks-select js-colored-select js-meta-field" name="category" data-kind="category">
                            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $categoryOptions; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $o): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                                <?php
                                    $value = (string) ($o['value'] ?? '');
                                    $label = (string) ($o['label'] ?? '');
                                    $selected = (bool) ($o['selected'] ?? false);
                                ?>
                                <option value="<?php echo e($value); ?>" <?php if($selected): echo 'selected'; endif; ?>><?php echo e($label); ?></option>
                            <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                        </select>
                    </div>

                    <div>
                        <div class="ks-muted" style="margin:0 0 6px 0;">Priorität</div>
                        <select id="js-priority-select" class="ks-input ks-select js-colored-select js-meta-field" name="priority" data-kind="priority">
                            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $priorityOptions; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $o): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                                <?php
                                    $value = (string) ($o['value'] ?? '');
                                    $label = (string) ($o['label'] ?? '');
                                    $selected = (bool) ($o['selected'] ?? false);
                                ?>
                                <option value="<?php echo e($value); ?>" <?php if($selected): echo 'selected'; endif; ?>><?php echo e($label); ?></option>
                            <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                        </select>
                    </div>

                    <div>
                        <div class="ks-muted" style="margin:0 0 6px 0;">Status</div>
                        <select id="js-status-select" class="ks-input ks-select js-colored-select js-meta-field" name="status" data-kind="status">
                            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $statusOptions; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $o): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                                <?php
                                    $value = (string) ($o['value'] ?? '');
                                    $label = (string) ($o['label'] ?? '');
                                    $selected = (bool) ($o['selected'] ?? false);
                                ?>
                                <option value="<?php echo e($value); ?>" <?php if($selected): echo 'selected'; endif; ?>><?php echo e($label); ?></option>
                            <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                        </select>
                    </div>

                </div>

            </form>
        </div>

        <div class="ks-card">
            <div class="ks-muted" style="margin:0 0 6px 0;">Betreff</div>
            <div style="font-weight:900; margin:0 0 10px 0;">
                <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($subjectText !== ''): ?>
                    <?php echo e($subjectText); ?>

                <?php else: ?>
                    <span style="color:#666;">(ohne)</span>
                <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
            </div>

            <div class="ks-muted" style="margin:0 0 6px 0;">Erstnachricht</div>
            <pre><?php echo $messageText !== '' ? e($messageText) : '<span style="color:#666;">(ohne)</span>'; ?></pre>
        </div>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($isReport): ?>
            <h2 style="margin:18px 0 10px 0; font-size:18px;">Moderation – Schnellaktionen</h2>
            <div class="ks-card">

                <div class="ks-row" style="margin:0 0 12px 0;">

                    <form method="POST" action="<?php echo e(route('admin.tickets.moderate.warn', $ticketId)); ?>" style="margin:0;">
                        <?php echo csrf_field(); ?>
                        <input class="ks-input" type="text" name="note" placeholder="Notiz (optional)" style="min-width:240px;">
                        <button type="submit" class="ks-btn">Verwarnen</button>
                    </form>

                    <form method="POST" action="<?php echo e(route('admin.tickets.moderate.tempBan', $ticketId)); ?>" style="margin:0;">
                        <?php echo csrf_field(); ?>
                        <input class="ks-input" type="number" name="days" min="1" max="365" value="7" style="width:96px;" required>
                        <input class="ks-input" type="text" name="note" placeholder="Notiz (optional)" style="min-width:240px;">
                        <button type="submit" class="ks-btn">Temp. Sperre</button>
                    </form>

                    <form method="POST" action="<?php echo e(route('admin.tickets.moderate.permBan', $ticketId)); ?>" style="margin:0;">
                        <?php echo csrf_field(); ?>
                        <input class="ks-input" type="text" name="note" placeholder="Notiz (optional)" style="min-width:240px;">
                        <button type="submit" class="ks-btn">Dauerhaft</button>
                    </form>

                    <form method="POST" action="<?php echo e(route('admin.tickets.moderate.unfounded', $ticketId)); ?>" style="margin:0;">
                        <?php echo csrf_field(); ?>
                        <input class="ks-input" type="text" name="note" placeholder="Notiz (optional)" style="min-width:240px;">
                        <button type="submit" class="ks-btn">Unbegründet</button>
                    </form>

                </div>
            </div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <h2 style="margin:18px 0 10px 0; font-size:18px;">Verlauf</h2>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(count($messageRows) < 1): ?>
            <div class="ks-muted">(noch keine Nachrichten)</div>
        <?php else: ?>
            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $messageRows; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $m): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                <?php
                    $who = (string) ($m['who'] ?? '-');
                    $pillClass = (string) ($m['pill_class'] ?? 'ks-pill');
                    $isInternal = (bool) ($m['is_internal'] ?? false);
                    $msgText = (string) ($m['message'] ?? '');
                    $ts = (string) ($m['created_at'] ?? '');
                ?>

                <div class="ks-msg">
                    <div class="ks-msg-head">
                        <div class="ks-row" style="gap:8px;">
                            <span class="<?php echo e($pillClass); ?>"><?php echo e($who); ?></span>
                            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($isInternal): ?>
                                <span class="ks-pill internal">INTERN</span>
                            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                        </div>
                        <div class="ks-muted"><?php echo e($ts); ?></div>
                    </div>
                    <pre><?php echo e($msgText); ?></pre>
                </div>
            <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <h2 style="margin:18px 0 10px 0; font-size:18px;">Antwort</h2>

        <div class="ks-card">
            <form id="js-reply-form" method="POST" action="<?php echo e(route('admin.tickets.reply', $ticketId)); ?>">
                <?php echo csrf_field(); ?>

                <div class="ks-row" style="justify-content:space-between; align-items:flex-end; margin:0 0 6px 0;">
                    <div class="ks-label">Antwort an Nutzer (sichtbar)</div>

                    <div class="ks-row" style="gap:8px; justify-content:flex-end; align-items:center;">
                        <span class="ks-muted" id="js-draft-status"></span>
                        <span class="ks-info" data-tip="Entwürfe werden automatisch als Draft gespeichert. Erst 'Absenden' erzeugt einen sichtbaren Eintrag und triggert Events.">i</span>
                    </div>
                </div>

                <textarea id="js-reply-message" class="ks-textarea" name="reply_message" placeholder="Antwort an den Nutzer..."><?php echo e($draftReplyText); ?></textarea>

                <div class="ks-label" style="margin:12px 0 6px 0;">Interne Admin-Notiz (nicht sichtbar für den Nutzer)</div>
                <textarea id="js-internal-note" class="ks-textarea" name="internal_note" placeholder="Interne Notiz..."><?php echo e($draftInternalText); ?></textarea>

                <div class="ks-row" style="justify-content:flex-end; margin:10px 0 0 0;">
                    <div class="ks-row" style="gap:10px;">
                        <button type="submit" class="ks-btn">Absenden</button>
                        <button type="submit" class="ks-btn" formaction="<?php echo e(route('admin.tickets.close', $ticketId)); ?>" formmethod="POST">Ticket schließen</button>
                    </div>
                </div>
            </form>
        </div>

        <h2 style="margin:18px 0 10px 0; font-size:18px;">Audit</h2>
        <div class="ks-card">
            <div class="ks-audit">
                <table>
                    <thead>
                    <tr>
                        <th>Zeit</th>
                        <th>Event</th>
                        <th>Akteur</th>
                        <th>Meta</th>
                    </tr>
                    </thead>
                    <tbody>
                    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(count($auditRows) < 1): ?>
                        <tr><td colspan="4" style="color:#666;">(keine Audit-Logs)</td></tr>
                    <?php else: ?>
                        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $auditRows; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $a): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                            <?php
                                $ts = (string) ($a['created_at'] ?? '');
                                $evLabel = (string) ($a['event_label'] ?? '');
                                $who = (string) ($a['who'] ?? '-');
                                $meta = (string) ($a['meta'] ?? '');
                            ?>
                            <tr>
                                <td><?php echo e($ts); ?></td>
                                <td><?php echo e($evLabel); ?></td>
                                <td><?php echo e($who); ?></td>
                                <td><pre><?php echo e($meta); ?></pre></td>
                            </tr>
                        <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>

        <script>
            (function () {
                function applySelectColor(sel) {
                    if (!sel) return;
                    var kind = sel.getAttribute("data-kind") || "";
                    var val = sel.value || "";
                    var bg = "#ffffff";
                    var bd = "#cbd5e1";

                    if (kind === "priority") {
                        if (val === "") { bg = "#dcfce7"; bd = "#bbf7d0"; }
                        else if (val === "low") { bg = "#ecfccb"; bd = "#d9f99d"; }
                        else if (val === "normal") { bg = "#fef9c3"; bd = "#fde68a"; }
                        else if (val === "high") { bg = "#ffedd5"; bd = "#fed7aa"; }
                        else if (val === "critical") { bg = "#fee2e2"; bd = "#fecaca"; }
                    } else if (kind === "status") {
                        if (val === "open") { bg = "#fef9c3"; bd = "#fde68a"; }
                        else if (val === "in_progress") { bg = "#e0f2fe"; bd = "#bae6fd"; }
                        else if (val === "closed") { bg = "#dcfce7"; bd = "#bbf7d0"; }
                        else if (val === "rejected") { bg = "#f1f5f9"; bd = "#e2e8f0"; }
                        else if (val === "escalated") { bg = "#fee2e2"; bd = "#fecaca"; }
                    } else if (kind === "category") {
                        if (val === "") { bg = "#f1f5f9"; bd = "#e2e8f0"; }
                        else if (val === "support") { bg = "#e0f2fe"; bd = "#bae6fd"; }
                        else if (val === "abuse") { bg = "#fee2e2"; bd = "#fecaca"; }
                        else if (val === "spam") { bg = "#ffedd5"; bd = "#fed7aa"; }
                        else if (val === "billing") { bg = "#ede9fe"; bd = "#ddd6fe"; }
                        else if (val === "bug") { bg = "#ccfbf1"; bd = "#99f6e4"; }
                    }

                    sel.style.backgroundColor = bg;
                    sel.style.borderColor = bd;
                }

                function initColoredSelects() {
                    var sels = document.querySelectorAll(".js-colored-select");
                    for (var i = 0; i < sels.length; i++) {
                        applySelectColor(sels[i]);
                        sels[i].addEventListener("change", function () {
                            applySelectColor(this);
                        });
                    }
                }

                function pad2(n) {
                    n = parseInt(n, 10);
                    if (isNaN(n)) return "00";
                    return (n < 10 ? "0" : "") + String(n);
                }

                function formatTime(tsMs) {
                    try {
                        var d = new Date(tsMs);
                        return pad2(d.getHours()) + ":" + pad2(d.getMinutes());
                    } catch (e) {
                        return "";
                    }
                }

                function classForCategory(val) {
                    if (!val) return "cat-none";
                    if (val === "support") return "cat-support";
                    if (val === "abuse") return "cat-abuse";
                    if (val === "spam") return "cat-spam";
                    if (val === "billing") return "cat-billing";
                    if (val === "bug") return "cat-bug";
                    return "cat-other";
                }

                function classForPriority(val) {
                    if (!val) return "prio-none";
                    if (val === "low") return "prio-low";
                    if (val === "normal") return "prio-normal";
                    if (val === "high") return "prio-high";
                    if (val === "critical") return "prio-critical";
                    return "prio-other";
                }

                function classForStatus(val) {
                    if (val === "open") return "st-open";
                    if (val === "in_progress") return "st-inprogress";
                    if (val === "closed") return "st-closed";
                    if (val === "rejected") return "st-rejected";
                    if (val === "escalated") return "st-escalated";
                    return "st-other";
                }

                function setBadge(el, text, newClass) {
                    if (!el) return;
                    el.textContent = text || "-";
                    var keep = ["ks-badge"];
                    el.className = keep.join(" ") + " " + (newClass || "");
                }

                function initMetaAutosave() {
                    var form = document.getElementById("js-meta-form");
                    var statusEl = document.getElementById("js-meta-status");
                    if (!form || !statusEl) return;

                    var timer = null;
                    var inFlight = false;
                    var queued = false;

                    var selAssigned = document.getElementById("js-assigned-admin-select");
                    var selCat = document.getElementById("js-category-select");
                    var selPrio = document.getElementById("js-priority-select");
                    var selStatus = document.getElementById("js-status-select");

                    var headAssigned = document.getElementById("js-head-assigned");
                    var headCatBadge = document.getElementById("js-head-category-badge");
                    var headPrioBadge = document.getElementById("js-head-priority-badge");
                    var headStatusBadge = document.getElementById("js-status-badge");

                    function setStatus(text) {
                        statusEl.textContent = text || "";
                    }

                    function updateHeaderFromMeta() {
                        try {
                            if (selAssigned && headAssigned) {
                                var aText = "";
                                if (selAssigned.selectedIndex >= 0) {
                                    aText = (selAssigned.options[selAssigned.selectedIndex].text || "").trim();
                                }
                                headAssigned.textContent = aText !== "" ? aText : "-";
                            }

                            if (selCat && headCatBadge) {
                                var cVal = selCat.value || "";
                                var cText = "";
                                if (selCat.selectedIndex >= 0) {
                                    cText = (selCat.options[selCat.selectedIndex].text || "").trim();
                                }
                                setBadge(headCatBadge, cVal !== "" ? cText : "-", classForCategory(cVal));
                            }

                            if (selPrio && headPrioBadge) {
                                var pVal = selPrio.value || "";
                                var pText = "";
                                if (selPrio.selectedIndex >= 0) {
                                    pText = (selPrio.options[selPrio.selectedIndex].text || "").trim();
                                }
                                setBadge(headPrioBadge, pVal !== "" ? pText : "-", classForPriority(pVal));
                            }

                            if (selStatus && headStatusBadge) {
                                var sVal = selStatus.value || "";
                                var sText = "";
                                if (selStatus.selectedIndex >= 0) {
                                    sText = (selStatus.options[selStatus.selectedIndex].text || "").trim();
                                }
                                setBadge(headStatusBadge, sText !== "" ? sText : "-", classForStatus(sVal));
                            }
                        } catch (e) {
                            // ignore
                        }
                    }

                    function doSave() {
                        if (!form) return;

                        if (inFlight) {
                            queued = true;
                            return;
                        }

                        inFlight = true;
                        queued = false;

                        setStatus("speichert…");

                        var fd = new FormData(form);

                        fetch(form.action, {
                            method: "POST",
                            headers: {
                                "Accept": "application/json",
                                "X-Requested-With": "XMLHttpRequest"
                            },
                            body: fd,
                            credentials: "same-origin"
                        }).then(function (res) {
                            if (!res.ok) throw new Error("HTTP " + res.status);
                            return res.json().catch(function () { return { ok: true }; });
                        }).then(function (data) {
                            if (data && data.ok === false) {
                                setStatus("Fehler");
                                return;
                            }
                            setStatus("gespeichert " + formatTime(Date.now()));
                            updateHeaderFromMeta();
                        }).catch(function () {
                            setStatus("Fehler");
                        }).finally(function () {
                            inFlight = false;
                            if (queued) {
                                queued = false;
                                doSave();
                            }
                        });
                    }

                    function scheduleSave() {
                        if (timer) clearTimeout(timer);
                        timer = setTimeout(doSave, 500);
                    }

                    var fields = form.querySelectorAll(".js-meta-field");
                    for (var i = 0; i < fields.length; i++) {
                        fields[i].addEventListener("change", function () {
                            scheduleSave();
                        });
                    }

                    form.addEventListener("submit", function (e) {
                        e.preventDefault();
                        doSave();
                    });

                    updateHeaderFromMeta();
                }

                function initReplyDraftAutosave() {
                    var page = document.getElementById("ks_ticket_page");
                    if (!page) return;

                    var draftSaveUrl = page.getAttribute("data-draft-save-url") || "";

                    var replyForm = document.getElementById("js-reply-form");
                    var replyEl = document.getElementById("js-reply-message");
                    var noteEl = document.getElementById("js-internal-note");
                    var statusEl = document.getElementById("js-draft-status");

                    if (!replyForm || !replyEl || !noteEl || !statusEl) return;

                    var timer = null;
                    var inFlight = false;
                    var queued = false;

                    function setStatus(text) {
                        statusEl.textContent = text || "";
                    }

                    function getCsrfToken() {
                        try {
                            var tokenInput = replyForm.querySelector('input[name="_token"]');
                            return tokenInput ? (tokenInput.value || "") : "";
                        } catch (e) {
                            return "";
                        }
                    }

                    function doSaveDraft() {
                        if (!draftSaveUrl) {
                            setStatus("Draft: kein Server-Endpunkt");
                            return;
                        }

                        if (inFlight) {
                            queued = true;
                            return;
                        }

                        inFlight = true;
                        queued = false;

                        setStatus("Entwurf speichert…");

                        var payload = {
                            reply_message: replyEl.value || "",
                            internal_note: noteEl.value || ""
                        };

                        fetch(draftSaveUrl, {
                            method: "POST",
                            headers: {
                                "Accept": "application/json",
                                "Content-Type": "application/json",
                                "X-Requested-With": "XMLHttpRequest",
                                "X-CSRF-TOKEN": getCsrfToken()
                            },
                            body: JSON.stringify(payload),
                            credentials: "same-origin"
                        }).then(function (res) {
                            if (!res.ok) throw new Error("HTTP " + res.status);
                            return res.json().catch(function () { return { ok: true }; });
                        }).then(function (data) {
                            if (data && data.ok === false) {
                                setStatus("Entwurf: Fehler");
                                return;
                            }

                            if ((payload.reply_message || "") !== "" || (payload.internal_note || "") !== "") {
                                setStatus("Entwurf gespeichert " + formatTime(Date.now()));
                            } else {
                                setStatus("");
                            }
                        }).catch(function () {
                            setStatus("Entwurf: Fehler");
                        }).finally(function () {
                            inFlight = false;
                            if (queued) {
                                queued = false;
                                doSaveDraft();
                            }
                        });
                    }

                    function scheduleSaveDraft() {
                        if (timer) clearTimeout(timer);
                        timer = setTimeout(doSaveDraft, 1000);
                    }

                    replyEl.addEventListener("input", function () {
                        setStatus("Entwurf…");
                        scheduleSaveDraft();
                    });

                    noteEl.addEventListener("input", function () {
                        setStatus("Entwurf…");
                        scheduleSaveDraft();
                    });

                    replyEl.addEventListener("blur", function () { doSaveDraft(); });
                    noteEl.addEventListener("blur", function () { doSaveDraft(); });

                    replyForm.addEventListener("submit", function () {
                        setStatus("");
                    });

                    if (!draftSaveUrl) {
                        setStatus("Draft: kein Server-Endpunkt");
                    } else {
                        setStatus("");
                    }
                }

                if (document.readyState === "loading") {
                    document.addEventListener("DOMContentLoaded", function () {
                        initColoredSelects();
                        initMetaAutosave();
                        initReplyDraftAutosave();
                    });
                } else {
                    initColoredSelects();
                    initMetaAutosave();
                    initReplyDraftAutosave();
                }
            })();
        </script>

    </div>
<?php $__env->stopSection(); ?>

<?php echo $__env->make('admin.layouts.admin', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/tickets/show.blade.php ENDPATH**/ ?>