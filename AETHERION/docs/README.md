# Aetherion — etapa 1

Generador procedural de un guardián de piedra celestial inspirado en la referencia entregada. Entrada: `../blender/Build_Aetherion.py`. No necesita paquetes de terceros. Los módulos deben permanecer juntos.

## Entrega actual

- Anatomía propia: casco, cavidades oculares, corona, pecho segmentado, protección dorsal, brazos, dedos, piernas y pies.
- Núcleo facetado independiente con engarces, dos placas pectorales con pivotes de apertura.
- Tres halos independientes, fragmentos suspendidos y faldones curvos con espesor.
- Materiales iniciales de piedra, oro, tela y energía; cámara y tres luces.
- Variantes GAMEPLAY y CINEMATIC, deterministas, con la misma estructura de articulación.
- Pivotes y pesos preliminares de tela. **No hay armature ni animaciones aún.**

No se entregan archivos .blend, FBX, renders ni una integración de combate terminada. El código está preparado para ejecutarse en Blender; su apariencia y compatibilidad exacta con Blender 5.2.2 requieren probarlo allí. No se ha ejecutado Blender durante esta entrega.

## Lectura de la referencia

1. Cabeza: máscara estrecha oscura, ojos hundidos y corona axial. El casco ocupa aproximadamente 5 unidades; sus puntas culminan a Z=38.
2. Armadura: masas pétreas grandes separadas por juntas, no un cuerpo R15 escalado. Hombros abovedados como dovelas de un templo.
3. Oro: cornisas, bordes, engarces y cinturón. Evitar que cubra toda la piedra.
4. Runas: símbolos cian sobre placas talladas; se distinguen de las fracturas estructurales entre rocas.
5. Pecho: cristal tridimensional dentro de un alojamiento circular profundo. Dos placas pueden abrirse en una etapa posterior.
6. Brazos: antebrazos largos y manos desproporcionadas; cuatro dedos y pulgar por mano, con pivotes individuales.
7. Fragmentos: pocos elementos grandes y medianos separados, sin simular física.
8. Halos: tres estructuras doradas a distintas profundidades detrás de cabeza y torso; no atraviesan el casco.
9. Telas: tres faldones marfil, curvos, con caída irregular, bordes dorados y espesor real.
10. Piernas: bases anchas, rodillas de oro, grebas rúnicas, pies pétreos segmentados apoyados en Z=0.
11. Paleta: gris carbón, gris frío, oro envejecido, cian y marfil. Sin rojo ni estética demoníaca.
12. Silueta: hombros amplios, cintura más estrecha, puños bajos y halo vertical. La pose neutra facilita el futuro rig; no reproduce el escorzo extremo de la imagen.
13. Energía: cristales en huecos articulares y núcleo. La niebla, los rayos y los efectos de ataque son etapas futuras.

La espalda inferida lleva costillas de piedra y una columna ornamental dorada; el halo se mantiene separado del volumen dorsal. Las superficies laterales conservan el mismo ritmo de piedra oscura y bordes claros. La referencia es una ilustración: esta reconstrucción es una interpretación procedural, cuya fidelidad debe revisarse en Blender.

## Arquitectura estable

`geometry.py`: generadores matemáticos puros y comprobaciones de índices.

`01_Aetherion_Model.py`: geometría y jerarquía. Cada visual lleva `joint_id`; cada pivote conserva su identificador entre variantes.

`02_Aetherion_Materials.py`: nodos iniciales. No texturas horneadas todavía.

`Build_Aetherion.py`: carga relativa de módulos, construcción temporal, validación y reemplazo de la versión anterior solamente tras éxito.

Las siguientes etapas añadirán `03_Aetherion_Rig.py`, `04_Aetherion_Animations.py`, `05_Aetherion_VFX.py` y `06_Aetherion_Export.py`, sobre estos mismos pivotes. No se incluyen módulos vacíos que aparenten implementar esas funciones. `../roblox/README.md` describe el contrato futuro.

## Validación

Ejecutar `python -m unittest discover -s AETHERION/tests -v` desde la raíz del repositorio. Se comprueba geometría cerrada, índices, determinismo, altura local de rocas y curvatura de telas. La compilación Python detecta errores sintácticos. Esto no prueba bpy ni valida resultados visuales.

Dentro de Blender, el lanzador comprueba referencias, materiales, valores finitos, pivotes esenciales, triángulos evaluados y altura entre 37 y 39 unidades. Imprime dimensiones y guarda el informe en la propiedad `report` de cada colección de variante.

Pruebas manuales necesarias: ejecutar dos veces sin duplicados; comprobar objetos ajenos; revisar frente, perfil y espalda; verificar halos despejados, ojos visibles, telas sin cruces, manos legibles y pies apoyados; alternar variantes. Guardar capturas antes de aprobar la silueta para rigging.
