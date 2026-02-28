<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\emails\maintenance-ended.blade.php
// Purpose: Inhalt der E-Mail „Wartungsmodus beendet“
// Changed: 10-02-2026 22:31
// Version: 0.1
// ============================================================================
?>


<?php $__env->startSection('content'); ?>
    <h2 style="margin:0 0 12px 0; font-size:18px;">
        <?php echo e(__('mail.maintenance_ended.headline')); ?>

    </h2>

    <p style="margin:0 0 16px 0; font-size:14px; line-height:1.5;">
        <?php echo e(__('mail.maintenance_ended.text', ['app' => $appName])); ?>

    </p>

    <p style="margin:0 0 20px 0;">
        <a href="<?php echo e($loginUrl); ?>"
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
            <?php echo e(__('mail.maintenance_ended.cta')); ?>

        </a>
    </p>
<?php $__env->stopSection(); ?>

<?php echo $__env->make('emails.layout', array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?><?php /**PATH C:\laragon\www\kiezsingles\resources\views\emails\maintenance-ended.blade.php ENDPATH**/ ?>