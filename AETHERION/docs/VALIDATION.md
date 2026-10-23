# Verificación de esta entrega

Ejecutado con Python 3.12, fuera de Blender:

- `python -m compileall -q AETHERION/blender AETHERION/tests`: correcto.
- `python -m unittest discover -s AETHERION/tests -v`: 3 pruebas correctas. Incluyen 100 piedras con semillas/niveles de detalle diferentes, topología cerrada de cristales y arcos, y tres telas curvas.

Revisión de dependencias: módulos hermanos cargados por ruta; biblioteca estándar, bpy, bmesh y mathutils. Los tres últimos solo existen en Blender y no se han importado ni ejecutado durante estas pruebas.

No verificado: ejecución con Blender 5.2.2, resultado visual, conteo real de triángulos evaluados, rendimiento del viewport, importación a Studio. El generador imprime datos reales cuando se ejecuta; no interpretar las pruebas puras como validación visual.

Prueba de aceptación en Blender: generar, guardar copia, capturar frente/perfil/espalda, comprobar 38 unidades de altura y pivotes, ejecutar nuevamente y verificar que no se duplique. Agregar antes un cubo ajeno a la colección para comprobar que se conserva. Si aparece un error, compartir el traceback completo.
