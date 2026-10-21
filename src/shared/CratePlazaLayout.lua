--!strict
-- CratePlazaLayout (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > CratePlazaLayout
-- Dónde queda la plaza volcánica de las cajas y cada plataforma. Lo calculan igual el servidor
-- (CratePlaza la construye, CrateService revisa que estés cerca) y el cliente (luz de la zona).
-- Se arma con Config.Lobby (la plaza va pegada al muro este del lobby) y Config.Crates.Plaza.

local Config = require(script.Parent.Config)
local Crates = require(script.Parent.Crates)

export type Station = { Id: string, Type: string, Top: CFrame, Position: Vector3 }
export type Layout = {
	Center: Vector3, -- centro del piso (a la altura del piso)
	Size: Vector3,
	DoorCenter: Vector3, -- centro de la puerta en el muro del lobby
	DoorWidth: number,
	LobbyWallX: number, -- X del muro este del lobby
	Stations: { Station },
}

local CratePlazaLayout = {}

local TIER = 0.8 -- alto de cada escalón de la plataforma (son 2)
CratePlazaLayout.PlatformHeight = TIER * 2

function CratePlazaLayout.get(): Layout
	local lobby = Config.Lobby
	local cfg = Config.Crates.Plaza
	local lobbyHalfX = lobby.Size.X / 2
	local center = Vector3.new(lobby.Center.X + lobbyHalfX + 1 + cfg.Size.X / 2, lobby.Center.Y, lobby.Center.Z + cfg.DoorZ)
	local stations = {}
	local crates: { Crates.Crate }, eggs: { Crates.Crate } = {}, {}
	for _, crate in Crates.List do
		table.insert(if Crates.isEgg(crate) then eggs else crates, crate)
	end
	local y = center.Y + CratePlazaLayout.PlatformHeight
	-- Cofres de skins: fila contra el muro del fondo (este), de frente a la puerta
	local rowX = center.X + cfg.Size.X / 2 - 16
	for i, crate in crates do
		local pos = Vector3.new(rowX, y, center.Z + (i - (#crates + 1) / 2) * cfg.StationSpacing)
		table.insert(stations, { Id = crate.Id, Type = crate.Type, Top = CFrame.lookAt(pos, pos + Vector3.new(-1, 0, 0)), Position = pos })
	end
	-- Huevos de mascotas: fila contra el muro sur, de frente al centro de la plaza
	local rowZ = center.Z - cfg.Size.Z / 2 + 16
	local eggCenterX = center.X - 12
	for i, crate in eggs do
		local pos = Vector3.new(eggCenterX + (i - (#eggs + 1) / 2) * cfg.StationSpacing, y, rowZ)
		table.insert(stations, { Id = crate.Id, Type = crate.Type, Top = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)), Position = pos })
	end
	return {
		Center = center,
		Size = cfg.Size,
		DoorCenter = Vector3.new(lobby.Center.X + lobbyHalfX + 0.5, lobby.Center.Y, center.Z),
		DoorWidth = cfg.DoorWidth,
		LobbyWallX = lobby.Center.X + lobbyHalfX + 0.5,
		Stations = stations,
	}
end

-- ¿La posición está dentro de la plaza? (con un margen en studs)
function CratePlazaLayout.contains(layout: Layout, pos: Vector3, margin: number?): boolean
	local m = margin or 0
	local d = pos - layout.Center
	return math.abs(d.X) <= layout.Size.X / 2 + m and math.abs(d.Z) <= layout.Size.Z / 2 + m and d.Y > -20 and d.Y < 80
end

return CratePlazaLayout
