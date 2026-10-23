# Rig y animaciones de Azrakoth

Lo arman `03_Azrakoth_Rig.py` y `04_Azrakoth_Animations.py`. `Build_Azrakoth.py` los corre solos, después del modelo.

## El rig (`AZR_Rig`, 45 huesos)

| Grupo | Huesos |
|---|---|
| Tronco | `Root` → `Hips` → `Spine` → `Chest` → `Neck` → `Head` → `Crown` |
| Extras del pecho | `Halo` (gira sobre su eje Y), `Core` (núcleo del pecho) |
| Brazos (×2) | `Shoulder` (mueve la hombrera) → `UpperArm` → `Forearm` → `Hand` → `Fingers` y `Thumb` |
| Piernas (×2) | `UpperLeg` → `LowerLeg` → `Foot` |
| Alas (×2) | `Wing_L_1` → `Wing_L_2` → `Wing_L_3` (y lo mismo con `R`) |
| Espadón | `Sword`, hijo de `Hand_R`; su cola es la punta de la hoja |
| Telas | `Cape_1..3`, `Tabard_1..2`, `TabardUnder_1..2`, `ClothSide_L_1..2`, `ClothSide_R_1..2` |

**Cómo se pegan las piezas al rig:**

- **Piezas rígidas:** cada una va al 100 % a su hueso.
- **Telas:** se reparten suave entre los huesos de su cadena, así se doblan.
- **Colisiones, puntos de VFX y luces:** cuelgan de los huesos, así que siguen cualquier animación. Eso incluye las hitboxes del espadón y el punto débil del núcleo.

**Ejes del boss:** mira hacia −Y, su izquierda es +X y la `L` de los nombres es su izquierda.

## Ver y editar las animaciones en Blender

1. Seleccioná `AZR_Rig`.
2. Abrí el editor **Dope Sheet → Action Editor**.
3. Elegí la acción en el desplegable, por ejemplo `AZR_AttackVertical`.
4. Barra espaciadora para reproducir. Cada acción tiene su rango de cuadros guardado.

Los **marcadores** aparecen abajo, en el Action Editor (Telegraph, Hit, FX_…). Si movés un golpe, mové también su marcador: es lo que usa el juego para el daño y los efectos.

Todas las acciones están guardadas con usuario falso (*fake user*), así no se pierden aunque no estén asignadas.

Para retocar las poses desde el código, cada animación está escrita como datos en `04_Azrakoth_Animations.py`:

- Cada clave es `(cuadro, pose)`.
- Cada pose dice cuánto gira cada hueso, en grados y en los ejes del boss:

| Hueso | Qué hace cada eje |
|---|---|
| Torso, cuello, cabeza | +X se inclina hacia adelante · +Z gira hacia su izquierda |
| Piernas | −X va adelante · rodilla: +X dobla |
| Brazos | −X levanta hacia adelante |
| Alas | Izquierda: −Y sube, +Z se pliega atrás. La derecha, al revés |

- `"loc:Hips"` / `"loc:Root"`: traslación en studs (agacharse, despegar, caer).
- `"apunta": (x, y, z)`: orienta el espadón hacia esa dirección. El script calcula solo el giro de la muñeca según cómo quedó el resto del cuerpo.

En cada clave se clavan **todos** los huesos. Si un hueso queda sin clave, conserva la pose de la animación anterior, tanto en Blender como en Roblox.

## Las 20 animaciones (30 FPS)

| # | Acción | Cuadros | Bucle | Marcadores (cuadro) | Qué hace |
|---|---|---|---|---|---|
| 1 | `AZR_Idle` | 120 (4.0 s) | sí | — | Respira con el espadón clavado |
| 2 | `AZR_Walk` | 72 (2.4 s) | sí | `Step_L` 0, `Step_R` 36 | Paso pesado: cada pisada (Step) sacude el suelo |
| 3 | `AZR_Turn` | 48 (1.6 s) | no | `Step_L` 24, `Step_R` 40 | Gira 90° a su izquierda pisando dos veces |
| 4 | `AZR_AttackHorizontal` | 66 (2.2 s) | no | `Telegraph` 0, `HitStart` 30, `Hit` 32, `HitEnd` 36, `Recover` 44 | Barrido amplio en diagonal baja |
| 5 | `AZR_AttackVertical` | 84 (2.8 s) | no | `Telegraph` 0, `FX_ChargeBlade` 10, `Hit` 51, `FX_Shockwave` 51, `CameraShake` 51, `Recover` 66 | **Juicio Carmesí**: levanta 1,5 s y golpea el suelo |
| 6 | `AZR_Combo3` | 120 (4.0 s) | no | `Hit1` 18, `Hit2` 36, `Telegraph3` 56, `Hit3` 86, `FX_Shockwave` 86, `Recover` 96 | **Danza del Verdugo**: dos tajos rápidos y un tercero con carga larga |
| 7 | `AZR_WingsOpen` | 45 (1.5 s) | no | `FX_WingBurst` 30 | Despliega las alas (antes de **Tormenta de Alas**) |
| 8 | `AZR_TakeOff` | 60 (2.0 s) | no | `FX_TakeOffDust` 22, `Airborne` 26 | Se agacha, bate las alas y sube 26 studs |
| 9 | `AZR_Fly` | 40 (1.3 s) | sí | `FX_WingBeat` 20 | Aleteo en el aire |
| 10 | `AZR_SeraphFall` | 100 (3.3 s) | no | `Telegraph` 0, `FX_LandingMarker` 0, `Dive` 34, `Hit` 50, `FX_FireColumn` 50, `FX_Crater` 50, `CameraShake` 50, `Recover` 64 | **Caída del Serafín**: planea, cae en picada y golpea |
| 11 | `AZR_ChainSummon` | 75 (2.5 s) | no | `Telegraph` 0, `FX_SummonCircles` 10, `Cast` 34, `Recover` 54 | **Cadenas del Abismo**: puño al suelo |
| 12 | `AZR_CoreCharge` | 60 (2.0 s) | sí | `FX_CorePulse` 0, `FX_CorePulse2` 30 | **Corazón del Eclipse**: pecho abierto, núcleo vulnerable |
| 13 | `AZR_SummonSoldiers` | 80 (2.7 s) | no | `Telegraph` 0, `Summon` 40, `FX_Portals` 40, `Recover` 60 | **Legión de los Condenados**: alza y clava el espadón |
| 14 | `AZR_BeamCharge` | 60 (2.0 s) | sí | `FX_HaloSpinUp` 0, `FX_Runes` 0 | Carga del **Rayo del Eclipse** |
| 15 | `AZR_BeamFire` | 100 (3.3 s) | no | `BeamStart` 10, `BeamEnd` 85, `Recover` 90 | Rayo: barre de su derecha a su izquierda |
| 16 | `AZR_PhaseTransform` | 130 (4.3 s) | no | `FX_Implode` 20, `FX_Burst` 78, `CameraShake` 78, `PhaseChange` 78, `Recover` 110 | **Ira del Serafín Caído** / cambio de fase |
| 17 | `AZR_Stunned` | 60 (2.0 s) | sí | `FX_StunStars` 0 | De rodillas, tambaleando |
| 18 | `AZR_HitReact` | 22 (0.7 s) | no | `Hit` 0 | Retrocede al recibir daño |
| 19 | `AZR_Death` | 160 (5.3 s) | no | `FX_CoreCrack` 20, `FX_Knees` 50, `FX_SwordDrop` 90, `FX_Collapse` 130, `Dead` 150 | Cae de rodillas, suelta el espadón y se derrumba |
| 20 | `AZR_Intro` | 200 (6.7 s) | no | `FX_EyesOn` 40, `FX_Rise` 60, `FX_WingsUnfurl` 110, `Roar` 160, `CameraShake` 160, `Fight` 200 | Presentación: arrodillado, se levanta, despliega las alas y alza el espadón |

**Cómo leer los marcadores:**

- **Telegraph → Hit:** es el tiempo que tienen los jugadores para leer el ataque.
- **Hit, o la ventana HitStart–HitEnd:** el servidor revisa las hitboxes solo en esos cuadros.
- **Recover:** desde ahí el boss queda expuesto para que lo castiguen.
- **FX_…:** el momento en que cada cliente dispara un efecto.

**Lo que hace Roblox, no la animación:**

- **Desplazamiento:** caminar y girar van en el lugar, y Roblox mueve y gira el modelo.
- **Altura del vuelo:** `TakeOff`, `Fly` y `SeraphFall` suben y bajan con el hueso `Root`. En el juego, la altura real y el punto de aterrizaje los decide el servidor.
- **El halo:** gira sin parar por código. La animación solo lo deja quieto, para que nunca se pelee con ese giro.

## Qué viaja a Roblox y qué no

| Viaja | Se reconstruye en Roblox |
|---|---|
| Rotaciones y traslaciones de los 45 huesos en las 20 acciones | El brillo animable de `AZR_Control` (lava, núcleo, runas): pasa a `EmissiveStrength` y luces por código |
| Marcadores → `KeyframeMarker` (eventos de animación) | Partículas, estelas, rayos y ondas (etapa de VFX) |
| Pesos de las telas | El giro continuo del halo |

**Cómo llevarlo:** el camino exacto se decide y se prueba en la etapa de exportación. Hay dos opciones:

1. **FBX con rig:** Roblox lo importa como malla con huesos, y las animaciones se suben desde el Animation Editor.
2. **Piezas rígidas unidas por `Motor6D`:** cada pieza ya es rígida y tiene su pivote en la articulación. Las animaciones se generan como `KeyframeSequence` a partir de los datos de Blender, sin pasar por el importador.

Antes de elegir, se prueban las dos con el boss de verdad en Studio.

## Lo que se probó

**Armado:** se corrió con `bpy` 5.2.2 sin ventana. Crea el rig y las 20 acciones con sus marcadores, sin errores.

**Revisión por animación:** cada una se revisó con un diagrama de huesos (frente y perfil), con estos chequeos:

- **Pies:** en las animaciones de suelo nunca se hunden más de unos 2 studs. Al arrodillarse o morir, la rodilla y la punta del pie apoyan.
- **Espadón:**
  - En Juicio Carmesí la punta llega al suelo, a Z ≈ 2–4.
  - Al clavar la espada para invocar soldados queda a Z ≈ 0,9.
  - En el resto entra como mucho 2 studs (apoyado o clavado).

**Renders:** algunas poses clave se renderizaron con la malla y se ven en `output/poses/`.

**No probado:** cómo se ven en movimiento continuo en la interfaz de Blender. Desde acá solo se revisaron cuadros sueltos.
