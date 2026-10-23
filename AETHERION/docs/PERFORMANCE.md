# Presupuestos provisionales

GAMEPLAY usa rocas de 3 anillos de vértices, arcos de 36 segmentos por vuelta, bisel de un segmento, telas 6x12 y 8 fragmentos. CINEMATIC usa 5, 64, 2, 12x24 y 18 respectivamente. Comparten anatomía y nombres de articulación.

El informe en Blender calcula triángulos evaluados incluyendo modificadores. No se publican conteos inventados sin ejecutar bpy. Umbrales de aviso: 65.000 triángulos o 350 mallas para GAMEPLAY. Son presupuestos de autoría, no garantías de rendimiento móvil.

Los objetos permanecen separados para edición. La etapa 6 deberá combinar por articulación y material, hornear atlas, reducir draw calls y limitar luces locales. La variante GAMEPLAY es de menor detalle, aún no un asset validado para producción. No hay simulación física de rocas ni cientos de luces. Los efectos de presentación actuales se limitan a tres luces de área y materiales emisivos.
