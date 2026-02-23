<!-- =========================================================================
File: C:\laragon\www\kiezsingles\resources\views\admin\tickets\index.blade.php
Purpose: Admin – Tickets Index (Blade)
Changed: 23-02-2026 20:48 (Europe/Berlin)
Version: 1.0
============================================================================= -->



<?php
    $type = (string) ($type ?? '');
    $status = (string) ($status ?? '');
    $ticketRows = $ticketRows ?? [];

    // Global Header (layouts/navigation.blade.php) – Admin Tabs + Badges
    $adminTab = $adminTab ?? 'tickets';
    $adminShowDebugTab = $adminShowDebugTab ?? (isset($maintenanceEnabled) ? (bool) $maintenanceEnabled : false);
?>

<?php $__env->startSection('content'); ?>
    <div class="ks-admin-tickets-index ks-wrap">
        <div class="ks-top">
            <h1 class="ks-h1">Admin – Tickets</h1>
        </div>

        <form method="GET" action="<?php echo e(route('admin.tickets.index')); ?>" class="ks-row" style="margin:0 0 14px 0;">
            <label class="ks-muted">Typ</label>
            <select class="ks-input" name="type">
                <option value="" <?php if($type === ''): echo 'selected'; endif; ?>>Alle</option>
                <option value="report" <?php if($type === 'report'): echo 'selected'; endif; ?>>Meldung</option>
                <option value="support" <?php if($type === 'support'): echo 'selected'; endif; ?>>Support</option>
            </select>

            <label class="ks-muted">Status</label>
            <select class="ks-input" name="status">
                <option value="" <?php if($status === ''): echo 'selected'; endif; ?>>Alle</option>
                <option value="open" <?php if($status === 'open'): echo 'selected'; endif; ?>>Offen</option>
                <option value="in_progress" <?php if($status === 'in_progress'): echo 'selected'; endif; ?>>In Bearbeitung</option>
                <option value="closed" <?php if($status === 'closed'): echo 'selected'; endif; ?>>Geschlossen</option>
                <option value="rejected" <?php if($status === 'rejected'): echo 'selected'; endif; ?>>Abgelehnt</option>
                <option value="escalated" <?php if($status === 'escalated'): echo 'selected'; endif; ?>>Eskaliert</option>
            </select>

            <button type="submit" class="ks-btn">Filtern</button>
        </form>

        <table>
            <thead>
            <tr>
                <th>ID</th>
                <th>Typ</th>
                <th>Kategorie</th>
                <th>Priorität</th>
                <th>Status</th>
                <th>Betreff</th>
                <th>Ersteller</th>
                <th>Gemeldet</th>
                <th>Erstellt</th>
            </tr>
            </thead>
            <tbody>
            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(count($ticketRows) < 1): ?>
                <tr><td colspan="9" style="color:#666;">(keine Tickets)</td></tr>
            <?php else: ?>
                <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $ticketRows; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $r): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                    <?php
                        $id = (int) ($r['id'] ?? 0);
                        $subjectText = (string) ($r['subject'] ?? '');
                        $rowHref = route('admin.tickets.show', $id);
                    ?>
                    <tr data-href="<?php echo e($rowHref); ?>">
                        <td><a href="<?php echo e($rowHref); ?>"><?php echo e($id); ?></a></td>
                        <td><?php echo e((string) ($r['type_label'] ?? '')); ?></td>
                        <td><span class="ks-badge <?php echo e((string) ($r['category_class'] ?? '')); ?>"><?php echo e(((string) ($r['category_raw'] ?? '')) !== '' ? (string) ($r['category_label'] ?? '') : '-'); ?></span></td>
                        <td><span class="ks-badge <?php echo e((string) ($r['priority_class'] ?? '')); ?>"><?php echo e(((string) ($r['priority_label'] ?? '')) !== '' ? (string) ($r['priority_label'] ?? '') : '-'); ?></span></td>
                        <td><span class="ks-badge <?php echo e((string) ($r['status_class'] ?? '')); ?>"><?php echo e((string) ($r['status_label'] ?? '')); ?></span></td>
                        <td>
                            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($subjectText !== ''): ?>
                                <?php echo e($subjectText); ?>

                            <?php else: ?>
                                <span style="color:#666;">(ohne)</span>
                            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                        </td>
                        <td><?php echo e((string) ($r['creator_display'] ?? '-')); ?></td>
                        <td><?php echo e((string) ($r['reported_display'] ?? '-')); ?></td>
                        <td><?php echo e((string) ($r['created_at'] ?? '')); ?></td>
                    </tr>
                <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
            </tbody>
        </table>
    </div>
<?php $__env->stopSection(); ?>
<?php echo $__env->make('admin.layouts.admin', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/tickets/index.blade.php ENDPATH**/ ?>