





<?php if (isset($component)) { $__componentOriginal69dc84650370d1d4dc1b42d016d7226b = $component; } ?>
<?php if (isset($attributes)) { $__attributesOriginal69dc84650370d1d4dc1b42d016d7226b = $attributes; } ?>
<?php $component = App\View\Components\GuestLayout::resolve([] + (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag ? $attributes->all() : [])); ?>
<?php $component->withName('guest-layout'); ?>
<?php if ($component->shouldRender()): ?>
<?php $__env->startComponent($component->resolveView(), $component->data()); ?>
<?php if (isset($attributes) && $attributes instanceof Illuminate\View\ComponentAttributeBag): ?>
<?php $attributes = $attributes->except(\App\View\Components\GuestLayout::ignoredParameterNames()); ?>
<?php endif; ?>
<?php $component->withAttributes([]); ?>
    <div class="max-w-2xl mx-auto">
        <h1 class="text-2xl font-semibold text-gray-900">Impressum</h1>

        <div class="mt-6 space-y-4 text-sm text-gray-700 leading-relaxed">
            <p>
                <strong>Platzhalter:</strong> Diese Seite ist noch nicht final befüllt.
                (Hier später die gesetzlich erforderlichen Angaben eintragen.)
            </p>

            <p class="text-gray-600">
                Hinweis: Bis zur finalen Veröffentlichung bitte die Inhalte vollständig ergänzen
                (Anbieter, Kontakt, Vertretung, ggf. USt-ID, Verantwortliche/r i.S.d. § 18 MStV, etc.).
            </p>
        </div>

        <div class="mt-8 flex gap-4 text-sm">
            <a href="<?php echo e(route('home')); ?>" class="underline text-gray-700 hover:text-gray-900">
                Zur Startseite
            </a>
            <a href="<?php echo e(route('contact.create')); ?>" class="underline text-gray-700 hover:text-gray-900">
                Kontakt
            </a>
        </div>
    </div>
 <?php echo $__env->renderComponent(); ?>
<?php endif; ?>
<?php if (isset($__attributesOriginal69dc84650370d1d4dc1b42d016d7226b)): ?>
<?php $attributes = $__attributesOriginal69dc84650370d1d4dc1b42d016d7226b; ?>
<?php unset($__attributesOriginal69dc84650370d1d4dc1b42d016d7226b); ?>
<?php endif; ?>
<?php if (isset($__componentOriginal69dc84650370d1d4dc1b42d016d7226b)): ?>
<?php $component = $__componentOriginal69dc84650370d1d4dc1b42d016d7226b; ?>
<?php unset($__componentOriginal69dc84650370d1d4dc1b42d016d7226b); ?>
<?php endif; ?>
<?php /**PATH C:\laragon\www\kiezsingles\resources\views\impressum.blade.php ENDPATH**/ ?>