# Ejecutar en Blender

1. Conservá toda la carpeta AETHERION. Abrí Blender y quedate en Object Mode.
2. En Scripting, Text > Open, elegí `AETHERION/blender/Build_Aetherion.py`.
3. Poné el cursor en el editor de texto y presioná Alt+P.
4. Esperá el mensaje `[AETHERION] Listo`. Verás `AETHERION_BOSS` en el Outliner.
5. Cambiá el sombreado a Material Preview para ver los colores. Seleccioná la colección visible y usá Frame Selected. Numpad 0 muestra la cámara creada.
6. Guardá como un .blend nuevo. El generador no sobrescribe archivos.

Se construyen las dos variantes en el origen, pero CINEMATIC queda oculta en viewport y render. Para verla podés cambiar `ACTIVE_VARIANT = 'CINEMATIC'` y ejecutar otra vez. `BUILD_BOTH = False` construye solamente la elegida.

Reejecutar reemplaza los objetos generados: guardá una copia si los editaste manualmente. Los objetos ajenos se conservan, incluso si los agregaste a una colección generada. La cámara activa cambia si PRESENTATION=True; podés desactivarlo. El script no modifica unidades, motor de render, mundo ni composición de tu escena.

Usá el archivo guardado en disco, no copies solo su contenido a un texto sin ruta: el lanzador necesita encontrar los módulos hermanos. No requiere pip. Si falla, copiá el traceback completo de la consola; la colección temporal se elimina y se conserva la anterior.

Objetivo de compatibilidad: bpy de Blender 5.x, incluido 5.2.2 solicitado; no verificado en ejecución. Referencias API utilizadas: [Mesh.from_pydata](https://docs.blender.org/api/current/bpy.types.Mesh.html), [Principled BSDF](https://docs.blender.org/api/5.0/bpy.types.ShaderNodeBsdfPrincipled.html), [BMesh](https://docs.blender.org/api/current/bmesh.html). Se evitan operadores dependientes del área activa, partículas antiguas y acceso a acciones que cambió entre versiones.
