-- FxStyles (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > FxStyles
-- Estilos de efectos "anime" para armas especiales (los dibuja Client/AnimeFx).
-- Un arma usa un estilo con el campo Fx en Shared/Weapons.lua (p. ej. Fx = "Frost").
-- Sin Fx, el arma usa los efectos simples de siempre (MeleeVisuals).
--
-- Texturas: se generan con tools/gen_vfx_textures.py (assets/vfx/al_vfx_<estilo>_<nombre>.png),
-- se importan en Studio (Asset Manager › Import) y el ID de cada una va abajo como
-- "rbxassetid://123". Si un ID está vacío se usa una textura de Roblox de respaldo, así el
-- efecto funciona igual mientras tanto (con menos estilo).
--
-- Texturas de cada estilo:
--   Flame     llama con contorno, flipbook 4x4 (16 cuadros)
--   Smoke     humo con contorno que se desarma, flipbook 4x4
--   Slash     media luna del tajo (se estira a lo largo de un Beam)
--   Swirl     franja turbulenta que se repite (remolino, columna)
--   Ring      anillo de onda expansiva (visto desde arriba)
--   Circle    círculo ornamental del piso
--   Star      destello de 4 puntas
--   Speedline línea de velocidad
--
-- Colores de cada estilo (los que no vienen en las texturas):
--   Light  color principal: luz del impacto, partículas y respaldo
--   Core   centro de la estela del arma (casi blanco)
--   Deep   cola de la estela (oscuro)
--   Flash  tinte de la pantalla después del "impact frame"
--
-- Rasgos opcionales del estilo (los dibuja AnimeFx):
--   BodyAura = true  llamas del color del estilo envolviendo a todo el personaje
--   Variant          efectos propios del arma además de los comunes: "Inferno" o "Crimson"
--   Burst = true     el Juicio y el remate del combo son una esfera gigante que explota
--                    (en vez de la columna), y la pantalla se tiñe (BurstTint)

local FxStyles = {}

FxStyles.Styles = {
	Frost = {
		Name = "Escarcha",
		Light = Color3.fromRGB(120, 215, 255), -- color de respaldo y de la luz del impacto
		Core = Color3.fromRGB(245, 252, 255),
		Deep = Color3.fromRGB(40, 110, 220),
		Flash = Color3.fromRGB(180, 225, 255),
		Textures = {
			Flame = "rbxassetid://92649021754528",
			Smoke = "rbxassetid://108728532325509",
			Slash = "rbxassetid://127094890871018",
			Swirl = "rbxassetid://77330761649876",
			Ring = "rbxassetid://99513047680727",
			Circle = "rbxassetid://87892107168236",
			Star = "rbxassetid://123174437460548",
			Speedline = "rbxassetid://80339343196939",
		},
	},
	Crimson = {
		Name = "Carmesí",
		Variant = "Crimson", -- corte en el aire, X en cada golpe, espinas (AnimeFx)
		Light = Color3.fromRGB(255, 40, 60),
		Core = Color3.fromRGB(255, 220, 225),
		Deep = Color3.fromRGB(90, 0, 12),
		Flash = Color3.fromRGB(255, 120, 130),
		BodyAura = true,
		Burst = true,
		BurstTint = Color3.fromRGB(255, 70, 80),
		-- Texturas: python tools/gen_vfx_textures.py assets/vfx crimson (al_vfx_crimson_*.png)
		-- Importar y pegar los IDs acá (vacío = respaldo de Roblox)
		Textures = {
			Flame = "",
			Smoke = "",
			Slash = "",
			Swirl = "",
			Ring = "",
			Circle = "",
			Star = "",
			Speedline = "",
		},
	},
	Inferno = {
		Name = "Infierno",
		Variant = "Inferno", -- fuego en el piso, erupciones, tornado, meteorito (AnimeFx)
		Light = Color3.fromRGB(255, 120, 40),
		Core = Color3.fromRGB(255, 246, 210),
		Deep = Color3.fromRGB(170, 20, 10),
		Flash = Color3.fromRGB(255, 200, 150),
		-- Generar con: python tools/gen_vfx_textures.py assets/vfx inferno
		-- Importar assets/vfx/al_vfx_inferno_*.png y pegar los IDs acá (vacío = respaldo de Roblox)
		Textures = {
			Flame = "",
			Smoke = "",
			Slash = "",
			Swirl = "",
			Ring = "",
			Circle = "",
			Star = "",
			Speedline = "",
		},
	},
}

-- Texturas de Roblox que vienen con el cliente (respaldo mientras no estén las propias)
FxStyles.Fallback = {
	Flame = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Slash = "rbxasset://textures/particles/sparkles_main.dds",
	Swirl = "rbxasset://textures/particles/smoke_main.dds",
	Ring = "rbxasset://textures/particles/sparkles_main.dds",
	Circle = "rbxasset://textures/particles/sparkles_main.dds",
	Star = "rbxasset://textures/particles/sparkles_main.dds",
	Speedline = "rbxasset://textures/particles/sparkles_main.dds",
}

function FxStyles.get(id: string?): any
	if type(id) ~= "string" then
		return nil
	end
	return FxStyles.Styles[id]
end

-- Devuelve (textura, esPropia). esPropia = false → es el respaldo de Roblox.
function FxStyles.texture(style: any, key: string): (string, boolean)
	local id = style and style.Textures and style.Textures[key]
	if type(id) == "string" and id ~= "" then
		return id, true
	end
	return FxStyles.Fallback[key] or "", false
end

return FxStyles
