


<?php $__env->startSection('content'); ?>

    <div class="ks-card mb-4">
        <div class="text-sm font-extrabold text-gray-900 mb-4">Schalter</div>

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>LOCAL Debug Banner anzeigen</strong>
                    <span class="ks-info" title="Blendet das gelbe LOCAL DEBUG Banner im Admin-Layout ein/aus (nur LOCAL).">i</span>
                </div>
                <div class="ks-sub"><code>debug.local_banner_enabled</code></div>
            </div>

            <form method="POST" action="<?php echo e(url('/admin/debug/toggle')); ?>" class="m-0 flex-shrink-0" data-ks-toggle-form="1">
                <?php echo csrf_field(); ?>
                <input type="hidden" name="key" value="debug.local_banner_enabled">
                <input type="hidden" name="value" value="<?php echo e($debugLocalBannerEnabled ? '1' : '0'); ?>">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        data-ks-toggle="1"
                        <?php if($debugLocalBannerEnabled): echo 'checked'; endif; ?>
                    >
                    <span class="ks-slider"></span>
                </label>
                <noscript>
                    <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900">Speichern</button>
                </noscript>
            </form>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>Debug UI (Master)</strong>
                    <span class="ks-info" title="Master-Schalter für Debug-Funktionen.">i</span>
                </div>
                <div class="ks-sub"><code>debug.ui_enabled</code></div>
            </div>

            <form method="POST" action="<?php echo e(url('/admin/debug/toggle')); ?>" class="m-0 flex-shrink-0" data-ks-toggle-form="1">
                <?php echo csrf_field(); ?>
                <input type="hidden" name="key" value="debug.ui_enabled">
                <input type="hidden" name="value" value="<?php echo e($debugUiEnabled ? '1' : '0'); ?>">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        data-ks-toggle="1"
                        <?php if($debugUiEnabled): echo 'checked'; endif; ?>
                    >
                    <span class="ks-slider"></span>
                </label>
                <noscript>
                    <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900">Speichern</button>
                </noscript>
            </form>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>Debug Routes</strong>
                    <span class="ks-info" title="Aktiviert zusätzliche Debug-Routen.">i</span>
                </div>
                <div class="ks-sub"><code>debug.routes_enabled</code></div>
            </div>

            <form method="POST" action="<?php echo e(url('/admin/debug/toggle')); ?>" class="m-0 flex-shrink-0" data-ks-toggle-form="1">
                <?php echo csrf_field(); ?>
                <input type="hidden" name="key" value="debug.routes_enabled">
                <input type="hidden" name="value" value="<?php echo e($getBool('debug.routes_enabled', false) ? '1' : '0'); ?>">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        data-ks-toggle="1"
                        <?php if((bool) $getBool('debug.routes_enabled', false)): echo 'checked'; endif; ?>
                    >
                    <span class="ks-slider"></span>
                </label>
                <noscript>
                    <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900">Speichern</button>
                </noscript>
            </form>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>Turnstile Debug</strong>
                    <span class="ks-info" title="Aktiviert Debug-Modus für Turnstile (Diagnose/Tests je nach Implementierung).">i</span>
                </div>
                <div class="ks-sub"><code>debug.turnstile_enabled</code></div>
            </div>

            <form method="POST" action="<?php echo e(url('/admin/debug/toggle')); ?>" class="m-0 flex-shrink-0" data-ks-toggle-form="1">
                <?php echo csrf_field(); ?>
                <input type="hidden" name="key" value="debug.turnstile_enabled">
                <input type="hidden" name="value" value="<?php echo e($debugTurnstile ? '1' : '0'); ?>">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        data-ks-toggle="1"
                        <?php if($debugTurnstile): echo 'checked'; endif; ?>
                    >
                    <span class="ks-slider"></span>
                </label>
                <noscript>
                    <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900">Speichern</button>
                </noscript>
            </form>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>Register: Validation Errors loggen</strong>
                    <span class="ks-info" title="Wenn aktiv: Registrierungs-Validierungsfehler werden protokolliert.">i</span>
                </div>
                <div class="ks-sub"><code>debug.register_errors</code></div>
            </div>

            <form method="POST" action="<?php echo e(url('/admin/debug/toggle')); ?>" class="m-0 flex-shrink-0" data-ks-toggle-form="1">
                <?php echo csrf_field(); ?>
                <input type="hidden" name="key" value="debug.register_errors">
                <input type="hidden" name="value" value="<?php echo e($debugRegisterErrors ? '1' : '0'); ?>">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        data-ks-toggle="1"
                        <?php if($debugRegisterErrors): echo 'checked'; endif; ?>
                    >
                    <span class="ks-slider"></span>
                </label>
                <noscript>
                    <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900">Speichern</button>
                </noscript>
            </form>
        </div>

        <hr class="border-0 border-t border-gray-200 my-[14px]">

        <div class="ks-row">
            <div class="ks-label">
                <div>
                    <strong>Register: Payload in Session flashen</strong>
                    <span class="ks-info" title="Wenn aktiv: Registrierungs-Payload wird in die Session geflasht (nur Debugging).">i</span>
                </div>
                <div class="ks-sub"><code>debug.register_payload</code></div>
            </div>

            <form method="POST" action="<?php echo e(url('/admin/debug/toggle')); ?>" class="m-0 flex-shrink-0" data-ks-toggle-form="1">
                <?php echo csrf_field(); ?>
                <input type="hidden" name="key" value="debug.register_payload">
                <input type="hidden" name="value" value="<?php echo e($debugRegisterPayload ? '1' : '0'); ?>">
                <label class="ks-toggle">
                    <input
                        type="checkbox"
                        data-ks-toggle="1"
                        <?php if($debugRegisterPayload): echo 'checked'; endif; ?>
                    >
                    <span class="ks-slider"></span>
                </label>
                <noscript>
                    <button type="submit" class="ml-2 px-3 py-1 rounded-lg border border-gray-300 bg-white text-xs font-semibold text-gray-900">Speichern</button>
                </noscript>
            </form>
        </div>
    </div>

    <div class="ks-card">
        <div class="text-sm font-extrabold text-gray-900 mb-3">Logs</div>

        <form method="POST" action="<?php echo e(url('/admin/debug/log-tail')); ?>" class="m-0 mb-3">
            <?php echo csrf_field(); ?>
            <button type="submit" class="inline-flex items-center px-4 py-2 rounded-xl border border-gray-300 bg-white text-xs font-extrabold text-gray-900 uppercase tracking-widest hover:bg-gray-50">
                Letzte Logzeilen laden
            </button>
        </form>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($logLines)): ?>
            <pre class="whitespace-pre-wrap bg-gray-900 text-gray-100 px-4 py-3 rounded-xl border border-gray-800 overflow-auto max-h-[420px] m-0"><?php echo e(implode("\n", array_map(fn($l) => (string) $l, $logLines))); ?></pre>
        <?php else: ?>
            <div class="text-sm text-gray-600">(noch keine Logausgabe geladen)</div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
    </div>

<?php $__env->stopSection(); ?>

<?php echo $__env->make('admin.layouts.admin', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/debug.blade.php ENDPATH**/ ?>