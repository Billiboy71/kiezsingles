<?php
// ============================================================================
// File: C:\laragon\www\kiezsingles\resources\views\emails\layout.blade.php
// Purpose: Zentrales Layout für alle System-E-Mails
// Changed: 10-02-2026 22:26
// Version: 0.1
// ============================================================================
?>
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?php echo e($subject ?? config('app.name')); ?></title>
</head>
<body style="margin:0; padding:0; background:#f6f7f9;">
    <table width="100%" cellpadding="0" cellspacing="0" role="presentation">
        <tr>
            <td align="center" style="padding:30px 12px;">
                <table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px; background:#ffffff; border:1px solid #e5e7eb;">
                    <tr>
                        <td style="padding:20px 24px; font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
                            <h1 style="margin:0 0 12px 0; font-size:20px;">
                                <?php echo e($appName ?? config('app.name')); ?>

                            </h1>

                            <?php echo $__env->yieldContent('content'); ?>

                            <hr style="margin:24px 0; border:0; border-top:1px solid #e5e7eb;">

                            <p style="margin:0; font-size:12px; color:#555;">
                                Diese E-Mail wurde automatisch versendet.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views\emails\layout.blade.php ENDPATH**/ ?>