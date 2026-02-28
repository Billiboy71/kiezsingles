

<footer class="bg-white border-t border-gray-200">
    <div class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8 text-sm text-gray-600">
        <?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if BLOCK]><![endif]--><?php endif; ?><?php if(!empty($footer)): ?>
            <?php echo e($footer); ?>

        <?php else: ?>
            <div>Footer (Platzhalter)</div>
        <?php endif; ?><?php if(\Livewire\Mechanisms\ExtendBlade\ExtendBlade::isRenderingLivewireComponent()): ?><!--[if ENDBLOCK]><![endif]--><?php endif; ?>
    </div>
</footer>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views\layouts\footer.blade.php ENDPATH**/ ?>