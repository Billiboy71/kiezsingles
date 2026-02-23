

<footer class="bg-white border-t border-gray-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 text-xs text-gray-500">
        <?php if (! empty(trim($__env->yieldContent('adminFooter')))): ?>
            <?php echo $__env->yieldContent('adminFooter'); ?>
        <?php else: ?>
            <div>Admin-Bereich</div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
    </div>
</footer>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views/admin/layouts/footer.blade.php ENDPATH**/ ?>