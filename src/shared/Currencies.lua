--!strict
-- Currencies (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Currencies
-- Las monedas del juego. Está en Shared porque el servidor las guarda (Profiles) y el
-- cliente las muestra (lobby y resultados) leyendo los atributos del Player con el mismo Id.
--
-- Para agregar una moneda: sumala acá. El perfil la crea en 0 para todos (también para los
-- perfiles ya guardados) y la interfaz la muestra sola.

export type Currency = {
	Id: string, -- nombre del atributo del Player y clave en el perfil (no cambiar una vez publicado)
	Name: string,
	Icon: string,
	Color: Color3,
}

local list: { Currency } = {
	{ Id = "Gold", Name = "Oro", Icon = "💰", Color = Color3.fromRGB(246, 208, 122) },
	{ Id = "Gems", Name = "Gemas", Icon = "💎", Color = Color3.fromRGB(130, 210, 255) },
	{ Id = "Stones", Name = "Piedras de mejora", Icon = "🔷", Color = Color3.fromRGB(150, 160, 255) },
}

return list
