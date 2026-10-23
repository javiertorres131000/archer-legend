# Blender: cómo generar a Azrakoth

## Ejecutarlo

1. Copiá la carpeta `AZRAKOTH` entera donde quieras. Los `.py` de `blender/` tienen que quedar juntos.
2. Abrí **Blender 5.2.2 LTS**: una escena nueva sirve, porque el script saca el cubo de inicio.
3. Pestaña **Scripting** → **Texto → Abrir** → `AZRAKOTH/blender/Build_Azrakoth.py`.
4. **Alt + P**, o el botón ▶. Tarda unos segundos.
5. Mirá la consola: **Ventana → Mostrar consola del sistema** en Windows. Ahí aparecen las medidas del boss y cualquier problema.

Correrlo de nuevo rehace todo sin duplicar, y no toca objetos que no sean del proyecto (todo lleva el prefijo `AZR_`).

**Si dice «No encuentro 00_Azrakoth_Core.py»:** pasa si pegaste el código en un texto nuevo en vez de abrir el archivo. Escribí la ruta de la carpeta en `CARPETA_MANUAL`, arriba de `Build_Azrakoth.py`:

```python
CARPETA_MANUAL = r"C:\Users\vos\Documents\AZRAKOTH\blender"
```

**Si algo falla,** la consola dice en qué etapa fue: «Falló la etapa «01 Modelo»», con el detalle del error.

### Por consola, sin abrir la interfaz

```
blender --background --python AZRAKOTH/blender/Build_Azrakoth.py
```

| Variable | Qué hace |
|---|---|
| `AZR_RENDER=1` | Renderiza todas las cámaras en `AZRAKOTH/output` |
| `AZR_CAMARAS=Frente,Heroica` | Solo esas cámaras |
| `AZR_MOTOR=CYCLES` | Cambia el motor (por defecto, Eevee) |
| `AZR_MUESTRAS=64` / `AZR_PORCENTAJE=50` | Calidad y tamaño del render |
| `AZR_GUARDAR=1` | Guarda `output/Azrakoth.blend` |
| `AZR_DETALLE=0.6` / `1.0` / `1.5` | Más o menos lados en las mallas |

## Qué arma

Todo queda dentro de la colección **AZRAKOTH_BOSS**:

| Colección | Contenido |
|---|---|
| `AZR_Cuerpo` | Casco, corona, coraza, núcleo, hombreras, brazos, puños, piernas, botas y la raíz `AZR_Root` |
| `AZR_Alas` | 6 segmentos (`Wing_L_1..3`, `Wing_R_1..3`), con plumas, cobertoras y cadenas |
| `AZR_Halo` | Halo del eclipse |
| `AZR_Espadon` | Espadón del Eclipse |
| `AZR_Telas` | Tabardo carmesí con emblema, tabardo hueso, dos faldones y capa |
| `AZR_Colision` | Cajas simples por pieza y el punto débil `HIT_ChestCore` (no se renderizan) |
| `AZR_Puntos` | Empties: agarre, estela e hitboxes del espadón, emisores de VFX |
| `AZR_Presentacion` | Cielo, eclipse, arena, torres, luces, 7 cámaras y un jugador de 5 studs |
| `AZR_Rig` | El esqueleto `AZR_Rig` (45 huesos) con las 20 animaciones (ver `ANIMATION_GUIDE.md`) |

El objeto **AZR_Control** está en la raíz de la colección (se ve como una esfera).

### Piezas y pivotes

Cada pieza tiene el **origen en su articulación**. Los huesos del rig nacen en esos mismos puntos (`ART` en `00_Azrakoth_Core.py`), así que ninguna pieza se mueve al riggear.

Con el rig, todas las piezas cuelgan de `AZR_Rig` y se mueven por sus huesos. Para posar: seleccioná `AZR_Rig` → **Ctrl + Tab** (modo pose) → rotá los huesos. La columna «Padre» de la tabla de abajo es la jerarquía de huesos. Si corrés el Build sin `03_Azrakoth_Rig.py`, las piezas quedan emparentadas entre sí como dice la tabla.

| Pieza | Pivote | Padre |
|---|---|---|
| `Pelvis` | Cadera | `Root` |
| `Abdomen` | Columna | `Pelvis` |
| `Chest` | Pecho | `Abdomen` |
| `ChestCore` | Centro del núcleo | `Chest` |
| `Helmet` | Cuello | `Chest` |
| `Crown` | Cabeza | `Helmet` |
| `Halo` | Centro del halo | `Chest` |
| `UpperArm_L/R` | Hombro | `Chest` |
| `Pauldron_L/R` | Hombro | `UpperArm` |
| `Forearm_L/R` | Codo | `UpperArm` |
| `Hand_L/R` | Muñeca | `Forearm` |
| `Fingers_L/R` | Centro del puño | `Hand` |
| `Thumb_L/R` | Centro del puño | `Hand` |
| `UpperLeg_L/R` | Cadera de esa pierna | `Pelvis` |
| `LowerLeg_L/R` | Rodilla | `UpperLeg` |
| `Foot_L/R` | Tobillo | `LowerLeg` |
| `Wing_L/R_1` | Raíz del ala | `Chest` |
| `Wing_L/R_2` | Codo del ala | `Wing_1` |
| `Wing_L/R_3` | Muñeca del ala | `Wing_2` |
| `Sword` | Centro del mango | `Hand_R` |
| `Tabard_Front`, `Tabard_Under`, `ClothSide_L/R` | Borde de arriba | `Pelvis` |
| `Cape` | Borde de arriba | `Chest` |

`L` es la izquierda del boss (+X) y `R` la derecha (−X). El boss mira hacia −Y y apoya los pies en Z = 0.

### Espadón

- **Eje:** el +Z local apunta al pomo y la hoja va hacia −Z.
- **Pose de presentación:** está clavado de punta en el suelo, a la derecha del boss, como en la referencia.
- **Puntos:**
  - `Sword_Grip`: agarre.
  - `Sword_TrailBase` y `Sword_TrailTip`: los dos extremos del `Trail`.
  - `Sword_Hitbox_1..3`: cajas de referencia a lo largo de la hoja. Son empties: no se ven y no se exportan como malla.
  - `Sword_FX_Core`: el núcleo rojo de la guarda.

## Materiales

Son 10, todos con el prefijo `AZR_`:

| Material | Uso |
|---|---|
| `Obsidian` | Armadura general, con grietas finas de magma |
| `ObsidianCracked` | Zonas muy fracturadas: pectorales, grebas, plumas negras |
| `AgedGold` | Ribetes, púas, emblemas |
| `Glow` | Ojos, ranura del visor, gema del cinturón |
| `RuneGlow` | Núcleos rojos (pecho y guarda), runas del halo, canal del espadón |
| `CrimsonCloth` / `BoneCloth` | Telas |
| `WingMembrane` | Membrana roja con venas de lava |
| `BladeMetal` | Hoja del espadón |
| `DarkIron` | Cadenas, mango, banda interna del halo |

**Las grietas son fracturas, no líneas pegadas:**

- Un voronoi deformado por ruido, con ancho variable y ramas finas.
- Una máscara que las reparte por zonas.
- Relieve que las hunde en la piedra.
- Rojo profundo en el borde, naranja adentro y amarillo solo en el centro más caliente.

Todo usa coordenadas de objeto en studs, así la escala de las grietas es la misma en todas las piezas.

### Intensidad animable (`AZR_Control`)

Seleccioná `AZR_Control` y mirá sus **Propiedades personalizadas** (pestaña Objeto). Los materiales las leen por driver:

| Propiedad | Controla | Valor normal | Ideas |
|---|---|---|---|
| `Lava` | Brillo de todas las grietas | 1 | Pulso: 0,8 ↔ 1,2. Fase 3: ~2 |
| `Nucleo` | Ojos y núcleo | 1 | Carga del Corazón del Eclipse: hasta 4 |
| `Runas` | Runas y núcleos rojos | 1 | Carga del Rayo del Eclipse: hasta 4 |

Los drivers no usan expresiones de Python, así que funcionan aunque Blender tenga apagada la ejecución automática de scripts.

**Para Roblox,** la etapa de exportación hornea estos materiales a texturas (BaseColor, Normal, Roughness, Metalness y Emissive) para el `SurfaceAppearance`. Roblox no lee los nodos de Blender.

## Cámaras

| Cámara | Para qué |
|---|---|
| `Heroica` | Contrapicado frontal, como la imagen de referencia |
| `Frente` / `Espalda` / `Perfil` / `TresCuartos` | Vistas para revisar la silueta |
| `Casco` | Primer plano del casco y la corona |
| `Escala` | El boss al lado del jugador de 5 studs |

Para renderizar desde la interfaz: elegí la cámara (clic derecho → *Establecer como cámara activa*) y pulsá **F12**. El script deja Eevee configurado, con AgX y bloom en el compositor.

## Si querés ajustar el diseño

- **Pose y proporciones:** en `00_Azrakoth_Core.py`, `ART` (articulaciones), `AGARRE_ESPADA`, `EJE_ESPADA` y `MANO_IZQ`. El codo de cada brazo se calcula solo con IK de dos huesos.
- **Medidas objetivo:** en `MEDIDAS`. La validación avisa si algo se aleja más de un 8 %.
- **Variaciones:** `SEMILLA` cambia los desgarros, las plumas y las espinas, pero no la silueta.
- **Detalle:** `AZR_DETALLE`, o `DETALLE` en el Core.
