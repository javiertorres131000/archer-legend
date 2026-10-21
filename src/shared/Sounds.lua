-- Sounds (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Sounds
-- Qué sonido suena con cada cosa (lo usa Sfx.client.lua).
--
-- IMPORTANTE: por ahora usan sonidos que vienen adentro de Roblox ("rbxasset://sounds/..."),
-- que son básicos. Para que suene mucho mejor, reemplazá Id por sonidos de la Tienda de
-- creadores: en Studio, Caja de herramientas › Audio, buscá (por ejemplo "coin", "explosion",
-- "level up", "whoosh"), clic derecho › Copiar ID del recurso, y pegá "rbxassetid://NÚMERO".
--
--   Volume: volumen (0 a 1) · Pitch: tono base (1 = normal, 2 = una octava arriba)
--   PitchVariation: ± al azar en cada reproducción (para que no suene repetido)
--   MinGap: segundos mínimos entre dos reproducciones (con hordas, evita un ruido continuo)

local Sounds = {}

Sounds.MasterVolume = 0.8

Sounds.List = {
	Shoot = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.18, Pitch = 1.7, PitchVariation = 0.1, MinGap = 0.06 },
	Hit = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.22, Pitch = 1.5, PitchVariation = 0.15, MinGap = 0.04 },
	Crit = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.5, Pitch = 0.85, PitchVariation = 0.05, MinGap = 0.08 },
	Kill = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.45, Pitch = 0.8, PitchVariation = 0.2, MinGap = 0.03 },
	Coin = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Pitch = 1.2, PitchVariation = 0, MinGap = 0.04 },
	-- XP: sube de tono en escalera si juntás orbes seguidos (Config.Effects.OrbLadder*)
	XP = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.18, Pitch = 1.2, PitchVariation = 0, MinGap = 0.06 },
	Hurt = { Id = "rbxasset://sounds/uuhhh.mp3", Volume = 0.35, Pitch = 1, PitchVariation = 0.1, MinGap = 0.4 },
	Chime = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.55, Pitch = 1, PitchVariation = 0, MinGap = 0 },
	-- Racha de muertes: una nota por muerte, cada vez más aguda (sin variación: es una melodía)
	Streak = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Pitch = 0.75, PitchVariation = 0, MinGap = 0.045 },
	-- Redoble antes de revelar una legendaria
	Drum = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.4, Pitch = 1.4, PitchVariation = 0, MinGap = 0 },
	Chest = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.6, Pitch = 0.9, PitchVariation = 0, MinGap = 0.2 },
	Door = { Id = "rbxasset://sounds/action_get_up.mp3", Volume = 0.6, Pitch = 0.7, PitchVariation = 0, MinGap = 1 },
	-- Marca de un compañero (Ping); el pedido de ayuda suena más grave
	Ping = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.6, PitchVariation = 0, MinGap = 0.15 },
	-- Apertura de cajas (CrateCinematic): título, caída, tensión (en bucle, sube de tono),
	-- explosión, cada salto de la ruleta, aparición de premios y el reveal (Big: Legendary o más)
	CrateSting = { Id = "rbxasset://sounds/bass.wav", Volume = 0.7, Pitch = 0.8, PitchVariation = 0, MinGap = 0 },
	CrateThud = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.8, Pitch = 0.55, PitchVariation = 0, MinGap = 0 },
	CrateTension = { Id = "rbxasset://sounds/action_falling.ogg", Volume = 0.5, Pitch = 0.6, PitchVariation = 0, MinGap = 0 },
	CrateBoom = { Id = "rbxasset://sounds/HalloweenThunder.wav", Volume = 0.9, Pitch = 1.15, PitchVariation = 0, MinGap = 0 },
	CratePop = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Pitch = 1, PitchVariation = 0, MinGap = 0 },
	CrateTick = { Id = "rbxasset://sounds/switch.wav", Volume = 0.55, Pitch = 1.3, PitchVariation = 0, MinGap = 0 },
	CrateWhoosh = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.6, Pitch = 0.6, PitchVariation = 0, MinGap = 0 },
	CrateReveal = { Id = "rbxasset://sounds/victory.wav", Volume = 0.7, Pitch = 1, PitchVariation = 0, MinGap = 0 },
	CrateRevealBig = { Id = "rbxasset://sounds/HalloweenThunder.wav", Volume = 0.8, Pitch = 0.75, PitchVariation = 0, MinGap = 0 },
}

return Sounds
