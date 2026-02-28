


<?php
    $adminTab = 'develop';
    $hasSystemSettingsTable = $hasSystemSettingsTable ?? true;

    $maintenanceEnabled = (bool) ($maintenanceEnabled ?? false);

    $layoutOutlinesFrontendEnabled = (bool) ($layoutOutlinesFrontendEnabled ?? false);
    $layoutOutlinesAdminEnabled = (bool) ($layoutOutlinesAdminEnabled ?? false);
    $layoutOutlinesAllowProduction = (bool) ($layoutOutlinesAllowProduction ?? false);
?>

<?php $__env->startSection('content'); ?>
    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($notice)): ?>
        <div class="ks-notice p-3 rounded-lg border mb-3">
            <?php echo e($notice); ?>

        </div>
    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!$maintenanceEnabled): ?>
        <div class="ks-notice p-3 rounded-lg border mb-3">
            Wartung ist aus - Änderungen wirken ggf. nur lokal / allow_production Regeln beachten.
        </div>
    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

    <div class="ks-card">
        <h3>Develop</h3>
        <p class="mb-3">Layout Outlines (Debug-Rahmen).</p>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!$hasSystemSettingsTable): ?>
            <p class="m-0 text-sm text-red-700 mb-3">
                Hinweis: Tabelle <code>debug_settings</code> fehlt. Speichern nicht möglich.
            </p>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <div class="space-y-3">
            <div class="ks-row">
                <div class="ks-label">
                    <div>
                        <strong>Frontend-Rahmen</strong> <span class="text-gray-600">(<code>debug.layout_outlines_frontend_enabled</code>)</span>
                    </div>
                    <div class="ks-sub">Nur visuell, ohne Funktionsänderung.</div>
                </div>

                <form method="POST" action="<?php echo e(route('admin.settings.layout_outlines')); ?>" class="m-0">
                    <?php echo csrf_field(); ?>
                    <input type="hidden" name="layout_outlines_frontend_enabled" value="0">
                    <label class="ks-toggle ml-auto">
                        <input
                            type="checkbox"
                            name="layout_outlines_frontend_enabled"
                            value="1"
                            <?php if($layoutOutlinesFrontendEnabled): echo 'checked'; endif; ?>
                            <?php if(!$hasSystemSettingsTable): echo 'disabled'; endif; ?>
                            onchange="this.form.submit()"
                        >
                        <span class="ks-slider"></span>
                    </label>
                    <noscript>
                        <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900" <?php if(!$hasSystemSettingsTable): echo 'disabled'; endif; ?>>Speichern</button>
                    </noscript>
                </form>
            </div>

            <div class="ks-row">
                <div class="ks-label">
                    <div>
                        <strong>Admin-Rahmen</strong> <span class="text-gray-600">(<code>debug.layout_outlines_admin_enabled</code>)</span>
                    </div>
                    <div class="ks-sub">Nur visuell, ohne Funktionsänderung.</div>
                </div>

                <form method="POST" action="<?php echo e(route('admin.settings.layout_outlines')); ?>" class="m-0">
                    <?php echo csrf_field(); ?>
                    <input type="hidden" name="layout_outlines_admin_enabled" value="0">
                    <label class="ks-toggle ml-auto">
                        <input
                            type="checkbox"
                            name="layout_outlines_admin_enabled"
                            value="1"
                            <?php if($layoutOutlinesAdminEnabled): echo 'checked'; endif; ?>
                            <?php if(!$hasSystemSettingsTable): echo 'disabled'; endif; ?>
                            onchange="this.form.submit()"
                        >
                        <span class="ks-slider"></span>
                    </label>
                    <noscript>
                        <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900" <?php if(!$hasSystemSettingsTable): echo 'disabled'; endif; ?>>Speichern</button>
                    </noscript>
                </form>
            </div>

            <div class="ks-row">
                <div class="ks-label">
                    <div>
                        <strong>Production erlauben</strong> <span class="text-gray-600">(<code>debug.layout_outlines_allow_production</code>)</span>
                    </div>
                    <div class="ks-sub">Standard: aus (fail-closed). Nur schaltbar im Wartungsmodus.</div>
                </div>

                <form method="POST" action="<?php echo e(route('admin.settings.layout_outlines')); ?>" class="m-0">
                    <?php echo csrf_field(); ?>
                    <input type="hidden" name="layout_outlines_allow_production" value="0">
                    <label class="ks-toggle ml-auto">
                        <input
                            type="checkbox"
                            name="layout_outlines_allow_production"
                            value="1"
                            <?php if($layoutOutlinesAllowProduction): echo 'checked'; endif; ?>
                            <?php if(!$hasSystemSettingsTable || !$maintenanceEnabled): echo 'disabled'; endif; ?>
                            onchange="this.form.submit()"
                        >
                        <span class="ks-slider"></span>
                    </label>
                    <noscript>
                        <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900" <?php if(!$hasSystemSettingsTable || !$maintenanceEnabled): echo 'disabled'; endif; ?>>Speichern</button>
                    </noscript>
                </form>
            </div>
        </div>
    </div>
<?php $__env->stopSection(); ?>

<?php echo $__env->make('admin.layouts.admin', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/develop.blade.php ENDPATH**/ ?>