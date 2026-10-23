# Azrakoth en Roblox: exportación (etapa 4)

## Qué genera

`06_Azrakoth_Export.py` arma la versión **GAMEPLAY OPTIMIZED** en `output/roblox/`:

| Archivo | Qué es |
|---|---|
| `Azrakoth_Roblox.fbx` | 43 piezas rígidas, **una por hueso**, con el nombre del hueso: `Chest`, `Wing_L_2`, `Sword`, `Cape_1`… Las telas están cortadas por hueso. Las texturas van dentro del FBX. |
| `textures/` | Las mismas texturas sueltas: `<Pieza>_Color / _Normal / _Roughness / _Metalness / _Emissive.png` (1024 para pecho, alas, espadón, capa, halo y hombreras; 512 el resto) |
| `Azrakoth_Rig.json` | Los 45 huesos (padre, articulación en coordenadas de Roblox, pieza que mueve) y las 20 animaciones con sus marcadores |
| `AzrakothAnimData.lua` | Lo mismo como ModuleScript de Luau, para el código del boss |

**Totales:** 33 156 triángulos en todo el boss, ninguna pieza pasa de 6000.

**Cómo correrlo:** hornear tarda unos 7 minutos, por eso no corre con cada Alt + P. Poné `EXPORTAR = True` en `06_Azrakoth_Export.py` (o `AZR_EXPORTAR=1` por consola) y corré `Build_Azrakoth.py`.

## Por qué piezas rígidas y no un esqueleto dentro del FBX

Cada pieza del boss ya es rígida y tiene el pivote en su articulación. En Roblox se unen con un `Motor6D` por hueso, y las animaciones se reproducen con los datos de `AzrakothAnimData.lua` (rotación de cada hueso respecto de su padre). Eso tiene tres ventajas:

- **No hay que publicar 20 animaciones** como assets.
- **El servidor puede calcular** dónde está el espadón en cada momento para las hitboxes, con los mismos datos.
- **Se evita el importador de mallas con huesos,** que con 45 huesos y telas es lo más frágil.

**Ejes:** en Roblox el boss mira hacia −Z, con +Y arriba, y su izquierda queda en −X. La conversión desde Blender es `(x, y, z) → (−x, z, y)`.

**Cómo usar los datos:** si `C0` y `C1` de cada `Motor6D` apuntan a la articulación sin rotación, `Motor6D.Transform = CFrame` del cuaternión de la animación (más la traslación de `Root`/`Hips` cuando la hay).

## Importar en Studio (un solo paso manual)

1. **Avatar** o **Home** → **Import 3D** → `assets/azrakoth/output/roblox/Azrakoth_Roblox.fbx`.
2. En las opciones: **Rig General → Rig Type: No Rig** (importar como modelo), y que deje las piezas separadas.
3. Revisá en la vista previa que mida unos 65 studs de alto y que mire hacia −Z.
4. Insertalo y dejalo en `ServerStorage` con el nombre `Azrakoth`.

El resto (Motor6D, SurfaceAppearance con la máscara de brillo, la raíz invisible y las colisiones) lo arma el script de la etapa 5.

## Lo que se probó

- La exportación corrió completa con `bpy` 5.2.2: 43 piezas, horneado de las 215 texturas, FBX, JSON y módulo Luau, sin errores.
- **No probado todavía:**
  - el Import 3D de este FBX en Studio;
  - cómo arma Roblox los `SurfaceAppearance` desde las texturas que van dentro del FBX;
  - las animaciones corriendo en Roblox.
