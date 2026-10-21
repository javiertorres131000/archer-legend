# Skin Demonio Ígneo (FireDemon)

## Código (en el repo, rama skin-demonio, base fase2)
- src/shared/CrateLooks.lua: trajes detallados. FireDemon usa las mallas de CrateAssets > Looks > FireDemon,
  con Glow (brillo), Fx (Flames / Embers / Smoke), Light y Sway (alas y capa).
- src/shared/CrateModels.lua: los premios con traje (CrateLooks.has) se ven con el traje en la caja y en el índice.
- src/server/CrateEquip.lua: al equiparlo, CrateLooks.applyToCharacter; al sacarlo, CrateLooks.removeFromCharacter.
- src/server/DebugCommands.lua: acción "Demon" en el panel F2 (te da y equipa el Demonio Ígneo).
- src/client/LavaSkinFx.client.lua: brillo que late, aleteo suave, alas que se abren al saltar, capa,
  pisadas de lava, aura, estela en el dash y explosión al equipar.

## Assets (viven en el place, Rojo no los toca)
- ReplicatedStorage > CrateAssets > Looks > FireDemon: 12 MeshParts con SurfaceAppearance
  (color, máscara de brillo, relieve y rugosidad).
- ServerStorage > DemonMeshes_Originales y ServerStorage > CrateLooks_backup: respaldos.
- Fuentes: los PNG de esta carpeta. En generadas/ están las máscaras de brillo (_Mask),
  los mapas de relieve (_Normal) y los de rugosidad (_Rough) que se subieron a Roblox.
