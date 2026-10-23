# Contrato de importación — etapa posterior

Esta entrega todavía no exporta FBX ni hornea texturas. Los materiales procedurales y luces de Blender no equivalen a materiales o VFX funcionales en Roblox.

Convención del modelo: X lateral, -Y frente, Z arriba; pies Z=0. Objetivo de escala: 1 unidad de geometría = 1 stud. El cuerpo con corona mide aproximadamente 38 unidades; los halos tienen 18, 13.8 y 9.8 de diámetro. La pose neutra tiene brazos inclinados hacia abajo, no 32 unidades de envergadura horizontal. El informe de Blender proporciona la medida real de cada variante.

En la etapa de exportación se convertirá Z-up a Y-up y frente a -Z. No compensar con escalas arbitrarias por pieza. Después de importar, comparar altura del Model:GetExtentsSize().Y con 38 y con un avatar de referencia de 5 studs. Una escala errónea debe corregirse uniformemente sobre el modelo completo.

Los empties son pivotes de autoría, no Motor6D funcionales ni un rig Roblox terminado. `joint_id` relaciona geometría con articulación. Antes de exportar habrá que hornear transformaciones, agrupar mallas por articulación/material y crear huesos o Motor6D según la ruta elegida. CoreCrystal será el visual; una hitbox propia de servidor resolverá los impactos sobre el punto débil.

No importar la colección de presentación. No activar colisión en fragmentos visuales. No colocar aún este modelo como enemigo activo: faltan rig, exportación y lógica de combate.
