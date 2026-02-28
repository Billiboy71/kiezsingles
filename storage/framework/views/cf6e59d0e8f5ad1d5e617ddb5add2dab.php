


<?php $__env->startSection('content'); ?>

    <div>

        <h1 class="m-0 mb-2 text-xl font-bold text-gray-900">Admin – Moderation</h1>

        <p class="m-0 mb-4 text-[13px] text-gray-700">
            Rechteverwaltung (Section-Whitelist, DB-basiert, pro User) für <b><?php echo e($roleLabel); ?></b>.
        </p>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($notice)): ?>
            <div class="px-[14px] py-[12px] rounded-[10px] border border-green-200 bg-green-50 mb-4">
                <?php echo e((string) $notice); ?>

            </div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!$hasUsersTable): ?>
            <div class="px-[14px] py-[12px] rounded-[10px] border border-red-200 bg-red-50 mb-4">
                <b>Hinweis:</b> Tabelle <code>users</code> existiert nicht. Auswahl ist nicht möglich.
            </div>
        <?php elseif(count($users) < 1): ?>
            <div class="px-[14px] py-[12px] rounded-[10px] border border-red-200 bg-red-50 mb-4">
                <b>Hinweis:</b> Keine User gefunden (role = <code><?php echo e($targetRole); ?></code>).
            </div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!$hasStaffPermissionsTable): ?>
            <div class="px-[14px] py-[12px] rounded-[10px] border border-red-200 bg-red-50 mb-4">
                <b>Hinweis:</b> Tabelle <code>staff_permissions</code> existiert nicht. Speichern ist nicht möglich.
            </div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

        
        <form id="js-select-form" method="GET" action="<?php echo e(route('admin.moderation')); ?>" class="m-0 mb-4">
            <div class="ks-card">
                <h2 class="m-0 mb-2 text-[16px] font-bold text-gray-900">Rolle &amp; User auswählen</h2>

                <div class="flex gap-[10px] flex-wrap items-center">
                    <label class="flex flex-col gap-[6px] text-[13px] text-gray-600">
                        Rolle
                        <select id="js-role-select" name="role" class="px-[12px] py-[10px] rounded-[10px] border border-slate-300 min-w-[180px] bg-white">
                            <option value="moderator" <?php if($targetRole === 'moderator'): echo 'selected'; endif; ?>>Moderator</option>
                            <option value="admin" <?php if($targetRole === 'admin'): echo 'selected'; endif; ?>>Admin</option>
                        </select>
                    </label>

                    <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($hasUsersTable && count($users) > 0): ?>
                        <label class="flex flex-col gap-[6px] text-[13px] text-gray-600">
                            User
                            <select id="js-user-select" name="user_id" class="px-[12px] py-[10px] rounded-[10px] border border-slate-300 min-w-[320px] bg-white">
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
                        <div class="text-[13px] text-gray-600">Keine Auswahl möglich.</div>
                    <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

                    <div id="js-load-status" class="text-[13px] text-gray-600 ml-auto"></div>
                </div>
            </div>
        </form>

        
        <form id="js-sections-form" method="POST" action="<?php echo e(route('admin.moderation.save')); ?>" class="m-0">
            <?php echo csrf_field(); ?>

            <input type="hidden" name="role" value="<?php echo e($targetRole); ?>">

            <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if($selectedUserId !== null): ?>
                <input type="hidden" name="user_id" value="<?php echo e((string) $selectedUserId); ?>">
            <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>

            <div class="ks-card mb-4">
                <div class="flex gap-[10px] items-end flex-wrap mb-[10px]">
                    <div class="flex-1 min-w-0">
                        <h2 class="m-0 mb-[6px] text-[16px] font-bold text-gray-900"><?php echo e($roleLabel); ?> darf sehen/darf nutzen</h2>
                        <div class="text-[13px] text-gray-600">Diese Sections werden serverseitig erzwungen (Middleware <code>section:*</code>).</div>
                    </div>
                    <div id="js-save-status" class="text-[13px] text-gray-600 min-w-[180px] text-right"></div>
                </div>

                <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php $__currentLoopData = $options; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $key => $label): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                    <?php
                        $checked = in_array((string) $key, (array) $current, true);
                        $disabled = (!$hasStaffPermissionsTable || $selectedUserId === null);
                    ?>

                    <label class="flex items-center gap-[10px] px-[12px] py-[10px] border border-gray-200 rounded-[10px] mb-[10px]">
                        <input class="js-section-box" type="checkbox" name="sections[]" value="<?php echo e((string) $key); ?>" <?php if($checked): echo 'checked'; endif; ?> <?php if($disabled): echo 'disabled'; endif; ?>>
                        <div>
                            <b><?php echo e((string) $label); ?></b>
                            <div class="text-[12px] text-gray-500"><?php echo e((string) $key); ?></div>
                        </div>
                    </label>
                <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
            </div>

            <div class="flex gap-[10px] flex-wrap">
                <a href="<?php echo e(url('/admin')); ?>" class="ks-btn no-underline text-gray-900">
                    Zur Übersicht
                </a>

                <noscript>
                    <button
                        type="submit"
                        class="px-[12px] py-[10px] rounded-[10px] border border-gray-900 bg-gray-900 text-white cursor-pointer disabled:opacity-45 disabled:cursor-not-allowed"
                        <?php if(!$hasStaffPermissionsTable || $selectedUserId === null): echo 'disabled'; endif; ?>
                    >
                        Speichern
                    </button>
                </noscript>
            </div>
        </form>

    </div>

<?php $__env->stopSection(); ?>

<?php echo $__env->make('admin.layouts.admin', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/moderation.blade.php ENDPATH**/ ?>