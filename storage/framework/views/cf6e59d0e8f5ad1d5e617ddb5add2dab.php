



<?php $__env->startSection('content'); ?>

    <div style="padding:0; margin:0;">

        <h1 style="margin:0 0 8px 0;">Admin – Moderation</h1>

        <p style="margin:0 0 16px 0; color:#444;">
            Rechteverwaltung (Section-Whitelist, DB-basiert, pro User) für <b><?php echo e($roleLabel); ?></b>.
        </p>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($notice)): ?>
            <div style="padding:12px 14px; border-radius:10px; border:1px solid #bbf7d0; background:#f0fff4; margin:0 0 16px 0;">
                <?php echo e((string) $notice); ?>

            </div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!$hasUsersTable): ?>
            <div style="padding:12px 14px; border-radius:10px; border:1px solid #fecaca; background:#fff5f5; margin:0 0 16px 0;">
                <b>Hinweis:</b> Tabelle <code>users</code> existiert nicht. Auswahl ist nicht möglich.
            </div>
        <?php elseif(count($users) < 1): ?>
            <div style="padding:12px 14px; border-radius:10px; border:1px solid #fecaca; background:#fff5f5; margin:0 0 16px 0;">
                <b>Hinweis:</b> Keine User gefunden (role = <code><?php echo e($targetRole); ?></code>).
            </div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!$hasSystemSettingsTable): ?>
            <div style="padding:12px 14px; border-radius:10px; border:1px solid #fecaca; background:#fff5f5; margin:0 0 16px 0;">
                <b>Hinweis:</b> Tabelle <code>system_settings</code> existiert nicht. Speichern ist nicht möglich.
            </div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        
        <form id="js-select-form" method="GET" action="<?php echo e(route('admin.moderation')); ?>" style="margin:0 0 16px 0;">
            <div style="border:1px solid #e5e7eb; border-radius:12px; padding:14px 14px; background:#fff;">
                <h2 style="margin:0 0 8px 0; font-size:16px;">Rolle &amp; User auswählen</h2>

                <div style="display:flex; gap:10px; flex-wrap:wrap; align-items:center;">
                    <label style="display:flex; flex-direction:column; gap:6px; font-size:13px; color:#555;">
                        Rolle
                        <select id="js-role-select" name="role" style="padding:10px 12px; border-radius:10px; border:1px solid #cbd5e1; min-width:180px;">
                            <option value="moderator" <?php if($targetRole === 'moderator'): echo 'selected'; endif; ?>>Moderator</option>
                            <option value="admin" <?php if($targetRole === 'admin'): echo 'selected'; endif; ?>>Admin</option>
                        </select>
                    </label>

                    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($hasUsersTable && count($users) > 0): ?>
                        <label style="display:flex; flex-direction:column; gap:6px; font-size:13px; color:#555;">
                            User
                            <select id="js-user-select" name="user_id" style="padding:10px 12px; border-radius:10px; border:1px solid #cbd5e1; min-width:320px;">
                                <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $users; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $u): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                                    <?php
                                        $uid = (int) ($u->id ?? 0);

                                        $label = '';
                                        if (!empty($hasUserNameColumn)) {
                                            $label = trim((string) ($u->name ?? ''));
                                        }
                                        if ($label === '' && !empty($hasUserUsernameColumn)) {
                                            $label = trim((string) ($u->username ?? ''));
                                        }
                                        if ($label === '') {
                                            $label = (string) ($u->email ?? ('User #' . $uid));
                                        }
                                    ?>

                                    <option value="<?php echo e((string) $uid); ?>" <?php if($selectedUserId !== null && (int) $selectedUserId === $uid): echo 'selected'; endif; ?>>
                                        <?php echo e($label); ?> (ID <?php echo e((string) $uid); ?>)
                                    </option>
                                <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
                            </select>
                        </label>
                    <?php else: ?>
                        <div style="color:#666; font-size:13px;">Keine Auswahl möglich.</div>
                    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

                    <div id="js-load-status" style="color:#666; font-size:13px; margin-left:auto;"></div>
                </div>
            </div>
        </form>

        
        <form id="js-sections-form" method="POST" action="<?php echo e(route('admin.moderation.save')); ?>" style="margin:0;">
            <?php echo csrf_field(); ?>

            <input type="hidden" name="role" value="<?php echo e($targetRole); ?>">

            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($selectedUserId !== null): ?>
                <input type="hidden" name="user_id" value="<?php echo e((string) $selectedUserId); ?>">
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

            <div style="border:1px solid #e5e7eb; border-radius:12px; padding:14px 14px; background:#fff; margin:0 0 16px 0;">
                <div style="display:flex; gap:10px; align-items:flex-end; flex-wrap:wrap; margin:0 0 10px 0;">
                    <div style="flex:1 1 auto;">
                        <h2 style="margin:0 0 6px 0; font-size:16px;"><?php echo e($roleLabel); ?> darf sehen/darf nutzen</h2>
                        <div style="color:#555; font-size:13px;">Diese Sections werden serverseitig erzwungen (Middleware <code>section:*</code>).</div>
                    </div>
                    <div id="js-save-status" style="color:#666; font-size:13px; min-width:180px; text-align:right;"></div>
                </div>

                <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $options; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $key => $label): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                    <?php
                        $checked = in_array((string) $key, (array) $current, true);
                        $disabled = (!$hasSystemSettingsTable || $selectedUserId === null);
                    ?>

                    <label style="display:flex; align-items:center; gap:10px; padding:10px 12px; border:1px solid #e5e7eb; border-radius:10px; margin:0 0 10px 0;">
                        <input class="js-section-box" type="checkbox" name="sections[]" value="<?php echo e((string) $key); ?>" <?php if($checked): echo 'checked'; endif; ?> <?php if($disabled): echo 'disabled'; endif; ?>>
                        <div>
                            <b><?php echo e((string) $label); ?></b>
                            <div style="color:#666; font-size:12px;"><?php echo e((string) $key); ?></div>
                        </div>
                    </label>
                <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
            </div>

            <div style="display:flex; gap:10px; flex-wrap:wrap;">
                <a href="<?php echo e(url('/admin')); ?>" style="padding:10px 12px; border-radius:10px; border:1px solid #cbd5e1; background:#fff; text-decoration:none; color:#111;">
                    Zur Übersicht
                </a>

                <button
                    type="submit"
                    style="padding:10px 12px; border-radius:10px; border:1px solid #111827; background:#111827; color:#fff; cursor:pointer;"
                    <?php if(!$hasSystemSettingsTable || $selectedUserId === null): echo 'disabled'; endif; ?>
                >
                    Speichern
                </button>
            </div>
        </form>

        <script>
            (function () {
                var f = document.getElementById('js-select-form');
                var rs = document.getElementById('js-role-select');
                var us = document.getElementById('js-user-select');
                var ls = document.getElementById('js-load-status');

                function submitSelect() {
                    if (!f) return;
                    if (ls) ls.textContent = 'lädt…';
                    try { f.submit(); } catch (e) {}
                }

                if (rs) { rs.addEventListener('change', function () { submitSelect(); }); }
                if (us) { us.addEventListener('change', function () { submitSelect(); }); }

                var sf = document.getElementById('js-sections-form');
                var ss = document.getElementById('js-save-status');
                var t = null;

                function scheduleSave() {
                    if (!sf) return;
                    if (t) clearTimeout(t);
                    if (ss) ss.textContent = 'speichert…';
                    t = setTimeout(function () {
                        try { sf.submit(); } catch (e) {}
                    }, 600);
                }

                if (sf) {
                    var boxes = sf.querySelectorAll('.js-section-box');
                    for (var i = 0; i < boxes.length; i++) {
                        boxes[i].addEventListener('change', function () { scheduleSave(); });
                    }
                }
            })();
        </script>

    </div>

<?php $__env->stopSection(); ?>

<?php echo $__env->make('admin.layouts.admin', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/moderation.blade.php ENDPATH**/ ?>