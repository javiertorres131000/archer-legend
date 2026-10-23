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
