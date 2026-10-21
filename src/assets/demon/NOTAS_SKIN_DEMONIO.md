# Skin Demonio Ígneo (FireDemon): pendiente de pasar al repo

Hecho directo en Roblox Studio (place "Leyendas de flechas", placeId 81254012896939) el 21/10/2026.
Antes de sincronizar con Rojo en otra PC, hay que traer estos scripts de Studio al repo; si no, Rojo los pisa.

## Scripts a pasar de Studio al repo
| En Studio | Archivo en el repo | Qué cambió |
|---|---|---|
| ReplicatedStorage > Shared > CrateLooks | src/shared/CrateLooks.lua | El traje FireDemon ahora usa mallas (campo `Mesh` y `MeshFolder`), con `Glow`, `Fx` ("Flames" / "Embers" / "Smoke"), `Light` y `Sway` (alas y capa con Weld). Los tags "LavaGlow" y "LavaSway" son para LavaSkinFx. |
| ServerScriptService > Server > DebugCommands | src/server/DebugCommands.lua | Nueva acción `Demon` en el panel F2: "Darme y equipar Demonio Ígneo". También agrega `require(script.Parent.CrateEquip)`. |
| StarterPlayer > StarterPlayerScripts > Client > LavaSkinFx | src/client/LavaSkinFx.client.lua (nuevo) | Efectos en el cliente: el brillo late; las alas aletean, se abren al saltar y la capa se balancea; pisadas de lava, aura, estela en el dash y explosión al equipar. |

Lo más seguro es copiar el código desde Studio: el place guardado tiene la versión final.
Ojo: en Studio también están los cambios de la otra PC (por ejemplo CrateLooks, CrateEquip con CrateLooks y los premios nuevos). Hay que mezclar con cuidado y no pisar el repo de esa PC a ciegas.

## Assets (no los maneja Rojo, viven en el place)
- ReplicatedStorage > CrateAssets > Looks > FireDemon: las 12 MeshParts con su SurfaceAppearance (color, brillo, relieve y rugosidad).
- ServerStorage > DemonMeshes_Originales: las piezas originales.
- ServerStorage > CrateLooks_backup: el traje anterior, hecho con Parts.
- Las texturas fuente están en esta carpeta. Las máscaras de brillo, relieve y rugosidad que se generaron están en /_emissive_tmp.
