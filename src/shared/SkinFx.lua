--!strict
-- SkinFx (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > SkinFx
-- Efectos visuales de cada skin de personaje (premio de las cajas que va en el lugar "Character"). Solo es
-- apariencia: nada de esto toca el daño ni la jugabilidad, y todo lo dibuja cada cliente.
--   · Colors: paleta de la skin (la usan las pisadas, el aura y la estela de LavaSkinFx).
--   · Arrow: cómo se ven las flechas de quien tiene la skin puesta (Client/SkinArrowFx):
--       Shaft / ShaftMaterial  vara de la flecha
--       Tip                    punta (de neón: brilla)
--       Style                  estilo de FxStyles cuyas texturas usa (llamas, anillo, destello, humo)
--       Flames / Embers        llamas y brasas que suelta en vuelo (partículas por segundo)
--       Light                  alcance de la luz que lleva la flecha (0 = sin luz)
--       TrailLife / TrailWidth estela: cuánto dura y qué tan ancha es (1 = como la flecha común)
--       ImpactSize             tamaño de la explosión al pegar (1 = normal)
-- Para sumar una skin: agregala acá con el mismo Id que en Shared/CrateItems.lua.

export type Palette = { hot: Color3, mid: Color3, dark: Color3 }
export type ArrowFx = {
	Shaft: Color3,
	ShaftMaterial: Enum.Material,
	Tip: Color3,
	Style: string,
	Flames: number,
	Embers: number,
	Light: number,
	TrailLife: number,
	TrailWidth: number,
	ImpactSize: number,
}
export type Skin = { Colors: Palette, Arrow: ArrowFx? }

local C = Color3.fromRGB

local SkinFx = {}

SkinFx.Skins = {
	FireDemon = {
		Colors = { hot = C(255, 190, 70), mid = C(255, 80, 20), dark = C(120, 15, 5) },
		Arrow = {
			Shaft = C(35, 22, 18),
			ShaftMaterial = Enum.Material.Basalt,
			Tip = C(255, 120, 30),
			Style = "Inferno",
			Flames = 28,
			Embers = 18,
			Light = 7,
			TrailLife = 0.3,
			TrailWidth = 2.2,
			ImpactSize = 1,
		},
	},
	-- Por ahora solo la paleta (pisadas, aura y estela); sus flechas todavía son las comunes
	CosmicMage = {
		Colors = { hot = C(220, 200, 255), mid = C(130, 100, 255), dark = C(60, 20, 120) },
	},
	Necromancer = {
		Colors = { hot = C(190, 255, 200), mid = C(60, 230, 100), dark = C(10, 70, 25) },
	},
	-- Seraphiel: flechas de luz (vara nacarada, punta turquesa, estela dorada que termina en celeste)
	Seraphiel = {
		Colors = { hot = C(255, 248, 215), mid = C(255, 200, 90), dark = C(80, 190, 255) },
		Arrow = {
			Shaft = C(236, 232, 222),
			ShaftMaterial = Enum.Material.SmoothPlastic,
			Tip = C(120, 235, 255),
			Style = "Celestial",
			Flames = 14,
			Embers = 24,
			Light = 7,
			TrailLife = 0.32,
			TrailWidth = 2.0,
			ImpactSize = 1.1,
		},
	},
} :: { [string]: Skin }

-- Aura de cuerpo entero según el traje (la dibuja Client/SkinAura en cada cliente).
--   Kind: "Flame" (llamas), "Spark" (chispas/estrellas), "Smoke" (humo), "Holy" (luz que sube y
--   brilla) o "Void" (humo oscuro que se mete hacia adentro). A, B: colores (inicio → final).
--   Rate: partículas por segundo en el torso (brazos y piernas usan la mitad).
--   Extra (opcional): una segunda capa con otro Kind (p. ej. llamas + brasas).
-- Los trajes que no están acá no tienen aura (el Aldeano, por ejemplo).
SkinFx.Auras = {
	Lumberjack = { Kind = "Smoke", A = C(150, 120, 90), B = C(90, 70, 50), Rate = 4 },
	Pirate = { Kind = "Smoke", A = C(170, 200, 210), B = C(90, 110, 130), Rate = 5 },
	Knight = { Kind = "Spark", A = C(180, 215, 255), B = C(60, 120, 230), Rate = 8 },
	Sorcerer = { Kind = "Spark", A = C(235, 200, 255), B = C(150, 70, 255), Rate = 10, Extra = { Kind = "Smoke", A = C(120, 60, 200), B = C(40, 10, 80), Rate = 4 } },
	GoldenKing = { Kind = "Holy", A = C(255, 240, 170), B = C(255, 180, 40), Rate = 12 },
	CosmicMage = { Kind = "Spark", A = C(240, 230, 255), B = C(130, 100, 255), Rate = 16, Extra = { Kind = "Void", A = C(80, 50, 180), B = C(20, 5, 50), Rate = 6 } },
	Seraphiel = { Kind = "Holy", A = C(255, 252, 230), B = C(255, 200, 90), Rate = 16, Extra = { Kind = "Spark", A = C(200, 245, 255), B = C(80, 190, 255), Rate = 8 } },
	Necromancer = { Kind = "Flame", A = C(190, 255, 200), B = C(20, 120, 40), Rate = 14, Extra = { Kind = "Smoke", A = C(30, 60, 35), B = C(5, 15, 8), Rate = 5 } },
	LavaGolem = { Kind = "Flame", A = C(255, 200, 80), B = C(220, 50, 10), Rate = 18, Extra = { Kind = "Spark", A = C(255, 170, 60), B = C(255, 80, 20), Rate = 10 } },
	VoidKnight = { Kind = "Void", A = C(170, 110, 255), B = C(30, 10, 60), Rate = 14, Extra = { Kind = "Spark", A = C(200, 160, 255), B = C(110, 50, 255), Rate = 6 } },
	FallenAngel = { Kind = "Flame", A = C(255, 200, 230), B = C(160, 40, 110), Rate = 16, Extra = { Kind = "Smoke", A = C(60, 20, 45), B = C(15, 5, 12), Rate = 6 } },
	FireDemon = { Kind = "Flame", A = C(255, 190, 70), B = C(170, 20, 5), Rate = 20, Extra = { Kind = "Spark", A = C(255, 200, 90), B = C(255, 80, 20), Rate = 10 } },
}

function SkinFx.aura(id: any): any
	return if type(id) == "string" then SkinFx.Auras[id] else nil
end

-- Skin por Id (nil si ese premio no tiene efectos)
function SkinFx.get(id: any): Skin?
	if type(id) ~= "string" then
		return nil
	end
	return SkinFx.Skins[id]
end

-- Skin que tiene puesta un personaje (el servidor marca el atributo CrateLook al equiparla)
function SkinFx.forCharacter(character: Instance?): (string?, Skin?)
	if not character then
		return nil, nil
	end
	local id = character:GetAttribute("CrateLook")
	local skin = SkinFx.get(id)
	if skin then
		return id :: string, skin
	end
	return nil, nil
end

return SkinFx
