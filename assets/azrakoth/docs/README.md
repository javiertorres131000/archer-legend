# AZRAKOTH — El Serafín del Eclipse Carmesí

Jefe principal de **Leyendas de Flechas (Arrow Legends)**. Es un caballero demoníaco colosal de obsidiana y magma, con:

- seis segmentos de ala;
- un halo del eclipse que gira;
- un espadón de 42 studs.

Todo se genera con Python (`bpy`) en Blender 5.2.2 LTS y después se lleva a Roblox Studio.

## Estado por etapas

| Etapa | Contenido | Estado |
|---|---|---|
| **1** | Modelo 3D completo, materiales procedurales, escala, alas, halo, espadón, colisiones, puntos de VFX y escena de presentación | **Entregada** |
| **2** | Rig propio del coloso (45 huesos, con alas, capa, halo y espadón) y las 20 animaciones con marcadores para el juego | **Entregada** |
| 3 | VFX de presentación en Blender (brasas, ceniza, humo, descargas del halo) | Pendiente |
| **4** | Exportación: versión GAMEPLAY OPTIMIZED (43 piezas, texturas horneadas), FBX y datos de animación para Roblox | **Entregada** (sin probar en Studio) |
| 5 | Luau: estados, fases, las 9 habilidades, hitboxes del servidor, VFX en clientes y recompensas | Pendiente |

## Estructura

```
AZRAKOTH/
├─ blender/
│  ├─ Build_Azrakoth.py              ← el que se ejecuta (Alt + P)
│  ├─ 00_Azrakoth_Core.py            medidas, esqueleto de referencia, colecciones, limpieza, primitivas bmesh
│  ├─ 01_Azrakoth_Model.py           geometría de todas las piezas, jerarquía, colisiones y puntos
│  ├─ 02_Azrakoth_Materials.py       materiales PBR procedurales y el control AZR_Control
│  ├─ 07_Azrakoth_Presentation.py    cielo, eclipse, arena, torres, luces, cámaras, jugador de escala, bloom
│  ├─ 03_Azrakoth_Rig.py             esqueleto, pesos (rígidos y de tela) y puntos pegados a huesos
│  ├─ 04_Azrakoth_Animations.py      las 20 acciones con sus marcadores
│  ├─ 05_Azrakoth_VFX_Preview.py     (etapa 3)
│  └─ 06_Azrakoth_Export.py          FBX liviano, texturas horneadas, Azrakoth_Rig.json y AzrakothAnimData.lua
├─ roblox/                           (etapa 5)
├─ docs/
│  ├─ README.md
│  ├─ BLENDER_SETUP.md
│  ├─ ANIMATION_GUIDE.md             rig, cómo editar, las 20 animaciones y sus marcadores
│  └─ ROBLOX_IMPORT.md               exportación y cómo importarlo en Studio
└─ output/                           renders y .blend generados
```

`Build_Azrakoth.py` carga los módulos en orden. Si un archivo de una etapa futura todavía no está, lo avisa y sigue. Así, cuando lleguen el rig o la exportación, alcanza con copiarlos a la misma carpeta.

## Medidas (1 unidad de Blender = 1 stud)

La validación del script mide esto en cada corrida:

| Medida | Objetivo | Resultado |
|---|---|---|
| Altura hasta la corona | 65 | 65,2 |
| Altura del cuerpo (sin púas) | 56 | 55,9 |
| Entre hombros (articulaciones) | 22 | 21,6 |
| Envergadura | 105 | 107,1 |
| Espadón (pomo a punta) | 42 | 44,2 |
| Halo (anillo exterior) | 24 | 24,7 |
| Ancho del pie | 8 | 8,6 |

Las alas levantadas llegan a Z ≈ 74 y el halo, con sus espinas, a Z ≈ 68. La altura total se mide hasta la corona, como pide el diseño.

## Lo que se probó y lo que no

**Se corrió de verdad** con el módulo `bpy` 5.2.2 LTS (Blender sin ventana):

- Arma las 37 piezas, el rig de 45 huesos y las 20 animaciones sin errores.
- Es idempotente: corrido 3 veces seguidas da los mismos conteos y no toca objetos ajenos.
- Funciona con los niveles de detalle 0.6, 1.0 y 1.5.
- Las medidas pasan la validación.
- Se renderizó con **Cycles**. Las imágenes de `output/` salen de ahí.

**No se probó:**

- **Eevee:** sin pantalla no anda, pero los materiales no usan nada exclusivo de Cycles.
- **Correrlo con Alt + P en el Blender con interfaz:** el código está preparado para ese caso, pero desde acá no hay interfaz para probarlo.
- **Importarlo en Roblox:** llega en la etapa 4.
